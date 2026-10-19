import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../core/theme/niyah_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'prayer_words.dart';

/// Timing of the prayer reminder.
enum PrayerTiming { before, adhan, after }

/// "Prayer reminders" (artboard `Prayer`): the words, the timing, today's
/// prayers with a switch each, and quiet hours. Every change is saved at once.
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  /// "How long before" range and step, in minutes.
  static const minBefore = 5, maxBefore = 45, step = 5;

  /// Offset used by "After" (the design has no stepper for it).
  static const afterOffset = -15;

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  /// Minutes restored when the user goes back to "Before".
  int _lastBefore = 10;
  bool _askedPermission = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final offset = _offsetOf(AppScope.of(context).reminders.prayer);
    if (offset > 0) _lastBefore = offset.clamp(PrayerScreen.minBefore, PrayerScreen.maxBefore);
  }

  static int _offsetOf(ReminderItem r) => switch (r.schedule) {
    PrayerSchedule(:final offsetMin) => offsetMin,
    _ => 0,
  };

  static Set<Prayer> _prayersOf(ReminderItem r) => switch (r.schedule) {
    PrayerSchedule(:final prayers) => prayers,
    _ => const {},
  };

  Future<void> _saveSchedule(Set<Prayer> prayers, int offset, {bool? enabled}) {
    final reminders = AppScope.of(context).reminders;
    final r = reminders.prayer;
    return reminders.save(
      r.copyWith(
        schedule: PrayerSchedule(prayers, offsetMin: offset),
        enabled: enabled,
      ),
    );
  }

  void _setTiming(PrayerTiming t) {
    final r = AppScope.of(context).reminders.prayer;
    final offset = switch (t) {
      PrayerTiming.before => _lastBefore,
      PrayerTiming.adhan => 0,
      PrayerTiming.after => PrayerScreen.afterOffset,
    };
    _saveSchedule(_prayersOf(r), offset);
  }

  void _setMinutes(int minutes) {
    final r = AppScope.of(context).reminders.prayer;
    _lastBefore = minutes;
    _saveSchedule(_prayersOf(r), minutes);
  }

  Future<void> _togglePrayer(Prayer p, bool on) async {
    final s = AppScope.of(context);
    final r = s.reminders.prayer;
    final current = r.enabled ? _prayersOf(r) : const <Prayer>{};
    final next = on ? {...current, p} : ({...current}..remove(p));
    if (on && !_askedPermission) {
      _askedPermission = true;
      await s.notifications.ensurePermission();
      await s.notifications.ensureExactAlarms();
      if (!mounted) return;
    }
    await _saveSchedule(next, _offsetOf(r), enabled: on ? true : null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = AppScope.of(context);
    return Scaffold(
      body: Column(
        children: [
          BackHeader(title: l.prayerTitle, backLabel: l.backToReminders),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([s.reminders, s.prayers, s.settings]),
              builder: (context, _) {
                final r = s.reminders.prayer;
                final offset = _offsetOf(r);
                final prayers = r.enabled ? _prayersOf(r) : const <Prayer>{};
                final timing = offset > 0
                    ? PrayerTiming.before
                    : offset == 0
                    ? PrayerTiming.adhan
                    : PrayerTiming.after;
                final upcoming = upcomingPrayer(s.prayers, prayers, DateTime.now());
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MessageCard(
                        title: r.title ?? l.prayerDefaultTitle,
                        body: r.body ?? defaultPrayerBody(l, offset, upcoming),
                      ),
                      const SizedBox(height: 22),
                      _WhenSection(
                        timing: timing,
                        minutes: offset > 0 ? offset : _lastBefore,
                        onTiming: _setTiming,
                        onMinutes: _setMinutes,
                      ),
                      const SizedBox(height: 22),
                      _TodaySection(
                        day: s.prayers.today,
                        location: prayerLocationLabel(l, s.settings.location, s.settings.method),
                        on: prayers,
                        remind: prayerTimingLabel(l, offset),
                        onToggle: _togglePrayer,
                      ),
                      const SizedBox(height: 22),
                      _QuietCard(value: s.settings.prayerDuringQuiet, onChanged: s.settings.setPrayerDuringQuiet),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return NiyahCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(l.prayerMessageLabel, fontSize: 12, padding: EdgeInsets.zero),
          const SizedBox(height: 10),
          QuoteBox(title: title, body: body, fontSize: 14),
          const SizedBox(height: 10),
          NiyahTextButton(
            label: l.prayerChangeWords,
            icon: NiyahIcons.pencil,
            fontSize: 14.5,
            center: false,
            onPressed: () => context.push(Routes.prayerWords),
          ),
        ],
      ),
    );
  }
}

class _WhenSection extends StatelessWidget {
  const _WhenSection({required this.timing, required this.minutes, required this.onTiming, required this.onMinutes});

  final PrayerTiming timing;
  final int minutes;
  final ValueChanged<PrayerTiming> onTiming;
  final ValueChanged<int> onMinutes;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Semantics(
            header: true,
            child: Text(
              l.fieldWhen,
              style: NiyahText.sans(14, weight: FontWeight.w600, color: c.text),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedControl<PrayerTiming>(
          values: PrayerTiming.values,
          selected: timing,
          semanticLabel: l.prayerTimingLabel,
          labelOf: (t) => switch (t) {
            PrayerTiming.before => l.prayerModeBefore,
            PrayerTiming.adhan => l.prayerModeAdhan,
            PrayerTiming.after => l.prayerModeAfter,
          },
          onChanged: (t) {
            if (t != timing) onTiming(t);
          },
        ),
        if (timing == PrayerTiming.before) ...[
          const SizedBox(height: 12),
          ValueStepper(
            style: ValueStepperStyle.outlined,
            label: l.prayerHowLongBefore,
            value: l.prayerMinutes(minutes),
            onDecrement: minutes > PrayerScreen.minBefore ? () => onMinutes(minutes - PrayerScreen.step) : null,
            onIncrement: minutes < PrayerScreen.maxBefore ? () => onMinutes(minutes + PrayerScreen.step) : null,
            decrementLabel: l.prayerLessTime,
            incrementLabel: l.prayerMoreTime,
          ),
        ],
      ],
    );
  }
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({
    required this.day,
    required this.location,
    required this.on,
    required this.remind,
    required this.onToggle,
  });

  final PrayerDay? day;

  /// "Milan · Muslim World League"; null while no location is set.
  final String? location;
  final Set<Prayer> on;

  /// Remind line of the prayers that are on ("10 min before").
  final String remind;
  final void Function(Prayer prayer, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final times = day?.times ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.prayerToday, trailing: location),
        const SizedBox(height: 10),
        if (day == null) ...[const _NoLocationCard(), const SizedBox(height: 12)],
        NiyahCard(
          child: Column(
            children: [
              for (final (i, p) in Prayer.values.indexed) ...[
                if (i > 0) const RowDivider(),
                _PrayerRow(
                  prayer: p,
                  time: times[p],
                  on: on.contains(p),
                  remind: on.contains(p) ? remind : l.off,
                  onChanged: (v) => onToggle(p, v),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.prayer,
    required this.time,
    required this.on,
    required this.remind,
    required this.onChanged,
  });

  final Prayer prayer;
  final LocalTime? time;
  final bool on;
  final String remind;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final name = prayerName(l, prayer);
    // With very large text the time and remind line move under the name.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 15;
    final names = Wrap(
      spacing: 10,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        Text(
          name,
          style: NiyahText.sans(16, weight: FontWeight.w600, color: c.text),
        ),
        ExcludeSemantics(
          child: Text(
            prayerArabicNames[prayer]!,
            textDirection: TextDirection.rtl,
            style: NiyahText.serif(17, weight: FontWeight.w400, color: c.text2),
          ),
        ),
      ],
    );
    final align = stacked ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final timing = Column(
      crossAxisAlignment: align,
      children: [
        if (time != null)
          Text(
            formatTime(time!),
            style: NiyahText.sans(15, weight: FontWeight.w700, color: c.text, features: NiyahText.tabular),
          ),
        const SizedBox(height: 1),
        Text(
          remind,
          style: NiyahText.sans(12, weight: FontWeight.w600, color: c.primaryInk),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
      child: Opacity(
        opacity: on ? 1 : 0.62,
        child: Row(
          children: [
            if (stacked)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [names, const SizedBox(height: 4), timing],
                ),
              )
            else ...[
              Expanded(child: names),
              const SizedBox(width: 12),
              timing,
            ],
            const SizedBox(width: 12),
            NiyahSwitch(value: on, onChanged: onChanged, semanticLabel: l.prayerRemindMeFor(name)),
          ],
        ),
      ),
    );
  }
}

/// Shown instead of today's times while no prayer location is set.
class _NoLocationCard extends StatelessWidget {
  const _NoLocationCard();

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    return NiyahCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.prayerNoLocation, style: NiyahText.sans(15, weight: FontWeight.w600, color: c.text)),
          const SizedBox(height: 4),
          NiyahTextButton(
            label: l.settingsSetLocation,
            icon: NiyahIcons.arrow,
            fontSize: 14.5,
            center: false,
            onPressed: () => context.push(Routes.location),
          ),
        ],
      ),
    );
  }
}

class _QuietCard extends StatelessWidget {
  const _QuietCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    return NiyahCard(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.prayerDuringQuiet,
                  style: NiyahText.sans(15, weight: FontWeight.w600, color: c.text),
                ),
                const SizedBox(height: 3),
                Text(l.prayerDuringQuietNote, style: NiyahText.sans(13, height: 1.4, color: c.text2)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          NiyahSwitch(value: value, onChanged: onChanged, semanticLabel: l.prayerDuringQuietLabel),
        ],
      ),
    );
  }
}
