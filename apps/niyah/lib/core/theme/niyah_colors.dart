import 'package:flutter/material.dart';

/// The `.th` colour tokens of the design, light and dark.
///
/// Read them with `context.niyah` (see `niyah_theme.dart`).
@immutable
class NiyahColors extends ThemeExtension<NiyahColors> {
  final Color bg;
  final Color surface;
  final Color text;
  final Color text2;
  final Color text3;
  final Color textBody;
  final Color border;
  final Color divider;
  final Color primary;
  final Color primaryInk;
  final Color primaryHover;
  final Color onPrimary;
  final Color tint;
  final Color warmTint;
  final Color warmInk;
  final Color secondary;
  final Color trackOff;
  final Color knob;
  final Color seg;
  final Color segOn;
  final Color chipOff;
  final Color inputBorder;
  final Color previewBg;
  final Color quoteBg;
  final Color danger;
  final Color dangerInk;
  final Color ornament;

  const NiyahColors({
    required this.bg,
    required this.surface,
    required this.text,
    required this.text2,
    required this.text3,
    required this.textBody,
    required this.border,
    required this.divider,
    required this.primary,
    required this.primaryInk,
    required this.primaryHover,
    required this.onPrimary,
    required this.tint,
    required this.warmTint,
    required this.warmInk,
    required this.secondary,
    required this.trackOff,
    required this.knob,
    required this.seg,
    required this.segOn,
    required this.chipOff,
    required this.inputBorder,
    required this.previewBg,
    required this.quoteBg,
    required this.danger,
    required this.dangerInk,
    required this.ornament,
  });

  static const light = NiyahColors(
    bg: Color(0xFFFAF8F3),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF2E3532),
    text2: Color(0xFF5E6662),
    text3: Color(0xFF6B736F),
    textBody: Color(0xFF3F4743),
    border: Color(0xFFE6E2D8),
    divider: Color(0xFFEFEBE2),
    primary: Color(0xFF3E7C6B),
    primaryInk: Color(0xFF2F6455),
    primaryHover: Color(0xFF24503F),
    onPrimary: Color(0xFFFFFFFF),
    tint: Color(0xFFEEF3EF),
    warmTint: Color(0xFFF4EFE3),
    warmInk: Color(0xFF7A5B2E),
    secondary: Color(0xFFA9C9B8),
    trackOff: Color(0xFFCFCABF),
    knob: Color(0xFFFFFFFF),
    seg: Color(0xFFEDE9DF),
    segOn: Color(0xFFFFFFFF),
    chipOff: Color(0xFFF3F0E8),
    inputBorder: Color(0xFFDCD7CB),
    previewBg: Color(0xFFE9EEE9),
    quoteBg: Color(0xFFF6F3EC),
    danger: Color(0xFFA3321F),
    dangerInk: Color(0xFFA3321F),
    ornament: Color(0xFFDCE7DF),
  );

  static const dark = NiyahColors(
    bg: Color(0xFF121614),
    surface: Color(0xFF1B201E),
    text: Color(0xFFECEFEA),
    text2: Color(0xFFA9B2AD),
    text3: Color(0xFF8E9792),
    textBody: Color(0xFFC9D0CB),
    border: Color(0xFF2B322F),
    divider: Color(0xFF252B28),
    primary: Color(0xFF3E7C6B),
    primaryInk: Color(0xFF93CDB8),
    primaryHover: Color(0xFFB5E0D0),
    onPrimary: Color(0xFFFFFFFF),
    tint: Color(0xFF21302A),
    warmTint: Color(0xFF33291C),
    warmInk: Color(0xFFE3C38E),
    secondary: Color(0xFF3F6B5D),
    trackOff: Color(0xFF3C4440),
    knob: Color(0xFFFFFFFF),
    seg: Color(0xFF232926),
    segOn: Color(0xFF38413D),
    chipOff: Color(0xFF252B28),
    inputBorder: Color(0xFF353D39),
    previewBg: Color(0xFF18221E),
    quoteBg: Color(0xFF222826),
    danger: Color(0xFFB8432D),
    dangerInk: Color(0xFFFF9580),
    ornament: Color(0xFF1F2A25),
  );

  /// Modal barrier behind bottom sheets: rgba(10,14,12,.5).
  static const scrim = Color(0x800A0E0C);

  /// Soft shadow under the selected segment: 0 1px 2px rgba(46,53,50,.12).
  static const segShadow = [BoxShadow(color: Color(0x1F2E3532), offset: Offset(0, 1), blurRadius: 2)];

  /// Shadow of the notification card in the preview.
  static const cardShadow = [
    BoxShadow(color: Color(0x142E3532), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0F2E3532), offset: Offset(0, 6), blurRadius: 18),
  ];

  @override
  NiyahColors copyWith() => this;

  @override
  NiyahColors lerp(NiyahColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return NiyahColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      text: l(text, other.text),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      textBody: l(textBody, other.textBody),
      border: l(border, other.border),
      divider: l(divider, other.divider),
      primary: l(primary, other.primary),
      primaryInk: l(primaryInk, other.primaryInk),
      primaryHover: l(primaryHover, other.primaryHover),
      onPrimary: l(onPrimary, other.onPrimary),
      tint: l(tint, other.tint),
      warmTint: l(warmTint, other.warmTint),
      warmInk: l(warmInk, other.warmInk),
      secondary: l(secondary, other.secondary),
      trackOff: l(trackOff, other.trackOff),
      knob: l(knob, other.knob),
      seg: l(seg, other.seg),
      segOn: l(segOn, other.segOn),
      chipOff: l(chipOff, other.chipOff),
      inputBorder: l(inputBorder, other.inputBorder),
      previewBg: l(previewBg, other.previewBg),
      quoteBg: l(quoteBg, other.quoteBg),
      danger: l(danger, other.danger),
      dangerInk: l(dangerInk, other.dangerInk),
      ornament: l(ornament, other.ornament),
    );
  }
}
