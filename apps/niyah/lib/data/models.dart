import 'package:niyah_core/niyah_core.dart' show LocalTime, Prayer, DaysMask;

export 'package:niyah_core/niyah_core.dart' show LocalTime, Prayer, DaysMask;

/// Which list a reminder belongs to in "My reminders".
enum ReminderSource { personal, template, prayer }

/// Wake-up or bedtime: reminders that follow the user's day, not a clock time.
enum Anchor { wake, sleep }

/// Groups and filters of the "Add a reminder" screen.
enum TemplateGroup { prayer, daily, dhikr, weekly }

/// When a reminder fires.
sealed class Schedule {
  const Schedule();
}

/// At a clock time on some days of the week. [daysMask]: bit 0 = Monday.
class TimeSchedule extends Schedule {
  final LocalTime time;
  final int daysMask;
  const TimeSchedule(this.time, {this.daysMask = DaysMask.all});

  TimeSchedule copyWith({LocalTime? time, int? daysMask}) =>
      TimeSchedule(time ?? this.time, daysMask: daysMask ?? this.daysMask);

  @override
  bool operator ==(Object other) => other is TimeSchedule && other.time == time && other.daysMask == daysMask;
  @override
  int get hashCode => Object.hash(time, daysMask);
}

/// At the user's wake-up time or bedtime (times live in [AnchorTimes]).
class AnchorSchedule extends Schedule {
  final Anchor anchor;
  const AnchorSchedule(this.anchor);

  @override
  bool operator ==(Object other) => other is AnchorSchedule && other.anchor == anchor;
  @override
  int get hashCode => anchor.hashCode;
}

/// Relative to one or more prayers. [offsetMin] > 0 = before adhan,
/// 0 = at adhan, < 0 = after adhan.
class PrayerSchedule extends Schedule {
  final Set<Prayer> prayers;
  final int offsetMin;
  const PrayerSchedule(this.prayers, {this.offsetMin = 10});

  PrayerSchedule copyWith({Set<Prayer>? prayers, int? offsetMin}) =>
      PrayerSchedule(prayers ?? this.prayers, offsetMin: offsetMin ?? this.offsetMin);

  @override
  bool operator ==(Object other) =>
      other is PrayerSchedule && other.offsetMin == offsetMin && other.prayers.length == prayers.length && other.prayers.containsAll(prayers);
  @override
  int get hashCode => Object.hash(offsetMin, Object.hashAllUnordered(prayers));
}

/// A reminder as the UI sees it.
///
/// For [ReminderSource.template], always read the texts from
/// [TemplateRepository.byId] in the current language: [title]/[body] may be
/// null (the SQLite repository does not store them). For
/// [ReminderSource.prayer], null texts mean "use the default words".
class ReminderItem {
  final String id;
  final ReminderSource source;
  final String? templateId;
  final String? title;
  final String? body;
  final Schedule schedule;
  final bool enabled;

  const ReminderItem({
    required this.id,
    required this.source,
    this.templateId,
    this.title,
    this.body,
    required this.schedule,
    this.enabled = true,
  });

  ReminderItem copyWith({String? title, String? body, Schedule? schedule, bool? enabled}) => ReminderItem(
        id: id,
        source: source,
        templateId: templateId,
        title: title ?? this.title,
        body: body ?? this.body,
        schedule: schedule ?? this.schedule,
        enabled: enabled ?? this.enabled,
      );
}

/// A ready-made moment on the "Add a reminder" screen.
class TemplateItem {
  final String id;
  final TemplateGroup group;

  /// Key into the icon set (`lib/core/widgets/niyah_icons.dart`).
  final String icon;
  final String title;
  final String body;
  final Schedule defaultSchedule;

  const TemplateItem({
    required this.id,
    required this.group,
    required this.icon,
    required this.title,
    required this.body,
    required this.defaultSchedule,
  });
}

/// The user's wake-up time and bedtime. A null weekend time = same as weekdays.
class AnchorTimes {
  final LocalTime wake;
  final LocalTime? wakeWeekend;
  final LocalTime sleep;
  final LocalTime? sleepWeekend;

  const AnchorTimes({required this.wake, this.wakeWeekend, required this.sleep, this.sleepWeekend});

  LocalTime weekday(Anchor a) => a == Anchor.wake ? wake : sleep;
  LocalTime? weekend(Anchor a) => a == Anchor.wake ? wakeWeekend : sleepWeekend;

  AnchorTimes withAnchor(Anchor a, LocalTime weekday, LocalTime? weekend) => a == Anchor.wake
      ? AnchorTimes(wake: weekday, wakeWeekend: weekend, sleep: sleep, sleepWeekend: sleepWeekend)
      : AnchorTimes(wake: wake, wakeWeekend: wakeWeekend, sleep: weekday, sleepWeekend: weekend);
}

/// Prayer times of one day, in local time.
class PrayerDay {
  final DateTime date;
  final Map<Prayer, LocalTime> times;
  const PrayerDay(this.date, this.times);
}
