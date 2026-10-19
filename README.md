# Niyah

App islamica gratuita per ricordare Allah e rinnovare la propria intenzione (niyyah) durante la giornata. Offline-first, senza pubblicità, senza gamification, senza contenuti religiosi generati automaticamente.

L'app mobile è scritta a mano in Flutter (`apps/niyah/`). FlutterFlow non si usa più (vedi `docs/app-plan.md`).

| Cartella | Contenuto | Test |
|---|---|---|
| [`docs/`](docs/) | architettura e piano dell'app | — |
| [`apps/niyah/`](apps/niyah/) | app Flutter (Android e iOS): schermate, database locale SQLite, notifiche locali | `flutter test` |
| [`packages/niyah_core/`](packages/niyah_core/) | logica pura in Dart: motore delle notifiche "ibrido a budget", orari di preghiera offline, selezione dei contenuti senza ripetizioni, unione per la sincronizzazione, query SQLite | `dart test` |
| `flutterflow/` | rimossa: FlutterFlow è stato abbandonato e il suo codice runtime portato in `apps/niyah/` | — |
| [`seed/`](seed/) | schema del database locale e script che costruisce il database incluso nell'app | `python3 -m unittest` |
| [`firebase/`](firebase/) | regole di sicurezza Firestore, indici e test con l'emulatore | `npm test` |
| [`firebase/functions/`](firebase/functions/) | Cloud Functions: versione dei contenuti, tombstone, verifica, ruoli admin | `npm test` |

## Principi tecnici
- Il database locale è la fonte di verità; Firebase serve solo a distribuire contenuti nuovi e, con un account, a sincronizzare.
- Le notifiche dei promemoria sono **locali**: funzionano senza rete e senza server.
- Il limite iOS di 64 notifiche in attesa è gestito davvero, non nascosto (vedi `docs/architettura.md` §6).
- I promemoria "peccato che sto combattendo" non lasciano mai il dispositivo.
- Nessun testo del Corano o di hadith è scritto in questo repository: il codice li accetta solo dal database curato, con fonte e verifica.

## Eseguire i test
```bash
# logica Dart (serve Dart SDK ≥ 3.4)
cd packages/niyah_core && dart pub get && dart test

# seed
python3 -m unittest discover -s seed/tests

# app Flutter
cd apps/niyah && flutter pub get && flutter analyze && flutter test

# regole Firestore (serve Java per l'emulatore)
cd firebase && npm install && npm test

# Cloud Functions (Java per gli emulatori)
cd firebase/functions && npm install && npm test
```
