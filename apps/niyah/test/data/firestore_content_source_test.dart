import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/sync/firestore_content_source.dart';

void main() {
  test('a cursor keeps the full timestamp and an id with colons', () {
    final at = Timestamp(1790000000, 123456789);
    final cursor = FirestoreContentSource.encodeCursor(at, 'a:b');
    expect(FirestoreContentSource.decodeCursor(cursor), [at, 'a:b']);
  });

  test('a damaged cursor is refused', () {
    expect(() => FirestoreContentSource.decodeCursor('nope'), throwsFormatException);
  });
}
