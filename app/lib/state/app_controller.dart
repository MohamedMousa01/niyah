// Coordina impostazioni, database e notifiche. Ogni modifica che cambia ciò
// che l'utente deve ricevere passa da qui e finisce con una riprogrammazione
// (idempotente: chiamarla due volte non crea duplicati).

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:niyah_core/niyah_core.dart' as core;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/catalog_repository.dart';
import '../data/niyah_database.dart';
import '../data/reminder_repository.dart';
import '../l10n/app_localizations.dart';
import '../services/notification_gateway.dart';
import '../services/schedule_builder.dart';
import 'app_settings.dart';

/// Esito dell'ultima riprogrammazione, per avvisi discreti nell'interfaccia.
class RescheduleSummary {
  const RescheduleSummary({
    this.scheduled = 0,
    this.cancelled = 0,
    this.pending = 0,
    this.overBudget = const [],
    this.mutedByQuietHours = const [],
    this.exact = false,
  });

  final int scheduled;
  final int cancelled;
  final int pending;
  final List<String> overBudget;
  final List<String> mutedByQuietHours;
  final bool exact;
}

class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController({
    required this.settings,
    required this.database,
    required this.gateway,
    DateTime Function()? clock,
  })  : catalog = CatalogRepository(database.db),
        reminders = ReminderRepository(database.db, clock: clock),
        _clock = clock ?? DateTime.now {
    _ensureTimezones();
  }

  final AppSettings settings;
  final NiyahDatabase database;
  final NotificationGateway gateway;
  final CatalogRepository catalog;
  final ReminderRepository reminders;
  final DateTime Function() _clock;

  static bool _tzReady = false;
  static void _ensureTimezones() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    _tzReady = true;
  }

  Future<void> _queue = Future.value();
  bool _started = false;
  StreamSubscription<String>? _tapSub;

  /// Le notifiche sono consentite per l'app (null = non ancora controllato).
  bool? notificationsEnabled;
  RescheduleSummary lastSummary = const RescheduleSummary();

  /// Notifica toccata che l'interfaccia non ha ancora aperto.
  String? pendingTap;

  /// Esegue i job uno alla volta: due riprogrammazioni non si sovrappongono.
  Future<T> _serialized<T>(Future<T> Function() job) {
    final result = _queue.then((_) => job());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  AppLocalizations get _l10n => lookupAppLocalizations(Locale(settings.language));

  Map<String, String> channelNames() {
    final l = _l10n;
    return {
      core.NiyahChannels.prayer: l.channelPrayer,
      core.NiyahChannels.niyyah: l.channelNiyyah,
      core.NiyahChannels.quran: l.channelQuran,
      core.NiyahChannels.hadith: l.channelHadith,
      core.NiyahChannels.dhikr: l.channelDhikr,
      core.NiyahChannels.goodDeeds: l.channelGoodDeeds,
      core.NiyahChannels.islamicEvents: l.channelIslamicEvents,
      core.NiyahChannels.personal: l.channelPersonal,
    };
  }

  core.NotificationStrings notificationStrings() {
    final l = _l10n;
    return core.NotificationStrings(
      prayerNames: {
        core.Prayer.fajr: l.prayerFajr,
        core.Prayer.dhuhr: l.prayerDhuhr,
        core.Prayer.asr: l.prayerAsr,
        core.Prayer.maghrib: l.prayerMaghrib,
        core.Prayer.isha: l.prayerIsha,
      },
      // Il pianificatore sostituisce {prayer} e {minutes}.
      prayerAtTime: l.notifPrayerAtTime('{prayer}'),
      prayerBefore: l.notifPrayerBefore('{prayer}', '{minutes}'),
      quranTitle: l.notifQuranTitle,
      hadithTitle: l.notifHadithTitle,
      dhikrTitle: l.notifDhikrTitle,
      tapToRead: l.notifTapToRead,
      refreshTitle: l.appTitle,
      refreshBody: l.notifRefreshBody,
      privateTitle: l.appTitle,
      privateBody: l.notifPrivateBody,
    );
  }

  /// Testi delle notifiche random nella lingua attiva.
  List<core.TextPair> randomTexts() {
    final l = _l10n;
    return [
      core.TextPair(l.randomTitle1, l.randomBody1),
      core.TextPair(l.randomTitle2, l.randomBody2),
      core.TextPair(l.randomTitle3, l.randomBody3),
      core.TextPair(l.randomTitle4, l.randomBody4),
      core.TextPair(l.randomTitle5, l.randomBody5),
    ];
  }

  /// Dopo il primo frame: notifiche pronte e programmazione aggiornata.
  /// Nessuna schermata aspetta questo lavoro (architettura §11).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    try {
      final launch = await gateway.init(channelNames());
      if (launch != null) pendingTap = launch;
      _tapSub = gateway.taps.listen((p) {
        pendingTap = p;
        notifyListeners();
      });
      await refreshPermission();
      await reschedule();
    } catch (e, s) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s, library: 'niyah'));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_onResume());
  }

  Future<void> _onResume() async {
    await refreshPermission();
    final last = DateTime.tryParse(await database.meta('last_reschedule_at') ?? '');
    final stale = last == null || _clock().toUtc().difference(last) > const Duration(hours: 6);
    if (stale) await reschedule();
  }

  Future<void> refreshPermission() async {
    final enabled = await gateway.areEnabled();
    if (enabled != notificationsEnabled) {
      notificationsEnabled = enabled;
      notifyListeners();
    }
  }

  Future<bool> requestPermission() async {
    final granted = await gateway.requestPermission();
    notificationsEnabled = granted;
    notifyListeners();
    if (granted) await reschedule();
    return granted;
  }

  /// Ricalcola il piano e lo confronta con le notifiche già nell'OS.
  Future<RescheduleSummary> reschedule({bool forceAll = false}) => _serialized(() async {
        final loc = resolveLocation(null, await gateway.deviceTimezone());
        final now = tz.TZDateTime.from(_clock(), loc);

        // Un cambio di fuso (viaggio) o di modalità esatta impone di rifare tutto.
        final lastTz = await database.meta('last_timezone');
        if (lastTz != null && lastTz != loc.name) forceAll = true;
        final exact = await gateway.canScheduleExact();
        final lastExact = await database.meta('last_exact_mode');
        if (lastExact != null && lastExact != '$exact') forceAll = true;

        if (forceAll) await gateway.cancelAll();
        final pending = await gateway.pending();

        final builder = ScheduleBuilder(database.db);
        final plan = await builder.build(
          ScheduleInput(
            language: settings.language,
            location: loc,
            strings: notificationStrings(),
            budget: gateway.isIos ? core.PlannerSettings.iosBudget : core.PlannerSettings.androidBudget,
            quietHours: settings.quietHours,
            pausedUntil: settings.pausedUntil,
            randomTexts: settings.randomEnabled ? randomTexts() : const [],
          ),
          now,
          existing: pending,
        );
        final diff = plan.diff(pending.map((p) => p.id));
        for (final id in diff.toCancel) {
          await gateway.cancel(id);
        }
        var scheduled = 0;
        for (final n in diff.toSchedule) {
          try {
            await gateway.schedule(n, exact: exact);
            scheduled++;
          } catch (_) {
            // Un errore su una notifica non deve bloccare le altre.
          }
        }
        await builder.rememberPicked(plan.newlyPickedContentIds, _clock());
        await database.setMeta('last_timezone', loc.name);
        await database.setMeta('last_exact_mode', '$exact');
        await database.setMeta('last_reschedule_at', _clock().toUtc().toIso8601String());

        lastSummary = RescheduleSummary(
          scheduled: scheduled,
          cancelled: diff.toCancel.length,
          pending: plan.notifications.length,
          overBudget: plan.overBudgetReminderIds,
          mutedByQuietHours: plan.mutedByQuietHours,
          exact: exact,
        );
        notifyListeners();
        return lastSummary;
      });

  // ── Azioni dell'interfaccia ─────────────────────────────────────────────

  Future<void> setLanguage(String lang) async {
    await settings.setLanguage(lang);
    if (!_started) return;
    // Nomi dei canali e testi delle notifiche nella nuova lingua.
    await gateway.init(channelNames());
    await reschedule();
  }

  Future<void> setQuietHours(core.QuietHours q) async {
    await settings.setQuietHours(q);
    await reschedule();
  }

  Future<void> pauseUntil(DateTime? until) async {
    await settings.setPausedUntil(until);
    await reschedule();
  }

  Future<void> setTemplateEnabled(TemplateItem t, bool enabled) async {
    await reminders.setTemplateEnabled(t, enabled, deviceId: settings.deviceId);
    notifyListeners();
    await reschedule();
  }

  Future<void> updateFixedSchedule(String reminderId, core.LocalTime time, int daysMask) async {
    await reminders.updateFixedSchedule(reminderId, time, daysMask, deviceId: settings.deviceId);
    notifyListeners();
    await reschedule();
  }

  Future<void> setRandomEnabled(bool enabled) async {
    await settings.setRandomEnabled(enabled);
    await reschedule();
  }

  Future<void> savePersonal({
    String? id,
    required String title,
    required String body,
    required core.LocalTime time,
    required int daysMask,
  }) async {
    await reminders.savePersonal(
      id: id,
      title: title,
      body: body,
      time: time,
      daysMask: daysMask,
      deviceId: settings.deviceId,
    );
    notifyListeners();
    await reschedule();
  }

  Future<void> setReminderEnabled(String reminderId, bool enabled) async {
    await reminders.setEnabled(reminderId, enabled, deviceId: settings.deviceId);
    notifyListeners();
    await reschedule();
  }

  Future<void> deleteReminder(String reminderId) async {
    await reminders.delete(reminderId, deviceId: settings.deviceId);
    notifyListeners();
    await reschedule();
  }

  String? takePendingTap() {
    final p = pendingTap;
    pendingTap = null;
    return p;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapSub?.cancel();
    super.dispose();
  }
}
