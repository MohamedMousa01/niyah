import 'models.dart';

/// First-run values: what the settings hold until the user changes them in
/// Settings, and the schedule of the prayer reminder when it is created.
/// There is no default prayer location: prayer times wait until the user
/// picks a city or uses the phone's location.
class Defaults {
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

  /// Asr: 'shafi' (standard: Shafi'i, Maliki, Hanbali) or 'hanafi'.
  static const madhab = 'shafi';

  /// Off, 22:30 → 07:00 when switched on.
  static const quietHours = QuietHours();
}
