import 'package:niyah/notifications/notification_platform.dart';
import 'package:niyah_core/niyah_core.dart';

final epoch = DateTime.utc(2026);
const start = LocalDate(2026, 1, 1);

Reminder personal(String id, {LocalTime time = const LocalTime(9, 0), int days = DaysMask.all, String title = 'Title'}) =>
    Reminder(
      id: id,
      kind: ReminderKind.personal,
      title: title,
      body: 'Body',
      scheduleType: days == DaysMask.all ? ScheduleType.daily : ScheduleType.weekly,
      time: time,
      daysMask: days,
      startDate: start,
      updatedAt: epoch,
    );

Reminder template(String id, String templateId, {LocalTime time = const LocalTime(7, 30)}) => Reminder(
      id: id,
      kind: ReminderKind.template,
      templateId: templateId,
      scheduleType: ScheduleType.daily,
      time: time,
      startDate: start,
      updatedAt: epoch,
    );

/// One expanded prayer reminder, as the data layer hands it over.
Reminder prayer(Prayer p, {int offset = 10, String? title, String? body}) => Reminder(
      id: 'prayer:${p.name}',
      kind: ReminderKind.prayer,
      title: title,
      body: body,
      scheduleType: ScheduleType.prayer,
      prayer: p,
      offsetMin: offset,
      startDate: start,
      updatedAt: epoch,
    );

List<Reminder> allPrayers({int offset = 10}) => [for (final p in Prayer.values) prayer(p, offset: offset)];

/// In-memory OS: records what the service schedules and cancels.
class FakeNotificationPlatform extends NotificationPlatform {
  FakeNotificationPlatform({this.isIos = false});

  @override
  final bool isIos;

  final Map<int, PlannedNotification> scheduled = {};
  final Map<int, bool> exactById = {};
  final Map<String, String> channels = {};
  int scheduleCalls = 0;
  int cancelCalls = 0;
  int cancelAllCalls = 0;

  bool exactAllowed = true;
  bool exactGrantedOnRequest = false;
  int exactRequests = 0;

  bool enabled = false;
  bool grantOnRequest = true;
  int permissionRequests = 0;

  String? launch;
  void Function(String payload)? onTap;

  @override
  Future<void> initialize(void Function(String payload) onTap) async => this.onTap = onTap;

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<void> createChannels(Map<String, String> names) async => channels
    ..clear()
    ..addAll(names);

  @override
  Future<List<ExistingNotification>> pending() async {
    // Yield, so overlapping reschedules would interleave if not serialized.
    await Future<void>.delayed(Duration.zero);
    return [
      for (final n in scheduled.values) ExistingNotification(n.id, title: n.title, body: n.body, payload: n.payload),
    ];
  }

  @override
  Future<void> cancel(int id) async {
    cancelCalls++;
    scheduled.remove(id);
  }

  @override
  Future<void> cancelAllPending() async {
    cancelAllCalls++;
    scheduled.clear();
  }

  @override
  Future<void> schedule(PlannedNotification n, {required bool exact, required String channelName}) async {
    await Future<void>.delayed(Duration.zero);
    scheduleCalls++;
    scheduled[n.id] = n;
    exactById[n.id] = exact;
  }

  @override
  Future<bool> canScheduleExact() async => isIos || exactAllowed;

  @override
  Future<bool> requestExact() async {
    exactRequests++;
    if (exactGrantedOnRequest) exactAllowed = true;
    return canScheduleExact();
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    enabled = grantOnRequest;
    return enabled;
  }

  @override
  Future<bool> areEnabled() async => enabled;

  @override
  Future<void> openSettings() async {}
}
