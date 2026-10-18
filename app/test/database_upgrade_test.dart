import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/niyah_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support.dart';

const _now = '2026-10-01T00:00:00Z';

/// Database con lo schema di seed/schema.sql; [oldSchema] simula un telefono
/// installato con la versione 1 (solo it/en/ar/fr).
Future<Database> _open(String path, {bool oldSchema = false}) async {
  var schema = File('../seed/schema.sql').readAsStringSync();
  if (oldSchema) {
    schema = schema
        .replaceAll("'it','en','ar','fr','es','de'", "'it','en','ar','fr'")
        .replaceAll('PRAGMA user_version = $kNiyahSchemaVersion;', 'PRAGMA user_version = 1;');
  }
  final db = await databaseFactoryFfiNoIsolate.openDatabase(path, options: OpenDatabaseOptions(singleInstance: false));
  for (final stmt in sqlStatements(schema)) {
    await db.execute(stmt);
  }
  return db;
}

Future<void> _template(Database db, String id, Map<String, String> titles) async {
  await db.insert('categories', {'id': 'niyyah', 'sort': 0, 'active': 1, 'updated_at': _now},
      conflictAlgorithm: ConflictAlgorithm.ignore);
  await db.insert('templates', {
    'id': id,
    'category_id': 'niyyah',
    'section': 'suggested',
    'channel': 'niyyah',
    'default_schedule_json': '{"schedule_type":"daily","time":"08:00"}',
    'editable': 1,
    'seasonal': 0,
    'active': 1,
    'updated_at': _now,
  });
  for (final e in titles.entries) {
    await db.insert('template_i18n', {'template_id': id, 'lang': e.key, 'title': e.value, 'body': e.value});
  }
}

void main() {
  late Directory dir;

  setUp(() {
    sqfliteFfiInit();
    dir = Directory.systemTemp.createTempSync('niyah_db');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('un telefono con lo schema vecchio riceve il catalogo nuovo e tiene i promemoria', () async {
    final seed = await _open('${dir.path}/seed.db');
    await _template(seed, 'morning', {'it': 'Mattino', 'es': 'Mañana', 'de': 'Morgen'});
    await seed.close();

    final phone = await _open('${dir.path}/phone.db', oldSchema: true);
    await _template(phone, 'old', {'it': 'Vecchio'});
    await phone.insert('reminders', {
      'id': 'r1',
      'kind': 'personal',
      'body': 'Chiama la mamma',
      'schedule_type': 'daily',
      'time': '09:00',
      'start_date': '2026-10-01',
      'created_at': _now,
      'updated_at': _now,
    });
    await phone.insert('sync_meta', {'key': 'last_timezone', 'value': 'Europe/Rome'});
    // Prima dell'aggiornamento lo spagnolo non entra nemmeno.
    await expectLater(
      phone.insert('template_i18n', {'template_id': 'old', 'lang': 'es', 'title': 'x', 'body': 'x'}),
      throwsA(anything),
    );

    await NiyahDatabase.upgradeCatalog(phone, '${dir.path}/seed.db');

    expect((await phone.rawQuery('PRAGMA user_version')).first.values.first, kNiyahSchemaVersion);
    final titles = await phone.query('template_i18n', where: "template_id = 'morning'", orderBy: 'lang');
    expect(titles.map((r) => r['lang']), ['de', 'es', 'it']);
    expect(await phone.query('templates', where: "id = 'old'"), isEmpty);
    final reminders = await phone.query('reminders');
    expect(reminders.single['body'], 'Chiama la mamma');
    expect(await NiyahDatabase(phone).meta('last_timezone'), 'Europe/Rome');
    // Il trigger sulle tabelle dell'utente c'è ancora, e una sola volta.
    final triggers = await phone.rawQuery("SELECT name FROM sqlite_master WHERE type = 'trigger'");
    expect(triggers, hasLength(1));
    await phone.close();
  });
}
