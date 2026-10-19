import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';
import '../theme/niyah_theme.dart';
import 'niyah_card.dart';
import 'niyah_switch.dart';
import 'time_stepper.dart';
import 'value_stepper.dart';

/// [t] moved by [minutes], wrapping around midnight.
LocalTime shiftTime(LocalTime t, int minutes) {
  final m = (t.minutesOfDay + minutes) % (24 * 60);
  return LocalTime(m ~/ 60, m % 60);
}

/// Editable copy of one anchor (wake-up or bedtime) of [AnchorTimes].
class AnchorDraft {
  AnchorDraft(AnchorTimes times, this.anchor)
    : weekday = times.weekday(anchor),
      weekendOn = times.weekend(anchor) != null && times.weekend(anchor) != times.weekday(anchor),
      weekend = times.weekend(anchor) ?? shiftTime(times.weekday(anchor), defaultWeekendShift);

  final Anchor anchor;
  LocalTime weekday;
  bool weekendOn;
  LocalTime weekend;

  /// Weekend time step, and the first weekend time offered when there is
  /// none yet (weekday + 1 h).
  static const weekendStep = 15, defaultWeekendShift = 60;

  /// [times] with this anchor replaced.
  AnchorTimes applyTo(AnchorTimes times) => times.withAnchor(anchor, weekday, weekendOn ? weekend : null);
}

/// Wake-up or bedtime editor: the weekday time, a note, "Different time on
/// weekends" and the weekend stepper. Used by the setup sheet of the
/// wake/bed moments and by "My day" in Settings.
class AnchorFields extends StatelessWidget {
  const AnchorFields({super.key, required this.draft, required this.onChanged, this.showLabel = true});

  final AnchorDraft draft;

  /// Called after [draft] was changed in place.
  final VoidCallback onChanged;

  /// Shows "Your wake-up time" above the stepper (off when a sheet title
  /// already says it).
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final wake = draft.anchor == Anchor.wake;
    void edit(void Function() change) {
      change();
      onChanged();
    }

    final children = [
      if (showLabel)
        Text(
          wake ? l.anchorWakeLabel : l.anchorSleepLabel,
          style: NiyahText.sans(15, weight: FontWeight.w600, color: c.text),
        ),
      TimeStepper(value: draft.weekday, onChanged: (v) => edit(() => draft.weekday = v)),
      Text(wake ? l.anchorWakeNote : l.anchorSleepNote, style: NiyahText.sans(13, height: 1.5, color: c.text2)),
      Column(
        children: [
          const RowDivider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    l.differentOnWeekends,
                    style: NiyahText.sans(15, weight: FontWeight.w600, color: c.text),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              NiyahSwitch(
                value: draft.weekendOn,
                semanticLabel: l.differentOnWeekends,
                onChanged: (v) => edit(() => draft.weekendOn = v),
              ),
            ],
          ),
        ],
      ),
      if (draft.weekendOn)
        ValueStepper(
          label: l.weekendDays,
          value: formatTime(draft.weekend),
          decrementLabel: l.weekendEarlier,
          incrementLabel: l.weekendLater,
          onDecrement: () => edit(() => draft.weekend = shiftTime(draft.weekend, -AnchorDraft.weekendStep)),
          onIncrement: () => edit(() => draft.weekend = shiftTime(draft.weekend, AnchorDraft.weekendStep)),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[if (i > 0) const SizedBox(height: 10), child],
      ],
    );
  }
}
