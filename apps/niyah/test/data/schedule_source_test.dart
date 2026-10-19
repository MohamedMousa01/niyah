import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/defaults.dart';
import 'package:niyah/data/fake/fake_repositories.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/data/sqlite/schedule_source.dart';
import 'package:niyah/data/sqlite/sqlite_reminder_repository.dart';
import 'package:niyah_core/niyah_core.dart' as core;

import 'sqlite_test_utils.dart';

void main() {
  final temp = TempDb()..setUpEach();

  Future<(SqliteReminderRepository, ScheduleSource, FakeSettingsStore)> setUpSource() async {
    final db = await temp.open();
    final repo = SqliteReminderRepository(db);
    await repo.init();
    final settings = FakeSettingsStore();
    return (repo, ScheduleSource(db, settings), settings);
  }

  test('planner-ready reminders: expanded, enabled only, not deleted', () async {
    final (repo, source, _) = await setUpSource();
    await repo.save(const ReminderItem(id: 'w', source: ReminderSource.template, templateId: 'wake_up', schedule: AnchorSchedule(Anchor.wake)));
    await repo.save(const ReminderItem(id: 'off', source: ReminderSource.personal, title: 't', schedule: TimeSchedule(LocalTime(9, 0)), enabled: false));
    await repo.save(const ReminderItem(id: 'gone', source: ReminderSource.personal, title: 't', schedule: TimeSchedule(LocalTime(9, 0))));
    await repo.delete('gone');

    final input = await source.load('it');
    expect(input.reminders.map((r) => r.id).toList(),
        ['prayer:fajr', 'prayer:dhuhr', 'prayer:asr', 'prayer:maghrib', 'prayer:isha', 'w:wd', 'w:we']);
    expect(input.reminders.every((r) => !r.needsExpansion && r.validate().isEmpty), isTrue);
    expect(input.needsPrayerTimes, isTrue);
    final wd = input.reminders.firstWhere((r) => r.id == 'w:wd');
    expect(wd.time, Defaults.anchors.wake);
    expect(wd.daysMask, core.DaysMask.weekdaysOnly);
    expect(input.reminders.firstWhere((r) => r.id == 'w:we').time, Defaults.anchors.wakeWeekend);
  });

  test('uses the anchors from the settings', () async {
    final (repo, source, settings) = await setUpSource();
    await repo.save(const ReminderItem(id: 's', source: ReminderSource.personal, title: 't', schedule: AnchorSchedule(Anchor.sleep)));
    await settings.setAnchors(Defaults.anchors.withAnchor(Anchor.sleep, const LocalTime(23, 0), const LocalTime(23, 45)));
    final times = {for (final r in await source.reminders()) r.id: r.time};
    expect(times['s:wd'], const LocalTime(23, 0));
    expect(times['s:we'], const LocalTime(23, 45));
  });

  test('the prayer reminder follows "ring during quiet hours"', () async {
    final (_, source, settings) = await setUpSource();
    bool respects(List<core.Reminder> rs) => rs.firstWhere((r) => r.id == 'prayer:fajr').respectsQuietHours;
    expect(respects(await source.reminders()), isFalse); // Defaults.prayerDuringQuiet = true
    await settings.setPrayerDuringQuiet(false);
    expect(respects(await source.reminders()), isTrue);
  });

  test('personal reminders stay local-only for the planner too', () async {
    final (repo, source, _) = await setUpSource();
    await repo.save(const ReminderItem(id: 'p', source: ReminderSource.personal, title: 't', schedule: TimeSchedule(LocalTime(9, 0))));
    final p = (await source.reminders()).firstWhere((r) => r.id == 'p');
    expect(p.syncPolicy, 'local_only');
    expect(p.channel, core.NiyahChannels.personal);
  });

  test('template texts per language, English when missing', () async {
    final (_, source, _) = await setUpSource();
    final it = await source.templateTexts('it');
    expect(it['wake_up']!.title, 'Dopo il risveglio');
    final en = await source.templateTexts('en');
    expect(en['wake_up']!.title, 'After waking up');
    final de = await source.templateTexts('de');
    expect(de['wake_up']!.title, 'After waking up');
    expect(de.length, en.length);
  });

  test('no prayer times needed when nothing is prayer-relative', () async {
    final (repo, source, _) = await setUpSource();
    await repo.setEnabled('prayer', false);
    expect((await source.load('en')).needsPrayerTimes, isFalse);
  });

  test('quiet hours, pause and prayer settings come from the settings', () async {
    final (_, source, settings) = await setUpSource();
    expect(source.prayerSettings!.latitude, FakeSettingsStore.sampleLocation.latitude);
    expect(source.prayerSettings!.method, 'muslim_world_league');
    expect(source.quietHours.enabled, isFalse);
    expect(source.pausedUntil, isNull);

    final until = DateTime.utc(2026, 10, 25);
    await settings.setQuietHours(const core.QuietHours(enabled: true, start: LocalTime(23, 0), end: LocalTime(6, 0)));
    await settings.setPausedUntil(until);
    await settings.setMadhab('hanafi');
    await settings.setMethodChoice('karachi');
    expect(source.quietHours.enabled, isTrue);
    expect(source.quietHours.start, const LocalTime(23, 0));
    expect(source.pausedUntil, until);
    expect((source.prayerSettings!.method, source.prayerSettings!.madhab), ('karachi', 'hanafi'));

    await settings.setLocation(null);
    expect(source.prayerSettings, isNull);
  });
}
