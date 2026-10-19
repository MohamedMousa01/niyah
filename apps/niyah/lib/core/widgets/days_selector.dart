import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../format.dart';
import '../theme/niyah_theme.dart';

/// Seven round day chips (Monday first) toggling bits of a days mask
/// (bit 0 = Monday). Chips show the narrow localized name and announce the
/// full one, pressed or not.
class DaysSelector extends StatelessWidget {
  const DaysSelector({super.key, required this.mask, required this.onChanged});

  final int mask;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final narrow = weekdayNames(l.localeName, width: DayNameWidth.narrow);
    final long = weekdayNames(l.localeName);
    return Semantics(
      container: true,
      label: l.fieldDays,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _DayChip(
                label: narrow[i],
                semanticLabel: long[i],
                on: mask & (1 << i) != 0,
                colors: c,
                onTap: () => onChanged(mask ^ (1 << i)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.semanticLabel,
    required this.on,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool on;
  final NiyahColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? colors.primary : colors.chipOff,
            borderRadius: BorderRadius.circular(999),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: NiyahText.sans(14, weight: FontWeight.w700, color: on ? colors.onPrimary : colors.text2),
            ),
          ),
        ),
      ),
    );
  }
}
