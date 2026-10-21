import 'package:niyah/data/sync/content_source.dart';

/// In-memory [ContentSource] with Firestore's query semantics: equality
/// filter, order by a timestamp field then id, start after a cursor, limit.
/// Documents without a [DateTime] in the order field are left out, as the
/// Firestore query's lower bound does.
class FakeContentSource implements ContentSource {
  final Map<String, int> versions = {};
  final Map<String, Map<String, Map<String, Object?>>> collections = {};

  /// contentItems/{id}/translations/{lang}.
  final Map<String, Map<String, Map<String, Object?>>> translations = {};

  /// Every request, e.g. 'version', 'page notificationTemplates', 'translations q1'.
  final List<String> requests = [];

  /// Called before each request; throw from it to simulate a failure.
  void Function(String request)? onRequest;

  void put(String collection, String id, Map<String, Object?> data) => (collections[collection] ??= {})[id] = data;

  /// Bumps every language, like the Cloud Function.
  void bump() {
    for (final l in ['it', 'en', 'ar', 'fr']) {
      versions[l] = (versions[l] ?? 0) + 1;
    }
  }

  void _request(String r) {
    requests.add(r);
    onRequest?.call(r);
  }

  @override
  Future<Map<String, int>> contentVersions() async {
    _request('version');
    return Map.of(versions);
  }

  @override
  Future<List<RemoteDoc>> page(
    String collection, {
    String? field,
    Object? value,
    required String orderField,
    String? after,
    required int limit,
  }) async {
    _request('page $collection');
    final docs = [
      for (final MapEntry(key: id, value: d) in (collections[collection] ?? const {}).entries)
        if ((field == null || d[field] == value) && d[orderField] is DateTime) (id: id, at: d[orderField] as DateTime, data: d),
    ]..sort((a, b) => a.at != b.at ? a.at.compareTo(b.at) : a.id.compareTo(b.id));
    // Fixed width, so the strings compare like (time, id).
    String cursor(DateTime at, String id) => '${at.microsecondsSinceEpoch.toString().padLeft(20, '0')}|$id';
    return [
      for (final d in docs)
        if (after == null || cursor(d.at, d.id).compareTo(after) > 0) RemoteDoc(d.id, Map.of(d.data), cursor(d.at, d.id)),
    ].take(limit).toList();
  }

  @override
  Future<List<RemoteDoc>> publishedTranslations(String contentId) async {
    _request('translations $contentId');
    return [
      for (final MapEntry(key: lang, value: t) in (translations[contentId] ?? const {}).entries)
        if (t['status'] == 'published') RemoteDoc(lang, Map.of(t), lang),
    ];
  }
}
