import 'package:shared_preferences/shared_preferences.dart';

import '../defaults.dart';
import '../models.dart';
import '../repositories.dart';

/// [SettingsStore] in shared_preferences. Missing keys fall back to [Defaults].
class PrefsSettingsStore extends SettingsStore {
  late SharedPreferences _prefs;
  AnchorTimes _anchors = Defaults.anchors;
  bool _prayerDuringQuiet = Defaults.prayerDuringQuiet;

  static const _wake = 'anchors.wake';
  static const _wakeWeekend = 'anchors.wake_weekend';
  static const _sleep = 'anchors.sleep';
  static const _sleepWeekend = 'anchors.sleep_weekend';
  static const _prayerQuiet = 'prayer_during_quiet';

  /// Stored for a weekend time set to "same as weekdays" (null), so it is
  /// not confused with a key that was never written.
  static const _sameAsWeekdays = '';

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    const d = Defaults.anchors;
    LocalTime? weekend(String key, LocalTime? fallback) {
      final s = _prefs.getString(key);
      if (s == null) return fallback;
      return s == _sameAsWeekdays ? null : LocalTime.tryParse(s) ?? fallback;
    }

    _anchors = AnchorTimes(
      wake: LocalTime.tryParse(_prefs.getString(_wake)) ?? d.wake,
      wakeWeekend: weekend(_wakeWeekend, d.wakeWeekend),
      sleep: LocalTime.tryParse(_prefs.getString(_sleep)) ?? d.sleep,
      sleepWeekend: weekend(_sleepWeekend, d.sleepWeekend),
    );
    _prayerDuringQuiet = _prefs.getBool(_prayerQuiet) ?? Defaults.prayerDuringQuiet;
  }

  @override
  AnchorTimes get anchors => _anchors;

  @override
  Future<void> setAnchors(AnchorTimes value) async {
    await Future.wait([
      _prefs.setString(_wake, value.wake.toString()),
      _prefs.setString(_wakeWeekend, value.wakeWeekend?.toString() ?? _sameAsWeekdays),
      _prefs.setString(_sleep, value.sleep.toString()),
      _prefs.setString(_sleepWeekend, value.sleepWeekend?.toString() ?? _sameAsWeekdays),
    ]);
    _anchors = value;
    notifyListeners();
  }

  @override
  bool get prayerDuringQuiet => _prayerDuringQuiet;

  @override
  Future<void> setPrayerDuringQuiet(bool value) async {
    await _prefs.setBool(_prayerQuiet, value);
    _prayerDuringQuiet = value;
    notifyListeners();
  }
}
