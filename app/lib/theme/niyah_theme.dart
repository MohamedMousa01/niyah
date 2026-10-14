// Design system di Niyah (architettura §10): colori calmi, molto spazio,
// nessun elemento che spinga a "consumare" l'app.

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Token di colore. Il tema scuro deriva dagli stessi toni.
abstract final class NiyahColors {
  static const background = Color(0xFFFAF8F3); // crema caldo
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF3E7C6B); // verde salvia profondo
  static const secondary = Color(0xFFA9C9B8); // salvia chiaro
  static const accent = Color(0xFF7FC2C0); // acqua
  static const textPrimary = Color(0xFF2E3532);
  static const textSecondary = Color(0xFF6B736F);
  static const border = Color(0xFFE6E2D8);

  static const darkBackground = Color(0xFF151A18);
  static const darkSurface = Color(0xFF1E2522);
  static const darkPrimary = Color(0xFF8CC3B1);
  static const darkTextPrimary = Color(0xFFE8ECEA);
  static const darkTextSecondary = Color(0xFFA9B2AE);
  static const darkBorder = Color(0xFF2F3834);
}

/// Spaziature (multipli di 4).
abstract final class NiyahSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;

  /// Larghezza massima del contenuto su tablet.
  static const maxContentWidth = 600.0;
}

abstract final class NiyahTheme {
  static const latinFont = 'PlusJakartaSans';
  static const arabicFont = 'IBMPlexSansArabic';

  static String fontFor(Locale locale) => locale.languageCode == 'ar' ? arabicFont : latinFont;

  static ThemeData light(Locale locale) => _build(
        locale,
        Brightness.light,
        const ColorScheme(
          brightness: Brightness.light,
          primary: NiyahColors.primary,
          onPrimary: Colors.white,
          secondary: NiyahColors.secondary,
          onSecondary: NiyahColors.textPrimary,
          tertiary: NiyahColors.accent,
          onTertiary: NiyahColors.textPrimary,
          error: Color(0xFFB3261E),
          onError: Colors.white,
          surface: NiyahColors.surface,
          onSurface: NiyahColors.textPrimary,
          onSurfaceVariant: NiyahColors.textSecondary,
          outline: NiyahColors.border,
          outlineVariant: NiyahColors.border,
          surfaceContainerLowest: NiyahColors.background,
          surfaceContainerLow: NiyahColors.background,
          surfaceContainer: NiyahColors.surface,
          surfaceContainerHigh: NiyahColors.surface,
          surfaceContainerHighest: Color(0xFFF1EEE6),
          secondaryContainer: Color(0xFFDCEBE3),
          onSecondaryContainer: NiyahColors.textPrimary,
        ),
        NiyahColors.background,
      );

  static ThemeData dark(Locale locale) => _build(
        locale,
        Brightness.dark,
        const ColorScheme(
          brightness: Brightness.dark,
          primary: NiyahColors.darkPrimary,
          onPrimary: Color(0xFF0E2A22),
          secondary: Color(0xFF4F6E61),
          onSecondary: NiyahColors.darkTextPrimary,
          tertiary: NiyahColors.accent,
          onTertiary: Color(0xFF0E2A22),
          error: Color(0xFFF2B8B5),
          onError: Color(0xFF601410),
          surface: NiyahColors.darkSurface,
          onSurface: NiyahColors.darkTextPrimary,
          onSurfaceVariant: NiyahColors.darkTextSecondary,
          outline: NiyahColors.darkBorder,
          outlineVariant: NiyahColors.darkBorder,
          surfaceContainerLowest: NiyahColors.darkBackground,
          surfaceContainerLow: NiyahColors.darkBackground,
          surfaceContainer: NiyahColors.darkSurface,
          surfaceContainerHigh: NiyahColors.darkSurface,
          surfaceContainerHighest: Color(0xFF28312D),
          secondaryContainer: Color(0xFF2C3D36),
          onSecondaryContainer: NiyahColors.darkTextPrimary,
        ),
        NiyahColors.darkBackground,
      );

  static ThemeData _build(Locale locale, Brightness brightness, ColorScheme scheme, Color background) {
    final font = fontFor(locale);
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: font,
      fontFamilyFallback: const [latinFont, arabicFont],
      scaffoldBackgroundColor: background,
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(base.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, space: 1, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.onPrimary : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.primary : null),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
