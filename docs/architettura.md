# Niyah — Architettura (Fase 1)

Versione 0.3 · 14 ottobre 2026 · Documento di riferimento per tutte le fasi successive.

> Dal 14 ottobre 2026 l'app si scrive in **Flutter** nel repository (`app/`) invece che in FlutterFlow. Le scelte qui sotto restano valide; dove si parla di "custom action" o di editor FlutterFlow, oggi si tratta di normali servizi Dart in `app/lib/`.

Priorità che guidano ogni scelta (dal master prompt, §66): **affidabilità → offline → notifiche corrette → integrità dei contenuti islamici → privacy/sicurezza → prestazioni → semplicità → scalabilità → estetica.**

Legenda: ✅ = deciso · ⚠️ = da verificare nel tuo piano/versione FlutterFlow prima di costruire · 🔒 = requisito di privacy

---

## 1. Visione d'insieme

```
┌────────────────────────────── App mobile (Flutter) ──────────────────────────────┐
│  UI (4 tab)  ──►  App State persistente (impostazioni piccole)                   │
│      │                                                                           │
│      ▼                                                                           │
│  SQLite locale  ◄── fonte di verità sul dispositivo (promemoria, contenuti,      │
│      │              argomenti, città, cache orari)                               │
│      ├──► Motore notifiche (custom code) ──► sistema operativo (iOS / Android)   │
│      ├──► Calcolo orari di preghiera (custom code, 100% offline)                 │
│      └──► Sync (solo se online, in background, incrementale)                     │
└──────────────────────────────────────┬───────────────────────────────────────────┘
                                       │ (opzionale, mai bloccante)
┌──────────────────────────────────────▼───────────────────────────────────────────┐
│  Firebase: Auth (anonima → account) · Firestore · App Check · Cloud Functions    │
│            · FCM (push per argomenti/topic) · Remote Config (facoltativo)        │
└──────────────────────────────────────┬───────────────────────────────────────────┘
                                       │
┌──────────────────────────────────────▼───────────────────────────────────────────┐
│  Pannello Admin (app web separata, stesso backend Firebase)                      │
└──────────────────────────────────────────────────────────────────────────────────┘
```

Tre regole fondanti:

1. **Il dispositivo è la fonte di verità per l'esperienza quotidiana.** Firestore serve a distribuire contenuti nuovi e, se l'utente lo vuole, a fare backup/sync. Nessuna schermata attende Firebase.
2. **La configurazione dei promemoria (database) è separata dalla programmazione nel sistema operativo (implementazione).** Il motore notifiche ricostruisce sempre la programmazione OS partendo dal database (§61).
3. **Nessun contenuto religioso nasce nell'app.** Corano, hadith e dhikr arrivano solo dal database curato, con metadati di fonte e verifica (§38, §48).

---

## 2. Schermate e navigazione

### 2.1 Barra di navigazione inferiore (4 voci, §35)

| Tab | Pagina | Scopo |
|---|---|---|
| Home | `HomePage` | Identità, messaggio centrale, 3 accessi rapidi |
| Le mie notifiche | `NotificationsPage` | Il cuore dell'app |
| Sto per… | `StoPerPage` | Griglia argomenti |
| Impostazioni | `SettingsPage` | Lingua, preghiera, quiet hours, pausa, account, privacy |

### 2.2 Mappa completa delle pagine

```
Avvio
 └─ onboarding non completato? ─► OnboardingPage (PageView, 7 passi, tutti saltabili tranne lingua)
                                   1 Benvenuto  2 Lingua  3 Posizione (opz.)  4 Notifiche
                                   5 Interessi  6 Profilo (opz.)  7 Suggerimenti (opz.)
 └─ altrimenti ─► NavBar
     ├─ HomePage
     ├─ NotificationsPage
     │    ├─ sezioni: Suggeriti da Niyah · I miei promemoria · Contenuti islamici
     │    │           · Preghiera · Settimanali e stagionali
     │    ├─ ReminderEditorPage (crea/modifica/duplica; usata da TUTTI i tipi tranne preghiera)
     │    ├─ StruggleIntroSheet ─► ReminderEditorPage(kind = struggle)      🔒
     │    ├─ ContentReminderPage (Corano / Hadith / Dhikr: frequenza, giorni, fascia oraria)
     │    └─ PrayerNotificationsPage (5 righe indipendenti: on/off + offset)
     ├─ StoPerPage ─► StoPerContentPage (pager: precedente / successivo / chiudi)
     └─ SettingsPage
          ├─ LanguagePage
          ├─ PrayerSettingsPage (metodo, madhhab Asr, alta latitudine, offset)
          │    └─ LocationPickerPage (GPS una tantum oppure ricerca città offline)
          ├─ QuietHoursSheet
          ├─ PauseSheet (1 ora / oggi / fino a domani / personalizzata / riprendi)
          ├─ PrivacyPage (anteprime sul blocco schermo, sync dei promemoria personali)
          ├─ AccountPage (accedi / crea account / esci)
          └─ AboutPage (fonti dei contenuti, licenze, versione)

ContentDetailPage ◄── aperta dal tap su una notifica Corano/Hadith/Dhikr (payload = contentId)
```

Nessuna sezione "Prossimo promemoria", nessun conteggio, nessuno storico (§1, §7).

### 2.3 Home (quasi vuota, §7)

1. `NiyahHeader`: "Niyah", Bismillah piccola e discreta, frase localizzata "Rinnova la tua intenzione."
2. Card "Le mie notifiche" → tab 2
3. Card "Sto per…" → tab 3
4. Card "Impostazioni" → tab 4
5. (Facoltativo) una riga sottile con la prossima preghiera del giorno: solo nome e orario, niente countdown. Disattivabile. Se dubbi, si omette.

---

## 3. Dati locali (offline-first)

### 3.1 Scelta tecnologica ✅

| Dato | Dove | Perché |
|---|---|---|
| Impostazioni piccole (lingua, onboarding, permessi, metodo di calcolo, quiet hours, pausa, deviceId) | **App State persistente** di FlutterFlow (usa `shared_preferences`) | Nativo, immediato all'avvio, zero codice |
| Promemoria, contenuti, argomenti, città, cache orari, metadati di sync | **SQLite** (`sqflite`) | Relazionale, veloce, regge migliaia di record, può essere **pre-popolato e incluso nell'app** |

⚠️ FlutterFlow ha un'integrazione SQLite nativa (query di lettura e di aggiornamento definite nell'editor, file `.db` caricabile come asset iniziale). Verifica che nel tuo piano supporti anche le query di scrittura. Se no, tutte le scritture passano da custom action con `sqflite` (stesso file DB): l'architettura non cambia.

Scartati: **Isar/Hive** (manutenzione incerta, poco adatti a relazioni argomento↔contenuto); **cache offline di Firestore come database principale** (non garantisce contenuti inclusi al primo avvio né persistenza controllata, e lega ogni lettura a Firebase).

### 3.2 Schema SQLite (v1)

```sql
-- Promemoria: UNA tabella per tutti i tipi
reminders(
  id TEXT PRIMARY KEY,            -- UUID generato sul dispositivo
  kind TEXT,                      -- template | personal | struggle | content | prayer | event
  template_id TEXT NULL,          -- origine se creato da un modello
  category_id TEXT NULL,
  title TEXT NULL, body TEXT NULL,-- NULL per i promemoria a contenuto (testo scelto al momento)
  content_type TEXT NULL,         -- quran | hadith | dhikr (solo kind = content)
  schedule_type TEXT,             -- daily | weekly | once | window | prayer
  time TEXT NULL,                 -- 'HH:mm' ora locale
  window_start TEXT NULL, window_end TEXT NULL,  -- "orario approssimativo" per i contenuti
  times_per_day INTEGER DEFAULT 1,
  days_mask INTEGER DEFAULT 127,  -- bit 0 = lunedì ... bit 6 = domenica
  prayer TEXT NULL, offset_min INTEGER NULL,      -- solo kind = prayer
  start_date TEXT, end_date TEXT NULL,
  enabled INTEGER, paused_until TEXT NULL,
  respects_quiet_hours INTEGER DEFAULT 1,
  channel TEXT,                   -- id canale Android (§6.5)
  sync_policy TEXT,               -- local_only | cloud   (struggle = local_only di default 🔒)
  created_at TEXT, updated_at TEXT, deleted INTEGER DEFAULT 0  -- tombstone per la sync
)

-- (v0.2) Nessuna tabella di mappatura verso l'OS: gli id delle notifiche sono
-- hash stabili di tutto ciò che è visibile, e il motore li confronta con le
-- notifiche in attesa restituite dal sistema. Schema definitivo: seed/schema.sql

categories(id, parent_id, icon, sort, active, updated_at)
category_i18n(category_id, lang, name)

content_items(id, type, arabic_text, surah INTEGER, ayah_from INTEGER, ayah_to INTEGER,
              collection TEXT, hadith_number TEXT, grade TEXT, source_ref TEXT,
              status TEXT, updated_at)               -- solo status = published arriva sul dispositivo
content_i18n(content_id, lang, text, translator, translation_source, updated_at)
content_categories(content_id, category_id)

topics(id, icon, sort, active, updated_at)
topic_i18n(topic_id, lang, name)
topic_content(topic_id, content_id, sort)

templates(id, category_id, content_type, default_schedule_json, editable, seasonal, active, updated_at)
template_i18n(template_id, lang, title, body)

events(id, type, start_date, end_date, hijri_json, active, updated_at)
event_i18n(event_id, lang, name, description)
event_templates(event_id, template_id)

cities(id, name, ascii_name, country, lat, lng, timezone)   -- incluse nell'app (§5.3)
prayer_cache(date TEXT, fajr, sunrise, dhuhr, asr, maghrib, isha, settings_hash)
recent_content(content_id, shown_at)   -- solo per evitare ripetizioni ravvicinate, max ~50 righe
sync_meta(key, value)                  -- lastSync per collezione/lingua, versione schema
```

Note:

- I **testi tradotti stanno in tabelle `_i18n` separate** (§73 A/B). Il testo arabo del Corano sta una sola volta in `content_items`.
- `recent_content` non è una statistica: si tronca automaticamente e non viene mai sincronizzata né mostrata.
- Migrazioni di schema: `sync_meta.schema_version` + script di migrazione in una custom action eseguita all'avvio.

### 3.3 Contenuti inclusi nell'app (§43)

Il file `niyah_seed.db` viene caricato in FlutterFlow come database iniziale e contiene:
argomenti di "Sto per…", categorie, modelli di notifica nelle 4 lingue, un set iniziale curato di versetti e hadith **già verificati da te o da un revisore qualificato**, i promemoria settimanali essenziali (lunedì, giovedì, venerdì, al-Kahf), le città.

Il seed viene generato da uno script a partire da un'esportazione dei contenuti `published` di Firestore, così app e backend partono allineati e ogni record porta il suo `updated_at`.

---

## 4. Backend Firebase / Firestore

### 4.1 Collezioni

Ho seguito i nomi del master prompt dove possibile; le differenze sono motivate.

```
# ── Contenuti pubblici (lettura: chiunque abbia App Check valido; scrittura: solo admin)
contentItems/{id}            type, arabicText, surah, ayahFrom, ayahTo, collection, hadithNumber,
                             grade, sourceRef, status(draft|review|verified|published|archived),
                             verifiedBy, verifiedAt, categoryIds[], updatedAt
contentItems/{id}/translations/{lang}
                             text, translator, translationSource, status, updatedAt
categories/{id}              parentId, icon, order, active, names{it,en,ar,fr}, updatedAt
topics/{id}                  icon, order, active, names{…}, updatedAt
topicContent/{topicId_contentId}   topicId, contentId, order, updatedAt
notificationTemplates/{id}   categoryId, contentType, defaultSchedule{}, editableByUser,
                             seasonal, active, i18n{lang:{title,body}}, updatedAt
islamicEvents/{id}           type, startDate, endDate, hijri{}, active, contentRefs[],
                             notificationTemplateRefs[], languages[], i18n{}, updatedAt
campaigns/{id}               name, description, startAt, endAt, active, targetLanguages[],
                             targetCategories[], notificationTemplateRefs[], fcmTopics[], updatedAt
meta/contentVersion          version{it,en,ar,fr}, updatedAt     # 1 sola lettura all'avvio

# ── Dati utente privati (solo il proprietario)
users/{uid}                  language, accountType(anonymous|email|apple|google),
                             suggestionsEnabled, onboardingCompleted, createdAt, updatedAt
users/{uid}/preferences/main selectedCategories[], profileType, prayerSettings{}, quietHours{},
                             updatedAt
users/{uid}/location/main    city, country, timezone, latRounded, lngRounded, source, updatedAt
users/{uid}/reminders/{id}   specchio della tabella locale `reminders` (MAI kind = struggle
                             salvo consenso esplicito, §7)

# ── Amministrazione
tombstones/{autoId}          collection, docId, removedAt (+ topicId, contentId)  # scritte dalle Functions:
                             il client non vede i documenti non pubblicati, così sa cosa rimuovere
adminRoles/{uid}             role(superAdmin|contentAdmin|notificationAdmin|translator)  # solo audit/UI
adminAudit/{autoId}          chi, cosa, quando (scritto da Cloud Function)
```

Differenze rispetto al prompt e perché:

- `userPreferences`, `userLocations`, `userNotifications` diventano **sottocollezioni di `users/{uid}`**: le regole di sicurezza diventano una riga sola ("solo il proprietario"), e cancellare un account cancella tutto.
- Le traduzioni dei contenuti sono una **sottocollezione** (`translations/{lang}`), così un traduttore può avere permessi solo lì.
- `deviceTokens` **non serve nella v1**: le campagne usano i **topic FCM** (`lang_it`, `cat_quran`, `campaign_ramadan`…). Il dispositivo si iscrive ai topic in locale e nessun token personale viene salvato nel database. Se un giorno serve il targeting per singolo utente, si aggiunge `deviceTokens` come da prompt, con pulizia dei token vecchi tramite Cloud Function.
- La posizione è arrotondata (2 decimali ≈ 1 km), sufficiente per gli orari di preghiera.

### 4.2 Ruoli admin ✅

I ruoli stanno nei **custom claims** di Firebase Auth (`request.auth.token.role`), assegnati solo da una Cloud Function chiamabile esclusivamente da un `superAdmin`. Il client non può mai scriverli. `adminRoles/{uid}` è solo una copia leggibile per il pannello.

| Ruolo | Può |
|---|---|
| superAdmin | tutto, inclusa la gestione dei ruoli |
| contentAdmin | contenuti, categorie, argomenti, eventi; portare un contenuto a `verified`/`published` |
| notificationAdmin | modelli di notifica, campagne |
| translator | solo `contentItems/*/translations/*` e i campi `i18n`, mai lo `status` |

### 4.3 Bozza delle regole Firestore (Fase 17 le completa e le testa)

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function signedIn()   { return request.auth != null; }
    function role()       { return signedIn() ? request.auth.token.get('role', '') : ''; }
    function isAdmin(rs)  { return role() in rs; }
    function owner(uid)   { return signedIn() && request.auth.uid == uid; }

    match /contentItems/{id} {
      allow read:  if resource.data.status == 'published' || isAdmin(['superAdmin','contentAdmin','translator']);
      allow write: if isAdmin(['superAdmin','contentAdmin']);
      match /translations/{lang} {
        allow read:  if true;   // la query client filtra per status == 'published'
        allow write: if isAdmin(['superAdmin','contentAdmin','translator']);
      }
    }
    match /{coll}/{id} {
      // categories, topics, topicContent, notificationTemplates, islamicEvents, campaigns, meta
      allow read:  if coll in ['categories','topics','topicContent','notificationTemplates',
                               'islamicEvents','campaigns','meta'];
      allow write: if coll in ['categories','topics','topicContent','islamicEvents']
                        && isAdmin(['superAdmin','contentAdmin'])
                   || coll in ['notificationTemplates','campaigns']
                        && isAdmin(['superAdmin','notificationAdmin']);
    }
    match /users/{uid} {
      allow read, write: if owner(uid);
      match /{sub=**} { allow read, write: if owner(uid); }
    }
    match /adminRoles/{uid} { allow read: if owner(uid) || isAdmin(['superAdmin']); allow write: if false; }
    match /adminAudit/{id}  { allow read: if isAdmin(['superAdmin']);              allow write: if false; }
  }
}
```

Più **App Check** obbligatorio su Firestore e Functions (Play Integrity / App Attest), così le letture pubbliche vengono solo dalla tua app.

### 4.4 Cloud Functions ✅ (codice in `firebase/functions/`)

| Funzione | Trigger | Cosa fa |
|---|---|---|
| `onContentItemWrite` | scrittura su `contentItems/{id}` | se il contenuto era o è pubblicato: incrementa `meta/contentVersion.version.<lingua>` (tutte e 4); se non è più pubblicato: scrive una tombstone. Un contenuto `verified`/`published` senza `verifiedBy` e `verifiedAt` torna in `review` (con voce in `adminAudit`). Se viene archiviato o cancellato, archivia le sue traduzioni pubblicate |
| `onTranslationWrite` | scrittura su `contentItems/{id}/translations/{lang}` | se il contenuto è pubblicato e cambia un campo visibile della traduzione, aggiorna `updatedAt` del contenuto (così la sync lo riscarica) |
| `onCategoryWrite`, `onTopicWrite`, `onTopicContentWrite`, `onNotificationTemplateWrite`, `onIslamicEventWrite` | scrittura sulla collezione | come sopra con `active == true`; la tombstone di `topicContent` porta anche `topicId` e `contentId` |
| `setAdminRole` | callable (solo superAdmin) | `{uid, role}` (`role` = ruolo o `null`): imposta il custom claim, aggiorna la copia `adminRoles/{uid}`, scrive `adminAudit`; se un ruolo esistente viene tolto o cambiato, revoca le sessioni. Un superAdmin non può togliersi il ruolo da solo |
| `sendCampaigns` | schedulata (es. ogni 15 min) | da fare (Fase 16): push FCM ai topic delle campagne attive |
| `exportSeed` | manuale | da fare: esporta i contenuti `published` per generare `niyah_seed.db` |

Il primo superAdmin di ogni ambiente si assegna una volta sola con `firebase/functions/scripts/first-superadmin.js` dal proprio computer.

### 4.5 Ambienti (§47)

Tre progetti Firebase: `niyah-dev`, `niyah-staging`, `niyah-prod`. Identificativi app: `app.niyah.dev`, `app.niyah.staging`, `app.niyah` (⚠️ scegli il dominio definitivo prima della prima pubblicazione: non si può cambiare dopo). In FlutterFlow si usano gli **ambienti di sviluppo** (Firebase per ambiente + variabili d'ambiente).

---

## 5. Orari di preghiera (offline)

### 5.1 Libreria ✅
`adhan` (porting Dart della libreria Adhan, calcolo astronomico locale). Supporta: metodi (Muslim World League, ISNA, Egitto, Umm al-Qura, Karachi, Dubai, Qatar, Kuwait, Moonsighting Committee, Singapore, Turchia, Tehran…), madhhab Asr (Shafi'i/Hanbali/Maliki vs Hanafi), regole per alta latitudine, aggiustamenti manuali in minuti.

### 5.2 Flusso
1. Posizione: GPS **una sola volta** su richiesta (azione nativa FlutterFlow "Get current location") oppure città scelta a mano.
2. Fuso orario: dalla città (tabella `cities`) o dal dispositivo con `flutter_timezone`.
3. Calcolo di **30 giorni** in `prayer_cache`, con `settings_hash` (lat, lng, metodo, madhhab, regola, offset, timezone). L'ora legale è gestita convertendo gli istanti UTC nel fuso IANA con il pacchetto `timezone`.
4. Ricalcolo solo se: cambia la data oltre la cache, la posizione, le impostazioni o il fuso. Mai in continuo.

Default proposto: metodo scelto dal paese della città (es. Italia/Francia → Muslim World League, Arabia Saudita → Umm al-Qura, Nord America → ISNA), madhhab Asr standard, regola alta latitudine automatica sopra 48°. Sempre modificabile e spiegato in una riga: "Esistono metodi diversi; scegli quello della tua moschea."

### 5.3 Città offline
Si include un elenco di città (es. dataset GeoNames "cities15000", circa 25.000 città con coordinate e fuso, licenza CC-BY: va citata in AboutPage). Ricerca per nome direttamente in SQLite, nessuna rete necessaria.

---

## 6. Motore notifiche (il punto più delicato)

### 6.1 Limiti reali dei sistemi operativi (nessuna finzione, §11, §76)

| Limite | iOS | Android |
|---|---|---|
| Notifiche locali in attesa | **64 per app**; le eccedenti vengono scartate in silenzio | nessun tetto ufficiale, ma alcuni produttori (es. Samsung) bloccano oltre **500 allarmi** |
| Orario esatto | sì | da Android 12 serve il permesso "Sveglie e promemoria" (`SCHEDULE_EXACT_ALARM`); da Android 14 è **negato di default**. Senza, le notifiche possono ritardare di alcuni minuti |
| Riavvio del telefono | il sistema conserva le notifiche | le programmazioni si perdono: vanno ripristinate al boot (il plugin lo fa con un receiver) |
| Lavoro in background | non garantito (BGAppRefresh decide il sistema) | WorkManager, minimo ogni 15 min, abbastanza affidabile |
| Risparmio energetico produttori (Xiaomi, Huawei, Oppo…) | — | possono bloccare notifiche: serve una pagina d'aiuto |

### 6.2 Strategia: "ibrida a budget" ✅

Ogni promemoria nel DB viene tradotto in programmazioni OS in uno di due modi:

**A. Ripetute nell'OS (1 slot, non scadono mai)**
Per promemoria a **testo fisso** con orario fisso: giornalieri → 1 notifica ripetuta (`matchDateTimeComponents: time`); settimanali → 1 per giorno selezionato (`dayOfWeekAndTime`). Funzionano anche se l'app non viene aperta per mesi. È il caso di quasi tutti i promemoria personali, di "Rinnova la tua intenzione", del venerdì, di al-Kahf.

**B. Singole in una finestra mobile (rolling window)**
Per ciò che cambia ogni volta:
- orari di preghiera (cambiano ogni giorno);
- notifiche Corano/Hadith/Dhikr (contenuto diverso ogni volta);
- promemoria con data di fine vicina, in pausa o che cadono nelle quiet hours (servono eccezioni);
- eventi stagionali (Ramadan, Dhul-Hijjah…).

**Allocazione del budget** (iOS: 64 − 4 di riserva = 60; Android: 200 per stare lontani dai limiti):
1. prima tutte le ripetute (A);
2. poi le singole (B) in ordine cronologico, con priorità a parità di orario: preghiera > promemoria personali > niyyah/buone azioni > contenuti;
3. la finestra si ferma quando il budget finisce (tipicamente 5–10 giorni).

**Notifica di "rinfresco".** Se la finestra B finisce entro 3 giorni e l'app non viene riaperta, l'ultimo slot diventa una notifica gentile: "Apri Niyah per continuare a ricevere gli orari di preghiera." Solo se ci sono promemoria di tipo B attivi. È l'unico modo onesto di gestire il limite iOS senza server.

### 6.3 Quando si riprogramma (funzione unica e idempotente `rescheduleAll()`)
- avvio dell'app e ritorno in primo piano (se sono passate più di 6 ore dall'ultima volta);
- creazione / modifica / eliminazione / attivazione / pausa di un promemoria;
- cambio lingua, posizione, fuso, impostazioni preghiera, quiet hours;
- riavvio del telefono e aggiornamento dell'app (Android: receiver `BOOT_COMPLETED` e `MY_PACKAGE_REPLACED`);
- background: WorkManager ogni 12 ore su Android, BGAppRefresh su iOS (best effort);
- cambio di fuso orario rilevato (`TIMEZONE_CHANGED` su Android; confronto all'apertura su iOS).

`rescheduleAll()` calcola l'insieme desiderato di notifiche, lo confronta con le notifiche in attesa nell'OS (`pendingNotificationRequests`), cancella ciò che non serve più e programma solo ciò che manca. Così non nascono duplicati (§60).

Nota v0.2: la riprogrammazione periodica in background (WorkManager / BGAppRefresh) è rimandata perché richiede di modificare il `main.dart` generato da FlutterFlow. Nel frattempo valgono la riprogrammazione a ogni apertura e la notifica di rinfresco.

### 6.4 ID stabili (§60)
`os_id` = hash a 31 bit di `reminderId + data/ora dell'occorrenza` (per le ripetute: `reminderId + giorno della settimana`). Modificare un promemoria significa: cancellare i suoi `os_id`, poi riprogrammare.

### 6.5 Canali Android (§28) — 8 canali
`prayer` · `niyyah` · `quran` · `hadith` · `dhikr` · `good_deeds` · `islamic_events` · `personal`. Nomi localizzati; al cambio lingua si ricreano con lo stesso id (Android consente di aggiornare il nome). I promemoria "peccato che sto combattendo" usano il canale `personal`: nessun canale dedicato che ne riveli l'esistenza nelle impostazioni di sistema. 🔒

### 6.6 Quiet hours, pausa, contenuti
- **Quiet hours**: applicate al momento della programmazione. Un'occorrenza che cade nella fascia viene saltata (default) o spostata alla fine della fascia (opzione per promemoria). Le preghiere seguono un interruttore dedicato ("Avvisi di preghiera anche durante il riposo", default: sì per Fajr se attivo). Un promemoria ripetuto il cui orario cade sempre nelle quiet hours viene segnalato nell'editor.
- **Pausa globale**: salva `pausedUntil` nell'App State e cancella tutto dall'OS. Poi programma, a partire da `pausedUntil`, le singole (B) e anche le ripetute (A) **convertite temporaneamente in singole**, così i promemoria ripartono da soli alla fine della pausa anche se l'app non viene aperta. Alla prima apertura dopo la pausa, le ripetute tornano nella forma A. Nessuna configurazione viene cancellata (§31, §62).
- **Contenuti Corano/Hadith/Dhikr**: per ogni occorrenza si sceglie un contenuto **al momento della programmazione** filtrando per lingua, `published`, categoria, preferenze, campagna attiva; si escludono gli ultimi ~30 mostrati (`recent_content`). Il testo della notifica è un estratto breve; il tap apre `ContentDetailPage` con testo completo e riferimento. Se nella lingua scelta non c'è una traduzione verificata, quel contenuto non viene usato (nessun fallback silenzioso, §24).

### 6.7 Permessi (§27)
- iOS: richiesta di autorizzazione solo dopo la schermata di spiegazione dell'onboarding. Se negata: l'app funziona, e "Le mie notifiche" mostra una riga discreta "Le notifiche sono disattivate · Apri impostazioni".
- Android 13+: `POST_NOTIFICATIONS`, stessa logica. Permesso orario esatto: chiesto solo se l'utente attiva la preghiera, con spiegazione; se negato si usa la modalità inesatta (`inexactAllowWhileIdle`) e lo si dice in una riga.
- Lo stato dei permessi si rilegge a ogni ritorno in primo piano (può essere revocato dalle impostazioni). Mai più di una richiesta di sistema per permesso; poi solo il link alle impostazioni.

### 6.8 Push remote (§12, §72)
Solo per contenuti nuovi, campagne e annunci. Mai per i promemoria dell'utente. Implementazione con **topic FCM** (§4.1): il dispositivo si iscrive a `lang_{lingua}` e `cat_{categoria}` per le categorie scelte; i topic si aggiornano quando cambiano lingua o interessi. Le push di una campagna, per chi ha già il contenuto in locale, possono anche essere programmate **in locale** al momento della sync (così funzionano offline): è la scelta di default per le campagne stagionali, mentre la push remota resta per gli annunci.

---

## 7. Privacy dei promemoria "peccato che sto combattendo" 🔒

| Misura | Dettaglio |
|---|---|
| Solo locale per default | `kind = struggle` → `sync_policy = local_only`. Nella v1 **non esiste** un'opzione per sincronizzarli. |
| Mai verso terzi | esclusi da analytics (non ce ne sono), da log di errore, da Firestore, da qualsiasi IA |
| Invisibili agli admin | non arrivano mai sul backend, quindi nessun pannello può mostrarli. Nota onesta: qualunque dato salvato su Firestore è tecnicamente leggibile dal proprietario del progetto Firebase dalla console; per questo la v1 non li carica affatto. |
| Blocco schermo | opzione per promemoria, **attiva di default** per `struggle`: la notifica mostra solo "Niyah · Ricorda la tua intenzione" sul blocco schermo (Android `visibility: private` con versione pubblica; iOS: testo generico nel titolo e corpo completo solo dopo lo sblocco tramite contenuto dell'app) |
| Backup del sistema | Android Auto Backup: escludere il DB dei promemoria `struggle` con `dataExtractionRules`, oppure tenerli in un file SQLite separato escluso dal backup. iOS: file marcato "exclude from backup". |
| Sync futura | se un giorno si offre, solo con scelta esplicita per singolo promemoria e **cifratura lato client** con chiave dell'utente (il server vede solo dati cifrati). |
| Linguaggio | testi di supporto mai colpevolizzanti; l'app non classifica né giudica il comportamento (§10 personale). |

Introduzione nell'interfaccia: "Stai combattendo con un peccato o un'abitudine che vuoi lasciare per Allah?" → "Crea un promemoria personale." Più una riga: "Resta solo su questo telefono."

---

## 8. Sincronizzazione

### 8.1 Contenuti (pubblici, anche senza account)
1. All'avvio, solo se online e dopo che la Home è visibile: 1 lettura di `meta/contentVersion`.
2. Se la versione della lingua attiva > locale: query `where('updatedAt', '>', lastSync)` sulle collezioni di contenuto, filtrate per `status == 'published'` (o `active`), paginate a 100.
3. Scrittura in SQLite in una transazione, aggiornamento di `lastSync`.
4. Prima dei documenti cambiati si leggono le `tombstones` nuove e si rimuovono in locale i record ritirati (per questo non si cancellano mai fisicamente su Firestore: si cambia lo stato). Prima le tombstone, poi i documenti: un contenuto ritirato e poi ripubblicato torna correttamente.
5. Errore → silenzio, nuovo tentativo alla prossima apertura o al prossimo job in background, con backoff (1h, 6h, 24h).

Costo tipico: 1 lettura al giorno quando non c'è nulla di nuovo.

### 8.2 Dati utente (solo con account)
- **Identità**: al primo avvio online si crea in silenzio un utente **anonimo** Firebase (serve ad App Check e a dare un uid). Nessun dato utente viene caricato finché l'utente non crea un account.
- **Creazione account**: `linkWithCredential` (email, Apple, Google) sull'utente anonimo → stesso uid, nessuna migrazione da fare lato server; poi si caricano i dati locali (eccetto `struggle`).
- **Accesso su un secondo dispositivo**: si scaricano i dati cloud e si **uniscono** a quelli locali (mai sovrascrittura cieca, §42).
- **Conflitti**: per record (non per campo), vince l'`updatedAt` più recente; a parità, vince il `deviceId` lessicograficamente maggiore (deterministico). Le eliminazioni viaggiano come tombstone (`deleted = 1`) per 30 giorni.
- **Logout**: i dati restano sul dispositivo (l'utente sceglie se cancellarli).
- Ascoltatori in tempo reale: **nessuno** nell'app mobile. Solo letture puntuali.

---

## 9. Lingue e RTL

- Interfaccia: sistema di **Languages** di FlutterFlow (it, en, ar, fr), nessuna stringa scritta direttamente nei widget. L'arabo attiva automaticamente il layout RTL; usare padding/allineamenti "start/end" e icone direzionali specchiate.
- Testi delle notifiche: generati al momento della programmazione nella lingua salvata; al cambio lingua → `rescheduleAll()`.
- Contenuti: lingua dei contenuti = lingua dell'app (default). Mai un contenuto in un'altra lingua senza scelta dell'utente.
- **Politica di fallback controllata**: stringhe di interfaccia mancanti → inglese (solo durante lo sviluppo, il test le deve trovare tutte); contenuti religiosi mancanti → il contenuto non viene mostrato in quella lingua.
- Font: latino **Plus Jakarta Sans** (o Inter); arabo interfaccia **IBM Plex Sans Arabic** o **Noto Sans Arabic**; testo coranico **Amiri Quran** (licenza OFL). Tutti inclusi nell'app, non scaricati.

---

## 10. Design system (anticipo della Fase 2)

Palette proposta:

| Token | Chiaro | Uso |
|---|---|---|
| `background` | `#FAF8F3` (crema caldo) | sfondo pagine |
| `surface` | `#FFFFFF` | card |
| `primary` | `#3E7C6B` (verde salvia profondo) | azioni principali |
| `secondary` | `#A9C9B8` (salvia chiaro) | toggle attivi, dettagli |
| `accent` | `#7FC2C0` (acqua) | evidenze leggere |
| `textPrimary` | `#2E3532` | testo |
| `textSecondary` | `#6B736F` | testo secondario |
| `border` | `#E6E2D8` | bordi sottili |

Componenti riutilizzabili (§49): `NiyahHeader`, `IslamicCard`, `NotificationCard`, `TopicCard`, `PrimaryButton`, `SecondaryButton`, `ToggleRow`, `SettingRow`, `QuranContentCard`, `HadithContentCard`, `DhikrContentCard`, `EmptyState`, `ErrorState`, `OfflineBanner`, `PermissionExplanationDialog`, `SectionHeader`, `TimePickerRow`, `DaysSelector`.

Layout adattivo: contenuto in un contenitore con larghezza massima 600 px su tablet; "Sto per…" a 2 colonne su telefono, 3–4 su tablet; "Le mie notifiche" su iPad in orizzontale può diventare elenco + editor affiancati.

Animazioni: solo transizioni standard e fade brevi; rispettare "riduci movimento".

---

## 11. Avvio (§44)

1. Apertura SQLite (seed copiato al primo avvio) e lettura App State → istantanei
2. Lingua e preferenze → istantanee
3. Se `onboardingCompleted == false` → Onboarding, altrimenti Home **subito**
4. Dopo il primo frame, in background: inizializzazione notifiche + `rescheduleAll()` se necessario, ricalcolo orari se serve, init Firebase, utente anonimo, sync contenuti

Nessuna attesa di Firebase nello splash.

---

## 12. Pacchetti per il codice personalizzato (§68)

| Pacchetto | Perché serve | Alternativa nativa FlutterFlow? |
|---|---|---|
| `flutter_local_notifications` | programmazione locale, ripetute, canali, boot receiver, permesso orario esatto | No (FlutterFlow ha solo push remote) |
| `timezone` + `flutter_timezone` | orari nel fuso corretto, ora legale | No |
| `adhan` | calcolo orari di preghiera offline | No |
| `sqflite` | DB locale (già usato dall'integrazione SQLite di FlutterFlow) | Parziale ⚠️ |
| `workmanager` | riprogrammazione periodica in background (Android; iOS best effort) | No |
| `hijri` | data dell'Egira per mostrare e calcolare eventi; le date ufficiali degli eventi restano comunque quelle impostate dall'admin (l'avvistamento lunare varia per paese) | No |
| `connectivity_plus` | sapere se ha senso tentare una sync (non per mostrare allarmi) | Verificare se già presente |
| `uuid` | id dei promemoria creati offline | — |
| `firebase_messaging` | iscrizione ai topic FCM | FlutterFlow gestisce le push ma lega i token agli utenti autenticati e non ai topic ⚠️ |

Già nativi in FlutterFlow, da **non** reimplementare: posizione una tantum, autenticazione Firebase (email, Apple, Google), Firestore, lingue, App State persistente, apertura impostazioni dell'app.

⚠️ `flutter_local_notifications` e `workmanager` richiedono modifiche ai file nativi (AndroidManifest: permessi e receiver; iOS AppDelegate: delegato delle notifiche). Verifica che il tuo piano FlutterFlow permetta di modificare i file di configurazione nativi; altrimenti servono "scarica codice" e build locale, ed è lì che un repository GitHub diventa utile.

---

## 13. Pannello admin

Progetto **FlutterFlow web separato** (ottimizzato per desktop/tablet), stesso Firebase. Motivi: nessun codice admin dentro l'app pubblicata, app mobile più leggera, permessi più semplici da verificare.

Flusso dei contenuti (§48): `draft → review → verified → published` (+ `archived`). Le regole rifiutano `verified`/`published` senza `verifiedBy` e `verifiedAt`; la Cloud Function `onContentItemWrite` riporta comunque in `review` ciò che arriva dalla console o dall'Admin SDK. Ogni hadith richiede raccolta, numero, grado, fonte; ogni versetto richiede sura, ayat, testo arabo, traduzione con traduttore e lingua.

**Fonti dei testi (da verificare con attenzione, non decise qui):** per il testo arabo del Corano esistono edizioni digitali verificate con licenze che impongono attribuzione e divieto di modifica; anche le traduzioni in italiano, inglese e francese hanno licenze proprie. Prima di caricare qualunque contenuto va verificato che la licenza ne permetta l'uso in un'app gratuita. Io non genero né riassumo testi coranici o hadith: il pannello serve proprio a farli inserire e verificare da persone qualificate.

---

## 14. Rischi e decisioni aperte

| # | Tema | Proposta di default |
|---|---|---|
| 1 | Limite 64 notifiche iOS con molti promemoria a contenuto variabile | strategia ibrida §6.2 + notifica di rinfresco; avviso nell'editor solo se il budget è davvero esaurito |
| 2 | Android 14 nega l'orario esatto di default | chiedere il permesso solo per la preghiera, altrimenti inesatto |
| 3 | Produttori Android aggressivi sulla batteria | pagina di aiuto "Non ricevo le notifiche" in Impostazioni |
| 4 | Date di Ramadan/Eid diverse per paese | date gestite dall'admin per evento, eventualmente per regione in futuro |
| 5 | Piano FlutterFlow e accesso ai file nativi | verificare prima della Fase 8 ⚠️ |
| 6 | Licenze di testi e traduzioni | verificare prima della Fase 9 |
| 7 | Revisore religioso | serve almeno una persona qualificata che porti i contenuti a `verified` |
| 8 | Dominio / bundle id definitivo | da decidere prima della Fase 21 |
