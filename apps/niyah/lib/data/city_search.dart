import 'dart:math' as math;

import 'models.dart';

/// Pure helpers of the offline city search, shared by the SQLite and the
/// in-memory [CityRepository]s.

const _folded = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a', //
  'ç': 'c', 'ć': 'c', 'č': 'c', 'ď': 'd', 'đ': 'd', //
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e', //
  'ğ': 'g', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i', 'ı': 'i', //
  'ł': 'l', 'ñ': 'n', 'ń': 'n', 'ň': 'n', //
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o', //
  'ř': 'r', 'ś': 's', 'š': 's', 'ş': 's', 'ș': 's', 'ß': 'ss', 'ť': 't', 'ţ': 't', 'ț': 't', //
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u', //
  'ý': 'y', 'ÿ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z', 'æ': 'ae', 'œ': 'oe', //
  '’': "'", '‘': "'",
};

/// Lower case, without accents and extra spaces: "  Città " → "citta".
/// Matches how `seed/build_seed.py` stores `alt_names`.
String foldCityName(String s) {
  final b = StringBuffer();
  for (final ch in s.trim().toLowerCase().split('')) {
    b.write(_folded[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Escapes `%`, `_` and `\` for a SQL `LIKE ... ESCAPE '\'`.
String escapeLike(String s) => s.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');

/// Distance in km on the sphere.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
}

/// The city of [cities] closest to the point (null if the list is empty).
PrayerLocation? closestCity(Iterable<PrayerLocation> cities, double latitude, double longitude) {
  PrayerLocation? best;
  var bestKm = double.infinity;
  for (final c in cities) {
    final km = distanceKm(latitude, longitude, c.latitude, c.longitude);
    if (km < bestKm) {
      best = c;
      bestKm = km;
    }
  }
  return best;
}

/// Radius in which the biggest place wins over the nearest one.
const nearbyKm = 15.0;

/// The city to name a GPS fix after: the most populous of [cities] within
/// [nearbyKm] (so a district like "Brera" gives way to Milan), otherwise
/// the closest. [cities] pairs each place with its population.
PrayerLocation? cityForPosition(Iterable<(PrayerLocation, int)> cities, double latitude, double longitude) {
  (PrayerLocation, int)? biggest;
  for (final c in cities) {
    if (distanceKm(latitude, longitude, c.$1.latitude, c.$1.longitude) > nearbyKm) continue;
    if (biggest == null || c.$2 > biggest.$2) biggest = c;
  }
  return biggest?.$1 ?? closestCity(cities.map((c) => c.$1), latitude, longitude);
}

/// A GPS fix as a prayer location: rounded to 0.01° (about 1 km, plenty for
/// prayer times) and named after [nearest], whose time zone it takes.
PrayerLocation gpsLocation(double latitude, double longitude, PrayerLocation nearest) {
  double round(double v) => (v * 100).roundToDouble() / 100;
  return PrayerLocation(
    name: nearest.name,
    country: nearest.country,
    latitude: round(latitude),
    longitude: round(longitude),
    timezone: nearest.timezone,
    fromGps: true,
  );
}
