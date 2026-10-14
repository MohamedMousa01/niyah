// Niyah — restituisce (e consuma) il payload dell'ultima notifica toccata.
// Nome dell'azione in FlutterFlow: takePendingNotificationTap
// Restituisce (String?): JSON {"r": reminderId, "c": contentId?} oppure null.
//
// Chiamarla in On Page Load della Home e quando l'app torna in primo piano:
// se c'è un "c" si apre ContentDetailPage, se "r" è un promemoria privato si
// apre il suo testo completo, se "r" è "_refresh" basta aver aperto l'app.

import '/custom_code/actions/niyah_runtime.dart';

Future<String?> takePendingNotificationTap() async {
  final rt = NiyahRuntime.instance;
  final payload = rt.pendingTapPayload;
  rt.pendingTapPayload = null;
  return payload;
}
