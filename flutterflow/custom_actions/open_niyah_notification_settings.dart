// Niyah — apre le impostazioni di sistema delle notifiche dell'app (per chi ha
// negato il permesso e vuole riattivarlo).
// Nome dell'azione in FlutterFlow: openNiyahNotificationSettings
// Restituisce (bool): true se la schermata è stata aperta.

import '/custom_code/actions/niyah_runtime.dart';

Future<bool> openNiyahNotificationSettings() async {
  final rt = NiyahRuntime.instance;
  await rt.ensurePlugin();
  if (rt.isIos) return await rt.ios?.openAppNotificationSettings() ?? false;
  return await rt.android?.openAppNotificationSettings() ?? false;
}
