// Niyah — servizi condivisi dalle custom action (plugin notifiche, fuso
// orario, database locale). Incollare SOTTO le righe automatiche di FlutterFlow
// ("Begin custom action code"). Nome dell'azione in FlutterFlow: niyahRuntimeVersion.

import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '/custom_code/actions/niyah_core.dart' as core;

/// ⚠️ Deve coincidere con il nome del database SQLite caricato in
/// FlutterFlow (Settings → SQLite). Il file viene letto e scritto sia dalle
/// query di FlutterFlow sia da queste azioni: è lo stesso database.
const String kNiyahDbFileName = 'niyah_seed.db';

/// Copia di riserva del seed, usata solo se il database non esiste ancora.
const String kNiyahSeedAsset = 'assets/databases/niyah_seed.db';

Future<String> niyahRuntimeVersion() async => core.kNiyahCoreVersion;

class NiyahRuntime {
  NiyahRuntime._();
  static final NiyahRuntime instance = NiyahRuntime._();

  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  /// Payload dell'ultima notifica toccata, in attesa che l'interfaccia lo apra.
  String? pendingTapPayload;

  /// Notifica i widget interessati quando l'utente tocca una notifica con
  /// l'app già aperta.
  final StreamController<String> taps = StreamController<String>.broadcast();

  /// Nomi localizzati dei canali Android (id → nome).
  Map<String, String> channelNames = {for (final c in core.NiyahChannels.all) c: c};

  bool _tzReady = false;
  bool _pluginReady = false;
  Database? _db;
  Future<void> _queue = Future.value();

  bool get isIos => Platform.isIOS;
  int get budget => isIos ? core.PlannerSettings.iosBudget : core.PlannerSettings.androidBudget;

  AndroidFlutterLocalNotificationsPlugin? get android =>
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  IOSFlutterLocalNotificationsPlugin? get ios =>
      plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  /// Esegue [job] dopo quelli già in corso: due riprogrammazioni non si
  /// sovrappongono mai (niente duplicati).
  Future<T> serialized<T>(Future<T> Function() job) {
    final result = _queue.then((_) => job());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  void ensureTimezones() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    _tzReady = true;
  }

  /// Fuso IANA: quello scelto dall'utente (città) o quello del dispositivo.
  Future<tz.Location> location([String? preferred]) async {
    ensureTimezones();
    for (final name in [preferred, await deviceTimezone()]) {
      if (name == null || name.isEmpty) continue;
      try {
        return tz.getLocation(name);
      } catch (_) {/* nome sconosciuto: si prova il successivo */}
    }
    return tz.UTC;
  }

  Future<String?> deviceTimezone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return null;
    }
  }

  Future<void> ensurePlugin() async {
    if (_pluginReady) return;
    ensureTimezones();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Nessuna richiesta di permesso all'avvio: si chiede solo dopo la
        // spiegazione dell'onboarding (§27).
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final payload = r.payload;
        if (payload == null) return;
        pendingTapPayload = payload;
        taps.add(payload);
      },
    );
    _pluginReady = true;
  }

  Future<void> createChannels() async {
    final a = android;
    if (a == null) return;
    for (final id in core.NiyahChannels.all) {
      await a.createNotificationChannel(AndroidNotificationChannel(
        id,
        channelNames[id] ?? id,
        importance: id == core.NiyahChannels.prayer ? Importance.high : Importance.defaultImportance,
      ));
    }
  }

  Future<Database> database() async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    final path = p.join(await getDatabasesPath(), kNiyahDbFileName);
    if (!await File(path).exists()) {
      try {
        final data = await rootBundle.load(kNiyahSeedAsset);
        await File(path).writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      } catch (_) {
        // Nessun seed tra gli asset: FlutterFlow non ha ancora creato il DB.
        throw StateError('Database $kNiyahDbFileName non trovato');
      }
    }
    return _db = await openDatabase(path);
  }

  Future<String?> meta(String key) async {
    final rows = await (await database()).query('sync_meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String? value) async {
    await (await database()).insert('sync_meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
