import 'dart:convert';

import 'package:niyah_core/niyah_core.dart' show QuietMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../defaults.dart';
import '../memory_settings_store.dart';
import '../models.dart';

/// [SettingsStore] in shared_preferences. Missing keys keep the [Defaults].
class PrefsSettingsStore extends MemorySettingsStore {
  late SharedPreferences _prefs;

  static const _wake = 'anchors.wake';
  static const _wakeWeekend = 'anchors.wake_weekend';
  static const _sleep = 'anchors.sleep';
  static const _sleepWeekend = 'anchors.sleep_weekend';
  static const _prayerQuiet = 'prayer_during_quiet';
  static const _theme = 'theme';
  static const _language = 'language';
  static const _location = 'prayer.location';
  static const _method = 'prayer.method';
  static const _madhab = 'prayer.madhab';
  static const _quiet = 'quiet_hours';
  static const _paused = 'paused_until';

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

    Object? json(String key) {
      try {
        return jsonDecode(_prefs.getString(key) ?? 'null');
      } on FormatException {
        return null;
      }
    }

    load(
      anchors: AnchorTimes(
        wake: LocalTime.tryParse(_prefs.getString(_wake)) ?? d.wake,
        wakeWeekend: weekend(_wakeWeekend, d.wakeWeekend),
        sleep: LocalTime.tryParse(_prefs.getString(_sleep)) ?? d.sleep,
        sleepWeekend: weekend(_sleepWeekend, d.sleepWeekend),
      ),
      prayerDuringQuiet: _prefs.getBool(_prayerQuiet),
      theme: AppTheme.values.asNameMap()[_prefs.getString(_theme)],
      languageCode: _prefs.getString(_language),
      location: PrayerLocation.fromJson(json(_location)),
      methodChoice: _prefs.getString(_method),
      madhab: _prefs.getString(_madhab),
      quietHours: _prefs.containsKey(_quiet) ? QuietHours.fromJson(json(_quiet)) : null,
      pausedUntil: DateTime.tryParse(_prefs.getString(_paused) ?? ''),
    );
  }

  Future<void> _setOrRemove(String key, String? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, value);

  @override
  Future<void> setAnchors(AnchorTimes value) async {
    await Future.wait([
      _prefs.setString(_wake, value.wake.toString()),
      _prefs.setString(_wakeWeekend, value.wakeWeekend?.toString() ?? _sameAsWeekdays),
      _prefs.setString(_sleep, value.sleep.toString()),
      _prefs.setString(_sleepWeekend, value.sleepWeekend?.toString() ?? _sameAsWeekdays),
    ]);
    await super.setAnchors(value);
  }

  @override
  Future<void> setPrayerDuringQuiet(bool value) async {
    await _prefs.setBool(_prayerQuiet, value);
    await super.setPrayerDuringQuiet(value);
  }

  @override
  Future<void> setTheme(AppTheme value) async {
    await _prefs.setString(_theme, value.name);
    await super.setTheme(value);
  }

  @override
  Future<void> setLanguageCode(String? value) async {
    await _setOrRemove(_language, value);
    await super.setLanguageCode(value);
  }

  @override
  Future<void> setLocation(PrayerLocation? value) async {
    await _setOrRemove(_location, value == null ? null : jsonEncode(value.toJson()));
    await super.setLocation(value);
  }

  @override
  Future<void> setMethodChoice(String? value) async {
    await _setOrRemove(_method, value);
    await super.setMethodChoice(value);
  }

  @override
  Future<void> setMadhab(String value) async {
    await _prefs.setString(_madhab, value);
    await super.setMadhab(value);
  }

  @override
  Future<void> setQuietHours(QuietHours value) async {
    await _prefs.setString(
      _quiet,
      jsonEncode({
        'enabled': value.enabled,
        'start': value.start.toString(),
        'end': value.end.toString(),
        'mode': value.mode == QuietMode.shift ? 'shift' : 'skip',
      }),
    );
    await super.setQuietHours(value);
  }

  @override
  Future<void> setPausedUntil(DateTime? value) async {
    await _setOrRemove(_paused, value?.toUtc().toIso8601String());
    await super.setPausedUntil(value);
  }
}
