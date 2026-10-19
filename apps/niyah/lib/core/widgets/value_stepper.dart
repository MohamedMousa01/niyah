import 'package:flutter/material.dart';

import '../theme/niyah_theme.dart';
import 'niyah_icons.dart';
import 'tap_area.dart';

/// Look of a [ValueStepper].
enum ValueStepperStyle {
  /// `chipOff` panel, bare − / + buttons (setup sheet: weekend time, offset).
  filled,

  /// `surface` panel with a border, − / + on `chipOff` squares (Prayer screen).
  outlined,
}

/// "label  − value +" row. [value] is optional: the offset stepper of the
/// setup sheet shows its value as the [label] itself ([emphasizeLabel]).
/// Null callbacks disable a button (e.g. at the end of a range).
/// The changing text is a live region, so screen readers read each new value.
class ValueStepper extends StatelessWidget {
  const ValueStepper({
    super.key,
    required this.label,
    this.value,
    required this.onDecrement,
    required this.onIncrement,
    required this.decrementLabel,
    required this.incrementLabel,
    this.style = ValueStepperStyle.filled,
    this.emphasizeLabel = false,
  });

  final String label;
  final String? value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final String decrementLabel;
  final String incrementLabel;
  final ValueStepperStyle style;

  /// Label in bold `primaryInk` (15 px) as a live region.
  final bool emphasizeLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final outlined = style == ValueStepperStyle.outlined;
    final buttonFill = outlined ? c.chipOff : null;
    final buttonRadius = outlined ? 12.0 : 999.0;

    final labelStyle = emphasizeLabel
        ? NiyahText.sans(15, weight: FontWeight.w700, color: c.primaryInk)
        : NiyahText.sans(outlined ? 15 : 14.5, weight: FontWeight.w600, color: c.text);
    final valueStyle = outlined
        ? NiyahText.sans(16, weight: FontWeight.w700, color: c.primaryInk)
        : NiyahText.sans(18, weight: FontWeight.w700, color: c.text, features: NiyahText.tabular);

    return Container(
      padding: outlined
          ? const EdgeInsetsDirectional.fromSTEB(16, 6, 6, 6)
          : const EdgeInsetsDirectional.fromSTEB(16, 4, 6, 4),
      decoration: BoxDecoration(
        color: outlined ? c.surface : c.chipOff,
        border: outlined ? Border.all(color: c.border) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: emphasizeLabel,
              child: Text(label, style: labelStyle),
            ),
          ),
          const SizedBox(width: 8),
          TapArea(
            onTap: onDecrement,
            semanticLabel: decrementLabel,
            radius: buttonRadius,
            color: buttonFill,
            child: NiyahIcon(NiyahIcons.minus, size: 18, strokeWidth: 2.2, color: c.primaryInk),
          ),
          SizedBox(width: outlined ? 4 : 2),
          if (value != null) ...[
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: outlined ? 72 : 64),
              child: Semantics(
                liveRegion: true,
                child: Text(value!, textAlign: TextAlign.center, style: valueStyle),
              ),
            ),
            SizedBox(width: outlined ? 4 : 2),
          ],
          TapArea(
            onTap: onIncrement,
            semanticLabel: incrementLabel,
            radius: buttonRadius,
            color: buttonFill,
            child: NiyahIcon(NiyahIcons.plus, size: 18, strokeWidth: 2.2, color: c.primaryInk),
          ),
        ],
      ),
    );
  }
}
