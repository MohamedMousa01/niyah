// Test delle Cloud Functions contro gli emulatori (Firestore, Functions, Auth).
// Avvio: npm run test:emulator  (firebase emulators:exec … "mocha lib/test/integration.test.js")
//
// I testi qui sotto sono SEGNAPOSTO, non citazioni reali.

import assert from 'node:assert/strict';

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { DocumentData, getFirestore, Timestamp } from 'firebase-admin/firestore';

const PROJECT = 'demo-niyah';
const REGION = 'europe-west1';

assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Avviare con firebase emulators:exec');
assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST, 'Serve anche l’emulatore Auth');

const app = initializeApp({ projectId: PROJECT });
const db = getFirestore(app);
const auth = getAuth(app);

const PAST = Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));
const run = Date.now().toString(36);
const id = (name: string) => `${name}_${run}`;

async function waitFor<T>(what: string, probe: () => Promise<T | undefined | null | false>, ms = 20000): Promise<T> {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    const v = await probe();
    if (v) return v;
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(`Tempo scaduto: ${what}`);
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function version(): Promise<number> {
  const d = (await db.doc('meta/contentVersion').get()).data();
  const v = (d?.version ?? {}) as Record<string, number>;
  // Tutte le lingue avanzano insieme.
  assert.ok(v.it === v.en && v.en === v.ar && v.ar === v.fr, `versioni disallineate: ${JSON.stringify(v)}`);
  return v.it ?? 0;
}

async function waitVersionAbove(n: number): Promise<number> {
  return waitFor(`versione > ${n}`, async () => {
    const v = await version();
    return v > n ? v : undefined;
  });
}

async function tombstones(docId: string): Promise<DocumentData[]> {
  return (await db.collection('tombstones').where('docId', '==', docId).get()).docs.map((d) => d.data());
}

const contentItem = (over: DocumentData = {}): DocumentData => ({
  type: 'quran',
  arabicText: '[testo arabo segnaposto]',
  surah: 2,
  ayahFrom: 153,
  ayahTo: 153,
  sourceRef: 'Quran 2:153',
  categoryIds: ['pazienza'],
  status: 'published',
  verifiedBy: 'uid-revisore',
  verifiedAt: PAST,
  updatedAt: PAST,
  ...over,
});

const translation = (over: DocumentData = {}): DocumentData => ({
  text: '[traduzione segnaposto]',
  referenceLabel: '[riferimento segnaposto]',
  translator: '[traduttore segnaposto]',
  translationSource: '[fonte segnaposto]',
  status: 'published',
  updatedAt: PAST,
  ...over,
});

describe('versione dei contenuti e tombstone', () => {
  it('una categoria attivata incrementa la versione per tutte le lingue', async () => {
    const v0 = await version();
    await db.doc(`categories/${id('cat')}`).set({ active: true, names: { it: 'Prova' }, order: 1, updatedAt: PAST });
    await waitVersionAbove(v0);
  });

  it('disattivarla scrive una tombstone', async () => {
    const v0 = await version();
    await db.doc(`categories/${id('cat')}`).update({ active: false });
    await waitVersionAbove(v0);
    const t = await waitFor('tombstone', async () => (await tombstones(id('cat')))[0]);
    assert.equal(t.collection, 'categories');
    assert.ok(t.removedAt instanceof Timestamp);
  });

  it('una bozza non tocca versione né tombstone', async () => {
    const v0 = await version();
    await db.doc(`contentItems/${id('bozza')}`).set(contentItem({ status: 'draft', verifiedBy: null, verifiedAt: null }));
    await db.doc(`contentItems/${id('bozza')}`).update({ status: 'review' });
    await sleep(3000);
    assert.equal(await version(), v0);
    assert.deepEqual(await tombstones(id('bozza')), []);
  });

  it('la tombstone di topicContent porta topicId e contentId', async () => {
    const docId = id('pazienza_q');
    await db.doc(`topicContent/${docId}`).set({ active: true, topicId: 'pazienza', contentId: id('q'), order: 1, updatedAt: PAST });
    await db.doc(`topicContent/${docId}`).update({ active: false });
    const t = await waitFor('tombstone topicContent', async () => (await tombstones(docId))[0]);
    assert.equal(t.collection, 'topicContent');
    assert.equal(t.topicId, 'pazienza');
    assert.equal(t.contentId, id('q'));
  });
});

describe('verifica prima della pubblicazione', () => {
  it('un contenuto pubblicato con verifica resta pubblicato', async () => {
    const v0 = await version();
    await db.doc(`contentItems/${id('ok')}`).set(contentItem());
    await waitVersionAbove(v0);
    await sleep(1500);
    assert.equal((await db.doc(`contentItems/${id('ok')}`).get()).data()?.status, 'published');
  });

  it('pubblicato senza verifica torna in review, con audit e tombstone', async () => {
    const ref = db.doc(`contentItems/${id('nover')}`);
    await ref.set(contentItem({ verifiedBy: null, verifiedAt: null }));
    await waitFor('status review', async () => (await ref.get()).data()?.status === 'review');
    const audit = await waitFor('audit', async () => {
      const q = await db.collection('adminAudit').where('target', '==', `contentItems/${id('nover')}`).get();
      return q.docs[0]?.data();
    });
    assert.equal(audit.action, 'verificationGuard');
    assert.equal(audit.from, 'published');
    assert.equal(audit.to, 'review');
    // Era leggibile dai client per un istante: va ritirato anche da loro.
    await waitFor('tombstone', async () => (await tombstones(id('nover')))[0]);
  });
});

describe('traduzioni', () => {
  it('archiviare un contenuto archivia le sue traduzioni pubblicate, non le bozze', async () => {
    const item = db.doc(`contentItems/${id('arch')}`);
    await item.set(contentItem());
    await item.collection('translations').doc('it').set(translation());
    await item.collection('translations').doc('fr').set(translation({ status: 'draft' }));
    await sleep(1500);
    await item.update({ status: 'archived' });
    await waitFor('traduzione it archiviata', async () => (await item.collection('translations').doc('it').get()).data()?.status === 'archived');
    assert.equal((await item.collection('translations').doc('fr').get()).data()?.status, 'draft');
    await waitFor('tombstone', async () => (await tombstones(id('arch')))[0]);
  });

  it('cambiare il testo di una traduzione aggiorna il contenuto pubblicato', async () => {
    const item = db.doc(`contentItems/${id('touch')}`);
    await item.set(contentItem());
    await item.collection('translations').doc('it').set(translation());
    await sleep(1500);
    const before = (await item.get()).data()?.updatedAt as Timestamp;
    const v0 = await version();
    await item.collection('translations').doc('it').update({ text: '[traduzione segnaposto corretta]' });
    await waitFor('updatedAt del contenuto', async () => {
      const u = (await item.get()).data()?.updatedAt as Timestamp;
      return u.toMillis() > before.toMillis();
    });
    await waitVersionAbove(v0);
  });

  it('una traduzione di un contenuto in bozza non tocca nulla', async () => {
    const item = db.doc(`contentItems/${id('drafttr')}`);
    await item.set(contentItem({ status: 'draft', verifiedBy: null, verifiedAt: null }));
    await item.collection('translations').doc('it').set(translation({ status: 'draft' }));
    await sleep(3000);
    assert.equal(((await item.get()).data()?.updatedAt as Timestamp).toMillis(), PAST.toMillis());
  });
});

describe('setAdminRole', () => {
  const password = 'password-di-prova';
  const email = (name: string) => `${name}.${run}@example.test`;
  const uids: Record<string, string> = {};

  async function idToken(name: string): Promise<string> {
    const res = await fetch(
      `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
      { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ email: email(name), password, returnSecureToken: true }) },
    );
    const body = (await res.json()) as { idToken?: string };
    assert.ok(body.idToken, `login fallito per ${name}`);
    return body.idToken;
  }

  async function call(as: string | null, data: unknown): Promise<{ status: number; body: { result?: unknown; error?: { status: string } } }> {
    const headers: Record<string, string> = { 'content-type': 'application/json' };
    if (as) headers.authorization = `Bearer ${await idToken(as)}`;
    const res = await fetch(`http://127.0.0.1:5001/${PROJECT}/${REGION}/setAdminRole`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ data }),
    });
    return { status: res.status, body: (await res.json()) as { result?: unknown; error?: { status: string } } };
  }

  before(async () => {
    for (const name of ['boss', 'utente', 'bersaglio']) {
      uids[name] = (await auth.createUser({ email: email(name), password })).uid;
    }
    await auth.setCustomUserClaims(uids.boss, { role: 'superAdmin' });
  });

  it('senza login: unauthenticated', async () => {
    const r = await call(null, { uid: 'x', role: 'translator' });
    assert.equal(r.body.error?.status, 'UNAUTHENTICATED');
  });

  it('un utente senza ruolo non può assegnare ruoli', async () => {
    const r = await call('utente', { uid: uids.utente, role: 'superAdmin' });
    assert.equal(r.body.error?.status, 'PERMISSION_DENIED');
    assert.equal((await auth.getUser(uids.utente)).customClaims?.role, undefined);
  });

  it('ruolo non valido o utente inesistente', async () => {
    assert.equal((await call('boss', { uid: uids.bersaglio, role: 'admin' })).body.error?.status, 'INVALID_ARGUMENT');
    assert.equal((await call('boss', { uid: 'nessuno', role: 'translator' })).body.error?.status, 'NOT_FOUND');
  });

  it('il superAdmin assegna un ruolo: claim, copia in adminRoles e audit', async () => {
    const r = await call('boss', { uid: uids.bersaglio, role: 'contentAdmin' });
    assert.equal(r.status, 200, JSON.stringify(r.body));
    assert.deepEqual(r.body.result, { uid: uids.bersaglio, role: 'contentAdmin' });
    assert.equal((await auth.getUser(uids.bersaglio)).customClaims?.role, 'contentAdmin');
    const copy = (await db.doc(`adminRoles/${uids.bersaglio}`).get()).data();
    assert.equal(copy?.role, 'contentAdmin');
    assert.equal(copy?.updatedBy, uids.boss);
    const audit = (await db.collection('adminAudit').where('target', '==', uids.bersaglio).get()).docs.map((d) => d.data());
    assert.equal(audit.length, 1);
    assert.equal(audit[0].actor, uids.boss);
    assert.equal(audit[0].to, 'contentAdmin');
    assert.equal(audit[0].sessionsRevoked, false);
  });

  it('il superAdmin toglie il ruolo: claim e copia rimossi, sessioni revocate', async () => {
    const r = await call('boss', { uid: uids.bersaglio, role: null });
    assert.equal(r.status, 200, JSON.stringify(r.body));
    const user = await auth.getUser(uids.bersaglio);
    assert.equal(user.customClaims?.role, undefined);
    assert.equal((await db.doc(`adminRoles/${uids.bersaglio}`).get()).exists, false);
    const audit = (await db.collection('adminAudit').where('target', '==', uids.bersaglio).where('to', '==', null).get()).docs;
    assert.equal(audit[0]?.data().sessionsRevoked, true);
  });

  it('il superAdmin non può togliersi il ruolo da solo', async () => {
    const r = await call('boss', { uid: uids.boss, role: null });
    assert.equal(r.body.error?.status, 'FAILED_PRECONDITION');
    assert.equal((await auth.getUser(uids.boss)).customClaims?.role, 'superAdmin');
  });
});
