import 'package:flutter/material.dart';

import '../theme/niyah_theme.dart';

/// Uppercase section heading (12.5 px, bold, 1.2 letter spacing, `text2`),
/// with an optional [trailing] text aligned on the baseline (e.g. the prayer
/// location on the Prayer screen).
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.fontSize = 12.5,
  });

  final String text;
  final String? trailing;
  final EdgeInsetsGeometry padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final label = Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: NiyahText.sans(fontSize, weight: FontWeight.w700, letterSpacing: 1.2, color: c.text2),
      ),
    );
    if (trailing == null) return Padding(padding: padding, child: label);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(child: label),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              trailing!,
              textAlign: TextAlign.end,
              style: NiyahText.sans(12.5, color: c.text2),
            ),
          ),
        ],
      ),
    );
  }
}
