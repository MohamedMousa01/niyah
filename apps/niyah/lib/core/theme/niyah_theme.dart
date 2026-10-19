import 'package:flutter/material.dart';

/// Placeholder until the design-system work package lands (docs/app-plan.md §4).
abstract final class NiyahTheme {
  static ThemeData light() => ThemeData(colorSchemeSeed: const Color(0xFF3E7C6B));
  static ThemeData dark() => ThemeData(colorSchemeSeed: const Color(0xFF3E7C6B), brightness: Brightness.dark);
}
