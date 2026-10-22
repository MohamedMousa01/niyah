import 'dart:convert';

import '../models.dart';
import '../repositories.dart';
import 'niyah_database.dart';
import 'schedule_codec.dart';

/// [TemplateRepository] backed by `templates` + `template_i18n`.
///
/// "Add a reminder" ([templates]) lists active templates with a group (a
/// template that needs a verified source stays inactive until it has one,
/// see `seed/build_seed.py`). [byId] also finds inactive ones: a template
/// withdrawn by the content sync keeps working for users who added it.
/// Italian and English are loaded into memory on [init] (call it again after
/// a content sync); any other language falls back to English.
class SqliteTemplateRepository implements TemplateRepository {
  SqliteTemplateRepository(this._db);

  final NiyahDatabase _db;
  final Map<String, List<TemplateItem>> _byLanguage = {};
  final Map<String, Map<String, TemplateItem>> _allByLanguage = {};

  static const languages = ['en', 'it'];
  static const fallbackLanguage = 'en';

  @override
  Future<void> init() async {
    final rows = await _db.db.rawQuery('''
      SELECT t.id, t.active, t.group_key, t.icon, t.default_schedule_json, i.lang, i.title, i.body
      FROM templates t
      JOIN template_i18n i ON i.template_id = t.id
      WHERE t.group_key IS NOT NULL AND i.lang IN (${List.filled(languages.length, '?').join(',')})
      ORDER BY t.rowid''', languages);
    final active = <String, List<TemplateItem>>{};
    final all = <String, Map<String, TemplateItem>>{};
    for (final r in rows) {
      final schedule = scheduleFromJson(jsonDecode(r['default_schedule_json'] as String) as Map<String, Object?>);
      if (schedule == null) continue;
      final lang = r['lang'] as String;
      final item = TemplateItem(
        id: r['id'] as String,
        group: TemplateGroup.values.byName(r['group_key'] as String),
        icon: (r['icon'] as String?) ?? 'heart',
        title: r['title'] as String,
        body: r['body'] as String,
        defaultSchedule: schedule,
      );
      (all[lang] ??= {})[item.id] = item;
      if (r['active'] == 1) (active[lang] ??= []).add(item);
    }
    _byLanguage
      ..clear()
      ..addAll({for (final e in active.entries) e.key: List.unmodifiable(e.value)});
    _allByLanguage
      ..clear()
      ..addAll(all);
  }

  @override
  List<TemplateItem> templates(String languageCode) =>
      _byLanguage[languageCode] ?? _byLanguage[fallbackLanguage] ?? const [];

  @override
  TemplateItem? byId(String id, String languageCode) =>
      (_allByLanguage[languageCode] ?? _allByLanguage[fallbackLanguage])?[id];
}
