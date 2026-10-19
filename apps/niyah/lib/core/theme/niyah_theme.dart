import 'package:flutter/material.dart';

import 'niyah_colors.dart';
import 'niyah_text.dart';

export 'niyah_colors.dart';
export 'niyah_text.dart';

/// Light and dark [ThemeData] built from the design tokens (docs/app-plan.md §4).
abstract final class NiyahTheme {
  static ThemeData light() => _build(NiyahColors.light, Brightness.light);
  static ThemeData dark() => _build(NiyahColors.dark, Brightness.dark);

  static ThemeData _build(NiyahColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.tint,
      onPrimaryContainer: c.primaryInk,
      secondary: c.secondary,
      onSecondary: c.text,
      secondaryContainer: c.warmTint,
      onSecondaryContainer: c.warmInk,
      error: c.danger,
      onError: c.onPrimary,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.text2,
      surfaceContainerHighest: c.chipOff,
      outline: c.border,
      outlineVariant: c.divider,
      scrim: NiyahColors.scrim,
    );
    final text = _textTheme(c);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.divider,
      fontFamily: NiyahText.sansFamily,
      textTheme: text,
      primaryTextTheme: text,
      splashFactory: InkRipple.splashFactory,
      iconTheme: IconThemeData(color: c.text, size: 24),
      extensions: [c],
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent, elevation: 0),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.text,
        contentTextStyle: NiyahText.sans(14, weight: FontWeight.w500, color: c.bg),
      ),
    );
  }

  static TextTheme _textTheme(NiyahColors c) => TextTheme(
    displayLarge: NiyahText.serif(44, weight: FontWeight.w400, height: 1.1, color: c.text),
    displayMedium: NiyahText.serif(34, height: 1.1, color: c.text),
    displaySmall: NiyahText.serif(30, color: c.text),
    headlineLarge: NiyahText.serif(34, height: 1.1, color: c.text),
    headlineMedium: NiyahText.serif(28, color: c.text),
    headlineSmall: NiyahText.sans(20, weight: FontWeight.w700, color: c.text),
    titleLarge: NiyahText.sans(18, weight: FontWeight.w700, color: c.text),
    titleMedium: NiyahText.sans(16, weight: FontWeight.w600, color: c.text),
    titleSmall: NiyahText.sans(15, weight: FontWeight.w600, color: c.text),
    bodyLarge: NiyahText.sans(16, color: c.text),
    bodyMedium: NiyahText.sans(14, color: c.text),
    bodySmall: NiyahText.sans(13, color: c.text2),
    labelLarge: NiyahText.sans(15, weight: FontWeight.w600, color: c.text),
    labelMedium: NiyahText.sans(12.5, weight: FontWeight.w600, color: c.text2),
    labelSmall: NiyahText.sans(11.5, weight: FontWeight.w500, color: c.text2),
  );
}

/// `context.niyah.primary` etc.
extension NiyahThemeContext on BuildContext {
  NiyahColors get niyah => Theme.of(this).extension<NiyahColors>() ?? NiyahColors.light;
}

/// Converts the design's top paddings (measured on a 390×844 frame whose
/// status bar is [designStatusBar] px tall) to the real safe area.
abstract final class NiyahInsets {
  static const designStatusBar = 44.0;

  /// e.g. `top(context, 60)` for a header drawn with `padding-top: 60px`.
  static double top(BuildContext context, double designTop) =>
      MediaQuery.paddingOf(context).top + designTop - designStatusBar;
}
