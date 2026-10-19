import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:niyah/core/format.dart';
import 'package:niyah/data/defaults.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/l10n/app_localizations.dart';

void main() {
  late AppLocalizations en, it;
  const five = {Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha};
  const anchors = Defaults.anchors; // wake 06:40, weekends 08:00, sleep 22:30

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('it');
    en = lookupAppLocalizations(const Locale('en'));
    it = lookupAppLocalizations(const Locale('it'));
  });

  test('formatTime pads to HH:mm', () {
    expect(formatTime(const LocalTime(7, 5)), '07:05');
    expect(formatTime(const LocalTime(23, 30)), '23:30');
  });

  test('weekdayNames start on Monday and are capitalized', () {
    expect(weekdayNames('en'), ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']);
    expect(weekdayNames('it', width: DayNameWidth.narrow), ['L', 'M', 'M', 'G', 'V', 'S', 'D']);
    expect(weekdayNames('it', width: DayNameWidth.short).first, 'Lun');
  });

  group('daysLabel', () {
    test('en', () {
      expect(daysLabel(en, 127), 'Every day');
      expect(daysLabel(en, 0), 'No days');
      expect(daysLabel(en, 31), 'Mon–Fri');
      expect(daysLabel(en, 96), 'Weekends');
      expect(daysLabel(en, 1 << 4), 'Friday');
      expect(daysLabel(en, 1 | 4 | 16), 'Mon, Wed, Fri');
    });
    test('it', () {
      expect(daysLabel(it, 127), 'Ogni giorno');
      expect(daysLabel(it, 31), 'Lun–Ven');
      expect(daysLabel(it, 96), 'Weekend');
      expect(daysLabel(it, 1 << 4), 'Venerdì');
      expect(daysLabel(it, 1 | 4), 'Lun, Mer');
    });
  });

  test('offsetLabel is signed: > 0 before, 0 at, < 0 after', () {
    expect(offsetLabel(en, 10), '10 min before adhan');
    expect(offsetLabel(en, 0), 'At adhan');
    expect(offsetLabel(en, -15), '15 min after adhan');
    expect(offsetLabel(it, 10), "10 min prima dell'adhan");
    expect(offsetLabel(it, -20), "20 min dopo l'adhan");
  });

  test('prayer names and lists', () {
    expect(prayerName(en, Prayer.maghrib), 'Maghrib');
    expect(prayersLabel(en, five), 'every prayer');
    expect(prayersLabel(it, five), 'ogni preghiera');
    expect(prayersLabel(en, {Prayer.isha, Prayer.fajr}), 'Fajr, Isha');
    expect(prayerList(en, five), 'Fajr, Dhuhr, Asr, Maghrib, Isha');
    expect(prayerTimingLabel(en, 10), '10 min before');
    expect(prayerTimingLabel(en, 0), 'At adhan');
    expect(prayerTimingLabel(it, -15), 'Dopo la preghiera');
  });

  group('scheduleText', () {
    test('time', () {
      expect(scheduleText(en, const TimeSchedule(LocalTime(8, 0)), anchors), '08:00 · Every day');
      expect(scheduleText(en, const TimeSchedule(LocalTime(9, 0), daysMask: 31), anchors), '09:00 · Mon–Fri');
      expect(scheduleText(it, const TimeSchedule(LocalTime(9, 0), daysMask: 31), anchors), '09:00 · Lun–Ven');
    });
    test('anchor, with and without a weekend time', () {
      expect(
        scheduleText(en, const AnchorSchedule(Anchor.wake), anchors),
        'At your wake-up time · 06:40 · weekends 08:00',
      );
      expect(scheduleText(en, const AnchorSchedule(Anchor.sleep), anchors), 'At your bedtime · 22:30');
      expect(scheduleText(it, const AnchorSchedule(Anchor.wake), anchors), 'Al tuo risveglio · 06:40 · weekend 08:00');
    });
    test('prayer', () {
      expect(
        scheduleText(en, const PrayerSchedule(five, offsetMin: 10), anchors),
        '10 min before adhan · every prayer',
      );
      expect(
        scheduleText(en, const PrayerSchedule({Prayer.fajr}, offsetMin: -20), anchors),
        '20 min after adhan · Fajr',
      );
      expect(scheduleText(it, const PrayerSchedule(five, offsetMin: 0), anchors), "All'adhan · ogni preghiera");
    });
  });
}
