import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/city_search.dart';
import 'package:niyah/data/fake/fake_repositories.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/data/repositories.dart';
import 'package:niyah/data/sqlite/sqlite_city_repository.dart';

import 'sqlite_test_utils.dart';

void main() {
  group('helpers', () {
    test('folding: case, accents, spaces', () {
      expect(foldCityName('  Città  di   Castello '), 'citta di castello');
      expect(foldCityName('İstanbul'.toLowerCase()), startsWith('i'));
      expect(foldCityName('Düsseldorf'), 'dusseldorf');
      expect(foldCityName('Kraków'), 'krakow');
    });

    test('LIKE wildcards are escaped', () {
      expect(escapeLike(r'50%_a\b'), r'50\%\_a\\b');
    });

    test('distance and GPS rounding', () {
      // Milan → Rome is about 477 km.
      expect(distanceKm(45.4643, 9.1895, 41.8919, 12.5113), closeTo(477, 5));
      const milan = FakeSettingsStore.sampleLocation;
      final gps = gpsLocation(45.47812, 9.22719, milan);
      expect((gps.latitude, gps.longitude), (45.48, 9.23));
      expect(gps.fromGps, isTrue);
      expect(gps.name, 'Milan');
      expect(gps.timezone, 'Europe/Rome');
    });
  });

  group('SqliteCityRepository', () {
    final temp = TempDb()..setUpEach();

    Future<CityRepository> repo() async => SqliteCityRepository(await temp.open());

    test('finds a city by its English, Italian or accented name, biggest first', () async {
      final cities = await repo();
      expect((await cities.search('Milan')).first.name, 'Milan');
      final milano = (await cities.search('milano')).first;
      expect((milano.name, milano.country, milano.timezone), ('Milan', 'IT', 'Europe/Rome'));
      expect((await cities.search('Roma')).first.name, 'Rome');
      expect((await cities.search('Il Cairo')).first.name, 'Cairo');
      final turin = (await cities.search('TORINO ')).first;
      expect(turin.name, 'Turin');
      expect((await cities.search('Düsseldorf')).first.country, 'DE');
    });

    test('an exact name comes before bigger cities that only start with it', () async {
      final cities = await repo();
      expect((await cities.search('Paris')).first.country, 'FR');
      final rome = await cities.search('rome');
      expect(rome.first.country, 'IT');
    });

    test('empty, wildcard-only and unknown queries return nothing', () async {
      final cities = await repo();
      expect(await cities.search('   '), isEmpty);
      expect(await cities.search('%'), isEmpty);
      expect(await cities.search('zzzzqqq'), isEmpty);
      expect(await cities.search('a', limit: 5), hasLength(5));
    });

    test('nearest city to a GPS fix, none in the open ocean', () async {
      final cities = await repo();
      // Milano Lambrate: closer to districts in the list ("Brera"), but
      // the biggest place nearby names it.
      final near = await cities.nearest(45.4781, 9.2272);
      expect(near!.name, 'Milan');
      expect((await cities.nearest(30.05, 31.24))!.timezone, 'Africa/Cairo');
      expect(await cities.nearest(-40.0, -130.0), isNull); // South Pacific
    });
  });

  test('the biggest place nearby wins, the closest one further away', () {
    PrayerLocation at(String name, double lat) =>
        PrayerLocation(name: name, country: 'IT', latitude: lat, longitude: 9.0, timezone: 'Europe/Rome');
    final district = (at('District', 45.001), 20000), city = (at('City', 45.05), 1000000);
    expect(cityForPosition([district, city], 45.0, 9.0)!.name, 'City'); // 5.5 km away
    final far = (at('Far', 45.5), 1000000), village = (at('Village', 45.3), 16000);
    expect(cityForPosition([far, village], 45.0, 9.0)!.name, 'Village'); // both beyond 15 km
    expect(cityForPosition(const [], 45.0, 9.0), isNull);
  });

  group('FakeCityRepository', () {
    test('same rules on the sample list', () async {
      final cities = FakeCityRepository();
      expect((await cities.search('napoli')).single.name, 'Naples');
      expect(await cities.search(''), isEmpty);
      expect((await cities.nearest(45.48, 9.23))!.name, 'Milan');
      expect(await cities.nearest(0, 0), isNull);
    });
  });

  test('PrayerLocation JSON round trip, incomplete JSON refused', () {
    const l = PrayerLocation(name: 'Milan', country: 'IT', latitude: 45.48, longitude: 9.23, timezone: 'Europe/Rome', fromGps: true);
    expect(PrayerLocation.fromJson(l.toJson()), l);
    expect(PrayerLocation.fromJson({'name': 'x'}), isNull);
    expect(PrayerLocation.fromJson('x'), isNull);
  });
}
