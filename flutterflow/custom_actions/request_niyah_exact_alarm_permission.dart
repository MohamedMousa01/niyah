// Niyah — Android 12+: permesso "Sveglie e promemoria" per l'orario esatto.
// Chiederlo solo quando l'utente attiva gli avvisi di preghiera, con una
// spiegazione. Su iOS restituisce sempre true.
// Nome dell'azione in FlutterFlow: requestNiyahExactAlarmPermission
// Restituisce (bool): true se le notifiche possono arrivare all'orario esatto.
// Dopo la risposta chiamare rescheduleAllNotifications (rileva da sola il
// cambio di modalità e riprogramma tutto).

import '/custom_code/actions/niyah_runtime.dart';

Future<bool> requestNiyahExactAlarmPermission() async {
  final rt = NiyahRuntime.instance;
  if (rt.isIos) return true;
  await rt.ensurePlugin();
  final a = rt.android;
  if (a == null) return false;
  if (await a.canScheduleExactNotifications() ?? false) return true;
  await a.requestExactAlarmsPermission();
  return await a.canScheduleExactNotifications() ?? false;
}
