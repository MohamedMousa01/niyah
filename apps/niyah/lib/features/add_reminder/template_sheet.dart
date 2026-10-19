import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../core/theme/niyah_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';

/// Opens the setup sheet of a ready-made moment (time / wake-bed / prayer),
/// used by "Add a reminder" and by template rows in "My reminders".
Future<void> showTemplateSheet(BuildContext context, String templateId) async {
  final template = AppScope.of(context).templates.byId(templateId, AppLocalizations.of(context).localeName);
  if (template == null) return;
  await showNiyahSheet<void>(context, builder: (_) => _TemplateSheet(template: template));
}

/// Prayer offset range of the sheet, in our sign convention (> 0 = before):
/// from 45 min before to 60 min after adhan, in steps of 5.
const _maxBefore = 45, _maxAfter = -60, _offsetStep = 5;

/// Weekend time step of the anchor kind, and the first weekend time offered
/// when there is none yet (weekday + 1 h).
const _weekendStep = 15, _defaultWeekendShift = 60;

LocalTime _shift(LocalTime t, int minutes) {
  final m = (t.minutesOfDay + minutes) % (24 * 60);
  return LocalTime(m ~/ 60, m % 60);
}

class _TemplateSheet extends StatefulWidget {
  const _TemplateSheet({required this.template});

  final TemplateItem template;

  @override
  State<_TemplateSheet> createState() => _TemplateSheetState();
}

class _TemplateSheetState extends State<_TemplateSheet> {
  /// The user's reminder made from this template, if added.
  ReminderItem? _added;

  /// Draft schedule (time and prayer kinds edit it; the anchor kind keeps
  /// its [AnchorSchedule] and edits the shared anchor times below).
  late Schedule _schedule;

  late LocalTime _weekday;
  late bool _weekendOn;
  late LocalTime _weekend;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = AppScope.of(context);
    _added = s.reminders.byTemplate(widget.template.id);
    _schedule = _added?.schedule ?? widget.template.defaultSchedule;
    final anchor = _schedule is AnchorSchedule ? (_schedule as AnchorSchedule).anchor : Anchor.wake;
    final anchors = s.settings.anchors;
    _weekday = anchors.weekday(anchor);
    final weekend = anchors.weekend(anchor);
    _weekendOn = weekend != null && weekend != _weekday;
    _weekend = weekend ?? _shift(_weekday, _defaultWeekendShift);
  }

  bool get _valid => switch (_schedule) {
    TimeSchedule(:final daysMask) => daysMask & DaysMask.all != 0,
    PrayerSchedule(:final prayers) => prayers.isNotEmpty,
    AnchorSchedule() => true,
  };

  Future<void> _save() async {
    if (_busy) return;
    _busy = true;
    final s = AppScope.of(context);
    final navigator = Navigator.of(context);
    final added = _added;
    final schedule = _schedule;
    if (added == null) {
      await s.notifications.ensurePermission();
      if (schedule is PrayerSchedule) await s.notifications.ensureExactAlarms();
    }
    if (schedule is AnchorSchedule) {
      await s.settings.setAnchors(
        s.settings.anchors.withAnchor(schedule.anchor, _weekday, _weekendOn ? _weekend : null),
      );
    }
    await s.reminders.save(
      added?.copyWith(schedule: schedule) ??
          ReminderItem(
            id: s.reminders.newId(),
            source: ReminderSource.template,
            templateId: widget.template.id,
            schedule: schedule,
          ),
    );
    if (mounted) navigator.pop();
  }

  Future<void> _remove() async {
    if (_busy) return;
    _busy = true;
    final navigator = Navigator.of(context);
    await AppScope.of(context).reminders.delete(_added!.id);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = widget.template;
    final added = _added != null;
    final String cta;
    if (!_valid) {
      cta = _schedule is PrayerSchedule ? l.pickOnePrayer : l.pickOneDay;
    } else {
      cta = added ? l.saveChanges : l.addReminderCta;
    }

    return NiyahBottomSheet(
      semanticLabel: t.title,
      children: [
        SheetHeader(icon: t.icon, title: t.title),
        QuoteBox(body: l.dQuoted(t.body)),
        switch (_schedule) {
          final TimeSchedule time => _timeFields(l, time),
          final AnchorSchedule anchor => _anchorFields(l, anchor.anchor),
          final PrayerSchedule prayer => _prayerFields(l, prayer),
        },
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton(label: cta, onPressed: _valid ? _save : null),
              if (added) ...[
                const SizedBox(height: 4),
                NiyahTextButton(label: l.removeFromMine, danger: true, onPressed: _remove),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Edits the draft as it is when the callback runs (not when it was built).
  void _edit<T extends Schedule>(T Function(T draft) change) => setState(() => _schedule = change(_schedule as T));

  Widget _timeFields(AppLocalizations l, TimeSchedule time) => _Fields([
    _Label(l.fieldTime),
    TimeStepper(value: time.time, onChanged: (v) => _edit<TimeSchedule>((d) => d.copyWith(time: v))),
    _Label(l.fieldDays, top: 6),
    DaysSelector(
      mask: time.daysMask,
      onChanged: (v) => _edit<TimeSchedule>((d) => d.copyWith(daysMask: v)),
    ),
  ]);

  Widget _anchorFields(AppLocalizations l, Anchor anchor) {
    final c = context.niyah;
    final wake = anchor == Anchor.wake;
    return _Fields([
      _Label(wake ? l.anchorWakeLabel : l.anchorSleepLabel),
      TimeStepper(value: _weekday, onChanged: (v) => setState(() => _weekday = v)),
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
                value: _weekendOn,
                semanticLabel: l.differentOnWeekends,
                onChanged: (v) => setState(() => _weekendOn = v),
              ),
            ],
          ),
        ],
      ),
      if (_weekendOn)
        ValueStepper(
          label: l.weekendDays,
          value: formatTime(_weekend),
          decrementLabel: l.weekendEarlier,
          incrementLabel: l.weekendLater,
          onDecrement: () => setState(() => _weekend = _shift(_weekend, -_weekendStep)),
          onIncrement: () => setState(() => _weekend = _shift(_weekend, _weekendStep)),
        ),
    ]);
  }

  Widget _prayerFields(AppLocalizations l, PrayerSchedule prayer) {
    final offset = prayer.offsetMin;
    void step(int by) => _edit<PrayerSchedule>(
      (d) => d.copyWith(offsetMin: (d.offsetMin + by).clamp(_maxAfter, _maxBefore)),
    );
    return _Fields([
      _Label(l.whichPrayers),
      PrayerChips(selected: prayer.prayers, onChanged: (v) => _edit<PrayerSchedule>((d) => d.copyWith(prayers: v))),
      _Label(l.fieldWhen, top: 6),
      ValueStepper(
        label: offsetLabel(l, offset),
        emphasizeLabel: true,
        decrementLabel: l.earlier,
        incrementLabel: l.later,
        onDecrement: offset < _maxBefore ? () => step(_offsetStep) : null,
        onIncrement: offset > _maxAfter ? () => step(-_offsetStep) : null,
      ),
    ]);
  }
}

/// A column of fields 10 px apart.
class _Fields extends StatelessWidget {
  const _Fields(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, child) in children.indexed) ...[if (i > 0) const SizedBox(height: 10), child],
    ],
  );
}

/// 15 px semibold field label ("Time", "Days", "Which prayers?").
class _Label extends StatelessWidget {
  const _Label(this.text, {this.top = 0});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top),
    child: Text(text, style: NiyahText.sans(15, weight: FontWeight.w600, color: context.niyah.text)),
  );
}
