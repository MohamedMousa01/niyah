#!/usr/bin/env python3
"""Costruisce niyah_seed.db, il database SQLite incluso nell'app (architettura §3.3).

Uso:
    python3 build_seed.py                                  # schema + categorie + argomenti + modelli
    python3 build_seed.py --cities cities15000.zip         # + città GeoNames (CC-BY 4.0)
    python3 build_seed.py --content export.json            # + contenuti verificati esportati da Firestore

Lo script NON contiene e NON genera testi del Corano o di hadith: li legge solo
da un'esportazione dei contenuti già verificati e pubblicati, e rifiuta tutto
ciò che non ha i metadati di fonte e verifica richiesti.
"""

from __future__ import annotations

import argparse
import io
import json
import sqlite3
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
LANGS = ("it", "en", "ar", "fr", "es", "de")
NOW = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


class SeedError(Exception):
    pass


# ── Validazione ─────────────────────────────────────────────────────────────

def _require_langs(where: str, d: dict) -> None:
    missing = [l for l in LANGS if not (d.get(l) or "")]
    if missing:
        raise SeedError(f"{where}: mancano le lingue {missing}")


def validate_content_item(item: dict) -> list[str]:
    """Errori di un contenuto esportato. Lista vuota = accettato."""
    errs: list[str] = []
    cid = item.get("id", "<senza id>")
    if item.get("status") != "published":
        errs.append(f"{cid}: status deve essere 'published'")
    if not item.get("verifiedBy") or not item.get("verifiedAt"):
        errs.append(f"{cid}: mancano verifiedBy/verifiedAt")
    t = item.get("type")
    if t not in ("quran", "hadith", "dhikr"):
        errs.append(f"{cid}: type non valido ({t!r})")
    if t == "quran":
        s = item.get("surah")
        if not isinstance(s, int) or not 1 <= s <= 114:
            errs.append(f"{cid}: surah non valida")
        if not isinstance(item.get("ayahFrom"), int) or item["ayahFrom"] < 1:
            errs.append(f"{cid}: ayahFrom non valido")
        if not item.get("arabicText"):
            errs.append(f"{cid}: manca il testo arabo")
    if t == "hadith":
        for f in ("collection", "sourceRef", "grade"):
            if not item.get(f):
                errs.append(f"{cid}: manca {f}")
    translations = item.get("translations") or {}
    published = {l: tr for l, tr in translations.items() if tr.get("status") == "published"}
    if not published:
        errs.append(f"{cid}: nessuna traduzione pubblicata")
    for lang, tr in published.items():
        if lang not in LANGS:
            errs.append(f"{cid}: lingua sconosciuta {lang}")
        if not tr.get("text") or not tr.get("referenceLabel"):
            errs.append(f"{cid}/{lang}: mancano text o referenceLabel")
        if not tr.get("translationSource"):
            errs.append(f"{cid}/{lang}: manca translationSource")
    return errs


# ── Costruzione ─────────────────────────────────────────────────────────────

def load_json(name: str) -> dict:
    return json.loads((HERE / "data" / name).read_text(encoding="utf-8"))


def build(out: Path, cities: Path | None = None, content: Path | None = None) -> dict:
    if out.exists():
        out.unlink()
    db = sqlite3.connect(out)
    db.execute("PRAGMA foreign_keys = ON")
    db.executescript((HERE / "schema.sql").read_text(encoding="utf-8"))

    # Categorie
    cats = load_json("categories.json")["categories"]
    ids = {c["id"] for c in cats}
    for sort, c in enumerate(cats):
        _require_langs(f"categoria {c['id']}", c["names"])
        if c.get("parent") and c["parent"] not in ids:
            raise SeedError(f"categoria {c['id']}: parent sconosciuto {c['parent']}")
    # i genitori prima dei figli (vincolo di chiave esterna)
    for sort, c in sorted(enumerate(cats), key=lambda x: (x[1].get("parent") is not None, x[0])):
        db.execute("INSERT INTO categories(id,parent_id,icon,sort,active,updated_at) VALUES (?,?,?,?,1,?)",
                   (c["id"], c.get("parent"), c.get("icon"), sort, NOW))
        db.executemany("INSERT INTO category_i18n VALUES (?,?,?)", [(c["id"], l, c["names"][l]) for l in LANGS])

    # Argomenti di "Sto per…"
    for sort, t in enumerate(load_json("topics.json")["topics"]):
        _require_langs(f"argomento {t['id']}", t["names"])
        db.execute("INSERT INTO topics VALUES (?,?,?,1,?)", (t["id"], t.get("icon"), sort, NOW))
        db.executemany("INSERT INTO topic_i18n VALUES (?,?,?)", [(t["id"], l, t["names"][l]) for l in LANGS])

    # Contenuti verificati (facoltativi)
    content_ids: set[str] = set()
    if content:
        items = json.loads(content.read_text(encoding="utf-8"))
        errors = [e for it in items for e in validate_content_item(it)]
        if errors:
            raise SeedError("contenuti rifiutati:\n  " + "\n  ".join(errors))
        for it in items:
            db.execute(
                "INSERT INTO content_items VALUES (?,?,?,?,?,?,?,?,?,?,'published',?)",
                (it["id"], it["type"], it.get("arabicText"), it.get("surah"), it.get("ayahFrom"),
                 it.get("ayahTo"), it.get("collection"), it.get("hadithNumber"), it.get("grade"),
                 it.get("sourceRef"), it.get("updatedAt", NOW)))
            for lang, tr in it["translations"].items():
                if tr.get("status") != "published":
                    continue
                db.execute("INSERT INTO content_i18n VALUES (?,?,?,?,?,?,?)",
                           (it["id"], lang, tr["text"], tr["referenceLabel"], tr.get("translator"),
                            tr["translationSource"], tr.get("updatedAt", NOW)))
            for cat in it.get("categoryIds", []):
                if cat not in ids:
                    raise SeedError(f"{it['id']}: categoria sconosciuta {cat}")
                db.execute("INSERT INTO content_categories VALUES (?,?)", (it["id"], cat))
            for i, topic in enumerate(it.get("topicIds", [])):
                db.execute("INSERT INTO topic_content VALUES (?,?,?)", (topic, it["id"], i))
            content_ids.add(it["id"])

    # Modelli di notifica
    disabled = []
    for t in load_json("templates.json")["templates"]:
        for l in LANGS:
            if not t["texts"].get(l, {}).get("title") or not t["texts"].get(l, {}).get("body"):
                raise SeedError(f"modello {t['id']}: testo mancante in {l}")
        if t["category"] not in ids:
            raise SeedError(f"modello {t['id']}: categoria sconosciuta {t['category']}")
        source = t.get("source_content_id")
        if source and source not in content_ids:
            raise SeedError(f"modello {t['id']}: source_content_id {source} non presente tra i contenuti verificati")
        # Un modello che richiama una pratica religiosa resta spento senza fonte verificata.
        active = 0 if t.get("requires_source") and not source else 1
        if not active:
            disabled.append(t["id"])
        db.execute("INSERT INTO templates VALUES (?,?,?,?,?,?,?,1,0,?,?)",
                   (t["id"], t["category"], t["section"], t.get("content_type"), t["channel"],
                    json.dumps(t["schedule"]), source, active, NOW))
        db.executemany("INSERT INTO template_i18n VALUES (?,?,?,?)",
                       [(t["id"], l, t["texts"][l]["title"], t["texts"][l]["body"]) for l in LANGS])

    # Città
    n_cities = 0
    if cities:
        n_cities = import_geonames(db, cities)

    db.execute("INSERT INTO sync_meta VALUES ('seed_built_at', ?)", (NOW,))
    db.execute("INSERT INTO sync_meta VALUES ('schema_version', '2')")
    db.commit()
    check = db.execute("PRAGMA integrity_check").fetchone()[0]
    fk = db.execute("PRAGMA foreign_key_check").fetchall()
    if check != "ok" or fk:
        raise SeedError(f"integrità: {check}, chiavi esterne: {fk}")
    counts = {t: db.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
              for t in ("categories", "topics", "templates", "content_items", "cities")}
    db.execute("VACUUM")
    db.close()
    counts["templates_disabled_without_source"] = disabled
    counts["cities"] = n_cities
    return counts


def import_geonames(db: sqlite3.Connection, path: Path) -> int:
    """Importa cities15000 (zip o txt) da https://download.geonames.org/export/dump/."""
    if path.suffix == ".zip":
        with zipfile.ZipFile(path) as z:
            name = next(n for n in z.namelist() if n.endswith(".txt"))
            text = io.TextIOWrapper(z.open(name), encoding="utf-8")
            rows = list(_parse_geonames(text))
    else:
        with path.open(encoding="utf-8") as f:
            rows = list(_parse_geonames(f))
    db.executemany("INSERT OR REPLACE INTO cities VALUES (?,?,?,?,?,?,?,?)", rows)
    return len(rows)


def _parse_geonames(lines):
    for line in lines:
        cols = line.rstrip("\n").split("\t")
        if len(cols) < 19 or not cols[17]:
            continue
        geonameid, name, ascii_name = cols[0], cols[1], cols[2]
        lat, lng, country, population, tzname = cols[4], cols[5], cols[8], cols[14], cols[17]
        yield (int(geonameid), name, ascii_name or name, country, float(lat), float(lng), tzname,
               int(population or 0))


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--out", type=Path, default=HERE / "build" / "niyah_seed.db")
    p.add_argument("--cities", type=Path, help="cities15000.zip o .txt di GeoNames")
    p.add_argument("--content", type=Path, help="JSON dei contenuti verificati esportati da Firestore")
    a = p.parse_args(argv)
    a.out.parent.mkdir(parents=True, exist_ok=True)
    try:
        counts = build(a.out, a.cities, a.content)
    except SeedError as e:
        print(f"ERRORE: {e}", file=sys.stderr)
        return 1
    print(f"Creato {a.out}")
    for k, v in counts.items():
        print(f"  {k}: {v}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
