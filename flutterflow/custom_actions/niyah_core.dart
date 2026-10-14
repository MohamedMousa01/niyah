// Niyah — logica pura condivisa (nessuna dipendenza da Flutter).
//
// Questo file è volutamente UNICO e autosufficiente: in FlutterFlow non si
// possono importare pacchetti locali, quindi va incollato così com'è come file
// di codice personalizzato (vedi flutterflow/README.md). Dipende solo da
// `timezone` e `adhan`.
//
// Contiene:
//   1. Modelli (promemoria, orari, quiet hours, testi localizzati)
//   2. Orari di preghiera offline (adhan)
//   3. Pianificatore delle notifiche "ibrido a budget" (architettura §6)
//   4. Selezione dei contenuti senza ripetizioni ravvicinate
//   5. Merge deterministico per la sincronizzazione (architettura §8.2)
//
// Regola: nessun testo religioso viene creato o modificato qui. I contenuti
// arrivano già verificati dal database e vengono mostrati integralmente.

import 'dart:convert';
import 'dart:math';

import 'package:adhan/adhan.dart' as adhan;
import 'package:timezone/timezone.dart' as tz;

const String kNiyahCoreVersion = '0.1.0';

/// Azione FlutterFlow "di servizio": serve solo perché FlutterFlow accetti
/// questo file come custom action. Restituisce la versione della libreria.
Future<String> niyahCoreVersion() async => kNiyahCoreVersion;

/// UUID v4 casuale per i promemoria creati sul dispositivo (anche offline).
String generateUuidV4() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

Map<String, Object?> _asMap(Object? j) {
  if (j is Map) return j.map((k, v) => MapEntry('$k', v));
  if (j is String && j.trim().isNotEmpty) return _asMap(jsonDecode(j));
  return const {};
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. MODELLI
// ═══════════════════════════════════════════════════════════════════════════

enum ReminderKind { template, personal, struggle, content, prayer, event }

enum ScheduleType { daily, weekly, once, window, prayer }

enum Prayer { fajr, dhuhr, asr, maghrib, isha }

enum QuietMode { skip, shift }

/// Id dei canali Android (architettura §6.5). I nomi visibili sono localizzati
/// dal livello Flutter.
class NiyahChannels {
  static const prayer = 'prayer';
  static const niyyah = 'niyyah';
  static const quran = 'quran';
  static const hadith = 'hadith';
  static const dhikr = 'dhikr';
  static const goodDeeds = 'good_deeds';
  static const islamicEvents = 'islamic_events';
  static const personal = 'personal';
  static const all = [prayer, niyyah, quran, hadith, dhikr, goodDeeds, islamicEvents, personal];
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// Ora locale "HH:mm".
class LocalTime implements Comparable<LocalTime> {
  final int hour;
  final int minute;
  const LocalTime(this.hour, this.minute)
      : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  static LocalTime? tryParse(Object? s) {
    if (s is! String) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!);
    if (h > 23 || mi > 59) return null;
    return LocalTime(h, mi);
  }

  int get minutesOfDay => hour * 60 + minute;

  @override
  int compareTo(LocalTime other) => minutesOfDay.compareTo(other.minutesOfDay);

  @override
  bool operator ==(Object other) => other is LocalTime && other.minutesOfDay == minutesOfDay;

  @override
  int get hashCode => minutesOfDay;

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Data di calendario senza ora (yyyy-MM-dd).
class LocalDate implements Comparable<LocalDate> {
  final int year, month, day;
  const LocalDate(this.year, this.month, this.day);

  factory LocalDate.of(DateTime d) => LocalDate(d.year, d.month, d.day);

  static LocalDate? tryParse(Object? s) {
    if (s is! String || s.length < 10) return null;
    final d = DateTime.tryParse(s.substring(0, 10));
    return d == null ? null : LocalDate(d.year, d.month, d.day);
  }

  LocalDate addDays(int n) => LocalDate.of(DateTime.utc(year, month, day + n));

  /// 1 = lunedì … 7 = domenica (come DateTime.weekday).
  int get weekday => DateTime.utc(year, month, day).weekday;

  tz.TZDateTime at(tz.Location loc, LocalTime t) => tz.TZDateTime(loc, year, month, day, t.hour, t.minute);

  @override
  int compareTo(LocalDate o) =>
      year != o.year ? year.compareTo(o.year) : (month != o.month ? month.compareTo(o.month) : day.compareTo(o.day));

  bool isAfter(LocalDate o) => compareTo(o) > 0;
  bool isBefore(LocalDate o) => compareTo(o) < 0;

  @override
  bool operator ==(Object other) => other is LocalDate && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

/// Maschera dei giorni: bit 0 = lunedì … bit 6 = domenica. 127 = tutti i giorni.
class DaysMask {
  static const all = 127;
  static bool includes(int mask, int weekday) => (mask >> (weekday - 1)) & 1 == 1;
  static List<int> weekdays(int mask) => [for (var w = 1; w <= 7; w++) if (includes(mask, w)) w];
}

/// Un promemoria come salvato nella tabella SQLite `reminders`
/// (architettura §3.2). È la fonte di verità: le notifiche dell'OS sono solo
/// una sua proiezione.
class Reminder {
  final String id;
  final ReminderKind kind;
  final String? templateId;
  final String? categoryId;
  final String? title;
  final String? body;
  final String? contentType; // quran | hadith | dhikr
  final ScheduleType scheduleType;
  final LocalTime? time;
  final LocalTime? windowStart;
  final LocalTime? windowEnd;
  final int timesPerDay;
  final int daysMask;
  final Prayer? prayer;
  final int offsetMin; // minuti PRIMA della preghiera (0 = all'orario)
  final LocalDate startDate;
  final LocalDate? endDate;
  final bool enabled;
  final DateTime? pausedUntil; // istante UTC
  final bool respectsQuietHours;
  final bool hideOnLockScreen;
  final String channel;
  final String syncPolicy; // local_only | cloud
  final DateTime updatedAt; // UTC
  final bool deleted;

  const Reminder({
    required this.id,
    required this.kind,
    this.templateId,
    this.categoryId,
    this.title,
    this.body,
    this.contentType,
    required this.scheduleType,
    this.time,
    this.windowStart,
    this.windowEnd,
    this.timesPerDay = 1,
    this.daysMask = DaysMask.all,
    this.prayer,
    this.offsetMin = 0,
    required this.startDate,
    this.endDate,
    this.enabled = true,
    this.pausedUntil,
    this.respectsQuietHours = true,
    bool? hideOnLockScreen,
    String? channel,
    String? syncPolicy,
    required this.updatedAt,
    this.deleted = false,
  })  : hideOnLockScreen = hideOnLockScreen ?? (kind == ReminderKind.struggle),
        channel = channel ?? (kind == ReminderKind.prayer ? NiyahChannels.prayer : NiyahChannels.personal),
        // I promemoria "peccato che sto combattendo" non lasciano MAI il
        // dispositivo nella v1, qualunque cosa ci sia scritto nel record.
        syncPolicy = kind == ReminderKind.struggle ? 'local_only' : (syncPolicy ?? 'cloud');

  /// Costruisce un promemoria da una riga SQLite (chiavi snake_case).
  factory Reminder.fromRow(Map<String, Object?> r) {
    bool b(Object? v, bool d) => v == null ? d : (v == 1 || v == true || v == '1');
    final kind = _enumByName(ReminderKind.values, r['kind'], ReminderKind.personal);
    return Reminder(
      id: r['id'] as String,
      kind: kind,
      templateId: r['template_id'] as String?,
      categoryId: r['category_id'] as String?,
      title: r['title'] as String?,
      body: r['body'] as String?,
      contentType: r['content_type'] as String?,
      scheduleType: _enumByName(ScheduleType.values, r['schedule_type'], ScheduleType.daily),
      time: LocalTime.tryParse(r['time']),
      windowStart: LocalTime.tryParse(r['window_start']),
      windowEnd: LocalTime.tryParse(r['window_end']),
      timesPerDay: (r['times_per_day'] as int?) ?? 1,
      daysMask: (r['days_mask'] as int?) ?? DaysMask.all,
      prayer: r['prayer'] == null ? null : _enumByName(Prayer.values, r['prayer'], Prayer.fajr),
      offsetMin: (r['offset_min'] as int?) ?? 0,
      startDate: LocalDate.tryParse(r['start_date']) ?? const LocalDate(2000, 1, 1),
      endDate: LocalDate.tryParse(r['end_date']),
      enabled: b(r['enabled'], true),
      pausedUntil: r['paused_until'] == null ? null : DateTime.tryParse(r['paused_until'] as String)?.toUtc(),
      respectsQuietHours: b(r['respects_quiet_hours'], true),
      hideOnLockScreen: r['hide_on_lock_screen'] == null ? null : b(r['hide_on_lock_screen'], false),
      channel: r['channel'] as String?,
      syncPolicy: r['sync_policy'] as String?,
      updatedAt: DateTime.tryParse((r['updated_at'] as String?) ?? '')?.toUtc() ?? DateTime.utc(2000),
      deleted: b(r['deleted'], false),
    );
  }

  /// Errori di validazione da mostrare nell'editor (chiavi da localizzare).
  /// Lista vuota = valido.
  List<String> validate() {
    final errors = <String>[];
    switch (scheduleType) {
      case ScheduleType.daily:
      case ScheduleType.weekly:
      case ScheduleType.once:
        if (time == null) errors.add('error_time_required');
        break;
      case ScheduleType.window:
        if (windowStart == null || windowEnd == null) errors.add('error_window_required');
        if (timesPerDay < 1 || timesPerDay > 12) errors.add('error_times_per_day');
        break;
      case ScheduleType.prayer:
        if (prayer == null) errors.add('error_prayer_required');
        if (offsetMin < 0 || offsetMin > 120) errors.add('error_prayer_offset');
        break;
    }
    if (scheduleType == ScheduleType.weekly && daysMask & DaysMask.all == 0) errors.add('error_days_required');
    if (endDate != null && endDate!.isBefore(startDate)) errors.add('error_end_before_start');
    final needsText = kind == ReminderKind.personal || kind == ReminderKind.struggle;
    if (needsText && (title ?? '').trim().isEmpty && (body ?? '').trim().isEmpty) {
      errors.add('error_text_required');
    }
    return errors;
  }
}

/// Fascia "Non disturbare". Può attraversare la mezzanotte (22:30 → 07:00).
class QuietHours {
  final bool enabled;
  final LocalTime start;
  final LocalTime end;
  final QuietMode mode;
  const QuietHours({this.enabled = false, this.start = const LocalTime(22, 30), this.end = const LocalTime(7, 0), this.mode = QuietMode.skip});

  /// {"enabled": true, "start": "22:30", "end": "07:00", "mode": "skip"}
  factory QuietHours.fromJson(Object? json) {
    final j = _asMap(json);
    return QuietHours(
      enabled: j['enabled'] == true,
      start: LocalTime.tryParse(j['start']) ?? const LocalTime(22, 30),
      end: LocalTime.tryParse(j['end']) ?? const LocalTime(7, 0),
      mode: _enumByName(QuietMode.values, j['mode'], QuietMode.skip),
    );
  }

  bool contains(LocalTime t) {
    if (!enabled || start == end) return false;
    final m = t.minutesOfDay, s = start.minutesOfDay, e = end.minutesOfDay;
    return s < e ? (m >= s && m < e) : (m >= s || m < e);
  }

  /// Prima fine della fascia successiva a [t] (stesso fuso di [t]).
  tz.TZDateTime endAfter(tz.TZDateTime t) {
    var candidate = tz.TZDateTime(t.location, t.year, t.month, t.day, end.hour, end.minute);
    if (!candidate.isAfter(t)) {
      final next = LocalDate.of(t).addDays(1);
      candidate = next.at(t.location, end);
    }
    return candidate;
  }
}

/// Testi localizzati che il pianificatore usa per le notifiche che non hanno
/// un testo scritto dall'utente. Vengono passati dal livello Flutter nella
/// lingua attiva (nessun testo hard-coded qui).
class NotificationStrings {
  final Map<Prayer, String> prayerNames;

  /// Es. "È l'ora di {prayer}" — segnaposto {prayer}.
  final String prayerAtTime;

  /// Es. "{prayer} tra {minutes} minuti" — segnaposti {prayer} e {minutes}.
  final String prayerBefore;
  final String quranTitle;
  final String hadithTitle;
  final String dhikrTitle;

  /// Corpo usato quando il testo di un contenuto è troppo lungo per una
  /// notifica: il testo NON viene mai tagliato, si invita ad aprirlo.
  final String tapToRead;
  final String refreshTitle;
  final String refreshBody;

  /// Testo neutro mostrato sul blocco schermo per i promemoria privati.
  final String privateTitle;
  final String privateBody;

  const NotificationStrings({
    required this.prayerNames,
    required this.prayerAtTime,
    required this.prayerBefore,
    required this.quranTitle,
    required this.hadithTitle,
    required this.dhikrTitle,
    required this.tapToRead,
    required this.refreshTitle,
    required this.refreshBody,
    required this.privateTitle,
    required this.privateBody,
  });

  factory NotificationStrings.fromJson(Object? json) => _stringsFrom(_asMap(json));

  static NotificationStrings _stringsFrom(Map<String, Object?> j) => NotificationStrings(
        prayerNames: {
          for (final p in Prayer.values) p: ((j['prayerNames'] as Map?)?[p.name] as String?) ?? p.name,
        },
        prayerAtTime: j['prayerAtTime'] as String,
        prayerBefore: j['prayerBefore'] as String,
        quranTitle: j['quranTitle'] as String,
        hadithTitle: j['hadithTitle'] as String,
        dhikrTitle: j['dhikrTitle'] as String,
        tapToRead: j['tapToRead'] as String,
        refreshTitle: j['refreshTitle'] as String,
        refreshBody: j['refreshBody'] as String,
        privateTitle: j['privateTitle'] as String,
        privateBody: j['privateBody'] as String,
      );
}

/// Titolo e testo di un modello di notifica nella lingua attiva.
class TextPair {
  final String title;
  final String body;
  const TextPair(this.title, this.body);
}

// ═══════════════════════════════════════════════════════════════════════════
// QUERY SQLITE (schema: seed/schema.sql) — testate in test/sql_test.dart
// ═══════════════════════════════════════════════════════════════════════════

class NiyahSql {
  static const activeReminders = 'SELECT * FROM reminders WHERE deleted = 0';

  static const templateTexts = 'SELECT template_id, title, body FROM template_i18n WHERE lang = ?';

  static const recentContent = 'SELECT content_id FROM recent_content ORDER BY shown_at DESC LIMIT 50';

  /// Contenuti pubblicati con traduzione nella lingua richiesta.
  /// Parametri: lingua, poi un valore per ogni tipo.
  static String contentCandidates(int typeCount) => '''
    SELECT ci.id, ci.type, i.reference_label, i.text, GROUP_CONCAT(cc.category_id) AS cats
    FROM content_items ci
    JOIN content_i18n i ON i.content_id = ci.id AND i.lang = ?
    LEFT JOIN content_categories cc ON cc.content_id = ci.id
    WHERE ci.status = 'published' AND ci.type IN (${List.filled(typeCount, '?').join(',')})
    GROUP BY ci.id
    ORDER BY ci.updated_at DESC
    LIMIT 2000''';

  static ContentCandidate candidateFromRow(Map<String, Object?> r) => ContentCandidate(
        id: r['id'] as String,
        type: r['type'] as String,
        reference: r['reference_label'] as String,
        text: r['text'] as String,
        categoryIds: ((r['cats'] as String?) ?? '').split(',').where((s) => s.isNotEmpty).toSet(),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. ORARI DI PREGHIERA (offline, architettura §5)
// ═══════════════════════════════════════════════════════════════════════════

class PrayerSettings {
  final double latitude;
  final double longitude;

  /// Nome di adhan.CalculationMethod, es. 'muslim_world_league'.
  final String method;

  /// 'shafi' (standard: Shafi'i, Maliki, Hanbali) oppure 'hanafi'.
  final String madhab;

  /// null = regola raccomandata in base alla latitudine.
  final String? highLatitudeRule;

  /// Aggiustamenti manuali in minuti per preghiera.
  final Map<Prayer, int> offsets;

  const PrayerSettings({
    required this.latitude,
    required this.longitude,
    this.method = 'muslim_world_league',
    this.madhab = 'shafi',
    this.highLatitudeRule,
    this.offsets = const {},
  });

  /// {"lat": 41.9, "lng": 12.5, "method": "muslim_world_league", "madhab": "shafi",
  ///  "highLatitudeRule": null, "offsets": {"fajr": 0, "isha": 2}}
  /// Restituisce null se la posizione non è ancora impostata.
  static PrayerSettings? fromJson(Object? json) {
    final j = _asMap(json);
    final lat = (j['lat'] as num?)?.toDouble(), lng = (j['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    final off = _asMap(j['offsets']);
    return PrayerSettings(
      latitude: lat,
      longitude: lng,
      method: (j['method'] as String?) ?? 'muslim_world_league',
      madhab: (j['madhab'] as String?) ?? 'shafi',
      highLatitudeRule: j['highLatitudeRule'] as String?,
      offsets: {for (final p in Prayer.values) if (off[p.name] is num) p: (off[p.name] as num).toInt()},
    );
  }

  /// Impronta delle impostazioni: se cambia, la cache `prayer_cache` va ricalcolata.
  String hash(String timezone) => stableHash(
          '$latitude|$longitude|$method|$madhab|${highLatitudeRule ?? 'auto'}|'
          '${Prayer.values.map((p) => offsets[p] ?? 0).join(',')}|$timezone')
      .toRadixString(16);
}

/// Metodo di calcolo proposto come default in base al paese (ISO 3166 alpha-2).
/// È solo un punto di partenza: l'utente lo può sempre cambiare (§16).
String defaultMethodForCountry(String? countryCode) {
  switch ((countryCode ?? '').toUpperCase()) {
    case 'SA':
    case 'YE':
      return 'umm_al_qura';
    case 'AE':
    case 'OM':
    case 'BH':
      return 'dubai';
    case 'QA':
      return 'qatar';
    case 'KW':
      return 'kuwait';
    case 'EG':
    case 'SD':
    case 'LY':
    case 'SY':
    case 'LB':
    case 'IQ':
    case 'JO':
    case 'PS':
      return 'egyptian';
    case 'PK':
    case 'IN':
    case 'BD':
    case 'AF':
      return 'karachi';
    case 'US':
    case 'CA':
      return 'north_america';
    case 'SG':
    case 'MY':
    case 'ID':
    case 'BN':
      return 'singapore';
    case 'TR':
      return 'turkey';
    case 'IR':
      return 'tehran';
    default:
      return 'muslim_world_league';
  }
}

class DayPrayerTimes {
  final LocalDate date;
  final Map<Prayer, tz.TZDateTime> times;
  final tz.TZDateTime sunrise;
  const DayPrayerTimes(this.date, this.times, this.sunrise);

  Map<String, Object?> toRow(String settingsHash) => {
        'date': date.toString(),
        for (final p in Prayer.values) p.name: times[p]!.toIso8601String(),
        'sunrise': sunrise.toIso8601String(),
        'settings_hash': settingsHash,
      };
}

/// Calcola gli orari di una giornata nel fuso [loc]. Tutto in locale, senza rete.
DayPrayerTimes computePrayerTimes(LocalDate date, PrayerSettings s, tz.Location loc) {
  final method = _enumByName(adhan.CalculationMethod.values, s.method, adhan.CalculationMethod.muslim_world_league);
  final params = method.getParameters();
  params.madhab = s.madhab == 'hanafi' ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
  params.highLatitudeRule = s.highLatitudeRule == null
      ? (s.latitude.abs() > 48 ? adhan.HighLatitudeRule.seventh_of_the_night : adhan.HighLatitudeRule.middle_of_the_night)
      : _enumByName(adhan.HighLatitudeRule.values, s.highLatitudeRule, adhan.HighLatitudeRule.middle_of_the_night);
  params.adjustments.fajr = s.offsets[Prayer.fajr] ?? 0;
  params.adjustments.dhuhr = s.offsets[Prayer.dhuhr] ?? 0;
  params.adjustments.asr = s.offsets[Prayer.asr] ?? 0;
  params.adjustments.maghrib = s.offsets[Prayer.maghrib] ?? 0;
  params.adjustments.isha = s.offsets[Prayer.isha] ?? 0;

  final pt = adhan.PrayerTimes.utc(
    adhan.Coordinates(s.latitude, s.longitude),
    adhan.DateComponents(date.year, date.month, date.day),
    params,
  );
  tz.TZDateTime local(DateTime utc) =>
      tz.TZDateTime.from(DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute, utc.second), loc);
  return DayPrayerTimes(
    date,
    {
      Prayer.fajr: local(pt.fajr),
      Prayer.dhuhr: local(pt.dhuhr),
      Prayer.asr: local(pt.asr),
      Prayer.maghrib: local(pt.maghrib),
      Prayer.isha: local(pt.isha),
    },
    local(pt.sunrise),
  );
}

List<DayPrayerTimes> computePrayerDays(LocalDate from, int days, PrayerSettings s, tz.Location loc) =>
    [for (var i = 0; i < days; i++) computePrayerTimes(from.addDays(i), s, loc)];

// ═══════════════════════════════════════════════════════════════════════════
// 3. PIANIFICATORE DELLE NOTIFICHE (architettura §6)
// ═══════════════════════════════════════════════════════════════════════════

/// Hash FNV-1a a 31 bit: id stabili e positivi per le notifiche dell'OS.
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(s)) {
    h ^= b;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  final id = h & 0x7FFFFFFF;
  return id == 0 ? 1 : id;
}

enum RepeatKind { none, daily, weekly }

/// Una notifica da consegnare al sistema operativo.
class PlannedNotification {
  final int id;
  final String reminderId;
  final RepeatKind repeat;

  /// Prima (o unica) occorrenza. Per le ripetute, l'OS ripete ora e giorno.
  final tz.TZDateTime fireAt;
  final String channel;
  final String title;
  final String body;

  /// Testo da mostrare sul blocco schermo al posto di title/body (privacy).
  final String? publicTitle;
  final String? publicBody;
  final String? contentId;
  final String payload;
  final int priority;

  const PlannedNotification({
    required this.id,
    required this.reminderId,
    required this.repeat,
    required this.fireAt,
    required this.channel,
    required this.title,
    required this.body,
    this.publicTitle,
    this.publicBody,
    this.contentId,
    required this.payload,
    required this.priority,
  });

  bool get isPrivate => publicTitle != null;

  @override
  String toString() => 'PN($id ${repeat.name} $fireAt "$title")';
}

/// Notifica già in attesa nell'OS (da pendingNotificationRequests()).
class ExistingNotification {
  final int id;
  final String? title;
  final String? body;
  final String? payload;
  const ExistingNotification(this.id, {this.title, this.body, this.payload});

  Map<String, Object?>? get payloadJson {
    try {
      final p = payload;
      return p == null ? null : jsonDecode(p) as Map<String, Object?>;
    } catch (_) {
      return null;
    }
  }
}

/// Un contenuto candidato per una notifica Corano/Hadith/Dhikr. Il livello
/// Flutter lo legge da SQLite già filtrato per lingua e `published`, con una
/// traduzione verificata nella lingua attiva.
class ContentCandidate {
  final String id;
  final String type; // quran | hadith | dhikr
  final Set<String> categoryIds;

  /// Riferimento leggibile, es. "Al-Baqarah 2:286" o "Sahih Muslim 2699".
  final String reference;

  /// Testo integrale nella lingua attiva (mai tagliato né riformulato).
  final String text;
  const ContentCandidate({
    required this.id,
    required this.type,
    this.categoryIds = const {},
    required this.reference,
    required this.text,
  });
}

class PlannerSettings {
  /// Numero massimo di notifiche in attesa che Niyah si concede.
  /// iOS: 64 per app → 60 (riserva di 4). Android: 200.
  final int budget;

  /// Quanti giorni avanti generare le occorrenze singole.
  final int horizonDays;
  final QuietHours quietHours;

  /// Pausa globale (istante UTC) — "Metti in pausa tutte le notifiche".
  final DateTime? pausedUntil;

  /// Oltre questa lunghezza il testo di un contenuto non va nella notifica:
  /// si mostra [NotificationStrings.tapToRead] e il testo integrale nell'app.
  final int maxContentBodyChars;

  /// Ultimi contenuti mostrati (dal più recente): non vengono ripetuti.
  final List<String> recentContentIds;
  final int avoidRepeatCount;

  const PlannerSettings({
    required this.budget,
    this.horizonDays = 14,
    this.quietHours = const QuietHours(),
    this.pausedUntil,
    this.maxContentBodyChars = 600,
    this.recentContentIds = const [],
    this.avoidRepeatCount = 30,
  });

  static const iosBudget = 60;
  static const androidBudget = 200;
}

class SchedulePlan {
  final List<PlannedNotification> notifications;

  /// Promemoria che non entrano nel budget dell'OS (da segnalare nell'editor).
  final List<String> overBudgetReminderIds;

  /// Promemoria con orario fisso sempre dentro la fascia "Non disturbare".
  final List<String> mutedByQuietHours;

  /// Fin dove arrivano le notifiche singole programmate (null = nessuna).
  final tz.TZDateTime? windowEnd;

  /// Contenuti scelti in questo giro: da salvare in `recent_content`.
  final List<String> newlyPickedContentIds;

  const SchedulePlan({
    required this.notifications,
    required this.overBudgetReminderIds,
    required this.mutedByQuietHours,
    required this.windowEnd,
    required this.newlyPickedContentIds,
  });

  /// Differenza con ciò che è già nell'OS. Gli id includono tutto ciò che è
  /// visibile (testo, orario, canale), quindi qualunque modifica produce un id
  /// nuovo: basta cancellare i vecchi e programmare i nuovi. Nessun duplicato.
  ScheduleDiff diff(Iterable<int> pendingIds) {
    final pending = pendingIds.toSet();
    final desired = {for (final n in notifications) n.id: n};
    return ScheduleDiff(
      toCancel: pending.difference(desired.keys.toSet()).toList()..sort(),
      toSchedule: [for (final e in desired.entries) if (!pending.contains(e.key)) e.value],
    );
  }
}

class ScheduleDiff {
  final List<int> toCancel;
  final List<PlannedNotification> toSchedule;
  const ScheduleDiff({required this.toCancel, required this.toSchedule});
}

typedef PrayerTimesProvider = DayPrayerTimes? Function(LocalDate date);

/// Priorità a parità di orario e per il taglio delle ripetute fuori budget.
int _priorityOf(Reminder r) {
  switch (r.kind) {
    case ReminderKind.prayer:
      return 100;
    case ReminderKind.personal:
    case ReminderKind.struggle:
      return 80;
    case ReminderKind.template:
    case ReminderKind.event:
      return 60;
    case ReminderKind.content:
      return 40;
  }
}

class _Occurrence {
  final Reminder r;
  final tz.TZDateTime at;
  final int index; // indice nella giornata (solo per i contenuti)
  _Occurrence(this.r, this.at, this.index);
  String get key => '${r.id}@${r.updatedAt.millisecondsSinceEpoch}@${at.toUtc().toIso8601String()}#$index';
}

/// Pianificatore ibrido a budget.
///
/// A) Promemoria a testo e orario fissi, senza pausa né scadenza vicina →
///    UNA notifica ripetuta nell'OS (giornaliera) o una per giorno scelto
///    (settimanale). Non scadono mai, anche se l'app non viene aperta.
/// B) Tutto il resto (preghiera, contenuti, pause, date di fine vicine, una
///    tantum) → occorrenze singole in una finestra mobile, finché c'è budget.
/// Se la finestra B ha un limite, l'ultimo slot diventa un invito gentile ad
/// aprire l'app (notifica di rinfresco).
class NotificationPlanner {
  final tz.Location location;
  final PlannerSettings settings;
  final NotificationStrings strings;
  final Map<String, TextPair> templateTexts;
  final PrayerTimesProvider? prayerTimes;
  final List<ContentCandidate> contentCandidates;

  NotificationPlanner({
    required this.location,
    required this.settings,
    required this.strings,
    this.templateTexts = const {},
    this.prayerTimes,
    this.contentCandidates = const [],
  });

  SchedulePlan plan(List<Reminder> reminders, tz.TZDateTime now, {List<ExistingNotification> existing = const []}) {
    now = tz.TZDateTime.from(now, location);
    final today = LocalDate.of(now);
    final horizonEnd = now.add(Duration(days: settings.horizonDays));
    final globalPause = settings.pausedUntil;

    final repeating = <PlannedNotification>[];
    final oneOffs = <_Occurrence>[];
    final muted = <String>[];
    final overBudget = <String>{};
    var needsRefresh = false;

    for (final r in reminders) {
      if (r.deleted || !r.enabled) continue;
      if (r.validate().isNotEmpty) continue;
      if (r.endDate != null && r.endDate!.isBefore(today)) continue;

      final pause = _maxDate(globalPause, r.pausedUntil);
      final paused = pause != null && pause.isAfter(now.toUtc());

      final fixedText = r.kind != ReminderKind.content &&
          r.kind != ReminderKind.prayer &&
          (r.scheduleType == ScheduleType.daily || r.scheduleType == ScheduleType.weekly);
      final startsNow = !r.startDate.isAfter(today);
      final endFar = r.endDate == null || r.endDate!.isAfter(LocalDate.of(horizonEnd));

      if (fixedText && startsNow && endFar && !paused) {
        var t = r.time!;
        if (r.respectsQuietHours && settings.quietHours.contains(t)) {
          if (settings.quietHours.mode == QuietMode.skip) {
            muted.add(r.id);
            continue;
          }
          t = settings.quietHours.end;
        }
        repeating.addAll(_repeatingFor(r, t, now));
        continue;
      }

      // Caso B: occorrenze singole.
      final occ = _occurrencesFor(r, today, now, horizonEnd);
      oneOffs.addAll(occ.where((o) => pause == null || !o.at.toUtc().isBefore(pause)));
      final endsInWindow = r.scheduleType == ScheduleType.once || (r.endDate != null && !r.endDate!.isAfter(LocalDate.of(horizonEnd)));
      final startsLater = r.startDate.isAfter(LocalDate.of(horizonEnd));
      if (!endsInWindow && (occ.isNotEmpty || startsLater)) needsRefresh = true;
    }

    // Applica la fascia "Non disturbare" alle singole.
    final adjusted = <_Occurrence>[];
    for (final o in oneOffs) {
      final t = LocalTime(o.at.hour, o.at.minute);
      if (o.r.respectsQuietHours && settings.quietHours.contains(t)) {
        if (settings.quietHours.mode == QuietMode.skip) continue;
        adjusted.add(_Occurrence(o.r, settings.quietHours.endAfter(o.at), o.index));
      } else {
        adjusted.add(o);
      }
    }
    adjusted.sort((a, b) {
      final c = a.at.compareTo(b.at);
      return c != 0 ? c : _priorityOf(b.r).compareTo(_priorityOf(a.r));
    });

    // Budget: prima le ripetute (per priorità), una riserva per il rinfresco.
    final reserve = needsRefresh ? 1 : 0;
    var budget = settings.budget - reserve;
    repeating.sort((a, b) => b.priority.compareTo(a.priority));
    final keptRepeating = <PlannedNotification>[];
    final droppedRepeating = <String>{};
    for (final n in repeating) {
      // Le notifiche settimanali di uno stesso promemoria stanno insieme o fuori insieme.
      if (droppedRepeating.contains(n.reminderId)) continue;
      final group = repeating.where((x) => x.reminderId == n.reminderId).toList();
      if (keptRepeating.any((k) => k.reminderId == n.reminderId)) continue;
      if (group.length <= budget) {
        keptRepeating.addAll(group);
        budget -= group.length;
      } else {
        droppedRepeating.add(n.reminderId);
        overBudget.add(n.reminderId);
      }
    }

    // Poi le singole in ordine cronologico, finché c'è posto.
    final existingByKey = <String, ExistingNotification>{};
    for (final e in existing) {
      final k = e.payloadJson?['k'];
      if (k is String) existingByKey[k] = e;
    }
    final recent = settings.recentContentIds.take(settings.avoidRepeatCount).toList();
    final picker = _ContentPicker(contentCandidates, recent);

    final singles = <PlannedNotification>[];
    final seenIds = <int>{for (final n in keptRepeating) n.id};
    tz.TZDateTime? windowEnd;
    var truncated = false;
    for (final o in adjusted) {
      if (budget <= 0) {
        truncated = true;
        windowEnd = o.at;
        break;
      }
      final n = _singleFor(o, picker, existingByKey);
      if (n == null || !seenIds.add(n.id)) continue;
      singles.add(n);
      budget--;
    }
    if (!truncated && adjusted.isNotEmpty) windowEnd = horizonEnd;
    if (!truncated && adjusted.isEmpty && needsRefresh) windowEnd = horizonEnd;

    final all = [...keptRepeating, ...singles];
    if (needsRefresh && windowEnd != null) {
      all.add(_refreshNotification(now, windowEnd));
    }
    all.sort((a, b) => a.fireAt.compareTo(b.fireAt));

    return SchedulePlan(
      notifications: all,
      overBudgetReminderIds: overBudget.toList(),
      mutedByQuietHours: muted,
      windowEnd: windowEnd,
      newlyPickedContentIds: picker.newlyPicked,
    );
  }

  // ── Ripetute ──────────────────────────────────────────────────────────────

  List<PlannedNotification> _repeatingFor(Reminder r, LocalTime t, tz.TZDateTime now) {
    final text = _textFor(r);
    final daily = r.scheduleType == ScheduleType.daily && r.daysMask & DaysMask.all == DaysMask.all;
    final days = daily ? [0] : DaysMask.weekdays(r.daysMask);
    return [
      for (final wd in days)
        _build(
          r: r,
          repeat: daily ? RepeatKind.daily : RepeatKind.weekly,
          fireAt: _nextAt(now, t, weekday: daily ? null : wd),
          title: text.title,
          body: text.body,
          key: 'rep|${r.id}|${daily ? 'd' : 'w$wd'}|$t',
        ),
    ];
  }

  tz.TZDateTime _nextAt(tz.TZDateTime now, LocalTime t, {int? weekday}) {
    var d = LocalDate.of(now);
    for (var i = 0; i < 8; i++) {
      final cand = d.addDays(i);
      if (weekday != null && cand.weekday != weekday) continue;
      final at = cand.at(location, t);
      if (at.isAfter(now)) return at;
    }
    return d.addDays(7).at(location, t);
  }

  // ── Singole ───────────────────────────────────────────────────────────────

  List<_Occurrence> _occurrencesFor(Reminder r, LocalDate today, tz.TZDateTime now, tz.TZDateTime horizonEnd) {
    final out = <_Occurrence>[];
    bool dayOk(LocalDate d) =>
        !d.isBefore(r.startDate) && (r.endDate == null || !d.isAfter(r.endDate!)) && DaysMask.includes(r.daysMask, d.weekday);
    void add(tz.TZDateTime at, int i) {
      if (at.isAfter(now) && !at.isAfter(horizonEnd)) out.add(_Occurrence(r, at, i));
    }

    if (r.scheduleType == ScheduleType.once) {
      add(r.startDate.at(location, r.time!), 0);
      return out;
    }
    for (var i = 0; i <= settings.horizonDays; i++) {
      final d = today.addDays(i);
      if (!dayOk(d)) continue;
      switch (r.scheduleType) {
        case ScheduleType.daily:
        case ScheduleType.weekly:
          add(d.at(location, r.time!), 0);
          break;
        case ScheduleType.window:
          for (final (idx, at) in _windowTimes(r, d).indexed) {
            add(at, idx);
          }
          break;
        case ScheduleType.prayer:
          final day = prayerTimes?.call(d);
          final pt = day?.times[r.prayer!];
          if (pt != null) add(pt.subtract(Duration(minutes: r.offsetMin)), 0);
          break;
        case ScheduleType.once:
          break;
      }
    }
    return out;
  }

  /// Orari "approssimativi" nella fascia scelta: distribuiti in modo uniforme
  /// con una piccola variazione deterministica (stessa giornata → stessi orari).
  List<tz.TZDateTime> _windowTimes(Reminder r, LocalDate d) {
    final s = r.windowStart!.minutesOfDay;
    var e = r.windowEnd!.minutesOfDay;
    if (e <= s) e += 24 * 60;
    final n = r.timesPerDay;
    final slot = (e - s) / n;
    final rnd = Random(stableHash('${r.id}|$d'));
    final jitterMax = min(15, slot ~/ 4);
    return [
      for (var i = 0; i < n; i++)
        () {
          final m = (s + slot * (i + 0.5)).round() + (jitterMax == 0 ? 0 : rnd.nextInt(2 * jitterMax + 1) - jitterMax);
          return tz.TZDateTime(location, d.year, d.month, d.day, 0, m);
        }(),
    ];
  }

  PlannedNotification? _singleFor(_Occurrence o, _ContentPicker picker, Map<String, ExistingNotification> existingByKey) {
    final r = o.r;
    if (r.kind == ReminderKind.content || r.scheduleType == ScheduleType.window && r.contentType != null) {
      // Se questa occorrenza è già programmata, si conserva il contenuto scelto
      // allora: evita di cambiare testo a ogni riprogrammazione.
      final prev = existingByKey[o.key];
      final prevContent = prev?.payloadJson?['c'];
      ContentCandidate? c;
      if (prevContent is String) c = picker.byId(prevContent);
      c ??= picker.pick(r.contentType, r.categoryId, stableHash(o.key));
      if (c == null) return null;
      picker.markUsed(c.id);
      final title = '${_contentTitle(c.type)} · ${c.reference}';
      final body = c.text.length <= settings.maxContentBodyChars ? c.text : strings.tapToRead;
      return _build(r: r, repeat: RepeatKind.none, fireAt: o.at, title: title, body: body, key: o.key, contentId: c.id, occurrenceKey: o.key);
    }
    if (r.kind == ReminderKind.prayer) {
      final name = strings.prayerNames[r.prayer!] ?? r.prayer!.name;
      final title = (r.title ?? '').isNotEmpty ? r.title! : name;
      final body = (r.body ?? '').isNotEmpty
          ? r.body!
          : (r.offsetMin == 0
              ? strings.prayerAtTime.replaceAll('{prayer}', name)
              : strings.prayerBefore.replaceAll('{prayer}', name).replaceAll('{minutes}', '${r.offsetMin}'));
      return _build(r: r, repeat: RepeatKind.none, fireAt: o.at, title: title, body: body, key: o.key, occurrenceKey: o.key);
    }
    final text = _textFor(r);
    return _build(r: r, repeat: RepeatKind.none, fireAt: o.at, title: text.title, body: text.body, key: o.key, occurrenceKey: o.key);
  }

  String _contentTitle(String type) => switch (type) {
        'quran' => strings.quranTitle,
        'hadith' => strings.hadithTitle,
        _ => strings.dhikrTitle,
      };

  TextPair _textFor(Reminder r) {
    final tpl = r.templateId == null ? null : templateTexts[r.templateId];
    // Il testo scritto dall'utente non viene mai modificato (§58).
    final title = (r.title ?? '').isNotEmpty ? r.title! : (tpl?.title ?? '');
    final body = (r.body ?? '').isNotEmpty ? r.body! : (tpl?.body ?? '');
    return TextPair(title, body);
  }

  PlannedNotification _build({
    required Reminder r,
    required RepeatKind repeat,
    required tz.TZDateTime fireAt,
    required String title,
    required String body,
    required String key,
    String? contentId,
    String? occurrenceKey,
  }) {
    final private = r.hideOnLockScreen;
    final payload = jsonEncode({
      'r': r.id,
      if (occurrenceKey != null) 'k': occurrenceKey,
      if (contentId != null) 'c': contentId,
    });
    final timePart = repeat == RepeatKind.none ? fireAt.toUtc().toIso8601String() : '';
    return PlannedNotification(
      id: stableHash('$key|$timePart|$title|$body|${r.channel}|$private|${contentId ?? ''}'),
      reminderId: r.id,
      repeat: repeat,
      fireAt: fireAt,
      channel: r.channel,
      title: title,
      body: body,
      publicTitle: private ? strings.privateTitle : null,
      publicBody: private ? strings.privateBody : null,
      contentId: contentId,
      payload: payload,
      priority: _priorityOf(r),
    );
  }

  PlannedNotification _refreshNotification(tz.TZDateTime now, tz.TZDateTime windowEnd) {
    var at = windowEnd.subtract(const Duration(hours: 24));
    final minAt = now.add(const Duration(hours: 1));
    if (at.isBefore(minAt)) {
      at = tz.TZDateTime.fromMillisecondsSinceEpoch(
          location, now.millisecondsSinceEpoch + (windowEnd.millisecondsSinceEpoch - now.millisecondsSinceEpoch) ~/ 2);
    }
    if (settings.quietHours.contains(LocalTime(at.hour, at.minute))) {
      at = settings.quietHours.endAfter(at);
    }
    return PlannedNotification(
      id: stableHash('refresh|${strings.refreshTitle}|${strings.refreshBody}|${at.toUtc().toIso8601String()}'),
      reminderId: '_refresh',
      repeat: RepeatKind.none,
      fireAt: at,
      channel: NiyahChannels.niyyah,
      title: strings.refreshTitle,
      body: strings.refreshBody,
      payload: jsonEncode({'r': '_refresh'}),
      priority: 0,
    );
  }
}

DateTime? _maxDate(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. SELEZIONE DEI CONTENUTI (§59)
// ═══════════════════════════════════════════════════════════════════════════

class _ContentPicker {
  final List<ContentCandidate> all;
  final List<String> recent; // dal più recente
  final List<String> newlyPicked = [];
  final Set<String> _used = {};

  _ContentPicker(this.all, this.recent);

  ContentCandidate? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  void markUsed(String id) {
    if (_used.add(id) && !recent.contains(id)) newlyPicked.add(id);
  }

  /// Sceglie tra i contenuti idonei evitando quelli mostrati di recente e
  /// quelli già usati in questo giro. Se sono stati usati tutti, sceglie quello
  /// mostrato meno di recente. Mai scelta "a caso dall'intero database".
  ContentCandidate? pick(String? type, String? categoryId, int seed) {
    final eligible = all
        .where((c) => (type == null || c.type == type) && (categoryId == null || c.categoryIds.contains(categoryId)))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (eligible.isEmpty) return null;
    final fresh = eligible.where((c) => !_used.contains(c.id) && !recent.contains(c.id)).toList();
    if (fresh.isNotEmpty) return fresh[Random(seed).nextInt(fresh.length)];
    // Tutti già visti: il meno recente (non nella lista recenti > più vecchio).
    final notUsedNow = eligible.where((c) => !_used.contains(c.id)).toList();
    final pool = notUsedNow.isNotEmpty ? notUsedNow : eligible;
    pool.sort((a, b) => _recency(b.id).compareTo(_recency(a.id)));
    return pool.first;
  }

  int _recency(String id) {
    final i = recent.indexOf(id);
    return i < 0 ? 1 << 30 : i; // più grande = visto meno di recente
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. MERGE PER LA SINCRONIZZAZIONE (§42, architettura §8.2)
// ═══════════════════════════════════════════════════════════════════════════

class SyncRecord {
  final String id;
  final DateTime updatedAt; // UTC
  final String deviceId;
  final bool deleted;

  /// Se true il record non lascia mai il dispositivo (promemoria privati).
  final bool localOnly;
  final Map<String, Object?> data;

  const SyncRecord({
    required this.id,
    required this.updatedAt,
    required this.deviceId,
    this.deleted = false,
    this.localOnly = false,
    this.data = const {},
  });
}

class MergeResult {
  /// Da scrivere in SQLite (vincono i dati del cloud).
  final List<SyncRecord> toLocal;

  /// Da scrivere su Firestore (vincono i dati locali).
  final List<SyncRecord> toRemote;

  /// Tombstone scadute da eliminare definitivamente da entrambe le parti.
  final List<String> toPurge;
  const MergeResult(this.toLocal, this.toRemote, this.toPurge);
}

/// Unione deterministica per record: vince l'`updatedAt` più recente; a
/// parità vince il `deviceId` lessicograficamente maggiore. Le eliminazioni
/// viaggiano come tombstone e vengono ripulite dopo [tombstoneTtl].
/// Nessun record locale viene mai perso senza una regola esplicita.
MergeResult mergeRecords(
  List<SyncRecord> local,
  List<SyncRecord> remote, {
  required DateTime nowUtc,
  Duration tombstoneTtl = const Duration(days: 30),
}) {
  final l = {for (final r in local) r.id: r};
  final rm = {for (final r in remote) r.id: r};
  final toLocal = <SyncRecord>[], toRemote = <SyncRecord>[], purge = <String>[];
  bool expired(SyncRecord r) => r.deleted && nowUtc.difference(r.updatedAt) > tombstoneTtl;

  for (final id in {...l.keys, ...rm.keys}.toList()..sort()) {
    final a = l[id], b = rm[id];
    if (a != null && a.localOnly) continue; // mai caricato, mai sovrascritto dal cloud
    if (b != null && b.localOnly) continue; // dato privato finito per errore nel cloud: ignorato
    if ((a == null || expired(a)) && (b == null || expired(b))) {
      purge.add(id);
      continue;
    }
    if (a == null) {
      toLocal.add(b!);
    } else if (b == null) {
      toRemote.add(a);
    } else {
      final c = a.updatedAt.compareTo(b.updatedAt);
      final localWins = c > 0 || (c == 0 && a.deviceId.compareTo(b.deviceId) > 0);
      final same = c == 0 && a.deviceId == b.deviceId && a.deleted == b.deleted;
      if (same) continue;
      if (localWins) {
        toRemote.add(a);
      } else {
        toLocal.add(b);
      }
    }
  }
  return MergeResult(toLocal, toRemote, purge);
}
