import 'dart:convert';

import '../models.dart';
import '../repositories.dart';
import 'niyah_database.dart';
import 'schedule_codec.dart';

/// [TemplateRepository] backed by `templates` + `template_i18n`.
///
/// Only templates shown in "Add a reminder" are returned: active ones (a
/// template that needs a verified source stays inactive until it has one,
/// see `seed/build_seed.py`) with a group. Italian and English are loaded
/// into memory on [init]; any other language falls back to English.
class SqliteTemplateRepository implements TemplateRepository {
  SqliteTemplateRepository(this._db);

  final NiyahDatabase _db;
  final Map<String, List<TemplateItem>> _byLanguage = {};

  static const languages = ['en', 'it'];
  static const fallbackLanguage = 'en';

  @override
  Future<void> init() async {
    final rows = await _db.db.rawQuery('''
      SELECT t.id, t.group_key, t.icon, t.default_schedule_json, i.lang, i.title, i.body
      FROM templates t
      JOIN template_i18n i ON i.template_id = t.id
      WHERE t.active = 1 AND t.group_key IS NOT NULL AND i.lang IN (${List.filled(languages.length, '?').join(',')})
      ORDER BY t.rowid''', languages);
    _byLanguage.clear();
    for (final r in rows) {
      final schedule = scheduleFromJson(jsonDecode(r['default_schedule_json'] as String) as Map<String, Object?>);
      if (schedule == null) continue;
      (_byLanguage[r['lang'] as String] ??= []).add(TemplateItem(
        id: r['id'] as String,
        group: TemplateGroup.values.byName(r['group_key'] as String),
        icon: (r['icon'] as String?) ?? 'heart',
        title: r['title'] as String,
        body: r['body'] as String,
        defaultSchedule: schedule,
      ));
    }
    _byLanguage.updateAll((_, list) => List.unmodifiable(list));
  }

  @override
  List<TemplateItem> templates(String languageCode) =>
      _byLanguage[languageCode] ?? _byLanguage[fallbackLanguage] ?? const [];

  @override
  TemplateItem? byId(String id, String languageCode) {
    for (final t in templates(languageCode)) {
      if (t.id == id) return t;
    }
    return null;
  }
}
