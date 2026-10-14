# Niyah — Firebase (regole, indici, test)

Questa cartella contiene il livello di sicurezza Firestore di Niyah:

| File | Contenuto |
|---|---|
| `firestore.rules` | regole di produzione (default deny) |
| `firestore.indexes.json` | indici composti per la sync incrementale |
| `firebase.json`, `.firebaserc` | configurazione CLI ed emulatore; alias `dev`, `staging`, `prod` |
| `test/rules.test.js` | test delle regole contro l'emulatore Firestore |
| `functions/` | Cloud Functions (TypeScript): versione dei contenuti, tombstone, verifica, ruoli admin |

## Cosa garantiscono le regole

- **Tutto ciò che non è elencato è negato** (collezioni sconosciute, sottocollezioni non previste).
- **Pubblico** (anche senza login; App Check si attiva dalla console, non dalle regole): legge solo
  - `contentItems` e `contentItems/*/translations/*` con `status == 'published'`;
  - `categories`, `topics`, `topicContent`, `notificationTemplates`, `islamicEvents`, `campaigns` con `active == true`;
  - `meta/*` e `tombstones/*`.

  Le query del client devono contenere il filtro (`where('status','==','published')` o `where('active','==',true)`), altrimenti vengono rifiutate.
- **Ruoli** solo dai custom claims (`request.auth.token.role`):
  - `contentAdmin`/`superAdmin`: contenuti, traduzioni, categorie, argomenti, `topicContent`, eventi;
  - `notificationAdmin`/`superAdmin`: modelli di notifica e campagne;
  - `translator`: solo traduzioni, solo in `draft`/`review`; non pubblica, non verifica (né `status` né `verifiedBy`/`verifiedAt`), non modifica traduzioni già verificate/pubblicate, non tocca i `contentItems`.
  - Ogni ruolo legge anche i documenti non pubblicati/non attivi delle collezioni che gestisce.
- **Verifica obbligatoria**: nessuno (nemmeno `superAdmin`) porta un contenuto a `verified` o `published` senza `verifiedBy` (stringa non vuota) e `verifiedAt` (timestamp). Un hadith `verified`/`published` deve avere anche `hadithNumber`. Una traduzione `published` deve citare `translator`, `referenceLabel` e `translationSource` e appartenere a un contenuto `verified`/`published`.
- **Validazione dei campi**: elenco chiuso dei campi per ogni collezione, tipi controllati, `updatedAt` (timestamp) obbligatorio, `active` (bool) obbligatorio dove serve. Versetti: `surah` intero 1–114, `ayahFrom` intero ≥ 1, `arabicText` stringa. Hadith: `collection`, `sourceRef`, `grade` stringhe. `topicContent` ha id `topicId_contentId` e un campo `active`.
- **Niente cancellazioni dei contenuti pubblici dal client**: si usa `status = 'archived'` o `active = false` (§8.1); la Cloud Function scrive il tombstone.
- **Dati utente** (`users/{uid}` e sottocollezioni dirette): solo il proprietario. Nessun admin vi accede. I promemoria con `kind` diverso da `template|personal|content|prayer|event` (quindi anche `struggle`) o marcati `local_only` vengono rifiutati.
- `adminRoles/{uid}`: lo legge il proprietario o un `superAdmin`; `adminAudit`: solo `superAdmin`. Nessuna scrittura dai client (solo Cloud Functions / Admin SDK).

Le Cloud Functions e la console usano l'Admin SDK, che **ignora le regole**.

Note per chi scrive i dati:

- `updatedAt` va scritto come timestamp, possibilmente del server (`FieldValue.serverTimestamp()`): un orologio client sbagliato farebbe sfuggire il documento alla sync incrementale.
- Le regole lavorano per documento: di un contenuto pubblicato si leggono **tutti** i campi, quindi `verifiedBy` è pubblico. Usare un identificativo che il revisore accetta di rendere visibile.
- Quando un contenuto viene archiviato, la Cloud Function `onContentItemWrite` archivia anche le sue traduzioni pubblicate.
- Il client legge la traduzione di un contenuto con una query `where('status','==','published')` sulla sottocollezione, non con un get: le regole negano il get di una traduzione in bozza o inesistente (anche una query filtrata per `documentId`).

## Indici

`firestore.indexes.json` contiene gli indici composti per le query di sync:

- `contentItems`: `status ==` + `updatedAt >`;
- `categories`, `topics`, `topicContent`, `notificationTemplates`, `islamicEvents`, `campaigns`: `active ==` + `updatedAt >`;
- `translations` (collection group): `status ==` + `updatedAt >`.

`tombstones where removedAt > X orderBy removedAt` usa un solo campo: basta l'indice automatico, nessun indice composto.

## Deploy

```bash
npm install
npx firebase login
npx firebase deploy --only firestore:rules,firestore:indexes -P dev
```

Per gli altri ambienti: `-P staging`, `-P prod`.

## Test

Servono Node.js 22 o successivo (24 LTS consigliato: `@firebase/rules-unit-testing` 6 lo dichiara come minimo, ma funziona anche con 22) e Java 21 o successivo per l'emulatore Firestore (un `.jar` scaricato al primo avvio in `~/.cache/firebase/emulators`).

```bash
npm install
npm test
```

`npm test` esegue `firebase emulators:exec --only firestore --project demo-niyah "mocha test"`: avvia l'emulatore, esegue i test e lo chiude. Il progetto `demo-niyah` è fittizio: non serve login né un progetto reale.

Se si aggiunge un campo a una collezione, va aggiunto anche all'elenco dei campi ammessi in `firestore.rules`, altrimenti le scritture vengono rifiutate.

## Cloud Functions (`functions/`)

Cosa fanno: vedi [architettura §4.4](../docs/architettura.md). In breve:

- ogni scrittura su un documento **che i client vedono o vedevano** (`contentItems` pubblicati; `categories`, `topics`, `topicContent`, `notificationTemplates`, `islamicEvents` attivi) incrementa `meta/contentVersion.version.{it,en,ar,fr}`; le bozze non costano nulla ai client;
- un documento ritirato, disattivato o cancellato produce una `tombstones/{autoId}` `{collection, docId, removedAt}` (+ `topicId`, `contentId` per `topicContent`);
- un contenuto `verified`/`published` senza `verifiedBy` e `verifiedAt` (scritto dalla console o dall'Admin SDK, che ignorano le regole) torna in `review`, con una voce in `adminAudit`;
- archiviare o cancellare un contenuto archivia le sue traduzioni pubblicate/verificate; cambiare una traduzione di un contenuto pubblicato aggiorna `updatedAt` del contenuto;
- `setAdminRole({uid, role})`, chiamabile solo da un `superAdmin`: imposta il custom claim `role` (o lo toglie con `role: null`), aggiorna `adminRoles/{uid}`, scrive `adminAudit` e revoca le sessioni quando un ruolo esistente viene tolto o cambiato.

### Primo superAdmin

Una volta per ambiente, dal proprio computer (l'utente deve già esistere in Authentication):

```bash
cd functions && npm install
gcloud auth application-default login
node scripts/first-superadmin.js --project niyah-dev --email tua@email
```

Lo script si rifiuta se esiste già un superAdmin. Il ruolo vale dal successivo accesso al pannello.

### Deploy

Le Cloud Functions richiedono il piano **Blaze** sul progetto.

```bash
cd functions && npm install
npx firebase deploy --only functions -P dev
```

⚠️ La regione è `europe-west1` (in `src/index.ts`): deve essere compatibile con la posizione del database Firestore scelta alla creazione del progetto. Se il database è altrove (es. `nam5`), cambiare la regione prima del deploy.

### Test

```bash
cd functions && npm install
npm test   # test della logica + test con gli emulatori Firestore, Functions e Auth
```

Limiti noti:

- un ruolo tolto smette di valere subito per le nuove sessioni, ma un ID token già emesso resta valido fino alla sua scadenza (al massimo 1 ora): le regole non possono controllare la revoca;
- `firebase-tools` ignora `NO_PROXY`: dietro un proxy HTTP le chiamate tra emulatori passano dal proxy e la registrazione dei trigger fallisce. In CI (nessun proxy) i test girano normalmente.
