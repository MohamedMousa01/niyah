import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../l10n/app_localizations.dart';

/// Text formatting shared by every screen: times, days, offsets, prayers and
/// the "when" line of a reminder, exactly as the design writes them.
///
/// Functions take [AppLocalizations] so they can be unit-tested; use
/// [scheduleLabel] from widgets.

/// Width of a localized day name.
enum DayNameWidth {
  /// "Monday", "Lunedì".
  long,

  /// "Mon", "Lun".
  short,

  /// "M", "L".
  narrow,
}

String _two(int n) => n.toString().padLeft(2, '0');

String _capitalized(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "07:15".
String formatTime(LocalTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// The seven day names in [locale], Monday first (index 0 = bit 0 of a days
/// mask), capitalized for standalone use.
List<String> weekdayNames(String locale, {DayNameWidth width = DayNameWidth.long}) {
  final symbols = DateFormat.E(locale).dateSymbols;
  final sundayFirst = switch (width) {
    DayNameWidth.long => symbols.STANDALONEWEEKDAYS,
    DayNameWidth.short => symbols.STANDALONESHORTWEEKDAYS,
    DayNameWidth.narrow => symbols.STANDALONENARROWWEEKDAYS,
  };
  return [for (var i = 1; i <= 7; i++) _capitalized(sundayFirst[i % 7])];
}

/// "Every day", "Mon–Fri", "Weekends", "Friday", "Mon, Wed, Fri", "No days".
String daysLabel(AppLocalizations l, int daysMask) {
  final mask = daysMask & DaysMask.all;
  final on = DaysMask.weekdays(mask);
  if (on.length == 7) return l.scheduleEveryDay;
  if (on.isEmpty) return l.scheduleNoDays;
  if (mask == 0x1F) return l.scheduleWeekdays;
  if (mask == 0x60) return l.scheduleWeekends;
  if (on.length == 1) return weekdayNames(l.localeName)[on.single - 1];
  final short = weekdayNames(l.localeName, width: DayNameWidth.short);
  return on.map((d) => short[d - 1]).join(', ');
}

/// Signed prayer offset (> 0 before, 0 at, < 0 after): "10 min before adhan".
String offsetLabel(AppLocalizations l, int offsetMin) {
  if (offsetMin > 0) return l.offsetBeforeAdhan(offsetMin);
  if (offsetMin == 0) return l.offsetAtAdhan;
  return l.offsetAfterAdhan(-offsetMin);
}

/// The short timing used by the Prayer screen and card: "10 min before",
/// "At adhan", "After prayer".
String prayerTimingLabel(AppLocalizations l, int offsetMin) {
  if (offsetMin > 0) return l.prayerMinBefore(offsetMin);
  if (offsetMin == 0) return l.prayerModeAdhan;
  return l.prayerAfterPrayer;
}

String prayerName(AppLocalizations l, Prayer p) => switch (p) {
  Prayer.fajr => l.prayerFajr,
  Prayer.dhuhr => l.prayerDhuhr,
  Prayer.asr => l.prayerAsr,
  Prayer.maghrib => l.prayerMaghrib,
  Prayer.isha => l.prayerIsha,
};

/// "Fajr, Asr" in prayer order.
String prayerList(AppLocalizations l, Set<Prayer> prayers) => [
  for (final p in Prayer.values)
    if (prayers.contains(p)) prayerName(l, p),
].join(', ');

/// Like [prayerList], but all five read "every prayer".
String prayersLabel(AppLocalizations l, Set<Prayer> prayers) =>
    prayers.length == Prayer.values.length ? l.everyPrayer : prayerList(l, prayers);

/// The "when" line of a reminder:
/// - time: "08:00 · Every day"
/// - anchor: "At your wake-up time · 06:40 · weekends 08:00"
/// - prayer: "10 min before adhan · every prayer"
String scheduleText(AppLocalizations l, Schedule schedule, AnchorTimes anchors) => switch (schedule) {
  TimeSchedule(:final time, :final daysMask) => l.scheduleTimeDays(formatTime(time), daysLabel(l, daysMask)),
  AnchorSchedule(:final anchor) => _anchorText(l, anchor, anchors),
  PrayerSchedule(:final prayers, :final offsetMin) => l.schedulePrayers(
    offsetLabel(l, offsetMin),
    prayersLabel(l, prayers),
  ),
};

String _anchorText(AppLocalizations l, Anchor anchor, AnchorTimes anchors) {
  final weekday = anchors.weekday(anchor);
  final weekend = anchors.weekend(anchor);
  final t = formatTime(weekday);
  final base = anchor == Anchor.wake ? l.scheduleAtWakeUp(t) : l.scheduleAtBedtime(t);
  if (weekend == null || weekend == weekday) return base;
  return '$base · ${l.scheduleWeekendsAt(formatTime(weekend))}';
}

/// [scheduleText] in the current locale.
String scheduleLabel(BuildContext context, Schedule schedule, AnchorTimes anchors) =>
    scheduleText(AppLocalizations.of(context), schedule, anchors);

/// The calculation methods offered in Settings (adhan `CalculationMethod`
/// names), most used first. adhan's `other` (no angles) is left out.
const calculationMethods = [
  'muslim_world_league',
  'umm_al_qura',
  'egyptian',
  'karachi',
  'north_america',
  'dubai',
  'kuwait',
  'qatar',
  'singapore',
  'turkey',
  'tehran',
  'moon_sighting_committee',
];

/// "Muslim World League"; the raw name for one this version doesn't know.
String methodName(AppLocalizations l, String method) => switch (method) {
  'muslim_world_league' => l.methodMuslimWorldLeague,
  'egyptian' => l.methodEgyptian,
  'karachi' => l.methodKarachi,
  'umm_al_qura' => l.methodUmmAlQura,
  'dubai' => l.methodDubai,
  'moon_sighting_committee' => l.methodMoonSighting,
  'north_america' => l.methodNorthAmerica,
  'kuwait' => l.methodKuwait,
  'qatar' => l.methodQatar,
  'singapore' => l.methodSingapore,
  'turkey' => l.methodTurkey,
  'tehran' => l.methodTehran,
  _ => method,
};

/// The place of a prayer location: "Milan", or "Near Milan" for a GPS fix.
String placeName(AppLocalizations l, PrayerLocation location) =>
    location.fromGps ? l.locationNear(location.name) : location.name;

/// "Milan · Muslim World League" (null while no location is set).
String? prayerLocationLabel(AppLocalizations l, PrayerLocation? location, String method) =>
    location == null ? null : l.locationAndMethod(placeName(l, location), methodName(l, method));

/// Wake-up or bedtime: "06:40", "06:40 · weekends 08:00".
String anchorTimesLabel(AppLocalizations l, AnchorTimes anchors, Anchor anchor) {
  final weekday = anchors.weekday(anchor);
  final weekend = anchors.weekend(anchor);
  final t = formatTime(weekday);
  if (weekend == null || weekend == weekday) return t;
  return '$t · ${l.scheduleWeekendsAt(formatTime(weekend))}';
}

/// "Tue, Oct 21, 09:00" / "mar 21 ott, 09:00".
String formatDateTime(AppLocalizations l, DateTime local) =>
    '${DateFormat.MMMEd(l.localeName).format(local)}, ${formatTime(LocalTime(local.hour, local.minute))}';
