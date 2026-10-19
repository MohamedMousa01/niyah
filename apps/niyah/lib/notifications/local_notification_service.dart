import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/repositories.dart';
import 'notification_platform.dart';
import 'schedule_builder.dart';
import 'schedule_inputs.dart';

/// [NotificationService] on `flutter_local_notifications`: the "hybrid
/// budget" strategy of architettura §6. Every method is a no-op on web (and
/// on any platform other than Android and iOS).
class LocalNotificationService implements NotificationService {
  LocalNotificationService({
    required this.inputs,
    NotificationPlatform? platform,
    Future<String?> Function()? deviceTimezone,
    Locale Function()? locale,
    DateTime Function()? clock,
  })  : _platform = platform ?? PluginNotificationPlatform(),
        _deviceTimezone = deviceTimezone ?? _flutterTimezone,
        _locale = locale ?? (() => PlatformDispatcher.instance.locale),
        _clock = clock ?? DateTime.now;

  final ScheduleInputs inputs;
  final NotificationPlatform _platform;
  final Future<String?> Function() _deviceTimezone;
  final Locale Function() _locale;
  final DateTime Function() _clock;

  static const _kLastTimezone = 'notif_last_timezone';
  static const _kLastExact = 'notif_last_exact';
  static const _kLastRescheduleAt = 'notif_last_reschedule_at';
  static const _kPermissionAsked = 'notif_permission_asked';

  static bool _tzReady = false;
  Future<void>? _pluginInit;
  Future<void> _queue = Future.value();

  /// Local notifications exist only on the mobile builds.
  static bool get _off =>
      kIsWeb || !(defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  final ValueNotifier<String?> _tapped = ValueNotifier(null);

  @override
  ValueListenable<String?> get tappedPayload => _tapped;

  @override
  String? takeTappedPayload() {
    final payload = _tapped.value;
    _tapped.value = null;
    return payload;
  }

  /// Plugin setup once, then the channel names in the current language
  /// (call again after a language change to rename them).
  @override
  Future<void> init() async {
    if (_off) return;
    await _ensurePlugin();
    await _platform.createChannels(channelNames(notificationLocalizations(_locale())));
  }

  /// Initializes the plugin once, even with concurrent callers.
  Future<void> _ensurePlugin() => _pluginInit ??= () async {
        try {
          _ensureTimezones();
          await _platform.initialize((payload) => _tapped.value = payload);
          final launch = await _platform.launchPayload();
          if (launch != null) _tapped.value = launch;
        } catch (_) {
          _pluginInit = null;
          rethrow;
        }
      }();

  static void _ensureTimezones() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    _tzReady = true;
  }

  @override
  Future<void> reschedule() {
    if (_off) return Future.value();
    return _serialized(() async {
      try {
        await _reschedule();
      } catch (e) {
        // Callers fire and forget; the next reschedule retries.
        debugPrint('Niyah: reschedule failed: $e');
      }
    });
  }

  /// Reschedules only if the last run is older than [maxAge] (app resume).
  Future<void> rescheduleIfStale([Duration maxAge = const Duration(hours: 6)]) async {
    if (_off) return;
    final prefs = await SharedPreferences.getInstance();
    final last = DateTime.tryParse(prefs.getString(_kLastRescheduleAt) ?? '');
    if (last == null || _clock().toUtc().difference(last) > maxAge) await reschedule();
  }

  /// Runs [job] after the ones already queued: two reschedules never overlap.
  Future<T> _serialized<T>(Future<T> Function() job) {
    final result = _queue.then((_) => job());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _reschedule() async {
    await _ensurePlugin();
    final prefs = await SharedPreferences.getInstance();
    final location = await _deviceLocation();
    final now = tz.TZDateTime.from(_clock(), location);

    // A new timezone or delivery mode changes every OS entry: rebuild all.
    final exact = await _platform.canScheduleExact();
    final lastTz = prefs.getString(_kLastTimezone);
    final lastExact = prefs.getBool(_kLastExact);
    final force = (lastTz != null && lastTz != location.name) || (lastExact != null && lastExact != exact);
    if (force) await _platform.cancelAllPending();

    final pending = await _platform.pending();
    final l10n = notificationLocalizations(_locale());
    final plan = await buildSchedulePlan(
      inputs: inputs,
      l10n: l10n,
      location: location,
      now: now,
      budget: _platform.budget,
      existing: pending,
    );
    final diff = plan.diff(pending.map((p) => p.id));

    for (final id in diff.toCancel) {
      await _platform.cancel(id);
    }
    final names = channelNames(l10n);
    for (final n in diff.toSchedule) {
      try {
        await _platform.schedule(n, exact: exact, channelName: names[n.channel] ?? n.channel);
      } catch (e) {
        // One bad entry must not block the others.
        debugPrint('Niyah: could not schedule ${n.id}: $e');
      }
    }

    await prefs.setString(_kLastTimezone, location.name);
    await prefs.setBool(_kLastExact, exact);
    await prefs.setString(_kLastRescheduleAt, _clock().toUtc().toIso8601String());
  }

  /// Device IANA timezone, or UTC if unknown.
  Future<tz.Location> _deviceLocation() async {
    _ensureTimezones();
    final name = await _deviceTimezone();
    if (name != null && name.isNotEmpty) {
      try {
        return tz.getLocation(name);
      } catch (_) {/* unknown name: fall back */}
    }
    return tz.UTC;
  }

  static Future<String?> _flutterTimezone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return null;
    }
  }

  /// Asks the OS once (remembered), then only reports the current state.
  @override
  Future<bool> ensurePermission() async {
    if (_off) return false;
    await _ensurePlugin();
    if (await _platform.areEnabled()) return true;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kPermissionAsked) ?? false) return false;
    await prefs.setBool(_kPermissionAsked, true);
    return _platform.requestPermission();
  }

  @override
  Future<bool> ensureExactAlarms() async {
    if (_off) return false;
    if (_platform.isIos) return true;
    await _ensurePlugin();
    return _platform.requestExact();
  }

  @override
  Future<bool> areEnabled() async {
    if (_off) return false;
    await _ensurePlugin();
    return _platform.areEnabled();
  }

  @override
  Future<void> openSystemSettings() async {
    if (_off) return;
    await _ensurePlugin();
    await _platform.openSettings();
  }
}
