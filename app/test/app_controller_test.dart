import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/catalog_repository.dart';
import 'package:niyah/state/app_controller.dart';
import 'package:niyah_core/niyah_core.dart' as core;

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Martedì 14 ottobre 2026, 10:00 a Roma (CEST).
  final now = DateTime.utc(2026, 10, 14, 8);

  late FakeGateway gateway;
  late AppController c;

  setUp(() async {
    gateway = FakeGateway();
    c = await makeController(now: now, gateway: gateway);
  });

  Future<TemplateItem> template(String id) async =>
      (await c.catalog.templates(c.settings.language)).firstWhere((t) => t.id == id);

  List<core.PlannedNotification> forReminder(String templateId) =>
      gateway.scheduled.values.where((n) => n.title.startsWith(templateId)).toList();

  test('un modello attivato diventa una notifica ripetuta con il suo testo', () async {
    await c.setTemplateEnabled(await template('morning'), true);
    final n = gateway.scheduled.values.where((n) => n.channel == 'niyyah').toList();
    expect(n, hasLength(1));
    expect(n.single.title, 'Mattino');
    expect(n.single.body, 'Mattino: testo');
    expect(n.single.repeat, core.RepeatKind.daily);
    expect(n.single.fireAt.location.name, 'Europe/Rome');
    expect(n.single.fireAt.hour, 8);
    expect(c.lastSummary.pending, gateway.scheduled.length);
  });

  test('riprogrammare due volte non crea duplicati', () async {
    await c.setTemplateEnabled(await template('morning'), true);
    final first = {...gateway.scheduled.keys};
    final s = await c.reschedule();
    expect(s.scheduled, 0);
    expect(s.cancelled, 0);
    expect(gateway.scheduled.keys.toSet(), first);
  });

  test('cambiare lingua cambia i testi e i nomi dei canali', () async {
    await c.setTemplateEnabled(await template('morning'), true);
    await c.start();
    await c.setLanguage('ar');
    final titles = gateway.scheduled.values.where((n) => n.channel == 'niyyah').map((n) => n.title);
    expect(titles, ['الصباح']);
    expect(gateway.channelNames['prayer'], 'الصلاة');
    expect(forReminder('Mattino'), isEmpty);
    c.dispose();
  });

  test('disattivare un modello cancella la sua notifica', () async {
    final t = await template('morning');
    await c.setTemplateEnabled(t, true);
    await c.setTemplateEnabled(t, false);
    expect(gateway.scheduled.values.where((n) => n.channel == 'niyyah'), isEmpty);
  });

  test('in pausa non parte nessun promemoria', () async {
    await c.setTemplateEnabled(await template('morning'), true);
    await c.pauseUntil(now.add(const Duration(days: 2)));
    for (final n in gateway.scheduled.values.where((n) => n.channel == 'niyyah')) {
      expect(n.fireAt.isAfter(now.add(const Duration(days: 2))), isTrue, reason: '${n.fireAt}');
    }
    await c.pauseUntil(null);
    expect(gateway.scheduled.values.where((n) => n.channel == 'niyyah' && n.repeat == core.RepeatKind.daily), hasLength(1));
  });

  test('un orario sempre dentro "Non disturbare" viene segnalato', () async {
    await c.setTemplateEnabled(await template('morning'), true);
    await c.setQuietHours(const core.QuietHours(enabled: true, start: core.LocalTime(22, 0), end: core.LocalTime(9, 0)));
    final id = (await c.reminders.templateReminders())['morning']!.id;
    expect(c.lastSummary.mutedByQuietHours, contains(id));
  });

  test('senza permesso "orario esatto" le notifiche sono inesatte', () async {
    await c.setTemplateEnabled(await template('morning'), true);
    expect(gateway.exactModes, everyElement(isFalse));
    expect(c.lastSummary.exact, isFalse);
  });

  test('il permesso: stato e richiesta', () async {
    gateway.enabled = false;
    await c.refreshPermission();
    expect(c.notificationsEnabled, isFalse);
    expect(await c.requestPermission(), isTrue);
    expect(c.notificationsEnabled, isTrue);
  });

  test('testi delle notifiche di preghiera con i segnaposto del motore', () {
    final s = c.notificationStrings();
    expect(s.prayerAtTime, "È l'ora di {prayer}");
    expect(s.prayerBefore, '{prayer} tra {minutes} minuti');
    expect(s.prayerNames[core.Prayer.fajr], 'Fajr');
  });

  test('notifiche random: 3 al giorno tra le 9 e le 21, e si possono spegnere', () async {
    await c.setRandomEnabled(true);
    final random = gateway.scheduled.values.where((n) => n.reminderId.startsWith('random|')).toList();
    // 7 giorni da martedì 14 ottobre alle 10:00: il primo invito di oggi può essere già passato.
    expect(random.length, inInclusiveRange(20, 21));
    for (final n in random) {
      expect(n.repeat, core.RepeatKind.none);
      expect(n.channel, 'niyyah');
      expect(n.fireAt.hour, inInclusiveRange(9, 20));
      expect(n.title, isNotEmpty);
    }
    final first = {for (final n in random) n.id};
    await c.reschedule();
    final again = {for (final n in gateway.scheduled.values.where((n) => n.reminderId.startsWith('random|'))) n.id};
    expect(again, first, reason: 'riprogrammare non cambia orari né testi');

    await c.setRandomEnabled(false);
    expect(gateway.scheduled.values.where((n) => n.reminderId.startsWith('random|')), isEmpty);
  });

  test('notifiche personalizzate: il testo dell\'utente arriva così com\'è', () async {
    await c.savePersonal(title: '', body: 'Bevi un bicchiere d\'acqua', time: const core.LocalTime(15, 30), daysMask: 1 | 4);
    final r = (await c.reminders.personalReminders()).single;
    expect(r.scheduleType, core.ScheduleType.weekly);
    final mine = gateway.scheduled.values.where((n) => n.reminderId == r.id).toList();
    expect(mine, hasLength(2)); // lunedì e mercoledì
    expect(mine.map((n) => n.body).toSet(), {'Bevi un bicchiere d\'acqua'});
    expect(mine.every((n) => n.channel == 'personal' && n.fireAt.hour == 15 && n.fireAt.minute == 30), isTrue);

    await c.setReminderEnabled(r.id, false);
    expect(gateway.scheduled.values.where((n) => n.reminderId == r.id), isEmpty);
    await c.setReminderEnabled(r.id, true);
    expect(gateway.scheduled.values.where((n) => n.reminderId == r.id), hasLength(2));

    await c.deleteReminder(r.id);
    expect(await c.reminders.personalReminders(), isEmpty);
    expect(gateway.scheduled.values.where((n) => n.reminderId == r.id), isEmpty);
  });
}
