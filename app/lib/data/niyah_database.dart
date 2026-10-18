// Database locale (SQLite): la fonte di verità sul dispositivo (architettura §3).
// Schema: seed/schema.sql. Al primo avvio si copia il database iniziale
// incluso nell'app (assets/databases/niyah_seed.db, vedi tool/prepare_seed.sh).

import 'dart:io';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const String kNiyahDbFileName = 'niyah.db';
const String kNiyahSeedAsset = 'assets/databases/niyah_seed.db';

/// Versione dello schema (PRAGMA user_version di seed/schema.sql). Quando il
/// seed incluso nell'app è più nuovo del database sul telefono, il catalogo
/// viene sostituito e i dati dell'utente restano.
const int kNiyahSchemaVersion = 2;

/// Tabelle dell'utente: un aggiornamento del catalogo non le tocca mai.
const Set<String> kUserTables = {'reminders', 'prayer_cache', 'recent_content', 'sync_meta'};

class NiyahDatabase {
  NiyahDatabase(this.db);

  final Database db;

  /// Apre il database dell'app, copiando il seed al primo avvio.
  static Future<NiyahDatabase> open({
    Future<ByteData> Function()? loadSeed,
  }) async {
    final load = loadSeed ?? () => rootBundle.load(kNiyahSeedAsset);
    final path = p.join(await getDatabasesPath(), kNiyahDbFileName);
    if (!await File(path).exists()) {
      await Directory(p.dirname(path)).create(recursive: true);
      // Copia su un file temporaneo e poi rinomina: un'interruzione a metà
      // non lascia mai un database incompleto.
      await _writeSeed(await load(), path);
    }
    final db = await openDatabase(path);
    final version = (await db.rawQuery('PRAGMA user_version')).first.values.first as int;
    if (version < kNiyahSchemaVersion) {
      final seedPath = '$path.seed';
      await _writeSeed(await load(), seedPath);
      try {
        await upgradeCatalog(db, seedPath);
      } finally {
        await File(seedPath).delete();
      }
    }
    return NiyahDatabase(db);
  }

  static Future<void> _writeSeed(ByteData data, String path) async {
    final tmp = File('$path.tmp');
    await tmp.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
    await tmp.rename(path);
  }

  /// Sostituisce le tabelle del catalogo (modelli, categorie, argomenti,
  /// città…) con quelle del seed in [seedPath], con il loro schema nuovo.
  /// Promemoria, cache e metadati dell'utente restano com'erano. Tutto in una
  /// transazione: se qualcosa va storto il database resta quello di prima.
  static Future<void> upgradeCatalog(Database db, String seedPath) async {
    await db.execute('ATTACH DATABASE ? AS seed', [seedPath]);
    try {
      final seedVersion = (await db.rawQuery('PRAGMA seed.user_version')).first.values.first as int;
      await db.transaction((txn) async {
        final objects = await txn.rawQuery(
            "SELECT type, name, tbl_name, sql FROM seed.sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY type = 'table' DESC");
        final tables = [
          for (final o in objects)
            if (o['type'] == 'table' && !kUserTables.contains(o['name'])) o['name'] as String,
        ];
        for (final t in tables) {
          await txn.execute('DROP TABLE IF EXISTS main."$t"');
        }
        for (final o in objects) {
          if (kUserTables.contains(o['tbl_name'])) continue;
          await txn.execute(o['sql'] as String);
        }
        for (final t in tables) {
          await txn.execute('INSERT INTO main."$t" SELECT * FROM seed."$t"');
        }
        await txn.execute('PRAGMA user_version = $seedVersion');
      });
    } finally {
      await db.execute('DETACH DATABASE seed');
    }
  }

  Future<String?> meta(String key) async {
    final rows = await db.query('sync_meta', columns: ['value'], where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String? value) async {
    await db.insert('sync_meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
