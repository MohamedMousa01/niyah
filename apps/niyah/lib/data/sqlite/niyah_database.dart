import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:niyah_core/niyah_core.dart' show generateUuidV4;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Returns the bytes of the bundled seed database.
typedef SeedLoader = Future<List<int>> Function();

/// The app's SQLite database (schema: `seed/schema.sql`).
///
/// On first run the bundled seed is copied to the app's database path. Every
/// open runs the migrations needed to reach [version] (`PRAGMA user_version`).
class NiyahDatabase {
  NiyahDatabase._(this.db);

  final Database db;

  static const fileName = 'niyah.db';
  static const seedAsset = 'assets/db/niyah_seed.db';
  static const version = 2;

  /// Tables whose rows come only from the seed: replaced from the bundled
  /// seed after a migration, so new or changed templates reach old installs.
  static const seedTables = ['categories', 'category_i18n', 'templates', 'template_i18n'];

  /// [factory] and [path] default to sqflite's; tests pass the FFI factory and
  /// a temporary file. [loadSeed] defaults to the bundled asset.
  static Future<NiyahDatabase> open({DatabaseFactory? factory, String? path, SeedLoader? loadSeed}) async {
    final f = factory ?? databaseFactory;
    final load = loadSeed ?? _loadAsset;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    final file = File(dbPath);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      // Write then rename: an interrupted copy never leaves a broken database.
      final tmp = File('$dbPath.tmp');
      await tmp.writeAsBytes(await load(), flush: true);
      await tmp.rename(dbPath);
    }
    final db = await f.openDatabase(dbPath);
    try {
      await _migrate(db, f, load);
    } catch (_) {
      await db.close();
      rethrow;
    }
    return NiyahDatabase._(db);
  }

  Future<void> close() => db.close();

  /// Id of this install, stored once in `sync_meta` (written on every change
  /// for the deterministic sync merge).
  Future<String> deviceId() async {
    final rows = await db.query('sync_meta', columns: ['value'], where: 'key = ?', whereArgs: ['device_id']);
    final existing = rows.isEmpty ? null : rows.first['value'] as String?;
    if (existing != null) return existing;
    final id = generateUuidV4();
    await db.insert('sync_meta', {'key': 'device_id', 'value': id}, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  static Future<List<int>> _loadAsset() async {
    final data = await rootBundle.load(seedAsset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static Future<void> _migrate(Database db, DatabaseFactory factory, SeedLoader loadSeed) async {
    final from = Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version')) ?? 0;
    if (from >= version) return;
    if (from < 1) throw StateError('${db.path} is not a MyNiyah database (user_version $from)');
    final seed = await _readSeedTables(db.path, factory, loadSeed);
    await db.transaction((txn) async {
      if (from < 2) await _v1ToV2(txn);
      for (final table in seedTables.reversed) {
        await txn.delete(table);
      }
      for (final table in seedTables) {
        for (final row in seed[table]!) {
          await txn.insert(table, row);
        }
      }
      await txn.execute('PRAGMA user_version = $version');
    });
  }

  static Future<Map<String, List<Map<String, Object?>>>> _readSeedTables(
      String dbPath, DatabaseFactory factory, SeedLoader loadSeed) async {
    final tmp = File(p.join(p.dirname(dbPath), 'niyah_seed_migration.db'));
    await tmp.writeAsBytes(await loadSeed(), flush: true);
    final seed = await factory.openDatabase(tmp.path, options: OpenDatabaseOptions(readOnly: true));
    try {
      return {for (final t in seedTables) t: await seed.query(t)};
    } finally {
      await seed.close();
      await tmp.delete();
    }
  }

  /// v1 → v2: multi-prayer, signed offset and anchor reminders; template
  /// group and icon. SQLite cannot change a CHECK constraint, so `reminders`
  /// is rebuilt. Keep this table identical to `seed/schema.sql`.
  static Future<void> _v1ToV2(Transaction txn) async {
    const v1Columns = 'id, kind, template_id, category_id, title, body, content_type, schedule_type, time, '
        'window_start, window_end, times_per_day, days_mask, prayer, start_date, end_date, enabled, paused_until, '
        'respects_quiet_hours, hide_on_lock_screen, channel, sync_policy, device_id, created_at, updated_at, deleted';
    await txn.execute('''
CREATE TABLE reminders_v2 (
  id                   TEXT PRIMARY KEY,
  kind                 TEXT NOT NULL CHECK (kind IN ('template','personal','struggle','content','prayer','event')),
  template_id          TEXT,
  category_id          TEXT,
  title                TEXT,
  body                 TEXT,
  content_type         TEXT CHECK (content_type IS NULL OR content_type IN ('quran','hadith','dhikr')),
  schedule_type        TEXT NOT NULL CHECK (schedule_type IN ('daily','weekly','once','window','prayer','anchor')),
  time                 TEXT,
  window_start         TEXT,
  window_end           TEXT,
  times_per_day        INTEGER NOT NULL DEFAULT 1,
  days_mask            INTEGER NOT NULL DEFAULT 127,
  prayer               TEXT CHECK (prayer IS NULL OR prayer IN ('fajr','dhuhr','asr','maghrib','isha')),
  prayers_mask         INTEGER,
  offset_min           INTEGER NOT NULL DEFAULT 0 CHECK (offset_min BETWEEN -60 AND 120),
  anchor               TEXT CHECK (anchor IS NULL OR anchor IN ('wake','sleep')),
  start_date           TEXT NOT NULL,
  end_date             TEXT,
  enabled              INTEGER NOT NULL DEFAULT 1,
  paused_until         TEXT,
  respects_quiet_hours INTEGER NOT NULL DEFAULT 1,
  hide_on_lock_screen  INTEGER,
  channel              TEXT NOT NULL DEFAULT 'personal',
  sync_policy          TEXT NOT NULL DEFAULT 'cloud' CHECK (sync_policy IN ('local_only','cloud')),
  device_id            TEXT,
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL,
  deleted              INTEGER NOT NULL DEFAULT 0,
  CHECK (kind <> 'struggle' OR sync_policy = 'local_only')
)''');
    // v1 had no range check on the offset: clamp instead of failing the copy.
    await txn.execute('INSERT INTO reminders_v2 ($v1Columns, offset_min) '
        'SELECT $v1Columns, MAX(-60, MIN(120, offset_min)) FROM reminders');
    await txn.execute('DROP TABLE reminders');
    await txn.execute('ALTER TABLE reminders_v2 RENAME TO reminders');
    await txn.execute('CREATE INDEX idx_reminders_active ON reminders(deleted, enabled)');
    await txn.execute("ALTER TABLE templates ADD COLUMN group_key TEXT "
        "CHECK (group_key IS NULL OR group_key IN ('prayer','daily','dhikr','weekly'))");
    await txn.execute('ALTER TABLE templates ADD COLUMN icon TEXT');
  }
}
