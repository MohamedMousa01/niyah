import 'models.dart';

/// Temporary values used until the Settings screen exists (docs/app-plan.md §1).
/// Keep every such default here so it is easy to remove later.
class Defaults {
  static const prayerCity = 'Milan';
  static const prayerLat = 45.4642;
  static const prayerLng = 9.1900;
  static const prayerTimezone = 'Europe/Rome';
  static const prayerMethod = 'muslim_world_league';
  static const prayerMethodLabel = 'Muslim World League';
  static const asrMadhab = 'shafi';

  static const anchors = AnchorTimes(
    wake: LocalTime(6, 40),
    wakeWeekend: LocalTime(8, 0),
    sleep: LocalTime(22, 30),
  );

  static const prayerReminder = PrayerSchedule(
    {Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha},
    offsetMin: 10,
  );

  static const prayerDuringQuiet = true;
}
