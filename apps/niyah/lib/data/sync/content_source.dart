/// Where the curated content comes from (Firestore on a device, a fake in
/// tests). Only public, published/active documents are visible. Every request
/// ends in bounded time: a lost connection throws [ContentOffline].
abstract class ContentSource {
  /// `meta/contentVersion.version`: the content version of each language.
  Future<Map<String, int>> contentVersions();

  /// Up to [limit] documents of [collection] ordered by [orderField] (a
  /// timestamp) then by id, starting after [after] (a [RemoteDoc.cursor] of
  /// the same query). With [field], only documents where it equals [value]
  /// (the security rules require that filter).
  Future<List<RemoteDoc>> page(
    String collection, {
    String? field,
    Object? value,
    required String orderField,
    String? after,
    required int limit,
  });

  /// The published translations of `contentItems/[contentId]` (doc id =
  /// language).
  Future<List<RemoteDoc>> publishedTranslations(String contentId);
}

/// One document. Timestamps are [DateTime]s in UTC.
class RemoteDoc {
  final String id;
  final Map<String, Object?> data;

  /// Position right after this document in its query; stored between runs.
  final String cursor;

  const RemoteDoc(this.id, this.data, this.cursor);
}

/// The server could not be reached (no network, timeout).
class ContentOffline implements Exception {
  const ContentOffline();

  @override
  String toString() => 'ContentOffline';
}
