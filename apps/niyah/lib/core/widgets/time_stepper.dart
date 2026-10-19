import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../theme/niyah_theme.dart';
import 'niyah_icons.dart';
import 'tap_area.dart';

/// Hour and minute columns with up/down chevrons on a `chipOff` panel.
/// Hours step by 1 and minutes by 5, both wrapping (as in the design).
class TimeStepper extends StatelessWidget {
  const TimeStepper({super.key, required this.value, required this.onChanged});

  final LocalTime value;
  final ValueChanged<LocalTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final h = value.hour, m = value.minute;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: c.chipOff, borderRadius: BorderRadius.circular(18)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Column(
            digits: h.toString().padLeft(2, '0'),
            upLabel: l.hourLater,
            downLabel: l.hourEarlier,
            onUp: () => onChanged(LocalTime((h + 1) % 24, m)),
            onDown: () => onChanged(LocalTime((h + 23) % 24, m)),
          ),
          const SizedBox(width: 14),
          ExcludeSemantics(
            child: Text(
              ':',
              style: NiyahText.sans(32, weight: FontWeight.w700, color: c.text3),
            ),
          ),
          const SizedBox(width: 14),
          _Column(
            digits: m.toString().padLeft(2, '0'),
            upLabel: l.minutesLater,
            downLabel: l.minutesEarlier,
            onUp: () => onChanged(LocalTime(h, (m + 5) % 60)),
            onDown: () => onChanged(LocalTime(h, (m + 55) % 60)),
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.digits,
    required this.upLabel,
    required this.downLabel,
    required this.onUp,
    required this.onDown,
  });

  final String digits;
  final String upLabel;
  final String downLabel;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final digitsStyle = NiyahText.sans(
      36,
      weight: FontWeight.w700,
      height: 1.1,
      color: c.text,
      features: NiyahText.tabular,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TapArea(
          onTap: onUp,
          semanticLabel: upLabel,
          width: 64,
          radius: 12,
          child: NiyahIcon(NiyahIcons.chevronUp, size: 22, strokeWidth: 2, color: c.primaryInk),
        ),
        Semantics(liveRegion: true, child: Text(digits, style: digitsStyle)),
        TapArea(
          onTap: onDown,
          semanticLabel: downLabel,
          width: 64,
          radius: 12,
          child: NiyahIcon(NiyahIcons.chevronDown, size: 22, strokeWidth: 2, color: c.primaryInk),
        ),
      ],
    );
  }
}
