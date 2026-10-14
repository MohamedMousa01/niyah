// Niyah — calcola gli orari di preghiera in locale (offline) e li salva in
// `prayer_cache` per i prossimi giorni.
// Nome dell'azione in FlutterFlow: refreshPrayerTimesCache
// Parametri:
//   prayerJson (JSON)  {"lat": 41.9, "lng": 12.5, "method": "muslim_world_league",
//                       "madhab": "shafi", "highLatitudeRule": null, "offsets": {}}
//   timezone   (String) fuso della città scelta; vuoto = quello del dispositivo
//   days       (int)    quanti giorni calcolare (consigliato 30)
// Restituisce (JSON): gli orari di oggi {"date": "...", "fajr": "05:47", ...,
//   "settingsHash": "..."} oppure null se la posizione non è impostata.
//
// Chiamarla quando cambiano posizione, fuso o impostazioni di calcolo, e
// all'avvio se la cache non copre più la data di oggi. Mai in continuo.

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:timezone/timezone.dart' as tz;

import '/custom_code/actions/niyah_core.dart' as core;
import '/custom_code/actions/niyah_runtime.dart';

Future<dynamic> refreshPrayerTimesCache(dynamic prayerJson, String? timezone, int days) async {
  final rt = NiyahRuntime.instance;
  final settings = core.PrayerSettings.fromJson(prayerJson);
  if (settings == null) return null;
  final loc = await rt.location(timezone);
  final today = core.LocalDate.of(tz.TZDateTime.now(loc));
  final hash = settings.hash(loc.name);
  final computed = core.computePrayerDays(today, days.clamp(1, 60), settings, loc);

  final db = await rt.database();
  final batch = db.batch();
  // Le righe calcolate con impostazioni diverse non servono più.
  batch.delete('prayer_cache', where: 'settings_hash <> ? OR date < ?', whereArgs: [hash, today.toString()]);
  for (final d in computed) {
    batch.insert('prayer_cache', d.toRow(hash), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await batch.commit(noResult: true);

  String hm(tz.TZDateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final t = computed.first;
  return {
    'date': t.date.toString(),
    for (final p in core.Prayer.values) p.name: hm(t.times[p]!),
    'sunrise': hm(t.sunrise),
    'settingsHash': hash,
    'timezone': loc.name,
  };
}
