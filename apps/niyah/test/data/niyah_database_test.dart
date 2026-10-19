import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/data/sqlite/niyah_database.dart';
import 'package:niyah/data/sqlite/sqlite_reminder_repository.dart';
import 'package:niyah/data/sqlite/sqlite_template_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sqlite_test_utils.dart';

Future<int> userVersion(Database db) async => (await db.rawQuery('PRAGMA user_version')).first.values.first as int;

Future<List<List<Object?>>> columns(Database db, String table) async => [
      for (final c in await db.rawQuery('PRAGMA table_info($table)')) [c['name'], c['type'], c['notnull'], c['dflt_value'], c['pk']],
    ];

void main() {
  final temp = TempDb()..setUpEach();

  group('first run', () {
    test('copies the seed and opens it at the current version', () async {
      expect(File(temp.path).existsSync(), isFalse);
      final db = await temp.open();
      expect(File(temp.path).existsSync(), isTrue);
      expect(await userVersion(db.db), NiyahDatabase.version);
      expect((await db.db.query('templates')).length, 18);
      expect(File('${temp.path}.tmp').existsSync(), isFalse);
    });

    test('later opens keep the user data (no second copy)', () async {
      final db = await temp.open();
      final repo = SqliteReminderRepository(db);
      await repo.init();
      await repo.save(const ReminderItem(id: 'x', source: ReminderSource.personal, title: 't', schedule: TimeSchedule(LocalTime(8, 0))));
      await db.close();
      var loads = 0;
      final again = await temp.open(seed: () {
        loads++;
        return loadSeed();
      });
      expect(loads, 0);
      expect((await again.db.query('reminders', where: "id = 'x'")), hasLength(1));
    });

    test('the device id is created once', () async {
      final db = await temp.open();
      final id = await db.deviceId();
      expect(id, hasLength(36));
      expect(await db.deviceId(), id);
    });
  });

  group('migration v1 → v3', () {
    Future<void> createV1() async {
      final db = await databaseFactoryFfi.openDatabase(temp.path);
      await db.execute(File('test/data/fixtures/schema_v1.sql').readAsStringSync());
      await db.execute("INSERT INTO categories VALUES ('dhikr', NULL, NULL, 0, 1, 'x')");
      await db.execute("INSERT INTO templates VALUES ('adhkar_morning','dhikr','suggested',NULL,'dhikr',"
          "'{\"schedule_type\":\"daily\",\"time\":\"07:00\"}',NULL,1,0,1,'x')");
      await db.execute("INSERT INTO template_i18n VALUES ('adhkar_morning','en','Old','Old body')");
      const cols = 'id,kind,template_id,title,body,schedule_type,time,prayer,offset_min,start_date,sync_policy,created_at,updated_at,deleted';
      await db.execute("INSERT INTO reminders ($cols) VALUES "
          "('p','personal',NULL,'Mine','Words','prayer',NULL,'asr',150,'2026-01-01','cloud','c1','u1',0),"
          "('t','template','adhkar_morning',NULL,NULL,'daily','07:00',NULL,0,'2026-01-01','cloud','c2','u2',0),"
          "('s','struggle',NULL,'Private',NULL,'daily','21:00',NULL,0,'2026-01-01','local_only','c3','u3',0),"
          "('d','personal',NULL,'Gone',NULL,'daily','08:00',NULL,0,'2026-01-01','cloud','c4','u4',1)");
      expect(await userVersion(db), 1);
      await db.close();
    }

    test('keeps every reminder, clamps the old offset and reaches the current version', () async {
      await createV1();
      final db = (await temp.open()).db;
      expect(await userVersion(db), NiyahDatabase.version);
      final rows = {for (final r in await db.query('reminders')) r['id']: r};
      expect(rows.keys.toSet(), {'p', 't', 's', 'd'});
      expect(rows['p']!['offset_min'], 120);
      expect(rows['p']!['prayer'], 'asr');
      expect(rows['p']!['prayers_mask'], isNull);
      expect(rows['p']!['title'], 'Mine');
      expect(rows['s']!['sync_policy'], 'local_only');
      expect(rows['d']!['deleted'], 1);
      expect(rows['t']!['created_at'], 'c2');
      expect(await db.query('sqlite_master', where: "type = 'index' AND name = 'idx_reminders_active'"), hasLength(1));
    });

    test('the tables end up like a fresh seed', () async {
      await createV1();
      final migrated = await temp.open();
      final freshDir = await Directory.systemTemp.createTemp('niyah_fresh_');
      final fresh = await NiyahDatabase.open(factory: databaseFactoryFfi, path: '${freshDir.path}/fresh.db', loadSeed: loadSeed);
      try {
        for (final table in ['reminders', 'templates', 'template_i18n', 'categories', 'cities']) {
          expect(await columns(migrated.db, table), await columns(fresh.db, table), reason: table);
        }
      } finally {
        await fresh.close();
        await freshDir.delete(recursive: true);
      }
    });

    test('the new constraints apply after the rebuild', () async {
      await createV1();
      final db = (await temp.open()).db;
      Future<void> insert(String id, Map<String, Object?> values) => db.insert('reminders', {
            'id': id, 'kind': 'personal', 'start_date': '2026-01-01', 'created_at': 'x', 'updated_at': 'x', ...values,
          });
      await insert('a', {'schedule_type': 'anchor', 'anchor': 'sleep'});
      await insert('b', {'schedule_type': 'prayer', 'prayers_mask': 31, 'offset_min': -60});
      await expectLater(insert('c', {'schedule_type': 'prayer', 'offset_min': -61}), throwsA(isA<DatabaseException>()));
      await expectLater(insert('d', {'schedule_type': 'anchor', 'anchor': 'noon'}), throwsA(isA<DatabaseException>()));
      await expectLater(insert('e', {'kind': 'struggle', 'schedule_type': 'daily', 'sync_policy': 'cloud'}),
          throwsA(isA<DatabaseException>()));
    });

    test('templates are replaced with the bundled ones', () async {
      await createV1();
      final db = await temp.open();
      final templates = SqliteTemplateRepository(db);
      await templates.init();
      final morning = templates.byId('adhkar_morning', 'en')!;
      expect(morning.title, 'Morning adhkar');
      expect(morning.defaultSchedule, const PrayerSchedule({Prayer.fajr}, offsetMin: -20));
      expect(templates.templates('en'), hasLength(12));

      final reminders = SqliteReminderRepository(db);
      await reminders.init();
      expect(reminders.byId('p')!.schedule, const PrayerSchedule({Prayer.asr}, offsetMin: 120));
      expect(reminders.byTemplate('adhkar_morning')!.schedule, const TimeSchedule(LocalTime(7, 0)));
    });

    test('a file that is not a MyNiyah database is refused', () async {
      final db = await databaseFactoryFfi.openDatabase(temp.path);
      await db.execute('CREATE TABLE x (y)');
      await db.close();
      await expectLater(temp.open(), throwsStateError);
    });
  });

  group('migration v2 → v3', () {
    /// A v2 database: the current seed with the v2 `cities` table (no
    /// `alt_names`, no rows) and one reminder.
    Future<void> createV2() async {
      final db = await temp.open();
      await db.db.execute('DROP TABLE cities');
      await db.db.execute('CREATE TABLE cities (id INTEGER PRIMARY KEY, name TEXT NOT NULL, ascii_name TEXT NOT NULL, '
          'country TEXT NOT NULL, lat REAL NOT NULL, lng REAL NOT NULL, timezone TEXT NOT NULL, population INTEGER NOT NULL DEFAULT 0)');
      final repo = SqliteReminderRepository(db);
      await repo.init();
      await repo.save(const ReminderItem(id: 'x', source: ReminderSource.personal, title: 't', schedule: TimeSchedule(LocalTime(8, 0))));
      await db.db.execute('PRAGMA user_version = 2');
      await db.close();
    }

    test('fills the cities, with their other names, and keeps the reminders', () async {
      await createV2();
      final db = (await temp.open()).db;
      expect(await userVersion(db), NiyahDatabase.version);
      expect((await db.rawQuery('SELECT COUNT(*) AS n FROM cities')).first['n'], greaterThan(30000));
      final milan = (await db.query('cities', where: "ascii_name = 'Milan' AND country = 'IT'")).single;
      expect(milan['timezone'], 'Europe/Rome');
      expect(milan['alt_names'] as String, contains('|milano|'));
      expect(await db.query('reminders', where: "id = 'x'"), hasLength(1));
      expect(await db.query('sqlite_master', where: "type = 'index' AND name = 'idx_cities_ascii'"), hasLength(1));
      // The seed copy used for the migration is gone and detached.
      expect(File('${temp.dir.path}/niyah_seed_migration.db').existsSync(), isFalse);
      expect((await db.rawQuery('PRAGMA database_list')).map((r) => r['name']), isNot(contains('seed')));
    });
  });
}
