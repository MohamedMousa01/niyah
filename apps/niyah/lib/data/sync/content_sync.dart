import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';

import '../sqlite/niyah_database.dart';
import '../sqlite/schedule_codec.dart';
import 'content_source.dart';

enum ContentSyncResult { upToDate, updated, offline, waiting, error }

/// Incremental download of the curated content into SQLite (architettura
/// §8.1): categories, topics, verses/hadith, notification templates, events.
///
/// The app always works from SQLite; this only adds to it. Run it after the
/// first frame, never before. When nothing changed it costs one read
/// (`meta/contentVersion`). After [ContentSyncResult.updated], reload the
/// templates and reschedule the notifications.
///
/// - Tombstones first, then the changed documents: content withdrawn and
///   published again is removed and downloaded again, not lost.
/// - Each collection is pulled in pages ordered by `updatedAt` then id; the
///   cursor is saved after every page, so an interrupted run resumes there.
/// - Verses and hadith come only in the app language: no silent fallback to
///   another language (§24). Without a translation the item is not there.
/// - After a failure the next runs wait 1 h, then 6 h, then 24 h.
/// - A withdrawn template, category, topic or event is made inactive, not
///   deleted: reminders the user already added keep their texts.
class ContentSync {
  ContentSync(this._db, this._source, {DateTime Function()? clock, this.pageSize = 100})
      : _clock = clock ?? DateTime.now;

  final NiyahDatabase _db;
  final ContentSource _source;
  final DateTime Function() _clock;
  final int pageSize;
  Future<ContentSyncResult>? _running;

  /// Languages of the `*_i18n` tables.
  static const languages = {'it', 'en', 'ar', 'fr'};
  static const backoff = [Duration(hours: 1), Duration(hours: 6), Duration(hours: 24)];

  /// Prefix of every `sync_meta` key written here (cleared by migrations).
  static const metaPrefix = NiyahDatabase.contentSyncMetaPrefix;
  static const _failuresKey = '${metaPrefix}failures';
  static const _lastFailureKey = '${metaPrefix}last_failure';
  static const _languageKey = '${metaPrefix}language';
  static const _lastSyncKey = '${metaPrefix}last_sync';
  static String _versionKey(String lang) => '${metaPrefix}version.$lang';
  static String _cursorKey(String collection) => '${metaPrefix}cursor.$collection';

  static const _templateSections = {'suggested', 'content', 'weekly', 'seasonal'};
  static const _templateGroups = {'prayer', 'daily', 'dhikr', 'weekly'};
  static const _contentTypes = {'quran', 'hadith', 'dhikr'};

  /// Syncs the content of [language] (one of [languages]). [force] skips the
  /// wait after a failure (e.g. pull to refresh). Never throws; concurrent
  /// calls share one run.
  Future<ContentSyncResult> run(String language, {bool force = false}) {
    if (!languages.contains(language)) throw ArgumentError.value(language, 'language');
    return _running ??= _run(language, force).whenComplete(() => _running = null);
  }

  Future<ContentSyncResult> _run(String lang, bool force) async {
    try {
      if (!force && await _waiting()) return ContentSyncResult.waiting;
      // No overall timeout: each request has its own ([ContentSource]), and a
      // run cut short from outside would go on writing beside the next one.
      final changed = await _sync(lang);
      await _setMeta(_failuresKey, null);
      return changed ? ContentSyncResult.updated : ContentSyncResult.upToDate;
    } catch (e) {
      final offline = e is ContentOffline || e is TimeoutException;
      if (!offline) debugPrint('Content sync failed: $e');
      try {
        await _recordFailure();
      } catch (_) {
        // The database is gone (app closing): nothing to record.
      }
      return offline ? ContentSyncResult.offline : ContentSyncResult.error;
    }
  }

  Future<bool> _waiting() async {
    final failures = int.tryParse(await _meta(_failuresKey) ?? '') ?? 0;
    final last = DateTime.tryParse(await _meta(_lastFailureKey) ?? '');
    if (failures == 0 || last == null) return false;
    final wait = backoff[(failures - 1).clamp(0, backoff.length - 1)];
    return _clock().toUtc().difference(last) < wait;
  }

  Future<void> _recordFailure() async {
    final failures = int.tryParse(await _meta(_failuresKey) ?? '') ?? 0;
    await _setMeta(_failuresKey, '${failures + 1}');
    await _setMeta(_lastFailureKey, _clock().toUtc().toIso8601String());
  }

  Future<bool> _sync(String lang) async {
    final remoteVersion = '${(await _source.contentVersions())[lang] ?? 0}';
    final contentLang = await _meta(_languageKey);
    if (await _meta(_versionKey(lang)) == remoteVersion && contentLang == lang) return false;

    // New language: the downloaded translations are of another one, so the
    // content is downloaded again (the other collections carry every language).
    if (contentLang != null && contentLang != lang) await _setMeta(_cursorKey('contentItems'), null);

    var changed = await _pull('tombstones', null, null, 'removedAt', _applyTombstone);
    changed += await _pull('categories', 'active', true, 'updatedAt', _applyCategory);
    changed += await _pull('topics', 'active', true, 'updatedAt', _applyTopic);
    changed += await _pull('contentItems', 'status', 'published', 'updatedAt', _applyContent,
        prefetch: (doc) => _translation(doc.id, lang));
    changed += await _pull('topicContent', 'active', true, 'updatedAt', _applyTopicContent);
    changed += await _pull('notificationTemplates', 'active', true, 'updatedAt', _applyTemplate);
    changed += await _pull('islamicEvents', 'active', true, 'updatedAt', _applyEvent);

    await _setMeta(_versionKey(lang), remoteVersion);
    await _setMeta(_languageKey, lang);
    await _setMeta(_lastSyncKey, _clock().toUtc().toIso8601String());
    return changed > 0;
  }

  /// Applies every document of [collection] after the saved cursor, one
  /// SQLite transaction per page. Network reads (the page, then [prefetch]
  /// for each document) all happen before the transaction opens.
  Future<int> _pull(
    String collection,
    String? field,
    Object? value,
    String orderField,
    Future<void> Function(Transaction tx, RemoteDoc doc, Object? extra) apply, {
    Future<Object?> Function(RemoteDoc doc)? prefetch,
  }) async {
    final key = _cursorKey(collection);
    var cursor = await _meta(key);
    var count = 0;
    while (true) {
      final docs = await _source.page(collection,
          field: field, value: value, orderField: orderField, after: cursor, limit: pageSize);
      if (docs.isEmpty) break;
      final extras = [for (final d in docs) prefetch == null ? null : await prefetch(d)];
      cursor = docs.last.cursor;
      await _db.db.transaction((tx) async {
        for (var i = 0; i < docs.length; i++) {
          await apply(tx, docs[i], extras[i]);
        }
        await _setMetaIn(tx, key, cursor);
      });
      count += docs.length;
      if (docs.length < pageSize) break;
    }
    return count;
  }

  // ── Tombstones ────────────────────────────────────────────────────────

  static const _deactivated = {
    'categories': 'categories',
    'topics': 'topics',
    'notificationTemplates': 'templates',
    'islamicEvents': 'events',
  };

  Future<void> _applyTombstone(Transaction tx, RemoteDoc doc, Object? _) async {
    final d = doc.data;
    final collection = d['collection'], id = d['docId'];
    if (id is! String) return;
    if (collection == 'topicContent') {
      // A link's tombstone carries both ends.
      final topicId = d['topicId'], contentId = d['contentId'];
      if (topicId is String && contentId is String) {
        await tx.delete('topic_content', where: 'topic_id = ? AND content_id = ?', whereArgs: [topicId, contentId]);
      }
    } else if (collection == 'contentItems') {
      await _deleteContent(tx, id);
    } else if (_deactivated[collection] case final table?) {
      await _deactivate(tx, table, id);
    }
  }

  // ── Documents ─────────────────────────────────────────────────────────
  // A document the app cannot store (missing or wrong fields, e.g. written
  // from the console, which skips the rules) is treated as withdrawn: it is
  // logged and hidden, and the rest of the sync goes on.

  Future<void> _applyCategory(Transaction tx, RemoteDoc doc, Object? _) async {
    final d = doc.data;
    final names = _names(d['names']);
    if (names.isEmpty) return _invalid(tx, 'categories', doc, 'no names');
    await _upsert(tx, 'categories', {
      'id': doc.id, 'parent_id': _string(d['parentId']), 'icon': _string(d['icon']),
      'sort': _int(d['order']) ?? 0, 'active': 1, 'updated_at': _iso(d['updatedAt']),
    });
    await _replaceNames(tx, 'category_i18n', 'category_id', doc.id, names);
  }

  Future<void> _applyTopic(Transaction tx, RemoteDoc doc, Object? _) async {
    final d = doc.data;
    final names = _names(d['names']);
    if (names.isEmpty) return _invalid(tx, 'topics', doc, 'no names');
    await _upsert(tx, 'topics', {
      'id': doc.id, 'icon': _string(d['icon']), 'sort': _int(d['order']) ?? 0, 'active': 1,
      'updated_at': _iso(d['updatedAt']),
    });
    await _replaceNames(tx, 'topic_i18n', 'topic_id', doc.id, names);
  }

  /// The published translation in [lang] (its doc id is the language).
  Future<RemoteDoc?> _translation(String contentId, String lang) async {
    for (final t in await _source.publishedTranslations(contentId)) {
      if (t.id == lang) return t;
    }
    return null;
  }

  Future<void> _applyContent(Transaction tx, RemoteDoc doc, Object? extra) async {
    await _deleteContent(tx, doc.id);
    final translation = extra as RemoteDoc?;
    // Only the published translation in the app language (§24).
    if (translation == null || translation.data['status'] != 'published') return;
    final t = translation.data;
    final d = doc.data;
    final type = d['type'];
    final row = {
      'id': doc.id, 'type': type, 'arabic_text': _string(d['arabicText']), 'surah': _int(d['surah']),
      'ayah_from': _int(d['ayahFrom']), 'ayah_to': _int(d['ayahTo']), 'collection': _string(d['collection']),
      'hadith_number': d['hadithNumber'] is num || d['hadithNumber'] is String ? '${d['hadithNumber']}' : null,
      'grade': _string(d['grade']), 'source_ref': _string(d['sourceRef']), 'status': 'published',
      'updated_at': _iso(d['updatedAt']),
    };
    final text = _string(t['text']), label = _string(t['referenceLabel']);
    final problem = switch (type) {
      _ when !_contentTypes.contains(type) => 'type $type',
      'quran' when row['surah'] == null || row['ayah_from'] == null || row['arabic_text'] == null => 'verse fields',
      'hadith' when row['collection'] == null || row['source_ref'] == null || row['grade'] == null => 'hadith fields',
      _ when text == null || label == null => 'translation text',
      _ => null,
    };
    if (problem != null) return _invalid(tx, null, doc, problem);
    await tx.insert('content_items', row);
    await tx.insert('content_i18n', {
      'content_id': doc.id, 'lang': translation.id, 'text': text,
      'reference_label': label, 'translator': _string(t['translator']),
      'translation_source': _string(t['translationSource']), 'updated_at': _iso(t['updatedAt'] ?? d['updatedAt']),
    });
    for (final c in (d['categoryIds'] as List?) ?? const []) {
      if (c is String) {
        await tx.insert('content_categories', {'content_id': doc.id, 'category_id': c},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  Future<void> _applyTopicContent(Transaction tx, RemoteDoc doc, Object? _) async {
    final d = doc.data;
    final topicId = _string(d['topicId']), contentId = _string(d['contentId']);
    if (topicId == null || contentId == null) return _invalid(tx, null, doc, 'topicId/contentId');
    await tx.insert('topic_content', {'topic_id': topicId, 'content_id': contentId, 'sort': _int(d['order']) ?? 0},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _applyTemplate(Transaction tx, RemoteDoc doc, Object? _) async {
    final d = doc.data;
    final texts = <String, (String, String)>{
      if (d['i18n'] case final Map i18n)
        for (final e in i18n.entries)
          if (languages.contains(e.key))
            if (e.value case {'title': final String title, 'body': final String body}) '${e.key}': (title, body),
    };
    final section = d['section'] ?? 'suggested';
    final group = d['groupKey'];
    final schedule = d['defaultSchedule'];
    final problem = switch (()) {
      _ when texts.isEmpty => 'no title/body in ${languages.join('/')}',
      _ when !_templateSections.contains(section) => 'section $section',
      _ when group != null && !_templateGroups.contains(group) => 'groupKey $group',
      _ when schedule is! Map || !_validSchedule(schedule) => 'defaultSchedule $schedule',
      _ => null,
    };
    if (problem != null) return _invalid(tx, 'templates', doc, problem);
    await _upsert(tx, 'templates', {
      'id': doc.id, 'category_id': _string(d['categoryId']), 'section': section,
      'content_type': _string(d['contentType']), 'channel': _string(d['channel']) ?? 'niyyah',
      'default_schedule_json': jsonEncode(schedule), 'source_content_id': _string(d['sourceContentId']),
      'editable': d['editableByUser'] == false ? 0 : 1, 'seasonal': d['seasonal'] == true ? 1 : 0,
      'active': 1, 'updated_at': _iso(d['updatedAt']), 'group_key': group, 'icon': _string(d['icon']),
    });
    await tx.delete('template_i18n', where: 'template_id = ?', whereArgs: [doc.id]);
    for (final MapEntry(key: lang, value: (title, body)) in texts.entries) {
      await tx.insert('template_i18n', {'template_id': doc.id, 'lang': lang, 'title': title, 'body': body});
    }
  }

  Future<void> _applyEvent(Transaction tx, RemoteDoc doc, Object? _) async {
    final d = doc.data;
    final type = _string(d['type']), start = _date(d['startDate']), end = _date(d['endDate']);
    if (type == null || start == null || end == null) return _invalid(tx, 'events', doc, 'type/startDate/endDate');
    await _upsert(tx, 'events', {
      'id': doc.id, 'type': type, 'start_date': start, 'end_date': end, 'hijri_json': jsonEncode(d['hijri'] ?? {}),
      'active': 1, 'updated_at': _iso(d['updatedAt']),
    });
    await tx.delete('event_i18n', where: 'event_id = ?', whereArgs: [doc.id]);
    if (d['i18n'] case final Map i18n) {
      for (final e in i18n.entries) {
        if (e.value case {'name': final String name} when languages.contains(e.key)) {
          await tx.insert('event_i18n',
              {'event_id': doc.id, 'lang': e.key, 'name': name, 'description': _string((e.value as Map)['description'])});
        }
      }
    }
    await tx.delete('event_templates', where: 'event_id = ?', whereArgs: [doc.id]);
    for (final t in (d['notificationTemplateRefs'] as List?) ?? const []) {
      if (t is String) {
        await tx.insert('event_templates', {'event_id': doc.id, 'template_id': t},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Future<void> _invalid(Transaction tx, String? table, RemoteDoc doc, String problem) async {
    debugPrint('Content sync: skipped ${table ?? 'document'} ${doc.id} ($problem)');
    if (table != null) {
      await _deactivate(tx, table, doc.id);
    } else {
      await _deleteContent(tx, doc.id);
    }
  }

  static Future<void> _deactivate(Transaction tx, String table, String id) =>
      tx.update(table, {'active': 0}, where: 'id = ?', whereArgs: [id]);

  /// Update, else insert: an existing row keeps its rowid, which is the
  /// order of the templates on screen.
  static Future<void> _upsert(Transaction tx, String table, Map<String, Object?> row) async {
    final updated = await tx.update(table, row, where: 'id = ?', whereArgs: [row['id']]);
    if (updated == 0) await tx.insert(table, row);
  }

  /// SQLite foreign keys are off on this connection: linked rows are
  /// deleted explicitly.
  static Future<void> _deleteContent(Transaction tx, String id) async {
    await tx.delete('content_i18n', where: 'content_id = ?', whereArgs: [id]);
    await tx.delete('content_categories', where: 'content_id = ?', whereArgs: [id]);
    await tx.delete('content_items', where: 'id = ?', whereArgs: [id]);
  }

  static Map<String, String> _names(Object? names) => {
        if (names is Map)
          for (final e in names.entries)
            if (languages.contains(e.key) && e.value is String) '${e.key}': e.value as String,
      };

  static Future<void> _replaceNames(Transaction tx, String table, String fk, String id, Map<String, String> names) async {
    await tx.delete(table, where: '$fk = ?', whereArgs: [id]);
    for (final e in names.entries) {
      await tx.insert(table, {fk: id, 'lang': e.key, 'name': e.value});
    }
  }

  /// A schedule the app can show. Checked here: reading a stored row, the
  /// core quietly turns unknown values into defaults (e.g. daily at 08:00).
  static bool _validSchedule(Map schedule) {
    final ok = switch (schedule['schedule_type']) {
      'daily' || 'weekly' => schedule['time'] is String && RegExp(r'^\d{2}:\d{2}$').hasMatch(schedule['time'] as String),
      'prayer' => schedule['prayers_mask'] is int || schedule['prayer'] is String,
      'anchor' => schedule['anchor'] == 'wake' || schedule['anchor'] == 'sleep',
      _ => false,
    };
    if (!ok) return false;
    try {
      return scheduleFromJson({for (final e in schedule.entries) '${e.key}': e.value}) != null;
    } catch (_) {
      return false;
    }
  }

  static String? _string(Object? v) => v is String && v.isNotEmpty ? v : null;
  static int? _int(Object? v) => v is num ? v.toInt() : null;

  /// `updatedAt` is always a timestamp: [ContentSource.page] orders by it.
  static String _iso(Object? v) => v is DateTime ? v.toUtc().toIso8601String() : '$v';

  /// 'yyyy-MM-dd' from a timestamp or a string that starts with one.
  static String? _date(Object? v) {
    if (v is DateTime) return v.toUtc().toIso8601String().substring(0, 10);
    if (v is String && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(v)) return v.substring(0, 10);
    return null;
  }

  Future<String?> _meta(String key) async {
    final rows = await _db.db.query('sync_meta', columns: ['value'], where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _setMeta(String key, String? value) => _setMetaIn(_db.db, key, value);

  static Future<void> _setMetaIn(DatabaseExecutor db, String key, String? value) async {
    if (value == null) {
      await db.delete('sync_meta', where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert('sync_meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}
