# Niyah — app Flutter (Android e iOS)

L'app vera e propria. La logica delle notifiche e degli orari di preghiera sta in [`packages/niyah_core`](../packages/niyah_core) (testata a parte); qui ci sono interfaccia, database locale e collegamento al sistema operativo.

## Provare l'app su Android

Ogni pull request e ogni modifica a `main` producono un APK installabile:

1. Apri la scheda **Actions** del repository su GitHub e scegli l'ultima esecuzione di **CI** con la spunta verde.
2. In fondo alla pagina, sotto **Artifacts**, scarica `niyah-apk` (un file zip).
3. Estrai `app-release.apk` e aprilo sul telefono Android. La prima volta Android chiede di consentire l'installazione da quella fonte.

L'APK è firmato con una chiave di prova fissa, così ogni nuova versione si installa sopra la precedente senza perdere i dati. Va bene per i test, non per Google Play.

La chiave arriva da quattro segreti del repository (Settings › Secrets and variables › Actions): `NIYAH_KEYSTORE_BASE64` (il file della chiave in base64), `NIYAH_KEYSTORE_PASSWORD`, `NIYAH_KEY_ALIAS` e `NIYAH_KEY_PASSWORD`. Se mancano, la CI firma con una chiave temporanea e l'APK non si installa sopra una versione firmata con la chiave fissa. Nel log del passo "Impronta della chiave" si vede con quale chiave è stato firmato.

## Sviluppo

Servono Flutter 3.47 (Dart 3.13) e Python 3 per generare il database iniziale.

```bash
cd app
./tool/prepare_seed.sh                      # crea assets/databases/niyah_seed.db
# ./tool/prepare_seed.sh cities15000.zip    # con le città di GeoNames per la ricerca offline
flutter pub get
flutter run
flutter analyze && flutter test
```

Per iOS serve un Mac con Xcode (oppure un servizio di build nel cloud come Codemagic).

## Struttura

| Cartella | Contenuto |
|---|---|
| `lib/data/` | database SQLite (copiato dal seed al primo avvio), catalogo dei modelli e degli argomenti, promemoria |
| `lib/services/` | piano delle notifiche dal database (`schedule_builder.dart`) e collegamento al sistema operativo (`notification_gateway.dart`) |
| `lib/state/` | impostazioni persistenti e `AppController`, che riprogramma le notifiche dopo ogni modifica |
| `lib/ui/` | schermate e componenti del design system |
| `lib/l10n/` | testi in it/en/fr/ar, generati da `tool/make_arb.py` (modificare lì, poi `python3 tool/make_arb.py`) |
| `assets/fonts/` | Plus Jakarta Sans e IBM Plex Sans Arabic (licenza OFL) |

## Cosa c'è e cosa manca

Già pronto: onboarding (benvenuto, lingua, permesso notifiche spiegato prima di chiederlo), barra in basso con due schede: "Le mie notifiche" (notifiche scritte dall'utente con testo, orario e giorni) e "Notifiche standard" (notifiche random con interruttore, modelli suggeriti con orario e giorni); impostazioni in una schermata a parte dall'icona in alto (lingua, Non disturbare, pausa, permesso, informazioni); 6 lingue (italiano, arabo da destra a sinistra, inglese, francese, spagnolo, tedesco); notifiche locali che su Android spariscono da sole dopo 3 ore e si ripristinano dopo il riavvio del telefono. "Sto per…" è nel codice ma non è raggiungibile dalla barra.

Prossimi passi: promemoria personali e "peccato che sto combattendo" (solo locali), orari e avvisi di preghiera con scelta della città, sincronizzazione dei contenuti verificati da Firebase, pagina di dettaglio dei contenuti.

⚠️ I testi in inglese, francese e arabo vanno rivisti da madrelingua prima della pubblicazione. L'identificativo `app.niyah` va confermato prima della prima pubblicazione su Google Play.
