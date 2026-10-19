import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/defaults.dart';
import 'package:niyah/data/fake/fake_repositories.dart';
import 'package:niyah/data/memory_settings_store.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/data/repositories.dart';
import 'package:niyah/data/sqlite/core_prayer_repository.dart';
import 'package:niyah/data/sqlite/prefs_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const milan = FakeSettingsStore.sampleLocation;
const cairo = PrayerLocation(name: 'Cairo', country: 'EG', latitude: 30.0626, longitude: 31.2497, timezone: 'Africa/Cairo');

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
      expect(s.languageCode, isNull);
      expect(s.location, isNull);
      expect(s.prayerSettings, isNull);
      expect(s.methodChoice, isNull);
      expect(s.method, 'muslim_world_league');
      expect(s.madhab, 'shafi');
      expect(s.quietHours.enabled, isFalse);
      expect(s.pausedUntil, isNull);
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

    test('language, location, method, madhab, quiet hours and pause persist', () async {
      final s = PrefsSettingsStore();
      await s.init();
      var n = 0;
      s.addListener(() => n++);
      final until = DateTime.utc(2026, 10, 21, 7, 0);
      await s.setLanguageCode('it');
      await s.setLocation(const PrayerLocation(
        name: 'Milan', country: 'IT', latitude: 45.48, longitude: 9.23, timezone: 'Europe/Rome', fromGps: true));
      await s.setMethodChoice('egyptian');
      await s.setMadhab('hanafi');
      await s.setQuietHours(const QuietHours(enabled: true, start: LocalTime(23, 0), end: LocalTime(6, 15)));
      await s.setPausedUntil(until);
      expect(n, 6);

      final again = PrefsSettingsStore();
      await again.init();
      expect(again.languageCode, 'it');
      expect(again.location, s.location);
      expect(again.location!.fromGps, isTrue);
      expect(again.method, 'egyptian');
      expect(again.madhab, 'hanafi');
      expect(again.quietHours.enabled, isTrue);
      expect(again.quietHours.start, const LocalTime(23, 0));
      expect(again.quietHours.end, const LocalTime(6, 15));
      expect(again.pausedUntil, until);
      final p = again.prayerSettings!;
      expect((p.latitude, p.longitude, p.method, p.madhab), (45.48, 9.23, 'egyptian', 'hanafi'));

      // Back to "phone language", "suggested method" and "not paused".
      await again.setLanguageCode(null);
      await again.setMethodChoice(null);
      await again.setPausedUntil(null);
      final third = PrefsSettingsStore();
      await third.init();
      expect(third.languageCode, isNull);
      expect(third.methodChoice, isNull);
      expect(third.pausedUntil, isNull);
    });
  });

  group('SettingsStore rules', () {
    test('the suggested method follows the country until one is chosen', () async {
      final s = MemorySettingsStore(location: cairo);
      expect(s.method, 'egyptian');
      await s.setLocation(milan);
      expect(s.method, 'muslim_world_league');
      await s.setMethodChoice('karachi');
      await s.setLocation(cairo);
      expect(s.method, 'karachi');
    });

    test('paused only before the end, "forever" included', () async {
      final s = MemorySettingsStore();
      final now = DateTime.utc(2026, 10, 19, 12);
      expect(s.isPaused(now), isFalse);
      await s.setPausedUntil(now.add(const Duration(hours: 1)));
      expect(s.isPaused(now), isTrue);
      expect(s.isPaused(now.add(const Duration(hours: 2))), isFalse);
      await s.setPausedUntil(SettingsStore.pausedForever);
      expect(s.isPaused(DateTime.utc(2100)), isTrue);
    });
  });

  group('CorePrayerRepository', () {
    Future<CorePrayerRepository> repoAt(DateTime Function() clock, {SettingsStore? settings}) async {
      final repo = CorePrayerRepository(settings ?? MemorySettingsStore(location: milan), clock: clock);
      await repo.init();
      return repo;
    }

    test('today in Milan, in order, recomputed when the day changes', () async {
      var now = DateTime(2026, 10, 19, 12);
      final repo = await repoAt(() => now);
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

    test('next prayer', () async {
      final repo = await repoAt(() => DateTime(2026, 10, 19, 12));
      final times = repo.today!.times;
      expect(repo.nextPrayer(DateTime(2026, 10, 19, 0, 1))!.$1, Prayer.fajr);
      final afterDhuhr = times[Prayer.dhuhr]!;
      expect(repo.nextPrayer(DateTime(2026, 10, 19, afterDhuhr.hour, afterDhuhr.minute))!.$1, Prayer.asr);
      expect(repo.nextPrayer(DateTime(2026, 10, 19, 23, 59)), isNull);
    });

    test('no location: no times and no next prayer', () async {
      final repo = await repoAt(() => DateTime(2026, 10, 19, 12), settings: MemorySettingsStore());
      expect(repo.today, isNull);
      expect(repo.nextPrayer(DateTime(2026, 10, 19, 1)), isNull);
    });

    test('follows the settings: madhab, location and time zone', () async {
      final settings = MemorySettingsStore(location: milan);
      final repo = await repoAt(() => DateTime(2026, 10, 19, 12), settings: settings);
      var notified = 0;
      repo.addListener(() => notified++);
      final standardAsr = repo.today!.times[Prayer.asr]!;

      await settings.setMadhab('hanafi');
      expect(notified, 1);
      expect(repo.today!.times[Prayer.asr]!.minutesOfDay, greaterThan(standardAsr.minutesOfDay + 20));

      await settings.setLocation(cairo);
      expect(notified, 2);
      // Cairo in October (EEST, UTC+3): Dhuhr just before 12:40 local time.
      expect(repo.today!.times[Prayer.dhuhr]!.hour, inInclusiveRange(11, 12));

      await settings.setAnchors(Defaults.anchors); // not a prayer setting
      expect(notified, 2);
      await settings.setLocation(null);
      expect(notified, 3);
      expect(repo.today, isNull);
    });

    test('an unknown time zone name falls back to UTC instead of failing', () async {
      final settings = MemorySettingsStore(
        location: const PrayerLocation(name: 'X', country: 'IT', latitude: 45.46, longitude: 9.19, timezone: 'Mars/Base'),
      );
      final repo = await repoAt(() => DateTime(2026, 10, 19, 12), settings: settings);
      expect(repo.today!.times[Prayer.dhuhr]!.hour, 11); // ≈ 11:00 UTC
    });
  });
}
