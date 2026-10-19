import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/data/sqlite/sqlite_reminder_repository.dart';
import 'package:niyah/data/sqlite/sqlite_template_repository.dart';

import 'repository_contract.dart';
import 'sqlite_test_utils.dart';

void main() {
  final temp = TempDb()..setUpEach();

  group('SqliteReminderRepository (contract)', () {
    reminderRepositoryContract((initial) async {
      final db = await temp.open();
      final repo = SqliteReminderRepository(db);
      await repo.init();
      for (final r in initial) {
        await repo.save(r);
      }
      return repo;
    });
  });

  group('SqliteTemplateRepository (contract)', () {
    templateRepositoryContract(() async {
      final repo = SqliteTemplateRepository(await temp.open());
      await repo.init();
      return repo;
    });
  });

  group('SqliteReminderRepository (storage)', () {
    var now = DateTime.utc(2026, 10, 19, 8);
    Future<SqliteReminderRepository> repo() async {
      final r = SqliteReminderRepository(await temp.open(), clock: () => now);
      await r.init();
      return r;
    }

    Future<Map<String, Object?>> row(String id) async =>
        (await (await temp.open()).db.query('reminders', where: 'id = ?', whereArgs: [id])).single;

    test('everything survives a restart, in the same order', () async {
      final a = await repo();
      await a.save(personal);
      await a.save(template);
      await a.setEnabled('t1', false);
      await a.save(a.prayer.copyWith(schedule: const PrayerSchedule({Prayer.maghrib}, offsetMin: -5)));
      final ids = a.all.map((r) => r.id).toList();
      await temp.open().then((db) => db.close());

      final b = await repo();
      expect(b.all.map((r) => r.id).toList(), ids);
      expect(b.byId('p1')!.title, 'My title');
      expect(b.byId('t1')!.enabled, isFalse);
      expect(b.prayer.schedule, const PrayerSchedule({Prayer.maghrib}, offsetMin: -5));
    });

    test('the prayer reminder row is created on first init, with a fixed id', () async {
      await repo();
      final r = await row('prayer');
      expect(r['kind'], 'prayer');
      expect(r['channel'], 'prayer');
      expect(r['schedule_type'], 'prayer');
      expect(r['prayers_mask'], 31);
      expect(r['offset_min'], 10);
      expect(r['title'], isNull);
    });

    test('personal reminders never sync (local_only)', () async {
      final r = await repo();
      await r.save(personal);
      final saved = await row('p1');
      expect(saved['kind'], 'personal');
      expect(saved['sync_policy'], 'local_only');
      expect(saved['channel'], 'personal');
      expect(saved['title'], 'My title');
      expect(saved['schedule_type'], 'daily');
      expect(saved['time'], '07:15');
      expect(saved['days_mask'], 127);
    });

    test('template reminders store the template id, not the texts', () async {
      final r = await repo();
      await r.save(template.copyWith(title: 'Remember Allah in your work', body: 'x'));
      final saved = await row('t1');
      expect(saved['kind'], 'template');
      expect(saved['template_id'], 'niyyah_work');
      expect(saved['category_id'], 'niyyah_work');
      expect(saved['channel'], 'niyyah');
      expect(saved['sync_policy'], 'cloud');
      expect(saved['title'], isNull);
      expect(saved['body'], isNull);
      expect(saved['schedule_type'], 'weekly');
      expect(saved['days_mask'], 31);
      expect(r.byId('t1')!.title, isNull); // same as after a reload
    });

    test('anchor and multi-prayer columns', () async {
      final r = await repo();
      await r.save(const ReminderItem(id: 'w', source: ReminderSource.template, templateId: 'wake_up', schedule: AnchorSchedule(Anchor.wake)));
      await r.save(const ReminderItem(
          id: 'a', source: ReminderSource.template, templateId: 'after_prayer', schedule: PrayerSchedule({Prayer.fajr, Prayer.isha}, offsetMin: -15)));
      final w = await row('w');
      expect([w['schedule_type'], w['anchor'], w['time']], ['anchor', 'wake', null]);
      final a = await row('a');
      expect([a['schedule_type'], a['prayers_mask'], a['offset_min'], a['prayer'], a['channel']], ['prayer', 1 | 16, -15, null, 'dhikr']);
    });

    test('changing the kind of schedule clears the old columns', () async {
      final r = await repo();
      await r.save(personal.copyWith(schedule: const PrayerSchedule({Prayer.asr}, offsetMin: -20)));
      await r.save(personal.copyWith(schedule: const AnchorSchedule(Anchor.sleep)));
      final saved = await row('p1');
      expect([saved['prayers_mask'], saved['offset_min'], saved['time'], saved['anchor']], [null, 0, null, 'sleep']);
    });

    test('out-of-range offsets are clamped like the table requires', () async {
      final r = await repo();
      await r.save(personal.copyWith(schedule: const PrayerSchedule({Prayer.asr}, offsetMin: -90)));
      expect((await row('p1'))['offset_min'], -60);
      expect(r.byId('p1')!.schedule, const PrayerSchedule({Prayer.asr}, offsetMin: -60));
    });

    test('delete is soft: a tombstone with updated_at and device_id', () async {
      final r = await repo();
      await r.save(personal);
      final created = await row('p1');
      now = DateTime.utc(2026, 10, 20, 9);
      await r.delete('p1');
      final deleted = await row('p1');
      expect(deleted['deleted'], 1);
      expect(deleted['updated_at'], '2026-10-20T09:00:00.000Z');
      expect(deleted['created_at'], created['created_at']);
      expect(deleted['device_id'], isNotNull);
      expect(deleted['device_id'], created['device_id']);
      expect((await repo()).byId('p1'), isNull);
    });

    test('the device id is stable across restarts', () async {
      final r = await repo();
      await r.save(personal);
      final first = (await row('p1'))['device_id'];
      final again = await repo();
      await again.setEnabled('p1', false);
      expect((await row('p1'))['device_id'], first);
    });

    test('rows the UI does not show are ignored', () async {
      final db = await temp.open();
      await db.db.insert('reminders', {
        'id': 's', 'kind': 'struggle', 'title': 'x', 'schedule_type': 'daily', 'time': '08:00',
        'start_date': '2026-01-01', 'created_at': 'x', 'updated_at': 'x', 'sync_policy': 'local_only',
      });
      await db.db.insert('reminders', {
        'id': 'c', 'kind': 'personal', 'title': 'x', 'schedule_type': 'window', 'window_start': '09:00',
        'window_end': '21:00', 'start_date': '2026-01-01', 'created_at': 'x', 'updated_at': 'x',
      });
      final r = await repo();
      expect(r.all.map((e) => e.id), ['prayer']);
    });
  });
}
