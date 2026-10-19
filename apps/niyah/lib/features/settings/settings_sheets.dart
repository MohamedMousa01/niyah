import 'package:flutter/material.dart';
import 'package:niyah_core/niyah_core.dart' show defaultMethodForCountry;

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../core/theme/niyah_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';
import 'settings_widgets.dart';

/// Calculation method: every method, the one usual for the location marked
/// "Suggested". Picking the suggested one stores "automatic", so it follows
/// a later change of location.
Future<void> showMethodSheet(BuildContext context) => showNiyahSheet<void>(
  context,
  builder: (context) {
    final l = AppLocalizations.of(context);
    final settings = AppScope.of(context).settings;
    final suggested = defaultMethodForCountry(settings.location?.country);
    return NiyahBottomSheet(
      semanticLabel: l.settingsMethod,
      gap: 14,
      children: [
        SheetHeader(icon: NiyahIcons.mosque, title: l.settingsMethod),
        Text(l.settingsMethodNote, style: NiyahText.sans(14, height: 1.45, color: context.niyah.text2)),
        SettingsCard(
          children: [
            for (final m in calculationMethods)
              ChoiceRow(
                title: methodName(l, m),
                subtitle: m == suggested && settings.location != null ? l.settingsMethodSuggested : null,
                selected: m == settings.method,
                onTap: () {
                  settings.setMethodChoice(m == suggested ? null : m);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ],
    );
  },
);

/// A clock time picked with the [TimeStepper]; null when dismissed.
Future<LocalTime?> showTimeSheet(BuildContext context, {required String title, required LocalTime initial}) =>
    showNiyahSheet<LocalTime>(context, builder: (_) => _TimeSheet(title: title, initial: initial));

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.title, required this.initial});

  final String title;
  final LocalTime initial;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late LocalTime _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return NiyahBottomSheet(
      semanticLabel: widget.title,
      children: [
        SheetHeader(icon: NiyahIcons.clock, title: widget.title),
        TimeStepper(value: _value, onChanged: (v) => setState(() => _value = v)),
        PrimaryButton(label: l.saveChanges, onPressed: () => Navigator.of(context).pop(_value)),
      ],
    );
  }
}

/// Wake-up time or bedtime, with the weekend option ("My day").
Future<void> showAnchorSheet(BuildContext context, Anchor anchor) =>
    showNiyahSheet<void>(context, builder: (_) => _AnchorSheet(anchor: anchor));

class _AnchorSheet extends StatefulWidget {
  const _AnchorSheet({required this.anchor});

  final Anchor anchor;

  @override
  State<_AnchorSheet> createState() => _AnchorSheetState();
}

class _AnchorSheetState extends State<_AnchorSheet> {
  late final AnchorDraft _draft = AnchorDraft(AppScope.of(context).settings.anchors, widget.anchor);

  Future<void> _save() async {
    final settings = AppScope.of(context).settings;
    final navigator = Navigator.of(context);
    await settings.setAnchors(_draft.applyTo(settings.anchors));
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final wake = widget.anchor == Anchor.wake;
    final title = wake ? l.anchorWakeLabel : l.anchorSleepLabel;
    return NiyahBottomSheet(
      semanticLabel: title,
      children: [
        SheetHeader(icon: wake ? NiyahIcons.sunrise : NiyahIcons.bed, title: title),
        AnchorFields(draft: _draft, showLabel: false, onChanged: () => setState(() {})),
        PrimaryButton(label: l.saveChanges, onPressed: _save),
      ],
    );
  }
}

/// How long to pause every reminder; "Turn reminders back on" while paused.
Future<void> showPauseSheet(BuildContext context) => showNiyahSheet<void>(
  context,
  builder: (context) {
    final l = AppLocalizations.of(context);
    final settings = AppScope.of(context).settings;
    final paused = settings.isPaused(DateTime.now());
    void pause(DateTime? until) {
      settings.setPausedUntil(until);
      Navigator.of(context).pop();
    }

    DateTime inDays(int days) => DateTime.now().add(Duration(days: days));
    return NiyahBottomSheet(
      semanticLabel: l.settingsPause,
      gap: 14,
      children: [
        SheetHeader(icon: 'pause', title: l.settingsPause),
        Text(l.settingsPauseNote, style: NiyahText.sans(14, height: 1.45, color: context.niyah.text2)),
        if (paused) QuoteBox(body: pauseLabel(l, settings)),
        SettingsCard(
          children: [
            ChoiceRow(title: l.settingsPauseDay, selected: false, onTap: () => pause(inDays(1))),
            ChoiceRow(title: l.settingsPause3Days, selected: false, onTap: () => pause(inDays(3))),
            ChoiceRow(title: l.settingsPauseWeek, selected: false, onTap: () => pause(inDays(7))),
            ChoiceRow(
              title: l.settingsPauseForever,
              selected: settings.pausedUntil == SettingsStore.pausedForever,
              onTap: () => pause(SettingsStore.pausedForever),
            ),
          ],
        ),
        if (paused) PrimaryButton(label: l.settingsResume, onPressed: () => pause(null)),
      ],
    );
  },
);

/// "Off", "Paused until Tue 21 Oct, 09:00" or "Paused until you turn them
/// back on".
String pauseLabel(AppLocalizations l, SettingsStore settings, {DateTime? now}) {
  final until = settings.pausedUntil;
  if (!settings.isPaused(now ?? DateTime.now()) || until == null) return l.off;
  if (until == SettingsStore.pausedForever) return l.settingsPausedForever;
  return l.settingsPausedUntil(formatDateTime(l, until.toLocal()));
}
