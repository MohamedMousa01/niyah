// Tutto ciò che tocca le notifiche del sistema operativo passa da qui
// (flutter_local_notifications). Interfaccia separata per poterla sostituire
// nei test.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:niyah_core/niyah_core.dart' as core;
import 'package:timezone/timezone.dart' as tz;

/// Una notifica non aperta sparisce da sola dopo questo tempo. Solo Android:
/// iOS non permette a un'app di ritirare da sola una notifica già mostrata.
const kNotificationLifetime = Duration(hours: 3);

abstract class NotificationGateway {
  bool get isIos;

  /// Prepara il plugin e i canali (nomi localizzati). Restituisce il payload
  /// della notifica che ha aperto l'app, se c'è. Non chiede permessi.
  Future<String?> init(Map<String, String> channelNames);

  /// Payload delle notifiche toccate con l'app già aperta.
  Stream<String> get taps;

  Future<bool> areEnabled();
  Future<bool> requestPermission();
  Future<bool> openSettings();

  /// Android: il permesso "sveglie e promemoria" (orario esatto). iOS: sempre.
  Future<bool> canScheduleExact();
  Future<bool> requestExact();

  Future<List<core.ExistingNotification>> pending();
  Future<void> cancelAll();
  Future<void> cancel(int id);
  Future<void> schedule(core.PlannedNotification n, {required bool exact});

  /// Fuso orario IANA del dispositivo (null se non disponibile).
  Future<String?> deviceTimezone();
}

class LocalNotificationGateway implements NotificationGateway {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<String> _taps = StreamController<String>.broadcast();
  Map<String, String> _channelNames = {for (final c in core.NiyahChannels.all) c: c};
  bool _ready = false;

  @override
  bool get isIos => Platform.isIOS;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> init(Map<String, String> channelNames) async {
    _channelNames = {..._channelNames, ...channelNames};
    if (!_ready) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_niyah'),
          // Nessuna richiesta di permesso all'avvio: si chiede solo dopo la
          // spiegazione dell'onboarding (§27).
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          final payload = r.payload;
          if (payload != null) _taps.add(payload);
        },
      );
      _ready = true;
    }
    final android = _android;
    if (android != null) {
      for (final id in core.NiyahChannels.all) {
        await android.createNotificationChannel(AndroidNotificationChannel(
          id,
          _channelNames[id] ?? id,
          importance: id == core.NiyahChannels.prayer ? Importance.high : Importance.defaultImportance,
        ));
      }
    }
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true ? launch!.notificationResponse?.payload : null;
  }

  @override
  Future<bool> areEnabled() async {
    if (isIos) return (await _ios?.checkPermissions())?.isEnabled ?? false;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    if (isIos) return await _ios?.requestPermissions(alert: true, badge: false, sound: true) ?? false;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> openSettings() async {
    if (isIos) return await _ios?.openAppNotificationSettings() ?? false;
    return await _android?.openAppNotificationSettings() ?? false;
  }

  @override
  Future<bool> canScheduleExact() async {
    if (isIos) return true;
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<bool> requestExact() async {
    if (isIos) return true;
    final android = _android;
    if (android == null) return false;
    if (await android.canScheduleExactNotifications() ?? false) return true;
    await android.requestExactAlarmsPermission();
    return await android.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<List<core.ExistingNotification>> pending() async => [
        for (final p in await _plugin.pendingNotificationRequests())
          core.ExistingNotification(p.id, title: p.title, body: p.body, payload: p.payload),
      ];

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> schedule(core.PlannedNotification n, {required bool exact}) async {
    // iOS non permette di nascondere il testo di una singola notifica sul
    // blocco schermo: per i promemoria privati si mostra il testo neutro e il
    // testo completo si apre nell'app toccando la notifica.
    final usePublicText = isIos && n.isPrivate;
    final isPrayer = n.channel == core.NiyahChannels.prayer;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        n.channel,
        _channelNames[n.channel] ?? n.channel,
        importance: isPrayer ? Importance.high : Importance.defaultImportance,
        priority: isPrayer ? Priority.high : Priority.defaultPriority,
        styleInformation: BigTextStyleInformation(n.body),
        // Su Android il blocco schermo mostra solo "contenuto nascosto".
        visibility: n.isPrivate ? NotificationVisibility.private : NotificationVisibility.public,
        category: isPrayer ? AndroidNotificationCategory.reminder : null,
        timeoutAfter: kNotificationLifetime.inMilliseconds,
      ),
      iOS: DarwinNotificationDetails(threadIdentifier: n.channel),
    );
    await _plugin.zonedSchedule(
      id: n.id,
      title: usePublicText ? n.publicTitle : n.title,
      body: usePublicText ? n.publicBody : n.body,
      scheduledDate: n.fireAt,
      notificationDetails: details,
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: n.payload,
      matchDateTimeComponents: switch (n.repeat) {
        core.RepeatKind.daily => DateTimeComponents.time,
        core.RepeatKind.weekly => DateTimeComponents.dayOfWeekAndTime,
        core.RepeatKind.none => null,
      },
    );
  }

  @override
  Future<String?> deviceTimezone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return null;
    }
  }
}

/// Fuso [preferred] se valido, altrimenti [fallback], altrimenti UTC.
tz.Location resolveLocation(String? preferred, String? fallback) {
  for (final name in [preferred, fallback]) {
    if (name == null || name.isEmpty) continue;
    try {
      return tz.getLocation(name);
    } catch (_) {/* nome sconosciuto: si prova il successivo */}
  }
  return tz.UTC;
}
