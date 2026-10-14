// Supporto comune ai test: database SQLite in memoria con lo schema reale
// (seed/schema.sql), un gateway delle notifiche finto e un controller pronto.

import 'dart:async';
import 'dart:io';

import 'package:niyah/data/niyah_database.dart';
import 'package:niyah/services/notification_gateway.dart';
import 'package:niyah/state/app_controller.dart';
import 'package:niyah/state/app_settings.dart';
import 'package:niyah_core/niyah_core.dart' as core;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _now = '2026-10-01T00:00:00Z';

/// Database in memoria con lo schema di seed/schema.sql e un piccolo catalogo.
/// Senza isolate: funziona anche dentro testWidgets (fake async).
Future<NiyahDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false));
  final schema = File('../seed/schema.sql').readAsStringSync();
  for (final stmt in _statements(schema)) {
    await db.execute(stmt);
  }
  await db.insert('categories', {'id': 'niyyah', 'sort': 0, 'active': 1, 'updated_at': _now});
  for (final (id, section, schedule, active, it, ar) in const [
    ('morning', 'suggested', '{"schedule_type":"daily","time":"08:00"}', 1, 'Mattino', 'الصباح'),
    ('work', 'suggested', '{"schedule_type":"weekly","time":"09:00","days_mask":31}', 1, 'Lavoro', 'العمل'),
    ('quran_daily', 'content', '{"schedule_type":"window","window_start":"09:00","window_end":"21:00"}', 1, 'Corano', 'القرآن'),
    ('needs_source', 'weekly', '{"schedule_type":"weekly","time":"20:00","days_mask":64}', 0, 'Spento', 'معطّل'),
  ]) {
    await db.insert('templates', {
      'id': id,
      'category_id': 'niyyah',
      'section': section,
      'content_type': section == 'content' ? 'quran' : null,
      'channel': 'niyyah',
      'default_schedule_json': schedule,
      'editable': 1,
      'seasonal': 0,
      'active': active,
      'updated_at': _now,
    });
    for (final (lang, title) in [('it', it), ('en', '$it (en)'), ('fr', '$it (fr)'), ('ar', ar)]) {
      await db.insert('template_i18n', {'template_id': id, 'lang': lang, 'title': title, 'body': '$title: testo'});
    }
  }
  await db.insert('topics', {'id': 'eat', 'icon': 'restaurant', 'sort': 0, 'active': 1, 'updated_at': _now});
  for (final (lang, name) in [('it', 'Mangiare'), ('en', 'Eating'), ('fr', 'Manger'), ('ar', 'الأكل')]) {
    await db.insert('topic_i18n', {'topic_id': 'eat', 'lang': lang, 'name': name});
  }
  return NiyahDatabase(db);
}

/// Divide lo script SQL in istruzioni, tenendo insieme i corpi dei trigger.
List<String> _statements(String sql) {
  final out = <String>[];
  final buf = StringBuffer();
  var inTrigger = false;
  for (final raw in sql.split('\n')) {
    final line = raw.replaceFirst(RegExp(r'--.*$'), '').trimRight();
    if (line.trim().isEmpty) continue;
    buf.writeln(line);
    final upper = line.trim().toUpperCase();
    if (upper.startsWith('CREATE TRIGGER')) inTrigger = true;
    final ends = inTrigger ? upper == 'END;' : upper.endsWith(';');
    if (ends) {
      out.add(buf.toString().trim());
      buf.clear();
      inTrigger = false;
    }
  }
  return out;
}

class FakeGateway implements NotificationGateway {
  final Map<int, core.PlannedNotification> scheduled = {};
  final List<bool> exactModes = [];
  Map<String, String> channelNames = {};
  bool enabled = true;
  bool grantOnRequest = true;
  bool exact = false;
  int openSettingsCalls = 0;
  final StreamController<String> tapController = StreamController<String>.broadcast();

  @override
  bool get isIos => false;

  @override
  Future<String?> init(Map<String, String> names) async {
    channelNames = names;
    return null;
  }

  @override
  Stream<String> get taps => tapController.stream;

  @override
  Future<bool> areEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async => enabled = grantOnRequest;

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return true;
  }

  @override
  Future<bool> canScheduleExact() async => exact;

  @override
  Future<bool> requestExact() async => exact = true;

  @override
  Future<List<core.ExistingNotification>> pending() async => [
        for (final n in scheduled.values) core.ExistingNotification(n.id, title: n.title, body: n.body, payload: n.payload),
      ];

  @override
  Future<void> cancelAll() async => scheduled.clear();

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);

  @override
  Future<void> schedule(core.PlannedNotification n, {required bool exact}) async {
    exactModes.add(exact);
    scheduled[n.id] = n;
  }

  @override
  Future<String?> deviceTimezone() async => 'Europe/Rome';
}

Future<AppController> makeController({
  Map<String, Object> prefs = const {},
  DateTime? now,
  FakeGateway? gateway,
  NiyahDatabase? database,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final settings = AppSettings(await SharedPreferences.getInstance());
  return AppController(
    settings: settings,
    database: database ?? await openTestDatabase(),
    gateway: gateway ?? FakeGateway(),
    clock: now == null ? null : () => now,
  );
}
