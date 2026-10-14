// Database locale (SQLite): la fonte di verità sul dispositivo (architettura §3).
// Schema: seed/schema.sql. Al primo avvio si copia il database iniziale
// incluso nell'app (assets/databases/niyah_seed.db, vedi tool/prepare_seed.sh).

import 'dart:io';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const String kNiyahDbFileName = 'niyah.db';
const String kNiyahSeedAsset = 'assets/databases/niyah_seed.db';

class NiyahDatabase {
  NiyahDatabase(this.db);

  final Database db;

  /// Apre il database dell'app, copiando il seed al primo avvio.
  static Future<NiyahDatabase> open({
    Future<ByteData> Function()? loadSeed,
  }) async {
    final path = p.join(await getDatabasesPath(), kNiyahDbFileName);
    if (!await File(path).exists()) {
      final data = await (loadSeed ?? () => rootBundle.load(kNiyahSeedAsset))();
      await Directory(p.dirname(path)).create(recursive: true);
      // Copia su un file temporaneo e poi rinomina: un'interruzione a metà
      // non lascia mai un database incompleto.
      final tmp = File('$path.tmp');
      await tmp.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      await tmp.rename(path);
    }
    return NiyahDatabase(await openDatabase(path));
  }

  Future<String?> meta(String key) async {
    final rows = await db.query('sync_meta', columns: ['value'], where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String? value) async {
    await db.insert('sync_meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
