import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/data/sqlite/niyah_database.dart';
import 'package:niyah/data/sqlite/sqlite_reminder_repository.dart';
import 'package:niyah/data/sqlite/sqlite_template_repository.dart';
import 'package:niyah/data/sync/content_source.dart';
import 'package:niyah/data/sync/content_sync.dart';

import 'fake_content_source.dart';
import 'sqlite_test_utils.dart';

final t0 = DateTime.utc(2026, 10, 1);

/// A `notificationTemplates` document as the rules accept it (+ groupKey, icon).
Map<String, Object?> template(DateTime at,
        {String title = 'New moment', bool active = true, Object? i18n, Object? schedule, String channel = 'niyyah'}) =>
    {
      'active': active, 'updatedAt': at, 'section': 'suggested', 'channel': channel, 'groupKey': 'daily', 'icon': 'heart',
      'defaultSchedule': schedule ?? {'schedule_type': 'daily', 'time': '10:30', 'days_mask': 127},
      'i18n': i18n ?? {'en': {'title': title, 'body': 'Body'}, 'it': {'title': 'Nuovo momento', 'body': 'Testo'}},
    };

void main() {
  final temp = TempDb()..setUpEach();
  late NiyahDatabase db;
  late FakeContentSource source;
  late DateTime now;
  late ContentSync sync;

  setUp(() async {
    db = await temp.open();
    source = FakeContentSource();
    now = t0.add(const Duration(days: 1));
    sync = ContentSync(db, source, clock: () => now);
  });

  Future<SqliteTemplateRepository> templates() async {
    final repo = SqliteTemplateRepository(db);
    await repo.init();
    return repo;
  }

  Future<String?> meta(String key) async {
    final rows = await db.db.query('sync_meta', where: 'key = ?', whereArgs: ['${ContentSync.metaPrefix}$key']);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  group('templates', () {
    test('a template added in Firestore is offered in "Add a reminder", in each language', () async {
      source
        ..put('notificationTemplates', 'new_moment', template(t0))
        ..bump();
      expect(await sync.run('en'), ContentSyncResult.updated);

      final repo = await templates();
      final added = repo.templates('en').last;
      expect(added.id, 'new_moment');
      expect(added.title, 'New moment');
      expect(added.group, TemplateGroup.daily);
      expect(added.defaultSchedule, isA<TimeSchedule>().having((s) => s.time.toString(), 'time', '10:30'));
      expect(repo.templates('it').last.title, 'Nuovo momento');
    });

    test('when nothing changed, a run reads only the version', () async {
      source
        ..put('notificationTemplates', 'new_moment', template(t0))
        ..bump();
      await sync.run('en');
      source.requests.clear();
      expect(await sync.run('en'), ContentSyncResult.upToDate);
      expect(source.requests, ['version']);
    });

    test('an updated seed template keeps its place in the list', () async {
      final before = (await templates()).templates('en').map((t) => t.id).toList();
      source
        ..put('notificationTemplates', 'niyyah_work', template(t0, title: 'Work, renewed'))
        ..bump();
      await sync.run('en');
      final repo = await templates();
      expect(repo.templates('en').map((t) => t.id), before);
      expect(repo.byId('niyyah_work', 'en')!.title, 'Work, renewed');
    });

    test('a withdrawn template leaves the list but keeps working for who added it', () async {
      source
        ..put('notificationTemplates', 'new_moment', template(t0))
        ..bump();
      await sync.run('en');

      source
        ..put('notificationTemplates', 'new_moment', template(t0.add(const Duration(hours: 1)), active: false))
        ..put('tombstones', 'a', {'collection': 'notificationTemplates', 'docId': 'new_moment', 'removedAt': t0.add(const Duration(hours: 1))})
        ..bump();
      expect(await sync.run('en'), ContentSyncResult.updated);

      final repo = await templates();
      expect(repo.templates('en').map((t) => t.id), isNot(contains('new_moment')));
      expect(repo.byId('new_moment', 'en')!.title, 'New moment');
    });

    test('tombstones go first: a template withdrawn then published again stays', () async {
      source
        ..put('tombstones', 'a', {'collection': 'notificationTemplates', 'docId': 'back', 'removedAt': t0})
        ..put('notificationTemplates', 'back', template(t0.add(const Duration(hours: 1))))
        ..bump();
      await sync.run('en');
      expect((await templates()).templates('en').map((t) => t.id), contains('back'));
    });

    test('a document the app cannot store is skipped and the rest goes on', () async {
      source
        ..put('notificationTemplates', 'niyyah_work', template(t0, i18n: {'de': {'title': 'Arbeit', 'body': '…'}}))
        ..put('notificationTemplates', 'bad_schedule', template(t0, schedule: {'schedule_type': 'sometimes'}))
        ..put('notificationTemplates', 'good', template(t0))
        ..bump();
      expect(await sync.run('en'), ContentSyncResult.updated);
      final ids = (await templates()).templates('en').map((t) => t.id);
      expect(ids, contains('good'));
      expect(ids, isNot(contains('bad_schedule')));
      // A template that can no longer be stored is withdrawn, not left stale.
      expect(ids, isNot(contains('niyyah_work')));
    });

    test('a reminder from a template added after start-up gets its channel', () async {
      final reminders = SqliteReminderRepository(db);
      await reminders.init();
      source
        ..put('notificationTemplates', 'new_moment', template(t0, channel: 'dhikr'))
        ..bump();
      await sync.run('en');
      await reminders.save(const ReminderItem(
          id: 'r1', source: ReminderSource.template, templateId: 'new_moment', schedule: TimeSchedule(LocalTime(10, 30))));
      final row = (await db.db.query('reminders', where: "id = 'r1'")).single;
      expect(row['channel'], 'dhikr');
    });
  });

  group('paging', () {
    test('pages share a timestamp without losing documents, and an interrupted run resumes', () async {
      sync = ContentSync(db, source, clock: () => now, pageSize: 2);
      for (var i = 0; i < 5; i++) {
        source.put('notificationTemplates', 'batch_$i', template(t0));
      }
      source.bump();
      var pages = 0;
      source.onRequest = (r) {
        if (r == 'page notificationTemplates' && ++pages == 2) throw StateError('connection reset');
      };
      expect(await sync.run('en'), ContentSyncResult.error);
      expect(await db.db.query('templates', where: "id LIKE 'batch_%'"), hasLength(2));

      source
        ..onRequest = null
        ..requests.clear();
      expect(await sync.run('en', force: true), ContentSyncResult.updated);
      final ids = (await templates()).templates('en').map((t) => t.id);
      expect(ids.where((id) => id.startsWith('batch_')), ['batch_0', 'batch_1', 'batch_2', 'batch_3', 'batch_4']);
      // Resumed after batch_1: two more pages (batch_2-3, batch_4).
      expect(source.requests.where((r) => r == 'page notificationTemplates'), hasLength(2));
    });
  });

  group('failures', () {
    test('offline: nothing changes, then 1 h, 6 h and 24 h of waiting', () async {
      source
        ..put('notificationTemplates', 'new_moment', template(t0))
        ..bump()
        ..onRequest = (_) => throw const ContentOffline();
      expect(await sync.run('en'), ContentSyncResult.offline);
      expect((await templates()).byId('new_moment', 'en'), isNull);

      Future<ContentSyncResult> after(Duration d) {
        now = now.add(d);
        return sync.run('en');
      }

      expect(await after(const Duration(minutes: 59)), ContentSyncResult.waiting);
      expect(await after(const Duration(minutes: 2)), ContentSyncResult.offline); // 2nd failure
      expect(await after(const Duration(hours: 5)), ContentSyncResult.waiting);
      expect(await after(const Duration(hours: 2)), ContentSyncResult.offline); // 3rd failure
      expect(await after(const Duration(hours: 23)), ContentSyncResult.waiting);
      expect(await after(const Duration(hours: 2)), ContentSyncResult.offline); // 4th: still 24 h
      expect(await after(const Duration(hours: 23)), ContentSyncResult.waiting);

      source.onRequest = null;
      expect(await sync.run('en', force: true), ContentSyncResult.updated);
      expect(await meta('failures'), isNull);
    });

    test('an unexpected error is reported, never thrown', () async {
      source
        ..bump()
        ..onRequest = (_) => throw StateError('boom');
      expect(await sync.run('en'), ContentSyncResult.error);
      expect(await meta('failures'), '1');
    });

    test('calls made while a run is going share it', () async {
      source.bump();
      final results = await Future.wait([sync.run('en'), sync.run('en')]);
      expect(results, [ContentSyncResult.upToDate, ContentSyncResult.upToDate]);
      expect(source.requests.where((r) => r == 'version'), hasLength(1));
    });
  });

  group('verses and hadith', () {
    void putContent() {
      source
        ..put('contentItems', 'q1', {
          'type': 'quran', 'status': 'published', 'updatedAt': t0, 'surah': 2, 'ayahFrom': 286,
          'arabicText': 'لَا يُكَلِّفُ ٱللَّهُ نَفْسًا إِلَّا وُسْعَهَا', 'categoryIds': ['patience'],
        })
        ..put('contentItems', 'h1', {
          'type': 'hadith', 'status': 'published', 'updatedAt': t0, 'collection': 'bukhari',
          'sourceRef': 'Bukhari 1', 'grade': 'sahih', 'hadithNumber': 1,
        })
        ..bump();
      source.translations['q1'] = {
        'en': {'status': 'published', 'text': 'Allah does not burden a soul beyond that it can bear.',
          'referenceLabel': 'Al-Baqarah 2:286', 'translator': 'Sahih International', 'translationSource': 'quran.com', 'updatedAt': t0},
        'fr': {'status': 'draft', 'text': '…', 'updatedAt': t0},
      };
      source.translations['h1'] = {
        'it': {'status': 'published', 'text': 'Le azioni valgono per le intenzioni.', 'referenceLabel': 'Bukhari 1',
          'translator': 'Redazione', 'translationSource': 'interna', 'updatedAt': t0},
      };
    }

    Future<List<String>> stored(String lang) async => [
          for (final r in await db.db.rawQuery(
              'SELECT c.id FROM content_items c JOIN content_i18n i ON i.content_id = c.id WHERE i.lang = ? ORDER BY c.id', [lang]))
            r['id'] as String,
        ];

    test('only items translated in the app language, with no fallback to another one', () async {
      putContent();
      await sync.run('en');
      expect(await stored('en'), ['q1']);
      expect(await db.db.query('content_items'), hasLength(1));
      expect(await db.db.query('content_categories', where: "content_id = 'q1'"), hasLength(1));
    });

    test('a new language downloads the content again in that language', () async {
      putContent();
      await sync.run('en');
      expect(await sync.run('it'), ContentSyncResult.updated);
      expect(await stored('it'), ['h1']);
      expect(await stored('en'), isEmpty);
    });

    test('a withdrawn item is removed', () async {
      putContent();
      await sync.run('en');
      source.collections['contentItems']!.remove('q1');
      source
        ..put('tombstones', 'a', {'collection': 'contentItems', 'docId': 'q1', 'removedAt': t0.add(const Duration(hours: 1))})
        ..bump();
      await sync.run('en');
      expect(await db.db.query('content_items'), isEmpty);
      expect(await db.db.query('content_i18n', where: "content_id = 'q1'"), isEmpty);
    });
  });

  test('categories and events arrive with their names', () async {
    source
      ..put('categories', 'patience', {'active': true, 'updatedAt': t0, 'icon': 'leaf', 'order': 3,
        'names': {'en': 'Patience', 'it': 'Pazienza', 'de': 'Geduld'}})
      ..put('islamicEvents', 'ramadan_2027', {'active': true, 'updatedAt': t0, 'type': 'ramadan',
        'startDate': DateTime.utc(2027, 2, 8), 'endDate': '2027-03-09', 'i18n': {'en': {'name': 'Ramadan'}},
        'notificationTemplateRefs': ['niyyah_work']})
      ..bump();
    await sync.run('en');
    expect((await db.db.query('category_i18n', where: "category_id = 'patience'")).map((r) => r['lang']),
        unorderedEquals(['en', 'it']));
    final event = (await db.db.query('events', where: "id = 'ramadan_2027'")).single;
    expect([event['start_date'], event['end_date']], ['2027-02-08', '2027-03-09']);
    expect(await db.db.query('event_templates', where: "event_id = 'ramadan_2027'"), hasLength(1));
  });
}
