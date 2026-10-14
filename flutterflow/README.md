# Niyah — custom code per FlutterFlow

Questa cartella contiene il codice da incollare in FlutterFlow (Custom Code → Actions). La logica vera sta in un solo file, `niyah_core.dart`, che è testato fuori da FlutterFlow (`packages/niyah_core`, 43 test). Le altre azioni sono involucri sottili che collegano quella logica al plugin delle notifiche, a SQLite e a Firestore.

Legenda: ⚠️ = da verificare nella tua versione di FlutterFlow prima di andare avanti.

---

## 1. Prima di incollare

### 1.1 Versione di Flutter ⚠️
Il codice è stato verificato con **Flutter 3.47 / Dart 3.13** e con queste versioni dei pacchetti (`flutter analyze` senza errori). Controlla la versione di Flutter del tuo progetto FlutterFlow (Settings → Project Setup → Flutter version) e usa versioni compatibili:

| Pacchetto | Versione verificata | Nota |
|---|---|---|
| `flutter_local_notifications` | `22.3.2` | richiede Flutter ≥ 3.38. Con versioni ≤ 18 la firma di `zonedSchedule`, `initialize` e `cancel` usa parametri posizionali: va adattata |
| `timezone` | `0.11.2` | |
| `flutter_timezone` | `5.1.1` | |
| `sqflite` | `2.4.4+1` | probabilmente già presente se usi l'integrazione SQLite di FlutterFlow |
| `path` | `1.9.1` | |
| `adhan` | `2.0.0+1` | calcolo astronomico, nessuna rete |
| `cloud_firestore` | quella già usata da FlutterFlow | solo per `syncNiyahContent` |

Aggiungi le dipendenze in Custom Code → **Dependencies** (pubspec).

### 1.2 File nativi ⚠️
Servono modifiche ai file nativi. In FlutterFlow: Custom Code → **Configuration Files** (se il tuo piano lo permette). In alternativa: "Download code" e build locale.

**`android/app/src/main/AndroidManifest.xml`**, dentro `<manifest>`:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```
e dentro `<application>`:
```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
```
Il boot receiver ripristina da solo le notifiche dopo un riavvio del telefono o un aggiornamento dell'app.

Non usare `USE_EXACT_ALARM`: Google Play lo riserva alle app sveglia/calendario. Con `SCHEDULE_EXACT_ALARM` l'utente concede il permesso dalla schermata che apre `requestNiyahExactAlarmPermission`; se non lo concede le notifiche arrivano con qualche minuto di tolleranza.

**`android/app/build.gradle`** (richiesto dal plugin delle notifiche):
```gradle
android {
    compileSdk 36
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```

**`ios/Runner/AppDelegate.swift`**, in `application(_:didFinishLaunchingWithOptions:)` prima di `return`:
```swift
UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
```
⚠️ Se usi anche le push di FlutterFlow (Firebase Messaging), controlla che non imposti a sua volta il delegato: deve essercene uno solo.

### 1.3 Database SQLite
1. Costruisci il seed: `python3 seed/build_seed.py --cities cities15000.zip` (vedi `seed/README.md`).
2. Caricalo in FlutterFlow: Settings → **SQLite** → carica `niyah_seed.db`.
3. ⚠️ In `niyah_runtime.dart` la costante `kNiyahDbFileName` deve essere uguale al nome del file con cui FlutterFlow salva il database. Le query di FlutterFlow e queste azioni usano **lo stesso file**.

---

## 2. Come incollare le azioni

FlutterFlow vuole un'azione per file, con il nome della funzione uguale al nome dell'azione. Per ogni file:

1. Custom Code → **+ Add** → Action, con il nome indicato in testa al file (es. `rescheduleAllNotifications`).
2. Imposta parametri e tipo di ritorno come scritto nel commento in testa al file.
3. Incolla il contenuto del file **sotto** la riga `// Begin custom action code` (lascia intatte le righe automatiche sopra).
4. Salva e compila.

**Ordine obbligatorio** (le altre azioni importano le prime due):

| # | File | Azione FlutterFlow | Ritorno |
|---|---|---|---|
| 1 | `niyah_core.dart` | `niyahCoreVersion` | String |
| 2 | `niyah_runtime.dart` | `niyahRuntimeVersion` | String |
| 3 | `init_niyah_notifications.dart` | `initNiyahNotifications(channelNamesJson: JSON)` | String? |
| 4 | `request_niyah_notification_permission.dart` | `requestNiyahNotificationPermission()` | bool |
| 5 | `niyah_notification_permission_status.dart` | `niyahNotificationPermissionStatus()` | String |
| 6 | `request_niyah_exact_alarm_permission.dart` | `requestNiyahExactAlarmPermission()` | bool |
| 7 | `open_niyah_notification_settings.dart` | `openNiyahNotificationSettings()` | bool |
| 8 | `reschedule_all_notifications.dart` | `rescheduleAllNotifications(settingsJson: JSON, stringsJson: JSON, forceAll: bool)` | JSON |
| 9 | `take_pending_notification_tap.dart` | `takePendingNotificationTap()` | String? |
| 10 | `refresh_prayer_times_cache.dart` | `refreshPrayerTimesCache(prayerJson: JSON, timezone: String?, days: int)` | JSON |
| 11 | `sync_niyah_content.dart` | `syncNiyahContent(language: String, force: bool)` | String |
| 12 | `new_reminder_id.dart` | `newReminderId()` | String |

⚠️ Le azioni importano i primi due file con `import '/custom_code/actions/niyah_core.dart' as core;`. Funziona in un progetto Flutter normale (verificato); se l'editor di FlutterFlow rifiuta l'import, la soluzione è incollare `niyah_core.dart` e `niyah_runtime.dart` in fondo a `reschedule_all_notifications.dart` e togliere il prefisso `core.` (meno ordinato, stesso comportamento).

`niyah_core.dart` è una **copia esatta** di `packages/niyah_core/lib/niyah_core.dart`: un test fallisce se le due copie divergono. Modifica sempre quella nel pacchetto, poi copia.

---

## 3. Dove collegarle nel flusso dell'app

| Quando | Cosa chiamare |
|---|---|
| Avvio (On Page Load della prima pagina) | `initNiyahNotifications` → se restituisce un payload, apri il contenuto; poi `rescheduleAllNotifications(forceAll: false)` |
| Home visibile, dopo l'avvio | `syncNiyahContent(lingua, false)`; se `"updated"` → `rescheduleAllNotifications` |
| Ritorno in primo piano | `niyahNotificationPermissionStatus` (aggiorna App State), `takePendingNotificationTap`, `rescheduleAllNotifications` se `lastRescheduleAt` è più vecchio di 6 ore |
| Onboarding passo 4, dopo la spiegazione | `requestNiyahNotificationPermission` |
| Attivazione degli avvisi di preghiera (Android) | `requestNiyahExactAlarmPermission`, poi `rescheduleAllNotifications` |
| Salvataggio/eliminazione/attivazione/pausa di un promemoria | query SQLite, poi `rescheduleAllNotifications` |
| Nuovo promemoria | `newReminderId` per l'id |
| Cambio lingua | `initNiyahNotifications` (nomi dei canali) + `rescheduleAllNotifications` + `syncNiyahContent` |
| Cambio posizione / metodo / madhhab / offset | `refreshPrayerTimesCache(…, 30)` + `rescheduleAllNotifications` |
| "Metti in pausa tutte le notifiche" | imposta `pausedUntil` in App State, poi `rescheduleAllNotifications` |
| Notifiche negate | riga discreta con `openNiyahNotificationSettings` |

Il risultato di `rescheduleAllNotifications` contiene `overBudget` (promemoria che non entrano nel limite di iOS) e `mutedByQuietHours` (promemoria sempre dentro il "Non disturbare"): usali per un avviso discreto nell'editor, non per statistiche.

---

## 4. JSON da passare

### `settingsJson` (costruito dall'App State)
```json
{
  "language": "it",
  "timezone": "Europe/Rome",
  "quietHours": {"enabled": true, "start": "22:30", "end": "07:00", "mode": "skip"},
  "pausedUntil": null,
  "prayer": {"lat": 41.90, "lng": 12.50, "method": "muslim_world_league", "madhab": "shafi",
             "highLatitudeRule": null, "offsets": {"fajr": 0, "dhuhr": 0, "asr": 0, "maghrib": 0, "isha": 0}}
}
```
`timezone` vuoto = fuso del dispositivo. `prayer` senza `lat`/`lng` = posizione non ancora scelta (le notifiche di preghiera restano ferme). `mode`: `skip` salta le notifiche nella fascia, `shift` le sposta alla fine. Metodi validi: `muslim_world_league`, `egyptian`, `karachi`, `umm_al_qura`, `dubai`, `moon_sighting_committee`, `north_america`, `kuwait`, `qatar`, `singapore`, `turkey`, `tehran`. Regole alta latitudine: `middle_of_the_night`, `seventh_of_the_night`, `twilight_angle` (null = automatica).

### `stringsJson` (dalle traduzioni di FlutterFlow, nella lingua attiva)
```json
{
  "prayerNames": {"fajr": "Fajr", "dhuhr": "Dhuhr", "asr": "Asr", "maghrib": "Maghrib", "isha": "Isha"},
  "prayerAtTime": "È l'ora di {prayer}",
  "prayerBefore": "{prayer} tra {minutes} minuti",
  "quranTitle": "Qur'an",
  "hadithTitle": "Hadith",
  "dhikrTitle": "Dhikr",
  "tapToRead": "Tocca per leggere",
  "refreshTitle": "Niyah",
  "refreshBody": "Apri Niyah per continuare a ricevere i promemoria.",
  "privateTitle": "Niyah",
  "privateBody": "Ricorda la tua intenzione"
}
```

### Payload di una notifica (da `takePendingNotificationTap`)
`{"r": "<id promemoria>", "c": "<id contenuto>"}`. Con `c` → apri ContentDetailPage. Con un promemoria privato → mostra il suo testo completo. Con `"r": "_refresh"` → nessuna navigazione.

---

## 5. Cosa NON è ancora qui
- Riprogrammazione periodica in background (WorkManager/BGAppRefresh): richiede di modificare `main.dart` generato da FlutterFlow. Per ora le notifiche si aggiornano a ogni apertura e la notifica di rinfresco invita ad aprire l'app prima che la finestra finisca. Si può aggiungere dopo, con codice scaricato.
- Sincronizzazione dei promemoria con l'account (Fase 14): la logica di unione è in `niyah_core.dart` (`mergeRecords`, testata), manca l'azione che legge e scrive Firestore.
- Iscrizione ai topic FCM per le campagne (Fase 16).
