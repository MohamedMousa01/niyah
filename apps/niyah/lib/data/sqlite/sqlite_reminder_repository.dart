import 'dart:async';

import 'package:niyah_core/niyah_core.dart' as core;

import '../defaults.dart';
import '../models.dart';
import '../repositories.dart';
import 'niyah_database.dart';
import 'schedule_codec.dart';

/// [ReminderRepository] backed by the `reminders` table. Rows are cached in
/// memory after [init]; every write goes to SQLite first.
///
/// - personal → `kind = 'personal'`, `sync_policy = 'local_only'` (the words
///   never leave the phone);
/// - template → `kind = 'template'` with `template_id`, null title/body (the
///   texts come from `template_i18n` in the current language);
/// - prayer → `kind = 'prayer'`, fixed id [prayerId].
/// Deletes are soft (`deleted = 1`), as the sync needs tombstones.
class SqliteReminderRepository extends ReminderRepository {
  SqliteReminderRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final NiyahDatabase _db;
  final DateTime Function() _clock;
  final Map<String, ReminderItem> _items = {};
  final Map<String, ({String channel, String? category})> _templates = {};
  late String _deviceId;

  static const prayerId = 'prayer';

  @override
  Future<void> init() async {
    _deviceId = await _db.deviceId();
    for (final t in await _db.db.query('templates', columns: ['id', 'channel', 'category_id'])) {
      _templates[t['id'] as String] = (channel: t['channel'] as String, category: t['category_id'] as String?);
    }
    final rows = await _db.db.query(
      'reminders',
      where: "deleted = 0 AND kind IN ('personal', 'template', 'prayer')",
      orderBy: 'created_at, rowid',
    );
    _items.clear();
    for (final row in rows) {
      final item = itemFromRow(row);
      if (item != null) _items[item.id] = item;
    }
    if (!_items.containsKey(prayerId)) await _write(_defaultPrayer);
  }

  @override
  List<ReminderItem> get all => List.unmodifiable(_items.values);

  @override
  ReminderItem? byId(String id) => _items[id];

  @override
  ReminderItem? byTemplate(String templateId) {
    for (final r in _items.values) {
      if (r.templateId == templateId) return r;
    }
    return null;
  }

  @override
  ReminderItem get prayer {
    final existing = _items[prayerId];
    if (existing != null) return existing;
    // Deleted since init: recreate it with the defaults.
    unawaited(_write(_defaultPrayer));
    return _items[prayerId] = _defaultPrayer;
  }

  @override
  Future<void> save(ReminderItem reminder) async {
    await _write(reminder);
    notifyListeners();
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    final r = _items[id];
    if (r == null) return;
    await _update(id, {'enabled': enabled ? 1 : 0});
    _items[id] = r.copyWith(enabled: enabled);
    notifyListeners();
  }

  @override
  Future<void> delete(String id) async {
    if (!_items.containsKey(id)) return;
    await _update(id, {'deleted': 1});
    _items.remove(id);
    notifyListeners();
  }

  @override
  String newId() => core.generateUuidV4();

  static const _defaultPrayer = ReminderItem(id: prayerId, source: ReminderSource.prayer, schedule: Defaults.prayerReminder);

  /// Channel and category of a template; one the content sync added after
  /// [init] is read from the database.
  Future<({String channel, String? category})?> _template(String? id) async {
    if (id == null) return null;
    final cached = _templates[id];
    if (cached != null) return cached;
    final rows = await _db.db.query('templates', columns: ['channel', 'category_id'], where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _templates[id] = (channel: rows.first['channel'] as String, category: rows.first['category_id'] as String?);
  }

  /// Upsert. A row deleted earlier with the same id comes back.
  Future<void> _write(ReminderItem r) async {
    final isTemplate = r.source == ReminderSource.template;
    final template = isTemplate ? await _template(r.templateId) : null;
    final row = <String, Object?>{
      'kind': r.source.name,
      'template_id': r.templateId,
      'category_id': template?.category,
      'title': isTemplate ? null : r.title,
      'body': isTemplate ? null : r.body,
      ...scheduleColumns(r.schedule),
      'enabled': r.enabled ? 1 : 0,
      'channel': switch (r.source) {
        ReminderSource.personal => core.NiyahChannels.personal,
        ReminderSource.prayer => core.NiyahChannels.prayer,
        ReminderSource.template => template?.channel ?? core.NiyahChannels.niyyah,
      },
      'sync_policy': r.source == ReminderSource.personal ? 'local_only' : 'cloud',
      'deleted': 0,
    };
    final updated = await _update(r.id, row);
    if (updated == 0) {
      final now = _clock();
      await _db.db.insert('reminders', {
        ...row,
        'id': r.id,
        'start_date': core.LocalDate.of(now).toString(),
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
        'device_id': _deviceId,
      });
    }
    _items[r.id] = ReminderItem(
      id: r.id,
      source: r.source,
      templateId: r.templateId,
      title: isTemplate ? null : r.title,
      body: isTemplate ? null : r.body,
      schedule: switch (r.schedule) {
        // Same value a reload would give (the column is clamped).
        PrayerSchedule s => s.copyWith(offsetMin: row['offset_min'] as int),
        final s => s,
      },
      enabled: r.enabled,
    );
  }

  Future<int> _update(String id, Map<String, Object?> values) => _db.db.update(
        'reminders',
        {...values, 'updated_at': _clock().toUtc().toIso8601String(), 'device_id': _deviceId},
        where: 'id = ?',
        whereArgs: [id],
      );

  /// The UI view of a `reminders` row, or null for kinds the UI does not show.
  static ReminderItem? itemFromRow(Map<String, Object?> row) {
    final r = core.Reminder.fromRow(row);
    final source = switch (r.kind) {
      core.ReminderKind.personal => ReminderSource.personal,
      core.ReminderKind.template => ReminderSource.template,
      core.ReminderKind.prayer => ReminderSource.prayer,
      _ => null,
    };
    final schedule = scheduleOf(r);
    if (source == null || schedule == null) return null;
    return ReminderItem(
      id: r.id,
      source: source,
      templateId: r.templateId,
      title: r.title,
      body: r.body,
      schedule: schedule,
      enabled: r.enabled,
    );
  }
}
