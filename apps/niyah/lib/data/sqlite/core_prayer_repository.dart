import 'package:niyah_core/niyah_core.dart' as core;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';
import '../repositories.dart';

/// [PrayerRepository] computed offline with niyah_core (adhan) for the
/// location, method and madhab in [SettingsStore], in the location's time
/// zone. Recomputes and notifies when those settings change.
class CorePrayerRepository extends PrayerRepository {
  CorePrayerRepository(this._settings, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _settings.addListener(_onSettings);
  }

  final SettingsStore _settings;
  final DateTime Function() _clock;
  PrayerDay? _today;

  /// Settings and time zone [_today] was computed with.
  String? _todayKey;

  static bool _tzReady = false;

  @override
  Future<void> init() async {
    if (!_tzReady) {
      tzdata.initializeTimeZones();
      _tzReady = true;
    }
  }

  String? _key() {
    final s = _settings.prayerSettings;
    return s?.hash(_settings.location!.timezone);
  }

  void _onSettings() {
    if (_key() == _todayKey) return;
    _today = null;
    _todayKey = null;
    notifyListeners();
  }

  /// Today's times, recomputed when the date or the settings change.
  @override
  PrayerDay? get today {
    final settings = _settings.prayerSettings;
    if (settings == null) return null;
    final now = _clock();
    final date = DateTime(now.year, now.month, now.day);
    final key = _key();
    final cached = _today;
    if (cached != null && cached.date == date && key == _todayKey) return cached;
    final day = core.computePrayerTimes(core.LocalDate.of(now), settings, _zone(_settings.location!.timezone));
    _todayKey = key;
    return _today = PrayerDay(date, {
      for (final e in day.times.entries) e.key: LocalTime(e.value.hour, e.value.minute),
    });
  }

  /// The location's zone; UTC for a name this tz database doesn't know.
  static tz.Location _zone(String name) {
    try {
      return tz.getLocation(name);
    } catch (_) {
      return tz.UTC;
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettings);
    super.dispose();
  }
}
