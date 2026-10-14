# Niyah

App islamica gratuita per ricordare Allah e rinnovare la propria intenzione (niyyah) durante la giornata. Offline-first, senza pubblicità, senza gamification, senza contenuti religiosi generati automaticamente.

L'interfaccia si costruisce in **FlutterFlow**. Questo repository contiene ciò che FlutterFlow non sa fare da solo, scritto e testato fuori dall'editor.

| Cartella | Contenuto | Test |
|---|---|---|
| [`docs/`](docs/) | architettura e piano di costruzione in FlutterFlow | — |
| [`packages/niyah_core/`](packages/niyah_core/) | logica pura in Dart: motore delle notifiche "ibrido a budget", orari di preghiera offline, selezione dei contenuti senza ripetizioni, unione per la sincronizzazione, query SQLite | `dart test` |
| [`flutterflow/custom_actions/`](flutterflow/) | custom action da incollare in FlutterFlow, con la guida di collegamento | `flutter analyze` |
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

# regole Firestore (serve Java per l'emulatore)
cd firebase && npm install && npm test

# Cloud Functions (Java per gli emulatori)
cd firebase/functions && npm install && npm test
```
