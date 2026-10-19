import 'package:flutter/painting.dart';

/// Text styles in the design's two families.
///
/// Plus Jakarta Sans ships as a variable font, so the weight is set both as
/// [TextStyle.fontWeight] and as a `wght` [FontVariation]. Always build sans
/// styles with [NiyahText.sans] (not `copyWith(fontWeight:)`).
abstract final class NiyahText {
  static const sansFamily = 'PlusJakartaSans';
  static const serifFamily = 'Amiri';

  static const tabular = [FontFeature.tabularFigures()];

  /// Plus Jakarta Sans: everything except titles.
  static TextStyle sans(
    double size, {
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    Color? color,
    List<FontFeature>? features,
  }) => TextStyle(
    fontFamily: sansFamily,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontFeatures: features,
  );

  /// Amiri: screen titles and the Home hero.
  static TextStyle serif(
    double size, {
    FontWeight weight = FontWeight.w700,
    double? height,
    double? letterSpacing,
    Color? color,
  }) => TextStyle(
    fontFamily: serifFamily,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
  );
}
