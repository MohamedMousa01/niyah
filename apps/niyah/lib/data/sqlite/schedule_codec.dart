import 'package:niyah_core/niyah_core.dart' as core;

import '../models.dart';

/// Conversions between the UI [Schedule] and the schedule columns of
/// `reminders` (also used for `templates.default_schedule_json`, which has the
/// same keys).

/// Schedule columns for [s]. Every column is set, so switching kind clears
/// the old values.
Map<String, Object?> scheduleColumns(Schedule s) => switch (s) {
      TimeSchedule(:final time, :final daysMask) => {
          'schedule_type': daysMask & DaysMask.all == DaysMask.all ? 'daily' : 'weekly',
          'time': time.toString(),
          'days_mask': daysMask,
          'prayer': null,
          'prayers_mask': null,
          'offset_min': 0,
          'anchor': null,
        },
      AnchorSchedule(:final anchor) => {
          'schedule_type': 'anchor',
          'time': null,
          'days_mask': DaysMask.all,
          'prayer': null,
          'prayers_mask': null,
          'offset_min': 0,
          'anchor': anchor.name,
        },
      PrayerSchedule(:final prayers, :final offsetMin) => {
          'schedule_type': 'prayer',
          'time': null,
          'days_mask': DaysMask.all,
          'prayer': null,
          'prayers_mask': core.PrayersMask.of(prayers),
          // The table only accepts −60…120.
          'offset_min': offsetMin.clamp(-60, 120),
          'anchor': null,
        },
    };

/// The UI schedule of a stored reminder, or null for kinds the UI does not
/// show (once, window).
Schedule? scheduleOf(core.Reminder r) => switch (r.scheduleType) {
      core.ScheduleType.daily ||
      core.ScheduleType.weekly =>
        TimeSchedule(r.time ?? const LocalTime(8, 0), daysMask: r.daysMask),
      core.ScheduleType.prayer => PrayerSchedule(r.prayers.toSet(), offsetMin: r.offsetMin),
      core.ScheduleType.anchor => AnchorSchedule(r.anchor == core.AnchorKind.sleep ? Anchor.sleep : Anchor.wake),
      core.ScheduleType.once || core.ScheduleType.window => null,
    };

/// The schedule in a template's `default_schedule_json`.
Schedule? scheduleFromJson(Map<String, Object?> json) => scheduleOf(core.Reminder.fromRow({
      ...json,
      'id': '',
      'kind': 'template',
      'start_date': '2000-01-01',
    }));

/// [AnchorTimes] for [core.expandReminders].
core.DayAnchors dayAnchors(AnchorTimes a) =>
    core.DayAnchors(wake: a.wake, wakeWeekend: a.wakeWeekend, sleep: a.sleep, sleepWeekend: a.sleepWeekend);
