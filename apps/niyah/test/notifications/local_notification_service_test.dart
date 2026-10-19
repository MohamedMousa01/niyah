import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/notifications/local_notification_service.dart';
import 'package:niyah/notifications/schedule_inputs.dart';
import 'package:niyah_core/niyah_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  late FakeNotificationPlatform os;
  late InMemoryScheduleInputs inputs;
  late String timezone;
  late DateTime clock;

  LocalNotificationService service() => LocalNotificationService(
        inputs: inputs,
        platform: os,
        deviceTimezone: () async => timezone,
        locale: () => const Locale('en'),
        clock: () => clock,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    os = FakeNotificationPlatform();
    inputs = InMemoryScheduleInputs(reminders: [personal('daily'), ...allPrayers()]);
    timezone = 'Europe/Rome';
    clock = DateTime.utc(2026, 10, 19, 6);
  });

  test('init creates the 8 localized channels', () async {
    await service().init();
    expect(os.channels.keys, unorderedEquals(NiyahChannels.all));
    expect(os.channels[NiyahChannels.prayer], 'Prayer');
  });

  test('reschedule is idempotent: a second run changes nothing', () async {
    final s = service();
    await s.reschedule();
    final first = os.scheduleCalls;
    expect(first, greaterThan(70));
    expect(os.scheduled.length, first);

    await s.reschedule();
    expect(os.scheduleCalls, first);
    expect(os.cancelCalls, 0);
    expect(os.cancelAllCalls, 0);
  });

  test('overlapping reschedules are serialized (no duplicates)', () async {
    final s = service();
    await Future.wait([s.reschedule(), s.reschedule(), s.reschedule()]);
    expect(os.scheduleCalls, os.scheduled.length);
  });

  test('only the difference is applied after a change', () async {
    final s = service();
    await s.reschedule();
    final before = os.scheduleCalls;

    inputs.reminders.removeWhere((r) => r.id == 'daily');
    inputs.reminders.add(personal('new', time: const LocalTime(12, 0)));
    await s.reschedule();

    expect(os.cancelCalls, 1);
    expect(os.scheduleCalls, before + 1);
    expect(os.scheduled.values.any((n) => n.reminderId == 'daily'), isFalse);
    expect(os.scheduled.values.where((n) => n.reminderId == 'new'), hasLength(1));
  });

  test('a timezone change forces a full rebuild', () async {
    final s = service();
    await s.reschedule();
    final count = os.scheduled.length;

    timezone = 'Europe/London';
    await s.reschedule();
    expect(os.cancelAllCalls, 1);
    expect(os.scheduleCalls, greaterThanOrEqualTo(count * 2 - 1));
    expect(os.scheduled.values.every((n) => n.fireAt.location.name == 'Europe/London'), isTrue);
  });

  test('a change of exact-alarm mode forces a full rebuild', () async {
    os.exactAllowed = false;
    final s = service();
    await s.reschedule();
    expect(os.exactById, isNotEmpty);
    expect(os.exactById.values.every((e) => !e), isTrue);

    os.exactAllowed = true;
    await s.reschedule();
    expect(os.cancelAllCalls, 1);
    expect(os.scheduled.keys.every((id) => os.exactById[id]!), isTrue);
  });

  test('iOS keeps within its budget of 60', () async {
    os = FakeNotificationPlatform(isIos: true);
    await service().reschedule();
    expect(os.scheduled.length, 60);
    expect(os.scheduled.values.where((n) => n.reminderId == '_refresh'), hasLength(1));
  });

  test('rescheduleIfStale waits 6 hours', () async {
    final s = service();
    await s.rescheduleIfStale();
    final calls = os.scheduleCalls;
    inputs.reminders.add(personal('later'));

    clock = clock.add(const Duration(hours: 5));
    await s.rescheduleIfStale();
    expect(os.scheduleCalls, calls);

    clock = clock.add(const Duration(hours: 2));
    await s.rescheduleIfStale();
    expect(os.scheduled.values.any((n) => n.reminderId == 'later'), isTrue);
  });

  group('permissions', () {
    test('the OS is asked only once', () async {
      os.grantOnRequest = false;
      final s = service();
      expect(await s.ensurePermission(), isFalse);
      expect(await s.ensurePermission(), isFalse);
      expect(os.permissionRequests, 1);

      os.enabled = true; // turned on from the system settings
      expect(await s.ensurePermission(), isTrue);
      expect(await s.areEnabled(), isTrue);
      expect(os.permissionRequests, 1);
    });

    test('no prompt when already allowed', () async {
      os.enabled = true;
      expect(await service().ensurePermission(), isTrue);
      expect(os.permissionRequests, 0);
    });

    test('exact alarms: requested on Android, always true on iOS', () async {
      os.exactAllowed = false;
      os.exactGrantedOnRequest = true;
      expect(await service().ensureExactAlarms(), isTrue);
      expect(os.exactRequests, 1);

      os = FakeNotificationPlatform(isIos: true);
      expect(await service().ensureExactAlarms(), isTrue);
      expect(os.exactRequests, 0);
    });
  });

  group('taps', () {
    test('the launch payload is exposed and taken once', () async {
      os.launch = '{"r":"daily"}';
      final s = service();
      await s.init();
      expect(s.tappedPayload.value, '{"r":"daily"}');
      expect(s.takeTappedPayload(), '{"r":"daily"}');
      expect(s.tappedPayload.value, isNull);
    });

    test('taps while running update the payload', () async {
      final s = service();
      await s.init();
      os.onTap!('{"r":"prayer:asr"}');
      expect(s.tappedPayload.value, '{"r":"prayer:asr"}');
    });
  });
}
