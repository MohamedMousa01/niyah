// Contenuti "di catalogo" arrivati dal seed o dalla sincronizzazione:
// modelli di notifica e argomenti di "Sto per…". Solo lettura.

import 'dart:convert';

import 'package:niyah_core/niyah_core.dart' as core;
import 'package:sqflite/sqflite.dart';

/// Pianificazione proposta da un modello (`templates.default_schedule_json`).
class TemplateSchedule {
  const TemplateSchedule({
    required this.type,
    this.time,
    this.daysMask = core.DaysMask.all,
    this.windowStart,
    this.windowEnd,
    this.timesPerDay = 1,
  });

  final core.ScheduleType type;
  final core.LocalTime? time;
  final int daysMask;
  final core.LocalTime? windowStart;
  final core.LocalTime? windowEnd;
  final int timesPerDay;

  factory TemplateSchedule.fromJson(String? raw) {
    Map<String, Object?> j;
    try {
      j = (jsonDecode(raw ?? '{}') as Map).cast<String, Object?>();
    } catch (_) {
      j = const {};
    }
    final type = core.ScheduleType.values.firstWhere(
      (t) => t.name == j['schedule_type'],
      orElse: () => core.ScheduleType.daily,
    );
    return TemplateSchedule(
      type: type,
      time: core.LocalTime.tryParse(j['time']),
      daysMask: (j['days_mask'] as int?) ?? core.DaysMask.all,
      windowStart: core.LocalTime.tryParse(j['window_start']),
      windowEnd: core.LocalTime.tryParse(j['window_end']),
      timesPerDay: (j['times_per_day'] as int?) ?? 1,
    );
  }
}

class TemplateItem {
  const TemplateItem({
    required this.id,
    required this.section,
    required this.channel,
    required this.title,
    required this.body,
    required this.schedule,
    this.categoryId,
    this.contentType,
  });

  final String id;
  final String section; // suggested | content | weekly | seasonal
  final String channel;
  final String? categoryId;
  final String? contentType;
  final String title;
  final String body;
  final TemplateSchedule schedule;
}

class TopicItem {
  const TopicItem({required this.id, required this.name, this.icon, required this.contentCount});

  final String id;
  final String name;
  final String? icon;
  final int contentCount;
}

class CatalogRepository {
  CatalogRepository(this.db);

  final Database db;

  /// Modelli attivi con il testo nella lingua [lang], nell'ordine del seed.
  /// Un modello senza testo in quella lingua non compare: nessun ripiego
  /// silenzioso su un'altra lingua.
  Future<List<TemplateItem>> templates(String lang) async {
    final rows = await db.rawQuery('''
      SELECT t.id, t.section, t.channel, t.category_id, t.content_type, t.default_schedule_json, i.title, i.body
      FROM templates t JOIN template_i18n i ON i.template_id = t.id AND i.lang = ?
      WHERE t.active = 1
      ORDER BY t.rowid''', [lang]);
    return [
      for (final r in rows)
        TemplateItem(
          id: r['id'] as String,
          section: r['section'] as String,
          channel: r['channel'] as String,
          categoryId: r['category_id'] as String?,
          contentType: r['content_type'] as String?,
          title: r['title'] as String,
          body: r['body'] as String,
          schedule: TemplateSchedule.fromJson(r['default_schedule_json'] as String?),
        ),
    ];
  }

  /// Numero di contenuti verificati disponibili per tipo (quran, hadith, dhikr)
  /// nella lingua [lang].
  Future<Map<String, int>> contentCounts(String lang) async {
    final rows = await db.rawQuery('''
      SELECT ci.type, COUNT(*) AS n FROM content_items ci
      JOIN content_i18n i ON i.content_id = ci.id AND i.lang = ?
      GROUP BY ci.type''', [lang]);
    return {for (final r in rows) r['type'] as String: r['n'] as int};
  }

  Future<List<TopicItem>> topics(String lang) async {
    final rows = await db.rawQuery('''
      SELECT t.id, t.icon, i.name,
        (SELECT COUNT(*) FROM topic_content tc
           JOIN content_i18n ci ON ci.content_id = tc.content_id AND ci.lang = ?
           WHERE tc.topic_id = t.id) AS n
      FROM topics t JOIN topic_i18n i ON i.topic_id = t.id AND i.lang = ?
      WHERE t.active = 1
      ORDER BY t.sort''', [lang, lang]);
    return [
      for (final r in rows)
        TopicItem(id: r['id'] as String, name: r['name'] as String, icon: r['icon'] as String?, contentCount: r['n'] as int),
    ];
  }
}
