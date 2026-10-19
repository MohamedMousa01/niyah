import 'package:niyah_core/niyah_core.dart' as core;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../defaults.dart';
import '../models.dart';
import '../repositories.dart';

/// [PrayerRepository] computed offline with niyah_core (adhan) for the
/// location in [Defaults], in that location's time zone.
class CorePrayerRepository extends PrayerRepository {
  CorePrayerRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  late tz.Location _location;
  PrayerDay? _today;

  static const settings = core.PrayerSettings(
    latitude: Defaults.prayerLat,
    longitude: Defaults.prayerLng,
    method: Defaults.prayerMethod,
    madhab: Defaults.asrMadhab,
  );

  static bool _tzReady = false;

  @override
  Future<void> init() async {
    if (!_tzReady) {
      tzdata.initializeTimeZones();
      _tzReady = true;
    }
    _location = tz.getLocation(Defaults.prayerTimezone);
  }

  /// Today's times, recomputed when the date changes.
  @override
  PrayerDay? get today {
    final now = _clock();
    final date = DateTime(now.year, now.month, now.day);
    final cached = _today;
    if (cached != null && cached.date == date) return cached;
    final day = core.computePrayerTimes(core.LocalDate.of(now), settings, _location);
    return _today = PrayerDay(date, {
      for (final e in day.times.entries) e.key: LocalTime(e.value.hour, e.value.minute),
    });
  }

  @override
  String get locationLabel => '${Defaults.prayerCity} · ${Defaults.prayerMethodLabel}';

  @override
  (Prayer, LocalTime)? nextPrayer(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    for (final e in today!.times.entries) {
      if (e.value.minutesOfDay > minutes) return (e.key, e.value);
    }
    return null;
  }
}
