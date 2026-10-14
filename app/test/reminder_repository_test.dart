import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/catalog_repository.dart';
import 'package:niyah/data/reminder_repository.dart';
import 'package:niyah_core/niyah_core.dart' as core;

import 'support.dart';

void main() {
  late CatalogRepository catalog;
  late ReminderRepository repo;

  setUp(() async {
    final db = await openTestDatabase();
    catalog = CatalogRepository(db.db);
    repo = ReminderRepository(db.db, clock: () => DateTime.utc(2026, 10, 14, 9));
  });

  Future<TemplateItem> template(String id) async => (await catalog.templates('it')).firstWhere((t) => t.id == id);

  test('il catalogo mostra solo i modelli attivi, nella lingua richiesta', () async {
    final it = await catalog.templates('it');
    expect(it.map((t) => t.id), ['morning', 'work', 'quran_daily']);
    expect(it.first.title, 'Mattino');
    expect((await catalog.templates('ar')).first.title, 'الصباح');
    expect(it[1].schedule.type, core.ScheduleType.weekly);
    expect(it[1].schedule.daysMask, 31);
    expect(it[2].schedule.windowStart, const core.LocalTime(9, 0));
  });

  test('senza contenuti verificati i conteggi sono vuoti', () async {
    expect(await catalog.contentCounts('it'), isEmpty);
    final topics = await catalog.topics('fr');
    expect(topics.single.name, 'Manger');
    expect(topics.single.contentCount, 0);
  });

  test('attivare un modello crea il promemoria con la pianificazione proposta', () async {
    await repo.setTemplateEnabled(await template('work'), true, deviceId: 'dev1');
    final r = (await repo.templateReminders())['work']!;
    expect(r.kind, core.ReminderKind.template);
    expect(r.enabled, isTrue);
    expect(r.scheduleType, core.ScheduleType.weekly);
    expect(r.time, const core.LocalTime(9, 0));
    expect(r.daysMask, 31);
    expect(r.channel, 'niyyah');
    expect(r.syncPolicy, 'cloud');
    expect(r.startDate, const core.LocalDate(2026, 10, 14));
    expect(r.validate(), isEmpty);
  });

  test('disattivare e riattivare riusa lo stesso promemoria', () async {
    final t = await template('morning');
    await repo.setTemplateEnabled(t, true, deviceId: 'dev1');
    final id = (await repo.templateReminders())['morning']!.id;
    await repo.setTemplateEnabled(t, false, deviceId: 'dev1');
    expect((await repo.templateReminders())['morning']!.enabled, isFalse);
    await repo.setTemplateEnabled(t, true, deviceId: 'dev1');
    final all = await repo.templateReminders();
    expect(all.length, 1);
    expect(all['morning']!.id, id);
    expect(all['morning']!.enabled, isTrue);
  });

  test('disattivare un modello mai attivato non crea nulla', () async {
    await repo.setTemplateEnabled(await template('morning'), false, deviceId: 'dev1');
    expect(await repo.templateReminders(), isEmpty);
  });

  test('orario e giorni: tutti i giorni = ogni giorno, altrimenti settimanale', () async {
    await repo.setTemplateEnabled(await template('morning'), true, deviceId: 'dev1');
    final id = (await repo.templateReminders())['morning']!.id;

    await repo.updateFixedSchedule(id, const core.LocalTime(6, 30), 0x60, deviceId: 'dev2');
    var r = (await repo.templateReminders())['morning']!;
    expect(r.scheduleType, core.ScheduleType.weekly);
    expect(r.time, const core.LocalTime(6, 30));
    expect(core.DaysMask.weekdays(r.daysMask), [6, 7]);

    await repo.updateFixedSchedule(id, const core.LocalTime(7, 0), core.DaysMask.all, deviceId: 'dev2');
    r = (await repo.templateReminders())['morning']!;
    expect(r.scheduleType, core.ScheduleType.daily);

    expect(() => repo.updateFixedSchedule(id, const core.LocalTime(7, 0), 0, deviceId: 'dev2'), throwsArgumentError);
  });
}
