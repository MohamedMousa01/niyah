// Verifica le query di NiyahSql contro lo schema reale (seed/schema.sql).
// Dati FITTIZI: nessun testo religioso.
import 'dart:io';

import 'package:niyah_core/niyah_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

List<Map<String, Object?>> rows(Database db, String sql, [List<Object?> args = const []]) =>
    db.select(sql, args).map((r) => Map<String, Object?>.from(r)).toList();

void main() {
  late Database db;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute(File('../../seed/schema.sql').readAsStringSync());
    db.execute("INSERT INTO categories VALUES ('patience', NULL, NULL, 0, 1, '2026-01-01')");
    db.execute("INSERT INTO categories VALUES ('work', NULL, NULL, 0, 1, '2026-01-01')");
    for (final (id, type) in [('h1', 'hadith'), ('h2', 'hadith'), ('q1', 'quran')]) {
      if (type == 'quran') {
        db.execute("INSERT INTO content_items (id,type,arabic_text,surah,ayah_from,status,updated_at) VALUES (?,?,'AR',1,1,'published','2026-10-01')", [id, type]);
      } else {
        db.execute("INSERT INTO content_items (id,type,collection,source_ref,grade,status,updated_at) VALUES (?,?,'C','R','G','published','2026-10-01')", [id, type]);
      }
      db.execute("INSERT INTO content_i18n VALUES (?, 'it', 'SEGNAPOSTO', 'RIF', NULL, 'FONTE', '2026-10-01')", [id]);
    }
    db.execute("INSERT INTO content_i18n VALUES ('h1', 'fr', 'SEGNAPOSTO-FR', 'RIF', NULL, 'FONTE', '2026-10-01')");
    db.execute("INSERT INTO content_categories VALUES ('h1','patience'), ('h1','work')");
  });

  tearDown(() => db.dispose());

  test('contenuti candidati: solo la lingua richiesta, con categorie', () {
    final it = rows(db, NiyahSql.contentCandidates(1), ['it', 'hadith']).map(NiyahSql.candidateFromRow).toList();
    expect(it.map((c) => c.id).toSet(), {'h1', 'h2'});
    expect(it.firstWhere((c) => c.id == 'h1').categoryIds, {'patience', 'work'});
    expect(it.firstWhere((c) => c.id == 'h2').categoryIds, isEmpty);
    final fr = rows(db, NiyahSql.contentCandidates(2), ['fr', 'hadith', 'quran']);
    expect(fr.map((r) => r['id']), ['h1']); // nessun ripiego su un'altra lingua
  });

  test('il database rifiuta contenuti senza metadati di fonte', () {
    expect(
      () => db.execute("INSERT INTO content_items (id,type,status,updated_at) VALUES ('x','hadith','published','2026')"),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute("INSERT INTO content_items (id,type,collection,source_ref,grade,status,updated_at) VALUES ('y','hadith','C','R','G','draft','2026')"),
      throwsA(isA<SqliteException>()),
    );
  });

  test('promemoria: una riga con i default dello schema diventa un Reminder valido', () {
    db.execute("INSERT INTO reminders (id,kind,title,schedule_type,time,start_date,created_at,updated_at) "
        "VALUES ('r1','personal','Titolo','daily','08:00','2026-01-01','2026-10-01T00:00:00Z','2026-10-01T00:00:00Z')");
    db.execute("INSERT INTO reminders (id,kind,title,schedule_type,time,start_date,created_at,updated_at,deleted) "
        "VALUES ('r2','personal','Titolo','daily','08:00','2026-01-01','x','2026-10-01T00:00:00Z',1)");
    final rs = rows(db, NiyahSql.activeReminders).map(Reminder.fromRow).toList();
    expect(rs.map((r) => r.id), ['r1']);
    final r = rs.single;
    expect(r.validate(), isEmpty);
    expect(r.enabled, isTrue);
    expect(r.daysMask, DaysMask.all);
    expect(r.hideOnLockScreen, isFalse);
    expect(r.syncPolicy, 'cloud');
  });

  test('promemoria v2: più preghiere, offset negativo, anchor', () {
    db.execute("INSERT INTO reminders (id,kind,template_id,schedule_type,prayers_mask,offset_min,start_date,created_at,updated_at) "
        "VALUES ('p','template','after_prayer','prayer',31,-15,'2026-01-01','x','2026-10-01T00:00:00Z')");
    db.execute("INSERT INTO reminders (id,kind,title,schedule_type,anchor,start_date,created_at,updated_at) "
        "VALUES ('w','personal','Titolo','anchor','wake','2026-01-01','x','2026-10-01T00:00:00Z')");
    final rs = {for (final r in rows(db, NiyahSql.activeReminders).map(Reminder.fromRow)) r.id: r};
    expect(rs['p']!.prayers, Prayer.values);
    expect(rs['p']!.offsetMin, -15);
    expect(rs['w']!.anchor, AnchorKind.wake);
    expect(rs.values.every((r) => r.validate().isEmpty), isTrue);
    for (final bad in [
      "INSERT INTO reminders (id,kind,schedule_type,offset_min,start_date,created_at,updated_at) VALUES ('a','personal','prayer',-61,'2026-01-01','x','x')",
      "INSERT INTO reminders (id,kind,schedule_type,anchor,start_date,created_at,updated_at) VALUES ('b','personal','anchor','noon','2026-01-01','x','x')",
    ]) {
      expect(() => db.execute(bad), throwsA(isA<SqliteException>()), reason: bad);
    }
  });

  test('recent_content si accorcia da solo a 50 righe e la query restituisce i più recenti', () {
    for (var i = 0; i < 60; i++) {
      db.execute('INSERT INTO recent_content VALUES (?, ?)', ['c$i', '2026-10-01T00:00:${i.toString().padLeft(2, '0')}Z']);
    }
    final ids = rows(db, NiyahSql.recentContent).map((r) => r['content_id']).toList();
    expect(ids.length, 50);
    expect(ids.first, 'c59');
    expect(db.select('SELECT COUNT(*) AS n FROM recent_content').first['n'], 50);
  });

  test('testi dei modelli per lingua', () {
    db.execute("INSERT INTO templates (id,category_id,section,channel,default_schedule_json,updated_at,group_key,icon) "
        "VALUES ('t1','work','suggested','niyyah','{}','x','daily','work')");
    db.execute("INSERT INTO template_i18n VALUES ('t1','it','Titolo','Testo'), ('t1','en','Title','Text')");
    expect(rows(db, NiyahSql.templateTexts, ['en']).single['title'], 'Title');
  });
}
