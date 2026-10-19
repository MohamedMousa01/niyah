import 'dart:math' as math;

import '../city_search.dart';
import '../models.dart';
import '../repositories.dart';
import 'niyah_database.dart';

/// [CityRepository] on the `cities` table of the bundled seed (GeoNames
/// cities15000: about 34,000 places with more than 15,000 people).
class SqliteCityRepository implements CityRepository {
  SqliteCityRepository(this._db);

  final NiyahDatabase _db;

  @override
  Future<List<PrayerLocation>> search(String query, {int limit = 20}) async {
    final q = foldCityName(query);
    if (q.isEmpty) return const [];
    final like = escapeLike(q);
    // ascii_name LIKE is case-insensitive for ASCII; alt_names is stored
    // folded as '|milano|mailand|'. Exact names first, then by size.
    final rows = await _db.db.rawQuery(
      r"SELECT * FROM cities WHERE ascii_name LIKE ?1 ESCAPE '\' OR alt_names LIKE ?2 ESCAPE '\' "
      r"ORDER BY (ascii_name LIKE ?3 ESCAPE '\' OR alt_names LIKE ?4 ESCAPE '\') DESC, population DESC LIMIT ?5",
      ['$like%', '%|$like%', like, '%|$like|%', limit],
    );
    return [for (final r in rows) _location(r)];
  }

  @override
  Future<PrayerLocation?> nearest(double latitude, double longitude) async {
    // Look in a growing box around the point, then pick the city.
    for (final degrees in const [0.5, 2.0, 8.0]) {
      final lngDegrees = math.min(180.0, degrees / math.max(0.1, math.cos(latitude * math.pi / 180)));
      final rows = await _db.db.query(
        'cities',
        where: 'lat BETWEEN ? AND ? AND lng BETWEEN ? AND ?',
        whereArgs: [latitude - degrees, latitude + degrees, longitude - lngDegrees, longitude + lngDegrees],
      );
      if (rows.isEmpty) continue;
      return cityForPosition([for (final r in rows) (_location(r), r['population'] as int)], latitude, longitude);
    }
    return null;
  }

  static PrayerLocation _location(Map<String, Object?> r) => PrayerLocation(
        name: r['name'] as String,
        country: r['country'] as String,
        latitude: (r['lat'] as num).toDouble(),
        longitude: (r['lng'] as num).toDouble(),
        timezone: r['timezone'] as String,
      );
}
