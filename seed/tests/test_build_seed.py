"""Test dello script del seed. Usa SOLO dati fittizi (segnaposto), nessun testo religioso."""
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_seed  # noqa: E402


def fake_item(**over):
    item = {
        "id": "h-test-1", "type": "hadith", "status": "published",
        "verifiedBy": "revisore-test", "verifiedAt": "2026-10-01T00:00:00Z",
        "collection": "COLLEZIONE-TEST", "sourceRef": "RIF-TEST", "grade": "GRADO-TEST",
        "categoryIds": ["patience"], "topicIds": ["work"],
        "translations": {"it": {"status": "published", "text": "SEGNAPOSTO", "referenceLabel": "RIF-TEST",
                                 "translationSource": "FONTE-TEST"}},
    }
    item.update(over)
    return item


class BuildSeedTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.out = self.tmp / "seed.db"

    def test_base_seed(self):
        counts = build_seed.build(self.out)
        self.assertGreater(counts["categories"], 30)
        self.assertEqual(counts["topics"], 10)
        self.assertEqual(counts["content_items"], 0)
        db = sqlite3.connect(self.out)
        # ogni categoria e argomento ha le 4 lingue
        self.assertEqual(db.execute("SELECT COUNT(*) FROM category_i18n").fetchone()[0], counts["categories"] * 4)
        # i modelli che richiamano una pratica restano spenti senza fonte verificata
        inactive = {r[0] for r in db.execute("SELECT id FROM templates WHERE active = 0")}
        self.assertEqual(inactive, {"monday_fast_eve", "thursday_fast_eve", "jumuah_morning", "kahf_friday"})
        # nessun contenuto religioso nel seed di base
        self.assertEqual(db.execute("SELECT COUNT(*) FROM content_i18n").fetchone()[0], 0)

    def test_struggle_reminder_cannot_be_cloud(self):
        build_seed.build(self.out)
        db = sqlite3.connect(self.out)
        with self.assertRaises(sqlite3.IntegrityError):
            db.execute("INSERT INTO reminders(id,kind,schedule_type,start_date,created_at,updated_at,sync_policy) "
                       "VALUES ('s','struggle','daily','2026-01-01','x','x','cloud')")
        db.execute("INSERT INTO reminders(id,kind,schedule_type,start_date,created_at,updated_at,sync_policy) "
                   "VALUES ('s','struggle','daily','2026-01-01','x','x','local_only')")

    def test_valid_content_is_imported(self):
        path = self.tmp / "c.json"
        path.write_text(json.dumps([fake_item()]))
        counts = build_seed.build(self.out, content=path)
        self.assertEqual(counts["content_items"], 1)

    def test_unverified_or_incomplete_content_is_rejected(self):
        bad = [
            fake_item(id="a", status="draft"),
            fake_item(id="b", verifiedBy=None),
            fake_item(id="c", grade=""),
            fake_item(id="d", type="quran", surah=115, ayahFrom=1, arabicText="X"),
            fake_item(id="e", translations={"it": {"status": "review", "text": "X", "referenceLabel": "R",
                                                    "translationSource": "F"}}),
        ]
        for item in bad:
            path = self.tmp / f"{item['id']}.json"
            path.write_text(json.dumps([item]))
            with self.assertRaises(build_seed.SeedError, msg=item["id"]):
                build_seed.build(self.out, content=path)

    def test_template_with_verified_source_becomes_active(self):
        # simula un modello collegato a un contenuto verificato
        data = build_seed.load_json("templates.json")
        orig = build_seed.load_json
        def patched(name):
            if name == "templates.json":
                d = json.loads(json.dumps(data))
                for t in d["templates"]:
                    if t["id"] == "kahf_friday":
                        t["source_content_id"] = "h-test-1"
                return d
            return orig(name)
        build_seed.load_json = patched
        try:
            path = self.tmp / "c.json"
            path.write_text(json.dumps([fake_item()]))
            build_seed.build(self.out, content=path)
        finally:
            build_seed.load_json = orig
        db = sqlite3.connect(self.out)
        self.assertEqual(db.execute("SELECT active FROM templates WHERE id='kahf_friday'").fetchone()[0], 1)

    def test_geonames_import(self):
        # due righe nel formato GeoNames (19 colonne), valori fittizi
        row = ["1", "Città Test", "Citta Test", "", "41.9", "12.5", "P", "PPLC", "IT", "", "07", "", "", "",
               "100000", "", "20", "Europe/Rome", "2026-01-01"]
        bad = row[:5]
        path = self.tmp / "cities.txt"
        path.write_text("\t".join(row) + "\n" + "\t".join(bad) + "\n", encoding="utf-8")
        counts = build_seed.build(self.out, cities=path)
        self.assertEqual(counts["cities"], 1)
        db = sqlite3.connect(self.out)
        self.assertEqual(db.execute("SELECT timezone FROM cities WHERE ascii_name LIKE 'citta%'").fetchone()[0], "Europe/Rome")


if __name__ == "__main__":
    unittest.main()
