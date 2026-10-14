// Niyah — chiede il permesso per le notifiche (una sola volta, dopo la
// schermata di spiegazione dell'onboarding, §27).
// Nome dell'azione in FlutterFlow: requestNiyahNotificationPermission
// Restituisce (bool): true se concesso.

import '/custom_code/actions/niyah_runtime.dart';

Future<bool> requestNiyahNotificationPermission() async {
  final rt = NiyahRuntime.instance;
  await rt.ensurePlugin();
  if (rt.isIos) {
    return await rt.ios?.requestPermissions(alert: true, badge: false, sound: true) ?? false;
  }
  return await rt.android?.requestNotificationsPermission() ?? false;
}
