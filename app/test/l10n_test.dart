import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/ui/settings_page.dart';

Map<String, Object?> _arb(String lang) =>
    (jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map).cast<String, Object?>();

void main() {
  test('le 4 lingue hanno le stesse chiavi, tutte tradotte', () {
    final keys = _arb('it').keys.where((k) => !k.startsWith('@')).toSet();
    for (final lang in ['en', 'fr', 'ar']) {
      final arb = _arb(lang);
      expect(arb.keys.where((k) => !k.startsWith('@')).toSet(), keys, reason: lang);
      for (final k in keys) {
        expect((arb[k] as String).trim(), isNotEmpty, reason: '$lang.$k');
      }
    }
  });

  test('i segnaposto sono gli stessi in ogni lingua', () {
    final placeholder = RegExp(r'\{(\w+)\}');
    final it = _arb('it');
    for (final lang in ['en', 'fr', 'ar']) {
      final arb = _arb(lang);
      for (final k in it.keys.where((k) => !k.startsWith('@'))) {
        Set<String> names(String s) => placeholder.allMatches(s).map((m) => m.group(1)!).toSet();
        expect(names(arb[k] as String), names(it[k] as String), reason: '$lang.$k');
      }
    }
  });

  test('la versione mostrata coincide con pubspec.yaml', () {
    final version = RegExp(r'^version:\s*([\d.]+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect(kAppVersion, version);
  });
}
