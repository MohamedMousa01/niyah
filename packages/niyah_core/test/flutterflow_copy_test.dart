import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('la copia per FlutterFlow è identica alla libreria testata', () {
    final lib = File('lib/niyah_core.dart').readAsStringSync();
    final ff = File('../../flutterflow/custom_actions/niyah_core.dart').readAsStringSync();
    expect(ff, lib, reason: 'Esegui: cp packages/niyah_core/lib/niyah_core.dart flutterflow/custom_actions/');
  });
}
