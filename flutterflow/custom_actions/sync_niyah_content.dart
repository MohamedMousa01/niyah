// Niyah — sincronizzazione incrementale dei contenuti pubblici (architettura §8.1).
// Nome dell'azione in FlutterFlow: syncNiyahContent
// Parametri:
//   language (String)  lingua attiva: it | en | ar | fr
//   force    (bool)    ignora l'attesa dopo un errore (es. tirando giù per aggiornare)
// Restituisce (String): "up_to_date" | "updated" | "offline" | "waiting" | "error"
//
// Va chiamata DOPO che la Home è visibile, mai prima: l'app funziona sempre con
// i dati locali. Costo tipico quando non c'è nulla di nuovo: 1 lettura.
// Dopo "updated" chiamare rescheduleAllNotifications (possono esserci nuovi
// contenuti o modelli).
//
// Requisiti lato backend (Cloud Functions, vedi firebase/README.md):
// - ogni scrittura su contenuti/argomenti/modelli/eventi aggiorna `updatedAt`
//   e incrementa meta/contentVersion.version.<lingua>;
// - la modifica di una traduzione aggiorna anche `updatedAt` del contenuto;
// - un documento non più pubblicato o disattivato produce un documento in
//   `tombstones` {collection, docId, removedAt} (+ topicId e contentId per
//   topicContent), perché le regole impediscono
//   al client di vedere i documenti non pubblicati.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm, Transaction;

import '/custom_code/actions/niyah_runtime.dart';

const _pageSize = 100;
const _serverOnly = GetOptions(source: Source.server);
const _timeout = Duration(seconds: 20);
const _backoff = [Duration(hours: 1), Duration(hours: 6), Duration(hours: 24)];

Future<String> syncNiyahContent(String language, bool force) {
  final rt = NiyahRuntime.instance;
  return rt.serialized(() async {
    final lang = const {'it', 'en', 'ar', 'fr'}.contains(language) ? language : 'it';

    // Attesa crescente dopo un errore, per non consumare batteria e dati.
    if (!force) {
      final failures = int.tryParse(await rt.meta('sync_failures') ?? '') ?? 0;
      final lastFail = DateTime.tryParse(await rt.meta('sync_last_failure') ?? '');
      if (failures > 0 && lastFail != null) {
        final wait = _backoff[(failures - 1).clamp(0, _backoff.length - 1)];
        if (DateTime.now().toUtc().difference(lastFail) < wait) return 'waiting';
      }
    }

    try {
      final result = await _sync(rt, FirebaseFirestore.instance, lang).timeout(_timeout * 6);
      await rt.setMeta('sync_failures', '0');
      return result;
    } on FirebaseException catch (e) {
      await _recordFailure(rt);
      return e.code == 'unavailable' ? 'offline' : 'error';
    } on TimeoutException {
      await _recordFailure(rt);
      return 'offline';
    } catch (_) {
      await _recordFailure(rt);
      return 'error';
    }
  });
}

Future<void> _recordFailure(NiyahRuntime rt) async {
  final failures = int.tryParse(await rt.meta('sync_failures') ?? '') ?? 0;
  await rt.setMeta('sync_failures', '${failures + 1}');
  await rt.setMeta('sync_last_failure', DateTime.now().toUtc().toIso8601String());
}

Future<String> _sync(NiyahRuntime rt, FirebaseFirestore fs, String lang) async {
  final meta = await fs.doc('meta/contentVersion').get(_serverOnly).timeout(_timeout);
  final remoteVersion = '${(meta.data()?['version'] as Map?)?[lang] ?? 0}';
  final localVersion = await rt.meta('content_version_$lang');
  final contentLang = await rt.meta('content_lang');
  if (localVersion == remoteVersion && contentLang == lang) return 'up_to_date';

  // Cambio lingua: le traduzioni scaricate sono di un'altra lingua → si
  // riscaricano i contenuti (le altre collezioni hanno già tutte le lingue).
  if (contentLang != null && contentLang != lang) {
    await rt.setMeta('last_sync_contentItems', null);
  }

  var changed = 0;

  changed += await _pull(rt, fs, 'categories', 'active', true, (tx, id, d, _) async {
    await tx.insert('categories', {
      'id': id, 'parent_id': d['parentId'], 'icon': d['icon'], 'sort': d['order'] ?? 0,
      'active': 1, 'updated_at': _iso(d['updatedAt']),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _names(tx, 'category_i18n', 'category_id', id, d['names']);
  });

  changed += await _pull(rt, fs, 'topics', 'active', true, (tx, id, d, _) async {
    await tx.insert('topics', {'id': id, 'icon': d['icon'], 'sort': d['order'] ?? 0, 'active': 1, 'updated_at': _iso(d['updatedAt'])},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _names(tx, 'topic_i18n', 'topic_id', id, d['names']);
  });

  changed += await _pull(
    rt, fs, 'contentItems', 'status', 'published',
    // Solo la traduzione pubblicata nella lingua attiva. Nessun ripiego
    // silenzioso su un'altra lingua (§24): senza traduzione il contenuto non c'è.
    prefetch: (id, d) async {
      final tr = await fs.doc('contentItems/$id/translations/$lang').get(_serverOnly).timeout(_timeout);
      return tr.data();
    },
    (tx, id, d, extra) async {
      await _deleteContent(tx, id);
      final t = extra as Map<String, dynamic>?;
      if (t == null || t['status'] != 'published') return;
      await tx.insert('content_items', {
        'id': id, 'type': d['type'], 'arabic_text': d['arabicText'], 'surah': d['surah'],
        'ayah_from': d['ayahFrom'], 'ayah_to': d['ayahTo'], 'collection': d['collection'],
        'hadith_number': d['hadithNumber'], 'grade': d['grade'], 'source_ref': d['sourceRef'],
        'status': 'published', 'updated_at': _iso(d['updatedAt']),
      });
      await tx.insert('content_i18n', {
        'content_id': id, 'lang': lang, 'text': t['text'], 'reference_label': t['referenceLabel'],
        'translator': t['translator'], 'translation_source': t['translationSource'], 'updated_at': _iso(t['updatedAt']),
      });
      for (final c in (d['categoryIds'] as List?) ?? const []) {
        await tx.insert('content_categories', {'content_id': id, 'category_id': '$c'},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    },
  );

  changed += await _pull(rt, fs, 'topicContent', 'active', true, (tx, id, d, _) async {
    await tx.insert('topic_content', {'topic_id': d['topicId'], 'content_id': d['contentId'], 'sort': d['order'] ?? 0},
        conflictAlgorithm: ConflictAlgorithm.replace);
  });

  changed += await _pull(rt, fs, 'notificationTemplates', 'active', true, (tx, id, d, _) async {
    await tx.insert('templates', {
      'id': id, 'category_id': d['categoryId'], 'section': d['section'] ?? 'suggested',
      'content_type': d['contentType'], 'channel': d['channel'] ?? 'niyyah',
      'default_schedule_json': jsonEncode(d['defaultSchedule'] ?? {}), 'source_content_id': d['sourceContentId'],
      'editable': d['editableByUser'] == false ? 0 : 1, 'seasonal': d['seasonal'] == true ? 1 : 0,
      'active': 1, 'updated_at': _iso(d['updatedAt']),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final i18n = (d['i18n'] as Map?) ?? const {};
    await tx.delete('template_i18n', where: 'template_id = ?', whereArgs: [id]);
    for (final e in i18n.entries) {
      final v = e.value as Map;
      await tx.insert('template_i18n', {'template_id': id, 'lang': '${e.key}', 'title': v['title'], 'body': v['body']});
    }
  });

  changed += await _pull(rt, fs, 'islamicEvents', 'active', true, (tx, id, d, _) async {
    await tx.insert('events', {
      'id': id, 'type': d['type'], 'start_date': _iso(d['startDate']).substring(0, 10),
      'end_date': _iso(d['endDate']).substring(0, 10), 'hijri_json': jsonEncode(d['hijri'] ?? {}),
      'active': 1, 'updated_at': _iso(d['updatedAt']),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await tx.delete('event_i18n', where: 'event_id = ?', whereArgs: [id]);
    for (final e in ((d['i18n'] as Map?) ?? const {}).entries) {
      final v = e.value as Map;
      await tx.insert('event_i18n', {'event_id': id, 'lang': '${e.key}', 'name': v['name'], 'description': v['description']});
    }
    await tx.delete('event_templates', where: 'event_id = ?', whereArgs: [id]);
    for (final t in (d['notificationTemplateRefs'] as List?) ?? const []) {
      await tx.insert('event_templates', {'event_id': id, 'template_id': '$t'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  });

  changed += await _applyTombstones(rt, fs);

  await rt.setMeta('content_version_$lang', remoteVersion);
  await rt.setMeta('content_lang', lang);
  await rt.setMeta('last_content_sync', DateTime.now().toUtc().toIso8601String());
  return changed > 0 ? 'updated' : 'up_to_date';
}

/// Scarica a pagine i documenti cambiati dopo l'ultima sincronizzazione di
/// [collection], filtrati come richiedono le regole ([field] == [value]).
Future<int> _pull(
  NiyahRuntime rt,
  FirebaseFirestore fs,
  String collection,
  String field,
  Object value,
  Future<void> Function(Transaction tx, String id, Map<String, dynamic> data, Object? extra) apply, {
  Future<Object?> Function(String id, Map<String, dynamic> data)? prefetch,
}) async {
  final key = 'last_sync_$collection';
  final since = DateTime.tryParse(await rt.meta(key) ?? '');
  var q = fs.collection(collection).where(field, isEqualTo: value).orderBy('updatedAt').limit(_pageSize);
  if (since != null) q = q.where('updatedAt', isGreaterThan: Timestamp.fromDate(since));

  final db = await rt.database();
  var count = 0;
  DocumentSnapshot<Map<String, dynamic>>? last;
  while (true) {
    final page = await (last == null ? q : q.startAfterDocument(last)).get(_serverOnly).timeout(_timeout);
    if (page.docs.isEmpty) break;
    // Prima tutte le letture di rete, poi un'unica transazione SQLite per
    // pagina (mai una transazione aperta durante una richiesta di rete).
    final extras = <Object?>[];
    for (final doc in page.docs) {
      extras.add(prefetch == null ? null : await prefetch(doc.id, doc.data()));
    }
    await db.transaction((tx) async {
      for (var i = 0; i < page.docs.length; i++) {
        await apply(tx, page.docs[i].id, page.docs[i].data(), extras[i]);
      }
    });
    count += page.docs.length;
    last = page.docs.last;
    await rt.setMeta(key, _iso(page.docs.last.data()['updatedAt']));
    if (page.docs.length < _pageSize) break;
  }
  return count;
}

Future<int> _applyTombstones(NiyahRuntime rt, FirebaseFirestore fs) async {
  const tables = {
    'categories': ('categories', 'id'),
    'topics': ('topics', 'id'),
    'notificationTemplates': ('templates', 'id'),
    'islamicEvents': ('events', 'id'),
  };
  final since = DateTime.tryParse(await rt.meta('last_sync_tombstones') ?? '');
  var q = fs.collection('tombstones').orderBy('removedAt').limit(500);
  if (since != null) q = q.where('removedAt', isGreaterThan: Timestamp.fromDate(since));
  final page = await q.get(_serverOnly).timeout(_timeout);
  if (page.docs.isEmpty) return 0;
  final db = await rt.database();
  await db.transaction((tx) async {
    for (final doc in page.docs) {
      final d = doc.data();
      final coll = d['collection'] as String?;
      final id = d['docId'] as String?;
      if (id == null) continue;
      if (coll == 'topicContent') {
        // La tombstone di un collegamento porta topicId e contentId.
        final topicId = d['topicId'], contentId = d['contentId'];
        if (topicId is String && contentId is String) {
          await tx.delete('topic_content', where: 'topic_id = ? AND content_id = ?', whereArgs: [topicId, contentId]);
        }
        continue;
      }
      if (coll == 'contentItems') {
        await _deleteContent(tx, id);
        continue;
      }
      final t = tables[coll];
      if (t != null) await tx.delete(t.$1, where: '${t.$2} = ?', whereArgs: [id]);
    }
  });
  await rt.setMeta('last_sync_tombstones', _iso(page.docs.last.data()['removedAt']));
  return page.docs.length;
}

/// Le chiavi esterne di SQLite non sono attive su questa connessione:
/// le righe collegate si eliminano esplicitamente.
Future<void> _deleteContent(Transaction tx, String id) async {
  await tx.delete('content_i18n', where: 'content_id = ?', whereArgs: [id]);
  await tx.delete('content_categories', where: 'content_id = ?', whereArgs: [id]);
  await tx.delete('content_items', where: 'id = ?', whereArgs: [id]);
}

Future<void> _names(Transaction tx, String table, String fk, String id, Object? names) async {
  await tx.delete(table, where: '$fk = ?', whereArgs: [id]);
  for (final e in ((names as Map?) ?? const {}).entries) {
    await tx.insert(table, {fk: id, 'lang': '${e.key}', 'name': '${e.value}'});
  }
}

String _iso(Object? v) {
  if (v is Timestamp) return v.toDate().toUtc().toIso8601String();
  if (v is DateTime) return v.toUtc().toIso8601String();
  if (v is String) return v;
  return DateTime.now().toUtc().toIso8601String();
}
