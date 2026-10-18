// Impostazioni piccole e persistenti (lingua, Non disturbare, pausa…).
// I promemoria stanno in SQLite; qui solo preferenze dell'utente.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:niyah_core/niyah_core.dart' as core;
import 'package:shared_preferences/shared_preferences.dart';

const kSupportedLanguages = ['it', 'en', 'fr', 'ar'];

/// Nome di ogni lingua scritto nella lingua stessa.
const kLanguageNames = {'it': 'Italiano', 'en': 'English', 'fr': 'Français', 'ar': 'العربية'};

class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs, {String? deviceLanguage, DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    final saved = _prefs.getString(_kLanguage);
    _language = kSupportedLanguages.contains(saved)
        ? saved!
        : (kSupportedLanguages.contains(deviceLanguage) ? deviceLanguage! : 'it');
    _onboardingCompleted = _prefs.getBool(_kOnboarding) ?? false;
    _quietHours = core.QuietHours.fromJson(_decode(_prefs.getString(_kQuietHours)));
    _pausedUntil = DateTime.tryParse(_prefs.getString(_kPausedUntil) ?? '')?.toUtc();
    _deviceId = _prefs.getString(_kDeviceId) ?? _newDeviceId();
  }

  static const _kLanguage = 'language';
  static const _kOnboarding = 'onboarding_completed';
  static const _kQuietHours = 'quiet_hours';
  static const _kPausedUntil = 'paused_until';
  static const _kDeviceId = 'device_id';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  late String _language;
  late bool _onboardingCompleted;
  late core.QuietHours _quietHours;
  DateTime? _pausedUntil;
  late String _deviceId;

  String get language => _language;
  bool get onboardingCompleted => _onboardingCompleted;
  core.QuietHours get quietHours => _quietHours;

  /// Istante UTC fino a cui tutte le notifiche sono in pausa (null = attive).
  DateTime? get pausedUntil {
    final p = _pausedUntil;
    return p != null && p.isAfter(_clock().toUtc()) ? p : null;
  }

  /// Identificativo anonimo di questo dispositivo, solo per risolvere i
  /// conflitti della sincronizzazione (mai usato per tracciare).
  String get deviceId => _deviceId;

  String _newDeviceId() {
    final id = core.generateUuidV4();
    _prefs.setString(_kDeviceId, id);
    return id;
  }

  static Object? _decode(String? s) {
    if (s == null) return null;
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLanguage(String lang) async {
    if (!kSupportedLanguages.contains(lang) || lang == _language) return;
    _language = lang;
    await _prefs.setString(_kLanguage, lang);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;
    await _prefs.setBool(_kOnboarding, true);
    notifyListeners();
  }

  Future<void> setQuietHours(core.QuietHours q) async {
    _quietHours = q;
    await _prefs.setString(_kQuietHours, jsonEncode({
      'enabled': q.enabled,
      'start': q.start.toString(),
      'end': q.end.toString(),
      'mode': q.mode.name,
    }));
    notifyListeners();
  }

  Future<void> setPausedUntil(DateTime? until) async {
    _pausedUntil = until?.toUtc();
    if (until == null) {
      await _prefs.remove(_kPausedUntil);
    } else {
      await _prefs.setString(_kPausedUntil, _pausedUntil!.toIso8601String());
    }
    notifyListeners();
  }
}
