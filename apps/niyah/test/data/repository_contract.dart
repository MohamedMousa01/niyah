// Behaviour every ReminderRepository / TemplateRepository must have. Run
// against the in-memory fakes and the SQLite versions, so both stay alike.
import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/defaults.dart';
import 'package:niyah/data/fake/fake_repositories.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/data/repositories.dart';

const personal = ReminderItem(
  id: 'p1',
  source: ReminderSource.personal,
  title: 'My title',
  body: 'My words',
  schedule: TimeSchedule(LocalTime(7, 15)),
);

const template = ReminderItem(
  id: 't1',
  source: ReminderSource.template,
  templateId: 'niyyah_work',
  schedule: TimeSchedule(LocalTime(9, 0), daysMask: 31),
);

/// [create] returns an initialised repository holding exactly [initial]
/// (plus the prayer reminder, once asked for).
void reminderRepositoryContract(Future<ReminderRepository> Function(List<ReminderItem> initial) create) {
  test('starts with the initial reminders', () async {
    final repo = await create([personal, template]);
    expect(repo.byId('p1')!.title, 'My title');
    expect(repo.byId('p1')!.body, 'My words');
    expect(repo.byId('t1')!.templateId, 'niyyah_work');
    expect(repo.byId('nope'), isNull);
  });

  test('the prayer reminder exists with the defaults and is listed', () async {
    final repo = await create(const []);
    final p = repo.prayer;
    expect(p.id, 'prayer');
    expect(p.source, ReminderSource.prayer);
    expect(p.schedule, Defaults.prayerReminder);
    expect(p.title, isNull);
    expect(p.body, isNull);
    expect(p.enabled, isTrue);
    expect(repo.all.map((r) => r.id), contains('prayer'));
  });

  test('byTemplate finds the reminder added from a template', () async {
    final repo = await create([personal, template]);
    expect(repo.byTemplate('niyyah_work')!.id, 't1');
    expect(repo.byTemplate('dhikr_pause'), isNull);
  });

  test('save creates a new reminder with a fresh id and notifies once', () async {
    final repo = await create([personal]);
    var n = 0;
    repo.addListener(() => n++);
    final id = repo.newId();
    await repo.save(ReminderItem(
      id: id,
      source: ReminderSource.personal,
      title: 'New',
      body: 'Body',
      schedule: const AnchorSchedule(Anchor.sleep),
    ));
    expect(n, 1);
    final saved = repo.byId(id)!;
    expect(saved.title, 'New');
    expect(saved.body, 'Body');
    expect(saved.schedule, const AnchorSchedule(Anchor.sleep));
    expect(repo.all.map((r) => r.id), containsAllInOrder(['p1', id]));
  });

  test('save updates in place', () async {
    final repo = await create([personal, template]);
    repo.prayer;
    final before = repo.all.map((r) => r.id).toList();
    await repo.save(personal.copyWith(title: 'Edited', schedule: const TimeSchedule(LocalTime(21, 0), daysMask: 96)));
    expect(repo.all.map((r) => r.id).toList(), before);
    expect(repo.byId('p1')!.title, 'Edited');
    expect(repo.byId('p1')!.schedule, const TimeSchedule(LocalTime(21, 0), daysMask: 96));
  });

  test('every schedule kind round-trips', () async {
    final repo = await create(const []);
    const schedules = <Schedule>[
      TimeSchedule(LocalTime(6, 5)),
      TimeSchedule(LocalTime(23, 55), daysMask: 1 | 16),
      AnchorSchedule(Anchor.wake),
      AnchorSchedule(Anchor.sleep),
      PrayerSchedule({Prayer.fajr, Prayer.asr}, offsetMin: -15),
      PrayerSchedule({Prayer.isha}, offsetMin: 0),
      PrayerSchedule({Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha}, offsetMin: 45),
      PrayerSchedule({}, offsetMin: 10),
    ];
    for (final (i, s) in schedules.indexed) {
      await repo.save(ReminderItem(id: 'r$i', source: ReminderSource.personal, title: 't', schedule: s));
      expect(repo.byId('r$i')!.schedule, s, reason: '$s');
    }
  });

  test('the prayer reminder keeps its own words and timing', () async {
    final repo = await create(const []);
    await repo.save(repo.prayer.copyWith(
      title: 'Prayer',
      body: 'Get ready',
      schedule: const PrayerSchedule({Prayer.fajr, Prayer.isha}, offsetMin: -10),
    ));
    expect(repo.prayer.title, 'Prayer');
    expect(repo.prayer.body, 'Get ready');
    expect(repo.prayer.schedule, const PrayerSchedule({Prayer.fajr, Prayer.isha}, offsetMin: -10));
  });

  test('setEnabled switches and notifies; unknown ids are ignored', () async {
    final repo = await create([personal]);
    var n = 0;
    repo.addListener(() => n++);
    await repo.setEnabled('p1', false);
    expect(repo.byId('p1')!.enabled, isFalse);
    expect(repo.byId('p1')!.title, 'My title');
    await repo.setEnabled('p1', true);
    expect(repo.byId('p1')!.enabled, isTrue);
    await repo.setEnabled('nope', false);
    expect(n, 2);
  });

  test('delete removes and notifies; unknown ids are ignored', () async {
    final repo = await create([personal, template]);
    var n = 0;
    repo.addListener(() => n++);
    await repo.delete('t1');
    expect(repo.byId('t1'), isNull);
    expect(repo.byTemplate('niyyah_work'), isNull);
    expect(repo.all.map((r) => r.id), isNot(contains('t1')));
    await repo.delete('t1');
    expect(n, 1);
  });

  test('a deleted template can be added again with the same id', () async {
    final repo = await create([template]);
    await repo.delete('t1');
    await repo.save(template);
    expect(repo.byTemplate('niyyah_work')!.id, 't1');
  });

  test('newId gives unique ids', () async {
    final repo = await create(const []);
    expect({for (var i = 0; i < 200; i++) repo.newId()}, hasLength(200));
  });

  test('listeners are not called by reads', () async {
    final repo = await create([personal]);
    repo.prayer;
    var n = 0;
    repo.addListener(() => n++);
    repo.all;
    repo.prayer;
    repo.byId('p1');
    repo.byTemplate('x');
    expect(n, 0);
  });
}

/// [create] returns an initialised repository. The canonical list is
/// [FakeTemplateRepository]: ids, order, group, icon, schedule and it/en texts.
void templateRepositoryContract(Future<TemplateRepository> Function() create) {
  final canonical = FakeTemplateRepository();

  for (final lang in ['en', 'it']) {
    test('matches the canonical templates in "$lang"', () async {
      final repo = await create();
      final got = repo.templates(lang);
      final want = canonical.templates(lang);
      expect(got.map((t) => t.id), want.map((t) => t.id));
      for (final (i, t) in got.indexed) {
        final w = want[i];
        expect(t.group, w.group, reason: t.id);
        expect(t.icon, w.icon, reason: t.id);
        expect(t.title, w.title, reason: t.id);
        expect(t.body, w.body, reason: t.id);
        expect(t.defaultSchedule, w.defaultSchedule, reason: t.id);
      }
    });
  }

  test('other languages fall back to English', () async {
    final repo = await create();
    expect(repo.templates('fr').map((t) => t.title), repo.templates('en').map((t) => t.title));
  });

  test('byId', () async {
    final repo = await create();
    expect(repo.byId('wake_up', 'it')!.title, 'Dopo il risveglio');
    expect(repo.byId('before_prayer', 'en')!.defaultSchedule, isA<PrayerSchedule>());
    expect(repo.byId('nope', 'en'), isNull);
  });

  test('templates that need a verified source stay hidden', () async {
    final repo = await create();
    final ids = repo.templates('en').map((t) => t.id).toSet();
    expect(ids.intersection({'monday_fast_eve', 'thursday_fast_eve', 'jumuah_morning', 'kahf_friday'}), isEmpty);
    expect(repo.templates('en').where((t) => t.group == TemplateGroup.weekly), isEmpty);
  });
}
