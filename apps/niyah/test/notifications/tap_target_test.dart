import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/fake/fake_repositories.dart';
import 'package:niyah/notifications/tap_target.dart';

void main() {
  final reminders = FakeReminderRepository();
  reminders.prayer; // creates the prayer reminder

  test('expanded ids map back to the saved reminder', () {
    expect(tappedReminder('{"r":"p1"}', reminders)!.id, 'p1');
    expect(tappedReminder('{"r":"p2:wd"}', reminders)!.id, 'p2');
    expect(tappedReminder('{"r":"prayer:fajr"}', reminders)!.id, 'prayer');
    expect(tappedReminder('{"r":"t1","c":"x"}', reminders)!.templateId, 'niyyah_renew_morning');
  });

  test('refresh notice, deleted reminders and bad payloads open nothing', () {
    expect(tappedReminder('{"r":"_refresh"}', reminders), isNull);
    expect(tappedReminder('{"r":"gone"}', reminders), isNull);
    expect(tappedReminder('{"r":1}', reminders), isNull);
    expect(tappedReminder('[]', reminders), isNull);
    expect(tappedReminder('not json', reminders), isNull);
  });
}
