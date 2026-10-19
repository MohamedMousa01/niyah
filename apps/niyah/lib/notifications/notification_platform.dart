import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:niyah_core/niyah_core.dart';

/// The OS side of notifications, kept thin so the service logic can be tested
/// with a fake. [PluginNotificationPlatform] is the real one.
abstract class NotificationPlatform {
  bool get isIos;

  /// Pending-notification budget: iOS keeps 64 per app (60 + 4 spare).
  int get budget => isIos ? PlannerSettings.iosBudget : PlannerSettings.androidBudget;

  Future<void> initialize(void Function(String payload) onTap);

  /// Payload of the notification that launched the app, if any.
  Future<String?> launchPayload();

  /// Creates or renames the Android channels (id → localized name).
  Future<void> createChannels(Map<String, String> names);

  Future<List<ExistingNotification>> pending();

  Future<void> cancel(int id);

  /// Cancels every scheduled notification (shown ones stay).
  Future<void> cancelAllPending();

  Future<void> schedule(PlannedNotification n, {required bool exact, required String channelName});

  /// Android 12+: exact alarms allowed. Always true on iOS.
  Future<bool> canScheduleExact();

  /// Opens the "Alarms & reminders" screen; returns the new state.
  Future<bool> requestExact();

  /// Shows the OS permission prompt.
  Future<bool> requestPermission();

  Future<bool> areEnabled();

  Future<void> openSettings();
}

/// [NotificationPlatform] on `flutter_local_notifications`.
class PluginNotificationPlatform extends NotificationPlatform {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  @override
  bool get isIos => defaultTargetPlatform == TargetPlatform.iOS;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<void> initialize(void Function(String payload) onTap) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // No prompt at launch: permission is asked in context.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final payload = r.payload;
        if (payload != null) onTap(payload);
      },
    );
  }

  @override
  Future<String?> launchPayload() async {
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true ? launch!.notificationResponse?.payload : null;
  }

  @override
  Future<void> createChannels(Map<String, String> names) async {
    final android = _android;
    if (android == null) return;
    for (final id in NiyahChannels.all) {
      await android.createNotificationChannel(AndroidNotificationChannel(
        id,
        names[id] ?? id,
        importance: _importance(id),
      ));
    }
  }

  @override
  Future<List<ExistingNotification>> pending() async => [
        for (final p in await _plugin.pendingNotificationRequests())
          ExistingNotification(p.id, title: p.title, body: p.body, payload: p.payload),
      ];

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAllPending() => _plugin.cancelAllPendingNotifications();

  @override
  Future<void> schedule(PlannedNotification n, {required bool exact, required String channelName}) {
    // iOS can't hide one notification's text on the lock screen: private
    // reminders show the neutral text, the full text opens in the app.
    final usePublicText = isIos && n.isPrivate;
    final prayer = n.channel == NiyahChannels.prayer;
    return _plugin.zonedSchedule(
      id: n.id,
      title: usePublicText ? n.publicTitle : n.title,
      body: usePublicText ? n.publicBody : n.body,
      scheduledDate: n.fireAt,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          n.channel,
          channelName,
          importance: _importance(n.channel),
          priority: prayer ? Priority.high : Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(n.body),
          // Android shows "contents hidden" on the lock screen.
          visibility: n.isPrivate ? NotificationVisibility.private : NotificationVisibility.public,
          category: prayer ? AndroidNotificationCategory.reminder : null,
        ),
        iOS: DarwinNotificationDetails(threadIdentifier: n.channel),
      ),
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: n.payload,
      matchDateTimeComponents: switch (n.repeat) {
        RepeatKind.daily => DateTimeComponents.time,
        RepeatKind.weekly => DateTimeComponents.dayOfWeekAndTime,
        RepeatKind.none => null,
      },
    );
  }

  @override
  Future<bool> canScheduleExact() async => isIos || (await _android?.canScheduleExactNotifications() ?? false);

  @override
  Future<bool> requestExact() async {
    if (await canScheduleExact()) return true;
    await _android?.requestExactAlarmsPermission();
    return canScheduleExact();
  }

  @override
  Future<bool> requestPermission() async {
    if (isIos) return await _ios?.requestPermissions(alert: true, badge: false, sound: true) ?? false;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> areEnabled() async {
    if (isIos) return (await _ios?.checkPermissions())?.isEnabled ?? false;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<void> openSettings() async {
    if (isIos) {
      await _ios?.openAppNotificationSettings();
    } else {
      await _android?.openAppNotificationSettings();
    }
  }

  static Importance _importance(String channel) =>
      channel == NiyahChannels.prayer ? Importance.high : Importance.defaultImportance;
}
