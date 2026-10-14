// Niyah — stato attuale del permesso notifiche (può essere stato revocato
// dalle impostazioni di sistema). Da rileggere al ritorno in primo piano.
// Nome dell'azione in FlutterFlow: niyahNotificationPermissionStatus
// Restituisce (String): "granted" | "denied"

import '/custom_code/actions/niyah_runtime.dart';

Future<String> niyahNotificationPermissionStatus() async {
  final rt = NiyahRuntime.instance;
  await rt.ensurePlugin();
  bool enabled;
  if (rt.isIos) {
    final o = await rt.ios?.checkPermissions();
    enabled = o?.isEnabled ?? false;
  } else {
    enabled = await rt.android?.areNotificationsEnabled() ?? false;
  }
  return enabled ? 'granted' : 'denied';
}
