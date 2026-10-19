import 'package:flutter/material.dart';

import '../theme/niyah_theme.dart';

/// Equal-width segments on a `seg` track (14 px radius, 4 px padding); the
/// selected one is raised on `segOn`. Each segment is a 44 px button exposed
/// as selected/not selected (the design's `aria-pressed`).
///
/// Used by the Add filters (5 items, [gap] 2, [fontSize] 13.5), the editor
/// trigger and the Prayer timing modes.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.semanticLabel,
    this.gap = 4,
    this.fontSize = 14.5,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  /// Name of the group (`aria-label`).
  final String? semanticLabel;
  final double gap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: c.seg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            for (var i = 0; i < values.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: _segment(context, values[i])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, T value) {
    final c = context.niyah;
    final on = value == selected;
    final label = labelOf(value);
    return Semantics(
      button: true,
      selected: on,
      label: label,
      onTap: () => onChanged(value),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? c.segOn : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: on ? NiyahColors.segShadow : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: NiyahText.sans(fontSize, weight: FontWeight.w600, color: on ? c.text : c.text2),
            ),
          ),
        ),
      ),
    );
  }
}
