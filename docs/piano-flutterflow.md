# Niyah — Piano di costruzione in FlutterFlow

> ⚠️ **Superato (14 ottobre 2026).** L'app ora si scrive in Flutter nel repository (`app/`), non più in FlutterFlow. Questo piano resta solo come riferimento storico.

Da seguire in ordine. Ogni fase finisce con un **controllo**: non si passa alla successiva finché non è superato. Riferimenti tra parentesi a [architettura.md](architettura.md).

---

## Prima di iniziare (una volta)

1. **Verifica il piano FlutterFlow**: servono codice personalizzato (custom actions/widgets), dipendenze pub, modifica dei file nativi (AndroidManifest, Info.plist, AppDelegate) e ambienti di sviluppo. Se manca la modifica dei file nativi, prevedi "Download code" + build locale (vedi architettura §12).
2. Crea 3 progetti Firebase: `niyah-dev`, `niyah-staging`, `niyah-prod`. Su ciascuno: Firestore (modalità **produzione**, mai test mode), Authentication (Anonimo, Email/Password, Apple, Google), App Check, Cloud Messaging. Piano Blaze solo sul progetto che usa Cloud Functions (puoi impostare un limite di spesa).
3. In FlutterFlow: crea il progetto **Niyah** (mobile) e collega `niyah-dev`. Configura gli ambienti di sviluppo per staging e prod.
4. Decidi il bundle id definitivo (es. `app.niyah`) prima di registrare le app iOS/Android in Firebase.

**Controllo:** l'app vuota parte su un iPhone e un Android reali in modalità debug.

---

## Fase 2 — Design system

1. **Theme Settings → Colors**: inserisci i token della tabella in architettura §10 (`primary`, `secondary`, `accent`, `background`, `surface`, `textPrimary`, `textSecondary`, `border`). Prevedi anche la modalità scura solo se la vuoi davvero (si può rimandare).
2. **Typography**: carica come font personalizzati Plus Jakarta Sans, IBM Plex Sans Arabic (o Noto Sans Arabic) e Amiri Quran. Definisci gli stili di testo (Display, Title, Body, Label, `QuranText` con Amiri Quran, interlinea ampia).
3. **Languages**: aggiungi it (principale), en, ar, fr.
4. **Componenti** (cartella `components/`): crea nell'ordine `PrimaryButton`, `SecondaryButton`, `IslamicCard`, `SectionHeader`, `ToggleRow`, `SettingRow`, `TimePickerRow`, `DaysSelector`, `EmptyState`, `ErrorState`, `OfflineBanner`, `PermissionExplanationDialog`, `NiyahHeader`, `TopicCard`, `NotificationCard`, `QuranContentCard`, `HadithContentCard`, `DhikrContentCard`. Ogni testo come parametro o come stringa tradotta, mai scritto a mano.
5. Usa sempre padding/allineamenti "start/end" (non left/right) per l'RTL.

**Controllo:** una pagina di prova con tutti i componenti, vista in italiano e in arabo (RTL corretto), su telefono e tablet.

---

## Fase 3 — Dati locali

1. **App State** (persistenti): `selectedLanguage`, `onboardingCompleted`, `notificationsPermission`, `exactAlarmPermission`, `locationPermission`, `selectedCityId`, `selectedLat`, `selectedLng`, `selectedTimezone`, `calculationMethod`, `asrMadhhab`, `highLatitudeRule`, `prayerOffsets` (JSON), `quietHoursEnabled`, `quietStart`, `quietEnd`, `prayerDuringQuiet`, `pausedUntil`, `suggestionsEnabled`, `profileType`, `selectedCategories` (lista), `deviceId`, `lastRescheduleAt`. Non persistenti: `isOffline`, `syncStatus`.
2. **SQLite**: prepara `niyah_seed.db` con lo schema di architettura §3.2 (posso generarti io lo script e il file vuoto con lo schema, più l'elenco città). Caricalo in **Settings → SQLite**.
3. Definisci le query SQLite: `GetReminders`, `GetReminderById`, `UpsertReminder`, `SoftDeleteReminder`, `GetTopics(lang)`, `GetTopicContent(topicId, lang)`, `GetContentById(id, lang)`, `SearchCities(text)`, `GetPrayerCache(date)`, `GetTemplates(lang)`. ⚠️ Se le query di scrittura non sono disponibili, diventano custom action con `sqflite`.
4. Custom action `initLocalDb` (migrazioni di schema) da chiamare all'avvio.

**Controllo:** in modalità aereo, crea un promemoria di prova via query, chiudi e riapri l'app: il record c'è ancora.

---

## Fase 4 — Firestore

1. Crea le collezioni di architettura §4.1 nello **schema Firestore** di FlutterFlow (contentItems con sottocollezione translations, categories, topics, topicContent, notificationTemplates, islamicEvents, campaigns, meta, users con sottocollezioni preferences, location, reminders).
2. **Non** usare le regole generate automaticamente: incolla la bozza di architettura §4.3 nella console Firebase (la Fase 17 la completa e la testa).
3. Attiva App Check (Play Integrity, App Attest; token di debug per lo sviluppo).

**Controllo:** dalla console, un documento `contentItems` con `status: draft` non è leggibile dall'app; con `published` sì.

---

## Fase 5 — Autenticazione

1. **Settings → Authentication**: Firebase, con "Anonymous" abilitato. Pagina iniziale = pagina di avvio (non la pagina di login: l'account è facoltativo).
2. Custom action `ensureAnonymousUser`: se online e nessun utente, `signInAnonymously()`. Mai bloccante.
3. `AccountPage`: crea account con email, Apple, Google **collegando** l'utente anonimo (`linkWithCredential`, custom action) così l'uid resta lo stesso. Accedi / esci.

**Controllo:** offline l'app si apre comunque; online compare un utente anonimo nella console; creando un account l'uid non cambia.

---

## Fase 6 — Home e navigazione

1. Attiva la **Nav Bar** con 4 pagine: `HomePage`, `NotificationsPage`, `StoPerPage`, `SettingsPage`.
2. `HomePage`: `NiyahHeader` + 3 `IslamicCard` che portano ai tab. Niente altro.
3. `OnboardingPage`: PageView con i 7 passi (architettura §2.2). Il passo 4 mostra `PermissionExplanationDialog` **prima** della richiesta di sistema. Il passo 5 non attiva nulla in automatico: propone al massimo 3 promemoria preselezionati, deselezionabili. Alla fine `onboardingCompleted = true`.
4. Logica di avvio nella pagina iniziale: se `onboardingCompleted` → Home, altrimenti Onboarding. Nessuna chiamata di rete prima del primo frame.

**Controllo:** un nuovo utente capisce l'app e arriva alla Home in meno di un minuto.

---

## Fase 7 — Le mie notifiche (interfaccia)

1. `NotificationsPage`: 5 sezioni con `SectionHeader`, ognuna una lista di `NotificationCard` (titolo, orario/frequenza in una riga, interruttore). Menu della card: modifica, duplica, pausa, elimina.
2. `ReminderEditorPage` (parametri: `reminderId` facoltativo, `kind`): titolo, testo, ora, frequenza (giornaliera/settimanale/una volta), giorni, data di inizio, data di fine facoltativa, attivo. Validazione chiara (es. "Scegli almeno un giorno").
3. `StruggleIntroSheet` con i testi di architettura §7 → apre l'editor con `kind = struggle`, `sync_policy = local_only`, anteprima nascosta sul blocco schermo attiva.
4. `ContentReminderPage` e `PrayerNotificationsPage` (5 righe: interruttore + "all'orario / X minuti prima").
5. `EmptyState`: "Non hai ancora creato nessuna notifica personale." + "+ Crea una notifica".
6. Ogni salvataggio: query SQLite → **poi** `rescheduleAll()` (Fase 8). Finché la Fase 8 non c'è, il pulsante salva solo e lo dichiara.

**Controllo:** crea, modifica, duplica, disattiva, elimina; tutto resta dopo il riavvio dell'app.

---

## Fase 8 — Motore notifiche locali (custom code)

1. Dipendenze: `flutter_local_notifications`, `timezone`, `flutter_timezone`, `workmanager`.
2. File nativi Android: permessi `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`; receiver del plugin per notifiche programmate e boot. iOS: delegato delle notifiche in AppDelegate; modalità background "fetch".
3. Custom actions:
   - `initNotifications` (canali Android §6.5, gestione tap → `ContentDetailPage`)
   - `requestNotificationPermission`, `requestExactAlarmPermission`, `readPermissionStatus`
   - `rescheduleAll` (algoritmo ibrido a budget di architettura §6.2–6.4: ripetute + finestra mobile + quiet hours + pausa + notifica di rinfresco)
   - `pauseAll(until)`, `resumeAll()`
4. Chiama `rescheduleAll` nei momenti di architettura §6.3 (avvio, ritorno in primo piano, ogni modifica, cambio lingua/fuso/impostazioni, boot, WorkManager ogni 12 h).

**Controllo:** promemoria giornaliero e settimanale arrivano in modalità aereo, dopo riavvio del telefono, dopo cambio di fuso orario; nessun duplicato modificando un promemoria; con 20 promemoria a contenuto su iOS il conteggio delle notifiche in attesa non supera 64.

---

## Fase 9 — Contenuti Corano / Hadith / Dhikr

1. Popola Firestore (dal pannello admin della Fase 15, oppure inizialmente dalla console) **solo con testi verificati** e licenze controllate.
2. Custom action `syncContent` (architettura §8.1): `meta/contentVersion` → query incrementali → transazione SQLite.
3. `ContentDetailPage` con `QuranContentCard` / `HadithContentCard` / `DhikrContentCard`; fonte in un'area secondaria espandibile.
4. Selezione dei contenuti per le notifiche dentro `rescheduleAll` (filtri + esclusione degli ultimi mostrati).

**Controllo:** con il telefono offline da giorni le notifiche Corano/Hadith arrivano e il tap apre il testo completo.

---

## Fase 10 — Sto per…

1. `StoPerPage`: GridView di `TopicCard` dalla query `GetTopics(lang)`; 2 colonne su telefono, 3–4 su tablet.
2. `StoPerContentPage`: PageView sui risultati di `GetTopicContent(topicId, lang)`, pulsanti precedente / successivo / chiudi. Nessun "mi piace", nessun completamento.

**Controllo:** offline, ogni argomento mostra solo versetti e hadith collegati, nella lingua scelta.

---

## Fase 11 — Orari di preghiera

1. Dipendenza `adhan`. Custom action `computePrayerTimes(days: 30)` che scrive `prayer_cache` (architettura §5).
2. `LocationPickerPage`: pulsante "Usa la mia posizione" (azione nativa, una tantum) + ricerca città su SQLite.
3. `PrayerSettingsPage`: metodo, madhhab Asr, regola alta latitudine, offset per preghiera; ogni modifica → ricalcolo → `rescheduleAll`.

**Controllo:** orari confrontati con il calendario della tua moschea per 2–3 città e metodi diversi; funzionano offline.

---

## Fase 12 — Calendario islamico ed eventi

1. Dipendenza `hijri` per mostrare la data dell'Egira.
2. Sync di `islamicEvents` e `campaigns`; `rescheduleAll` programma in locale i modelli degli eventi attivi e li ferma alla data di fine.
3. Promemoria settimanali (lunedì, giovedì, venerdì, al-Kahf) come modelli disattivati di default, attivabili dall'utente.

**Controllo:** un evento di prova con date passate non genera notifiche; uno in corso sì.

---

## Fase 13 — Impostazioni

`SettingsPage` con `SettingRow`: Lingua · Preghiera · Posizione · Non disturbare · Metti in pausa tutte le notifiche · Privacy · Account · "Non ricevo le notifiche" (aiuto per produttori Android) · Informazioni e fonti.

**Controllo:** ogni riga fa qualcosa di reale; il cambio lingua riprogramma le notifiche nella nuova lingua.

---

## Fase 14 — Sincronizzazione dell'account

Custom action `syncUserData` (architettura §8.2): upload alla creazione dell'account (escluso `struggle`), unione all'accesso su un secondo dispositivo, conflitti per `updatedAt` + `deviceId`, tombstone. Solo letture puntuali, nessun listener.

**Controllo:** stesso account su iPhone e iPad, modifica offline su entrambi, poi online: risultato deterministico, nessun promemoria perso.

---

## Fase 15 — Pannello admin

Nuovo progetto FlutterFlow **web** collegato agli stessi progetti Firebase. Pagine: login, contenuti (lista con filtri per stato e tipo, editor con flusso draft → review → verified → published), traduzioni, categorie, argomenti (con assegnazione dei contenuti), modelli di notifica, eventi, campagne, ruoli (solo superAdmin). Cloud Functions di architettura §4.4.

**Controllo:** un utente normale che apre il pannello non vede e non scrive nulla; un translator non può pubblicare.

---

## Fase 16 — Push remote

Dipendenza `firebase_messaging`; custom action `updateFcmTopics` (lingua + categorie). Cloud Function `sendCampaigns`. Le campagne stagionali, quando possibile, vengono programmate anche in locale (architettura §6.8).

**Controllo:** una campagna di prova in francese arriva solo ai dispositivi in francese.

---

## Fasi 17–22 — Chiusura

- **17 Sicurezza**: regole complete + test con l'emulatore Firebase (utente normale che tenta scritture admin, utente A che legge dati di B, escalation dei ruoli).
- **18 Errori**: messaggi umani per ogni caso di §32 del master prompt; mai errori tecnici a schermo.
- **19 Prestazioni**: profilo di avvio, liste lazy, nessun listener, nessun polling, nessun GPS continuo.
- **20 Test**: la matrice completa di §46 del master prompt (offline, notifiche, preghiera, lingue, dispositivi, account, backend, sicurezza).
- **21 Produzione**: ambiente prod, App Check in modalità enforce, bundle id definitivo, versioning.
- **22 Store**: icona, splash, testi di privacy (iOS privacy manifest, Data Safety su Play), descrizioni dei permessi solo per quelli usati, spiegazione del permesso "Sveglie e promemoria" su Play.
