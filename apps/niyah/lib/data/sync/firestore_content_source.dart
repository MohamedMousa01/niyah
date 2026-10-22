import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'content_source.dart';

/// [ContentSource] on Cloud Firestore. Every read goes to the server: SQLite
/// is the only copy on the device, so Firestore's own cache is switched off.
class FirestoreContentSource implements ContentSource {
  FirestoreContentSource(this._fs);

  /// The default app's Firestore without the offline cache. Call before any
  /// other use of [FirebaseFirestore.instance].
  factory FirestoreContentSource.instance() {
    final fs = FirebaseFirestore.instance;
    fs.settings = const Settings(persistenceEnabled: false);
    return FirestoreContentSource(fs);
  }

  final FirebaseFirestore _fs;

  static const _server = GetOptions(source: Source.server);
  static const timeout = Duration(seconds: 20);

  /// Lower bound on the order field: the inequality also leaves out documents
  /// whose field is missing or not a timestamp, which have no valid cursor.
  static final _minTimestamp = Timestamp(-62135596800, 0);

  @override
  Future<Map<String, int>> contentVersions() async {
    final doc = await _call(_fs.doc('meta/contentVersion').get(_server));
    final version = doc.data()?['version'];
    return {
      if (version is Map)
        for (final e in version.entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
    };
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
    Query<Map<String, dynamic>> q = _fs.collection(collection);
    if (field != null) q = q.where(field, isEqualTo: value);
    q = q
        .where(orderField, isGreaterThanOrEqualTo: _minTimestamp)
        .orderBy(orderField)
        .orderBy(FieldPath.documentId)
        .limit(limit);
    if (after != null) q = q.startAfter(decodeCursor(after));
    final snap = await _call(q.get(_server));
    return [
      for (final d in snap.docs)
        RemoteDoc(d.id, _plain(d.data()), encodeCursor(d.data()[orderField] as Timestamp, d.id)),
    ];
  }

  @override
  Future<List<RemoteDoc>> publishedTranslations(String contentId) async {
    // A query, not a get: the rules deny a get on a draft or missing
    // translation, and one denial would fail the whole sync.
    final snap = await _call(
        _fs.collection('contentItems/$contentId/translations').where('status', isEqualTo: 'published').get(_server));
    return [for (final d in snap.docs) RemoteDoc(d.id, _plain(d.data()), d.id)];
  }

  static Future<T> _call<T>(Future<T> request) async {
    try {
      return await request.timeout(timeout);
    } on TimeoutException {
      throw const ContentOffline();
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') throw const ContentOffline();
      rethrow;
    }
  }

  /// "seconds:nanoseconds:docId" (a doc id may itself contain ':').
  @visibleForTesting
  static String encodeCursor(Timestamp t, String id) => '${t.seconds}:${t.nanoseconds}:$id';

  /// The `startAfter` values of [encodeCursor]'s output.
  @visibleForTesting
  static List<Object> decodeCursor(String cursor) {
    final a = cursor.indexOf(':'), b = cursor.indexOf(':', a + 1);
    if (a < 0 || b < 0) throw FormatException('Bad content cursor', cursor);
    return [Timestamp(int.parse(cursor.substring(0, a)), int.parse(cursor.substring(a + 1, b))), cursor.substring(b + 1)];
  }

  static Object? _plainValue(Object? v) => switch (v) {
        Timestamp() => v.toDate().toUtc(),
        Map() => {for (final e in v.entries) '${e.key}': _plainValue(e.value)},
        List() => [for (final x in v) _plainValue(x)],
        _ => v,
      };

  static Map<String, Object?> _plain(Map<String, dynamic> data) => _plainValue(data) as Map<String, Object?>;
}
