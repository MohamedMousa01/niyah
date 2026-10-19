import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';
import '../theme/niyah_theme.dart';

/// The five prayers as wrapping pill chips (44 px, filled `primary` when on,
/// outlined with `inputBorder` when off), each announced as pressed or not.
class PrayerChips extends StatelessWidget {
  const PrayerChips({super.key, required this.selected, required this.onChanged});

  final Set<Prayer> selected;
  final ValueChanged<Set<Prayer>> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in Prayer.values)
          _chip(c, prayerName(l, p), selected.contains(p), () {
            final next = {...selected};
            if (!next.remove(p)) next.add(p);
            onChanged(next);
          }),
      ],
    );
  }

  Widget _chip(NiyahColors c, String name, bool on, VoidCallback onTap) => Semantics(
    button: true,
    selected: on,
    label: name,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: on ? c.primary : c.surface,
          border: Border.all(color: on ? c.primary : c.inputBorder),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            name,
            style: NiyahText.sans(14, weight: FontWeight.w600, color: on ? c.onPrimary : c.text),
          ),
        ),
      ),
    ),
  );
}
