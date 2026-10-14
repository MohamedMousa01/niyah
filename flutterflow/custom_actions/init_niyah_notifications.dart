// Niyah — inizializza le notifiche locali e i canali Android.
// Nome dell'azione in FlutterFlow: initNiyahNotifications
// Parametri:
//   channelNamesJson (JSON)  nomi localizzati dei canali, es.
//     {"prayer": "Preghiera", "niyyah": "Niyyah", "quran": "Corano", "hadith": "Hadith",
//      "dhikr": "Dhikr", "good_deeds": "Buone azioni", "islamic_events": "Eventi islamici",
//      "personal": "Promemoria personali"}
// Restituisce (String?): il payload della notifica che ha aperto l'app, se c'è.
//
// Chiamarla all'avvio (On Page Load della prima pagina) e dopo ogni cambio di
// lingua (aggiorna i nomi dei canali). Non chiede permessi.

import '/custom_code/actions/niyah_runtime.dart';

Future<String?> initNiyahNotifications(dynamic channelNamesJson) async {
  final rt = NiyahRuntime.instance;
  if (channelNamesJson is Map) {
    rt.channelNames = {
      ...rt.channelNames,
      for (final e in channelNamesJson.entries) '${e.key}': '${e.value}',
    };
  }
  await rt.ensurePlugin();
  await rt.createChannels();
  final launch = await rt.plugin.getNotificationAppLaunchDetails();
  if (launch?.didNotificationLaunchApp == true) {
    final payload = launch!.notificationResponse?.payload;
    if (payload != null) rt.pendingTapPayload = payload;
  }
  return rt.pendingTapPayload;
}
