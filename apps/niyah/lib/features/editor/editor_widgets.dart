import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/niyah_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';

/// Labelled text input of the editor: 14 px label, 14 px radius field with an
/// `inputBorder` outline (2 px `primary` when focused), optional [trailing]
/// text on the label row (the "{count} left" counter).
class EditorField extends StatelessWidget {
  const EditorField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.trailing,
    this.multiline = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final String? trailing;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    style: NiyahText.sans(14, weight: FontWeight.w600, color: c.text),
                  ),
                ),
              ),
              if (trailing != null) Text(trailing!, style: NiyahText.sans(12.5, color: c.text2)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: label,
          child: TextField(
            controller: controller,
            maxLength: maxLength,
            minLines: multiline ? 3 : 1,
            maxLines: multiline ? 5 : 1,
            keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
            textCapitalization: TextCapitalization.sentences,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            cursorColor: c.primary,
            style: NiyahText.sans(16, height: multiline ? 1.45 : null, color: c.text),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintMaxLines: multiline ? 3 : 1,
              hintStyle: NiyahText.sans(16, height: multiline ? 1.45 : null, color: c.text3),
              filled: true,
              fillColor: c.surface,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: multiline ? 14 : 15),
              enabledBorder: border(c.inputBorder, 1),
              focusedBorder: border(c.primary, 2),
              border: border(c.inputBorder, 1),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Need words?" suggestion: a pill with a dashed `secondary` outline.
class IdeaChip extends StatelessWidget {
  const IdeaChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: CustomPaint(
            painter: _DashedPillPainter(c.secondary),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: NiyahText.sans(13.5, weight: FontWeight.w600, color: c.primaryInk),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedPillPainter extends CustomPainter {
  _DashedPillPainter(this.color);

  final Color color;

  static const _dash = 4.0, _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final PathMetric metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillPainter old) => old.color != color;
}

/// "At a time" card: a collapsible time row with the [TimeStepper], then the
/// days.
class TimeCard extends StatelessWidget {
  const TimeCard({
    super.key,
    required this.time,
    required this.open,
    required this.daysMask,
    required this.onToggle,
    required this.onTime,
    required this.onDays,
  });

  final LocalTime time;
  final bool open;
  final int daysMask;
  final VoidCallback onToggle;
  final ValueChanged<LocalTime> onTime;
  final ValueChanged<int> onDays;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final label = formatTime(time);
    final rowTitle = NiyahText.sans(15, weight: FontWeight.w600, color: c.text);
    return NiyahCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: l.editorTimeButtonLabel(label),
            onTap: onToggle,
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    NiyahIcon(NiyahIcons.clock, size: 20, color: c.primaryInk),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l.fieldTime, style: rowTitle)),
                    Text(
                      label,
                      style: NiyahText.sans(
                        22,
                        weight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: c.primaryInk,
                        features: NiyahText.tabular,
                      ),
                    ),
                    const SizedBox(width: 8),
                    NiyahIcon(
                      open ? NiyahIcons.chevronUp : NiyahIcons.chevronDown,
                      size: 18,
                      strokeWidth: 2,
                      color: c.primaryInk,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: TimeStepper(value: time, onChanged: onTime),
            ),
          const RowDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(child: Text(l.fieldDays, style: rowTitle)),
                const SizedBox(height: 10),
                DaysSelector(mask: daysMask, onChanged: onDays),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Around a prayer" card: prayer chips and the signed offset stepper
/// (> 0 before adhan, < 0 after).
class PrayerCard extends StatelessWidget {
  const PrayerCard({
    super.key,
    required this.prayers,
    required this.offsetMin,
    required this.label,
    required this.onPrayers,
    required this.onOffset,
  });

  /// Offset range and step of the stepper.
  static const minOffset = -45, maxOffset = 60, step = 5;

  final Set<Prayer> prayers;
  final int offsetMin;

  /// The offset as text, e.g. "10 min before adhan".
  final String label;
  final ValueChanged<Set<Prayer>> onPrayers;
  final ValueChanged<int> onOffset;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final rowTitle = NiyahText.sans(15, weight: FontWeight.w600, color: c.text);
    return NiyahCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.whichPrayers, style: rowTitle),
          const SizedBox(height: 12),
          PrayerChips(selected: prayers, onChanged: onPrayers),
          const SizedBox(height: 12),
          const RowDivider(),
          const SizedBox(height: 12),
          Text(l.editorTiming, style: rowTitle),
          const SizedBox(height: 10),
          ValueStepper(
            label: label,
            emphasizeLabel: true,
            // Minus moves towards "after", plus towards "before".
            onDecrement: offsetMin > minOffset ? () => onOffset(offsetMin - step) : null,
            onIncrement: offsetMin < maxOffset ? () => onOffset(offsetMin + step) : null,
            decrementLabel: l.later,
            incrementLabel: l.earlier,
          ),
        ],
      ),
    );
  }
}
