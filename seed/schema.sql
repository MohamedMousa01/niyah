-- Niyah — schema del database locale (SQLite), versione 2.
-- Fonte di verità sul dispositivo (architettura §3). Le notifiche dell'OS sono
-- solo una proiezione della tabella `reminders`: il motore le ricalcola sempre
-- da qui e le confronta con le notifiche in attesa nell'OS (id stabili), per
-- questo non serve una tabella di mappatura `scheduled_os`.

-- v2: prayers_mask, anchor e offset_min con segno (reminders); group_key e icon
-- (templates). I database creati in v1 li migra l'app
-- (apps/niyah/lib/data/sqlite/niyah_database.dart): tieni le due definizioni uguali.
PRAGMA user_version = 2;

-- ── Promemoria (tutti i tipi) ───────────────────────────────────────────────
CREATE TABLE reminders (
  id                   TEXT PRIMARY KEY,           -- UUID generato sul dispositivo
  kind                 TEXT NOT NULL CHECK (kind IN ('template','personal','struggle','content','prayer','event')),
  template_id          TEXT,
  category_id          TEXT,
  title                TEXT,                       -- testo dell'utente: mai modificato dall'app
  body                 TEXT,
  content_type         TEXT CHECK (content_type IS NULL OR content_type IN ('quran','hadith','dhikr')),
  schedule_type        TEXT NOT NULL CHECK (schedule_type IN ('daily','weekly','once','window','prayer','anchor')),
  time                 TEXT,                       -- 'HH:mm'
  window_start         TEXT,
  window_end           TEXT,
  times_per_day        INTEGER NOT NULL DEFAULT 1,
  days_mask            INTEGER NOT NULL DEFAULT 127, -- bit 0 = lunedì … bit 6 = domenica
  prayer               TEXT CHECK (prayer IS NULL OR prayer IN ('fajr','dhuhr','asr','maghrib','isha')), -- righe v1: una sola preghiera
  prayers_mask         INTEGER,                    -- bit 0 = Fajr … bit 4 = Isha; se presente vince su `prayer`
  offset_min           INTEGER NOT NULL DEFAULT 0 CHECK (offset_min BETWEEN -60 AND 120), -- > 0 = minuti prima dell'adhan, 0 = all'adhan, < 0 = dopo
  anchor               TEXT CHECK (anchor IS NULL OR anchor IN ('wake','sleep')), -- per schedule_type = 'anchor' (orari nelle impostazioni)
  start_date           TEXT NOT NULL,              -- 'yyyy-MM-dd'
  end_date             TEXT,
  enabled              INTEGER NOT NULL DEFAULT 1,
  paused_until         TEXT,                       -- ISO 8601 UTC
  respects_quiet_hours INTEGER NOT NULL DEFAULT 1,
  hide_on_lock_screen  INTEGER,                    -- NULL = default (1 per 'struggle')
  channel              TEXT NOT NULL DEFAULT 'personal',
  sync_policy          TEXT NOT NULL DEFAULT 'cloud' CHECK (sync_policy IN ('local_only','cloud')),
  device_id            TEXT,                       -- dispositivo dell'ultima modifica (merge deterministico)
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL,
  deleted              INTEGER NOT NULL DEFAULT 0, -- tombstone per la sync
  -- I promemoria "peccato che sto combattendo" non lasciano mai il dispositivo (v1).
  CHECK (kind <> 'struggle' OR sync_policy = 'local_only')
);
CREATE INDEX idx_reminders_active ON reminders(deleted, enabled);

-- ── Categorie ───────────────────────────────────────────────────────────────
CREATE TABLE categories (
  id         TEXT PRIMARY KEY,
  parent_id  TEXT REFERENCES categories(id),
  icon       TEXT,
  sort       INTEGER NOT NULL DEFAULT 0,
  active     INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
);
CREATE TABLE category_i18n (
  category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  lang        TEXT NOT NULL CHECK (lang IN ('it','en','ar','fr')),
  name        TEXT NOT NULL,
  PRIMARY KEY (category_id, lang)
);

-- ── Contenuti islamici verificati ──────────────────────────────────────────
-- Arrivano SOLO dal database curato (status = published). Il testo arabo del
-- Corano è salvato una sola volta qui; le traduzioni in content_i18n.
CREATE TABLE content_items (
  id            TEXT PRIMARY KEY,
  type          TEXT NOT NULL CHECK (type IN ('quran','hadith','dhikr')),
  arabic_text   TEXT,
  surah         INTEGER CHECK (surah IS NULL OR surah BETWEEN 1 AND 114),
  ayah_from     INTEGER,
  ayah_to       INTEGER,
  collection    TEXT,
  hadith_number TEXT,
  grade         TEXT,
  source_ref    TEXT,
  status        TEXT NOT NULL CHECK (status = 'published'),
  updated_at    TEXT NOT NULL,
  CHECK (type <> 'quran'  OR (surah IS NOT NULL AND ayah_from IS NOT NULL AND arabic_text IS NOT NULL)),
  CHECK (type <> 'hadith' OR (collection IS NOT NULL AND source_ref IS NOT NULL AND grade IS NOT NULL))
);
CREATE TABLE content_i18n (
  content_id         TEXT NOT NULL REFERENCES content_items(id) ON DELETE CASCADE,
  lang               TEXT NOT NULL CHECK (lang IN ('it','en','ar','fr')),
  text               TEXT NOT NULL,
  reference_label    TEXT NOT NULL,   -- es. "Al-Baqarah 2:286", localizzato
  translator         TEXT,
  translation_source TEXT,
  updated_at         TEXT NOT NULL,
  PRIMARY KEY (content_id, lang)
);
CREATE TABLE content_categories (
  content_id  TEXT NOT NULL REFERENCES content_items(id) ON DELETE CASCADE,
  category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (content_id, category_id)
);

-- ── "Sto per…" ──────────────────────────────────────────────────────────────
CREATE TABLE topics (
  id         TEXT PRIMARY KEY,
  icon       TEXT,
  sort       INTEGER NOT NULL DEFAULT 0,
  active     INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
);
CREATE TABLE topic_i18n (
  topic_id TEXT NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  lang     TEXT NOT NULL CHECK (lang IN ('it','en','ar','fr')),
  name     TEXT NOT NULL,
  PRIMARY KEY (topic_id, lang)
);
CREATE TABLE topic_content (
  topic_id   TEXT NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  content_id TEXT NOT NULL REFERENCES content_items(id) ON DELETE CASCADE,
  sort       INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (topic_id, content_id)
);

-- ── Modelli di notifica ────────────────────────────────────────────────────
CREATE TABLE templates (
  id                    TEXT PRIMARY KEY,
  category_id           TEXT REFERENCES categories(id),
  section               TEXT NOT NULL CHECK (section IN ('suggested','content','weekly','seasonal')),
  content_type          TEXT,
  channel               TEXT NOT NULL,
  default_schedule_json TEXT NOT NULL,  -- es. {"schedule_type":"daily","time":"08:00"}
  source_content_id     TEXT REFERENCES content_items(id), -- obbligatorio se il testo fa un'affermazione religiosa
  editable              INTEGER NOT NULL DEFAULT 1,
  seasonal              INTEGER NOT NULL DEFAULT 0,
  active                INTEGER NOT NULL DEFAULT 1,
  updated_at            TEXT NOT NULL,
  -- v2, in fondo come dopo ALTER TABLE ADD COLUMN nella migrazione:
  group_key             TEXT CHECK (group_key IS NULL OR group_key IN ('prayer','daily','dhikr','weekly')), -- gruppo in "Aggiungi"; NULL = non mostrato
  icon                  TEXT              -- chiave dell'icona nell'app
);
CREATE TABLE template_i18n (
  template_id TEXT NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
  lang        TEXT NOT NULL CHECK (lang IN ('it','en','ar','fr')),
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  PRIMARY KEY (template_id, lang)
);

-- ── Eventi islamici e campagne ─────────────────────────────────────────────
CREATE TABLE events (
  id         TEXT PRIMARY KEY,
  type       TEXT NOT NULL,
  start_date TEXT NOT NULL,
  end_date   TEXT NOT NULL,
  hijri_json TEXT,
  active     INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
);
CREATE TABLE event_i18n (
  event_id    TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  lang        TEXT NOT NULL CHECK (lang IN ('it','en','ar','fr')),
  name        TEXT NOT NULL,
  description TEXT,
  PRIMARY KEY (event_id, lang)
);
CREATE TABLE event_templates (
  event_id    TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  template_id TEXT NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
  PRIMARY KEY (event_id, template_id)
);

-- ── Città (ricerca offline per gli orari di preghiera) ─────────────────────
CREATE TABLE cities (
  id         INTEGER PRIMARY KEY,   -- geonameid
  name       TEXT NOT NULL,
  ascii_name TEXT NOT NULL,
  country    TEXT NOT NULL,         -- ISO 3166 alpha-2
  lat        REAL NOT NULL,
  lng        REAL NOT NULL,
  timezone   TEXT NOT NULL,
  population INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_cities_ascii ON cities(ascii_name COLLATE NOCASE);

-- ── Cache e metadati ────────────────────────────────────────────────────────
CREATE TABLE prayer_cache (
  date          TEXT PRIMARY KEY,   -- 'yyyy-MM-dd'
  fajr          TEXT NOT NULL, sunrise TEXT NOT NULL, dhuhr TEXT NOT NULL,
  asr           TEXT NOT NULL, maghrib TEXT NOT NULL, isha  TEXT NOT NULL,
  settings_hash TEXT NOT NULL
);
-- Solo per evitare di ripetere lo stesso contenuto a breve distanza.
-- Non è una statistica: non viene mai mostrata né sincronizzata.
CREATE TABLE recent_content (
  content_id TEXT PRIMARY KEY,
  shown_at   TEXT NOT NULL
);
CREATE TRIGGER trim_recent_content AFTER INSERT ON recent_content
BEGIN
  DELETE FROM recent_content WHERE content_id NOT IN
    (SELECT content_id FROM recent_content ORDER BY shown_at DESC LIMIT 50);
END;
CREATE TABLE sync_meta (
  key   TEXT PRIMARY KEY,
  value TEXT
);
