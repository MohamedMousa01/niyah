import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/defaults.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/data/sqlite/core_prayer_repository.dart';
import 'package:niyah/data/sqlite/prefs_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PrefsSettingsStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults when nothing is stored', () async {
      final s = PrefsSettingsStore();
      await s.init();
      expect(s.anchors.wake, Defaults.anchors.wake);
      expect(s.anchors.wakeWeekend, Defaults.anchors.wakeWeekend);
      expect(s.anchors.sleep, Defaults.anchors.sleep);
      expect(s.anchors.sleepWeekend, isNull);
      expect(s.prayerDuringQuiet, Defaults.prayerDuringQuiet);
    });

    test('values persist, including "weekend = same as weekdays"', () async {
      final s = PrefsSettingsStore();
      await s.init();
      var n = 0;
      s.addListener(() => n++);
      await s.setAnchors(const AnchorTimes(wake: LocalTime(5, 30), sleep: LocalTime(23, 0), sleepWeekend: LocalTime(23, 30)));
      await s.setPrayerDuringQuiet(false);
      expect(n, 2);

      final again = PrefsSettingsStore();
      await again.init();
      expect(again.anchors.wake, const LocalTime(5, 30));
      expect(again.anchors.wakeWeekend, isNull); // not the 08:00 default
      expect(again.anchors.sleep, const LocalTime(23, 0));
      expect(again.anchors.sleepWeekend, const LocalTime(23, 30));
      expect(again.prayerDuringQuiet, isFalse);
    });
  });

  group('CorePrayerRepository', () {
    test('today in Milan, in order, recomputed when the day changes', () async {
      var now = DateTime(2026, 10, 19, 12);
      final repo = CorePrayerRepository(clock: () => now);
      await repo.init();
      final day = repo.today!;
      expect(day.date, DateTime(2026, 10, 19));
      expect(day.times.keys, Prayer.values);
      final minutes = day.times.values.map((t) => t.minutesOfDay).toList();
      expect([...minutes]..sort(), minutes);
      // Milan, mid-October (CEST): Fajr before 7:00, Dhuhr around 13:00, Isha after 19:00.
      expect(day.times[Prayer.fajr]!.hour, inInclusiveRange(5, 6));
      expect(day.times[Prayer.dhuhr]!.hour, inInclusiveRange(12, 13));
      expect(day.times[Prayer.isha]!.hour, inInclusiveRange(19, 20));
      expect(identical(repo.today, day), isTrue);

      now = DateTime(2026, 12, 21, 12);
      expect(repo.today!.date, DateTime(2026, 12, 21));
      expect(repo.today!.times[Prayer.maghrib]!.minutesOfDay, lessThan(day.times[Prayer.maghrib]!.minutesOfDay));
    });

    test('next prayer and label', () async {
      final repo = CorePrayerRepository(clock: () => DateTime(2026, 10, 19, 12));
      await repo.init();
      final times = repo.today!.times;
      expect(repo.nextPrayer(DateTime(2026, 10, 19, 0, 1))!.$1, Prayer.fajr);
      final afterDhuhr = times[Prayer.dhuhr]!;
      expect(repo.nextPrayer(DateTime(2026, 10, 19, afterDhuhr.hour, afterDhuhr.minute))!.$1, Prayer.asr);
      expect(repo.nextPrayer(DateTime(2026, 10, 19, 23, 59)), isNull);
      expect(repo.locationLabel, 'Milan · Muslim World League');
    });
  });
}
