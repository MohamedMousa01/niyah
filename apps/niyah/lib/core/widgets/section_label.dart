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

  /// Widest share of the row the label takes when there is a [trailing].
  static const maxLabelShare = 0.6;

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
    // The label keeps its natural width (wrapping past [maxLabelShare] of
    // the row); the trailing text gets all the rest, aligned to the end.
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * maxLabelShare),
              child: label,
            ),
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
      ),
    );
  }
}
