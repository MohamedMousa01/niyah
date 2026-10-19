// Helpers to run the SQLite repositories on the host (sqflite_common_ffi).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/sqlite/niyah_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The committed seed asset (flutter test runs from the package root).
Future<List<int>> loadSeed() => File('assets/db/niyah_seed.db').readAsBytes();

/// A temporary folder per test, removed afterwards; [path] is a database
/// file inside it that does not exist yet.
class TempDb {
  late Directory dir;
  String get path => p.join(dir.path, 'niyah.db');
  final List<NiyahDatabase> _open = [];

  void setUpEach() {
    setUpAll(sqfliteFfiInit);
    setUp(() async => dir = await Directory.systemTemp.createTemp('niyah_test_'));
    tearDown(() async {
      for (final db in _open) {
        if (db.db.isOpen) await db.close();
      }
      _open.clear();
      await dir.delete(recursive: true);
    });
  }

  Future<NiyahDatabase> open({SeedLoader? seed}) async {
    final db = await NiyahDatabase.open(factory: databaseFactoryFfi, path: path, loadSeed: seed ?? loadSeed);
    _open.add(db);
    return db;
  }
}
