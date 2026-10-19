# Niyah — database iniziale (seed)

`build_seed.py` crea `build/niyah_seed.db`, il database SQLite incluso nell'app al primo avvio.

```bash
python3 seed/build_seed.py                                   # schema, categorie, argomenti, modelli
python3 seed/build_seed.py --cities cities15000.zip          # + città per la ricerca offline
python3 seed/build_seed.py --content contenuti_verificati.json  # + Corano/hadith verificati
python3 -m unittest discover -s seed/tests                   # test (dati fittizi)
```

## Cosa contiene
- `schema.sql`: lo schema del database locale (architettura §3.2), versione 2 (`PRAGMA user_version = 2`). I vincoli impediscono di salvare un promemoria "peccato che sto combattendo" con sync cloud e un contenuto senza metadati di fonte. La v2 aggiunge `prayers_mask`, `anchor` (risveglio/sonno) e `offset_min` con segno ai promemoria, `group_key` e `icon` ai modelli; l'app migra i database v1 (`apps/niyah/lib/data/sqlite/niyah_database.dart`), quindi le due definizioni vanno tenute uguali.
- `../scripts/build_seed_asset.sh`: ricostruisce il seed e lo copia in `apps/niyah/assets/db/niyah_seed.db` (senza città). Va rilanciato e committato dopo ogni modifica a schema o dati.
- `data/categories.json`, `data/topics.json`: nomi in it/en/fr/ar. Sono testi d'interfaccia; **le traduzioni en/fr/ar vanno riviste da madrelingua**.
- `data/templates.json`: modelli di notifica brevi, senza citazioni, nell'ordine della schermata "Aggiungi un promemoria" (`group`, `icon`; `group: null` = non mostrato lì). I quattro modelli che richiamano una pratica (digiuno di lunedì e giovedì, venerdì, al-Kahf) restano **spenti** finché non vengono collegati a un contenuto verificato con `source_content_id`.

## Contenuti religiosi
Il seed di base **non contiene alcun versetto né hadith**. Si aggiungono solo con `--content`, da un'esportazione dei contenuti già portati a `published` nel pannello admin. Lo script rifiuta un contenuto se:
- non è `published` o manca `verifiedBy` / `verifiedAt`;
- è un versetto senza sura valida, ayah o testo arabo;
- è un hadith senza raccolta, riferimento o grado;
- non ha almeno una traduzione pubblicata con `referenceLabel` e `translationSource`.

Formato di un elemento (stessi campi di Firestore):
```json
{
  "id": "...", "type": "quran|hadith|dhikr", "status": "published",
  "verifiedBy": "...", "verifiedAt": "2026-10-01T00:00:00Z",
  "arabicText": "...", "surah": 2, "ayahFrom": 1, "ayahTo": 1,
  "collection": "...", "hadithNumber": "...", "grade": "...", "sourceRef": "...",
  "categoryIds": ["patience"], "topicIds": ["work"],
  "translations": {"it": {"status": "published", "text": "...", "referenceLabel": "...",
                          "translator": "...", "translationSource": "..."}}
}
```

## Città
Le città vengono da GeoNames (`cities15000.zip`, https://download.geonames.org/export/dump/), licenza CC-BY 4.0: va citata nella pagina Informazioni dell'app. Il file non è nel repository: scaricalo e passalo con `--cities`.
