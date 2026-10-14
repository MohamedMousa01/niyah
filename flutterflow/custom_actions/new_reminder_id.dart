// Niyah — nuovo id per un promemoria creato sul dispositivo (anche offline).
// Nome dell'azione in FlutterFlow: newReminderId
// Restituisce (String): UUID v4.

import '/custom_code/actions/niyah_core.dart' as core;

Future<String> newReminderId() async => core.generateUuidV4();
