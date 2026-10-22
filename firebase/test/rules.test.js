// Test delle regole Firestore di Niyah contro l'emulatore.
// Avvio: npm test  (firebase emulators:exec --only firestore --project demo-niyah "mocha test")
//
// Nota: i testi arabi/tradotti qui sotto sono SEGNAPOSTO, non citazioni reali.

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  collectionGroup,
  query,
  where,
  orderBy,
  limit,
  startAfter,
  getDocs,
  documentId,
  serverTimestamp,
  Timestamp,
  setLogLevel,
} = require('firebase/firestore');

const PROJECT_ID = 'demo-niyah';
const PAST = Timestamp.fromDate(new Date('2024-01-01T00:00:00Z'));

let testEnv;

// ------------------------------------------------------------------ contesti
const anon = () => testEnv.unauthenticatedContext().firestore();
const user = (uid) => testEnv.authenticatedContext(uid).firestore();
const withRole = (role, uid = `${role}-uid`) =>
  testEnv.authenticatedContext(uid, { role }).firestore();

// ------------------------------------------------------------------ fixture
const quran = (over = {}) => ({
  type: 'quran',
  surah: 2,
  ayahFrom: 255,
  arabicText: '[testo arabo segnaposto]',
  status: 'draft',
  categoryIds: ['quran'],
  updatedAt: serverTimestamp(),
  ...over,
});

const hadith = (over = {}) => ({
  type: 'hadith',
  arabicText: '[testo arabo segnaposto]',
  collection: 'bukhari',
  hadithNumber: '1',
  grade: 'sahih',
  sourceRef: '[riferimento segnaposto]',
  status: 'draft',
  updatedAt: serverTimestamp(),
  ...over,
});

const verified = { verifiedBy: 'revisore-1', verifiedAt: PAST };

const translation = (over = {}) => ({
  text: '[traduzione segnaposto]',
  referenceLabel: '[riferimento segnaposto]',
  translator: '[traduttore segnaposto]',
  translationSource: '[fonte segnaposto]',
  status: 'draft',
  updatedAt: serverTimestamp(),
  ...over,
});

const category = (over = {}) => ({
  parentId: null,
  icon: 'book',
  order: 1,
  active: true,
  names: { it: 'Corano', en: 'Quran', ar: 'القرآن', fr: 'Coran' },
  updatedAt: serverTimestamp(),
  ...over,
});

const campaign = (over = {}) => ({
  name: 'Ramadan',
  description: 'Campagna di prova',
  startAt: PAST,
  endAt: Timestamp.fromDate(new Date('2024-02-01T00:00:00Z')),
  active: true,
  targetLanguages: ['it'],
  targetCategories: [],
  notificationTemplateRefs: [],
  fcmTopics: ['campaign_ramadan'],
  updatedAt: serverTimestamp(),
  ...over,
});

const reminder = (over = {}) => ({
  kind: 'personal',
  title: 'Leggi al-Kahf',
  scheduleType: 'weekly',
  time: '09:00',
  enabled: true,
  updatedAt: PAST,
  ...over,
});

async function seed() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'contentItems/pub1'), quran({ status: 'published', ...verified }));
    await setDoc(doc(db, 'contentItems/draft1'), hadith({ status: 'draft' }));
    await setDoc(doc(db, 'contentItems/pub1/translations/it'), translation({ status: 'published' }));
    await setDoc(doc(db, 'contentItems/pub1/translations/fr'), translation({ status: 'draft' }));
    await setDoc(doc(db, 'contentItems/pub1/translations/en'), translation({ status: 'review' }));
    await setDoc(doc(db, 'contentItems/draft1/translations/it'), translation({ status: 'review' }));

    await setDoc(doc(db, 'categories/catOn'), category({ active: true }));
    await setDoc(doc(db, 'categories/catOff'), category({ active: false }));
    await setDoc(doc(db, 'campaigns/campOn'), campaign({ active: true }));
    await setDoc(doc(db, 'campaigns/campOff'), campaign({ active: false }));

    await setDoc(doc(db, 'meta/contentVersion'), {
      version: { it: 3, en: 3, ar: 3, fr: 3 },
      updatedAt: serverTimestamp(),
    });
    await setDoc(doc(db, 'tombstones/t1'), {
      collection: 'contentItems',
      docId: 'old1',
      removedAt: serverTimestamp(),
    });

    await setDoc(doc(db, 'users/alice'), { language: 'it', accountType: 'email' });
    await setDoc(doc(db, 'users/alice/reminders/r1'), reminder());
    await setDoc(doc(db, 'users/alice/preferences/main'), { selectedCategories: ['quran'] });

    await setDoc(doc(db, 'adminRoles/contentAdmin-uid'), { role: 'contentAdmin' });
    await setDoc(doc(db, 'adminAudit/a1'), { who: 'super', what: 'setRole', when: PAST });

    await setDoc(doc(db, 'secretStuff/x'), { a: 1 });
  });
}

// ------------------------------------------------------------------ setup
before(async () => {
  // I PERMISSION_DENIED attesi non devono riempire l'output.
  setLogLevel('silent');
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed();
});

// =================================================================== test
describe('Contenuti pubblici: lettura', () => {
  it('anonimo legge un contentItem pubblicato', async () => {
    await assertSucceeds(getDoc(doc(anon(), 'contentItems/pub1')));
  });

  it('anonimo NON legge un contentItem in bozza', async () => {
    await assertFails(getDoc(doc(anon(), 'contentItems/draft1')));
  });

  it('query filtrata status == published (sync incrementale) è permessa', async () => {
    const db = anon();
    await assertSucceeds(getDocs(query(collection(db, 'contentItems'), where('status', '==', 'published'))));
    const snap = await getDocs(
      query(
        collection(db, 'contentItems'),
        where('status', '==', 'published'),
        where('updatedAt', '>', PAST),
        orderBy('updatedAt'),
        limit(100),
      ),
    );
    if (snap.size !== 1 || snap.docs[0].id !== 'pub1') throw new Error(`risultati inattesi: ${snap.size}`);
  });

  it('query senza filtro o con status diverso da published è negata', async () => {
    const db = anon();
    await assertFails(getDocs(collection(db, 'contentItems')));
    await assertFails(getDocs(query(collection(db, 'contentItems'), where('status', '==', 'draft'))));
  });

  it('anonimo legge una traduzione pubblicata ma NON una in bozza/revisione', async () => {
    const db = anon();
    await assertSucceeds(getDoc(doc(db, 'contentItems/pub1/translations/it')));
    await assertFails(getDoc(doc(db, 'contentItems/pub1/translations/fr')));
    await assertFails(getDoc(doc(db, 'contentItems/pub1/translations/en')));
  });

  it('query collection-group sulle traduzioni: solo con filtro published', async () => {
    const db = anon();
    await assertSucceeds(
      getDocs(
        query(
          collectionGroup(db, 'translations'),
          where('status', '==', 'published'),
          where('updatedAt', '>', PAST),
          orderBy('updatedAt'),
        ),
      ),
    );
    await assertFails(getDocs(collectionGroup(db, 'translations')));
    await assertFails(getDocs(query(collection(db, 'contentItems/pub1/translations'))));
    await assertSucceeds(
      getDocs(query(collection(db, 'contentItems/pub1/translations'), where('status', '==', 'published'))),
    );
  });

  it('la sync legge le traduzioni con una query: un get su una lingua mancante o in bozza è negato', async () => {
    // Stessa query di sync_niyah_content.dart. Un get diretto (o una query
    // filtrata per documentId) su una traduzione in bozza o inesistente viene
    // negato e farebbe fallire tutta la sincronizzazione.
    const db = anon();
    const published = await assertSucceeds(
      getDocs(query(collection(db, 'contentItems/pub1/translations'), where('status', '==', 'published'))),
    );
    assert.deepEqual(published.docs.map((d) => d.id), ['it']);
    await assertFails(getDoc(doc(db, 'contentItems/pub1/translations/ar')));
    await assertFails(
      getDocs(
        query(collection(db, 'contentItems/pub1/translations'), where('status', '==', 'published'), where(documentId(), '==', 'fr')),
      ),
    );
  });

  it('collezioni con active: pubblico vede solo active == true', async () => {
    const db = anon();
    await assertSucceeds(getDoc(doc(db, 'categories/catOn')));
    await assertFails(getDoc(doc(db, 'categories/catOff')));
    await assertSucceeds(
      getDocs(
        query(collection(db, 'categories'), where('active', '==', true), where('updatedAt', '>', PAST), orderBy('updatedAt')),
      ),
    );
    await assertFails(getDocs(collection(db, 'categories')));
    await assertSucceeds(getDoc(doc(db, 'campaigns/campOn')));
    await assertFails(getDoc(doc(db, 'campaigns/campOff')));
  });

  it('meta/contentVersion è leggibile da chiunque, non scrivibile', async () => {
    await assertSucceeds(getDoc(doc(anon(), 'meta/contentVersion')));
    await assertFails(setDoc(doc(user('alice'), 'meta/contentVersion'), { version: {} }));
    await assertFails(setDoc(doc(withRole('superAdmin'), 'meta/contentVersion'), { version: {} }));
  });

  it('gli admin leggono i documenti non pubblicati delle collezioni che gestiscono', async () => {
    await assertSucceeds(getDoc(doc(withRole('contentAdmin'), 'contentItems/draft1')));
    await assertSucceeds(getDoc(doc(withRole('translator'), 'contentItems/draft1')));
    await assertSucceeds(getDoc(doc(withRole('translator'), 'contentItems/pub1/translations/fr')));
    await assertSucceeds(getDocs(collection(withRole('contentAdmin'), 'contentItems')));
    await assertSucceeds(getDoc(doc(withRole('contentAdmin'), 'categories/catOff')));
    await assertSucceeds(getDoc(doc(withRole('notificationAdmin'), 'campaigns/campOff')));
    // ma non quelli che non gestiscono
    await assertFails(getDoc(doc(withRole('contentAdmin'), 'campaigns/campOff')));
    await assertFails(getDoc(doc(withRole('notificationAdmin'), 'contentItems/draft1')));
    await assertFails(getDoc(doc(withRole('notificationAdmin'), 'categories/catOff')));
  });
});

describe('Traduttore', () => {
  const tr = () => withRole('translator');

  it('può creare e aggiornare traduzioni in draft/review', async () => {
    await assertSucceeds(setDoc(doc(tr(), 'contentItems/draft1/translations/fr'), translation({ status: 'draft' })));
    await assertSucceeds(
      updateDoc(doc(tr(), 'contentItems/draft1/translations/fr'), { status: 'review', updatedAt: serverTimestamp() }),
    );
  });

  it('NON può pubblicare né verificare una traduzione', async () => {
    await assertFails(setDoc(doc(tr(), 'contentItems/pub1/translations/ar'), translation({ status: 'published' })));
    await assertFails(
      updateDoc(doc(tr(), 'contentItems/pub1/translations/fr'), { status: 'published', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(tr(), 'contentItems/pub1/translations/fr'), { status: 'verified', updatedAt: serverTimestamp() }),
    );
    // né impostare i campi della revisione
    await assertFails(setDoc(doc(tr(), 'contentItems/pub1/translations/ar'), translation({ ...verified })));
    await assertFails(
      updateDoc(doc(tr(), 'contentItems/pub1/translations/fr'), { ...verified, updatedAt: serverTimestamp() }),
    );
  });

  it('NON può modificare o ritirare una traduzione già pubblicata', async () => {
    await assertFails(
      updateDoc(doc(tr(), 'contentItems/pub1/translations/it'), { text: 'altro', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(tr(), 'contentItems/pub1/translations/it'), { status: 'draft', updatedAt: serverTimestamp() }),
    );
  });

  it('NON può scrivere i documenti contentItems né cancellare traduzioni', async () => {
    await assertFails(setDoc(doc(tr(), 'contentItems/new1'), quran()));
    await assertFails(updateDoc(doc(tr(), 'contentItems/draft1'), { grade: 'daif', updatedAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(tr(), 'contentItems/pub1/translations/fr')));
  });

  it('NON può creare traduzioni per un contenuto inesistente o con lingua non valida', async () => {
    await assertFails(setDoc(doc(tr(), 'contentItems/ghost/translations/it'), translation()));
    await assertFails(setDoc(doc(tr(), 'contentItems/draft1/translations/Italiano!'), translation()));
  });
});

describe('contentAdmin: pubblicazione e validazione', () => {
  const ca = () => withRole('contentAdmin');

  it('NON può pubblicare senza verifiedBy/verifiedAt', async () => {
    await assertFails(setDoc(doc(ca(), 'contentItems/new1'), quran({ status: 'published' })));
    await assertFails(
      setDoc(doc(ca(), 'contentItems/new1'), quran({ status: 'published', verifiedBy: 'revisore-1' })),
    );
    await assertFails(
      setDoc(doc(ca(), 'contentItems/new1'), quran({ status: 'published', verifiedAt: PAST })),
    );
    await assertFails(
      setDoc(doc(ca(), 'contentItems/new1'), quran({ status: 'published', verifiedBy: '', verifiedAt: PAST })),
    );
    await assertFails(
      updateDoc(doc(ca(), 'contentItems/draft1'), { status: 'published', updatedAt: serverTimestamp() }),
    );
  });

  it('nemmeno un superAdmin può pubblicare senza verifica', async () => {
    await assertFails(
      updateDoc(doc(withRole('superAdmin'), 'contentItems/draft1'), { status: 'published', updatedAt: serverTimestamp() }),
    );
  });

  it('può pubblicare con verifiedBy (stringa) e verifiedAt (timestamp)', async () => {
    await assertSucceeds(setDoc(doc(ca(), 'contentItems/new1'), quran({ status: 'published', ...verified })));
    await assertSucceeds(
      updateDoc(doc(ca(), 'contentItems/draft1'), {
        status: 'published',
        verifiedBy: 'revisore-2',
        verifiedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('valida i campi di un versetto', async () => {
    await assertSucceeds(setDoc(doc(ca(), 'contentItems/q1'), quran({ ayahTo: 257 })));
    await assertFails(setDoc(doc(ca(), 'contentItems/q2'), quran({ surah: 115 })));
    await assertFails(setDoc(doc(ca(), 'contentItems/q2'), quran({ surah: 0 })));
    await assertFails(setDoc(doc(ca(), 'contentItems/q2'), quran({ surah: '2' })));
    await assertFails(setDoc(doc(ca(), 'contentItems/q2'), quran({ ayahFrom: 0 })));
    await assertFails(setDoc(doc(ca(), 'contentItems/q2'), quran({ ayahFrom: 1.5 })));
    await assertFails(setDoc(doc(ca(), 'contentItems/q2'), quran({ ayahTo: 254 })));
    await assertFails(setDoc(doc(ca(), 'contentItems/q2'), quran({ arabicText: null })));
  });

  it('valida i campi di un hadith', async () => {
    await assertSucceeds(setDoc(doc(ca(), 'contentItems/h1'), hadith()));
    await assertFails(setDoc(doc(ca(), 'contentItems/h2'), hadith({ grade: null })));
    await assertFails(setDoc(doc(ca(), 'contentItems/h2'), hadith({ collection: '' })));
    await assertFails(setDoc(doc(ca(), 'contentItems/h2'), hadith({ sourceRef: 42 })));
    // hadith verificato senza numero
    await assertFails(
      setDoc(doc(ca(), 'contentItems/h2'), hadith({ status: 'verified', hadithNumber: null, ...verified })),
    );
  });

  it('rifiuta type/status sconosciuti, campi extra e updatedAt mancante', async () => {
    await assertFails(setDoc(doc(ca(), 'contentItems/x'), quran({ type: 'poem' })));
    await assertFails(setDoc(doc(ca(), 'contentItems/x'), quran({ status: 'live' })));
    await assertFails(setDoc(doc(ca(), 'contentItems/x'), quran({ isAdmin: true })));
    const { updatedAt, ...noUpdatedAt } = quran();
    await assertFails(setDoc(doc(ca(), 'contentItems/x'), noUpdatedAt));
    await assertSucceeds(setDoc(doc(ca(), 'contentItems/d1'), { type: 'dhikr', status: 'draft', updatedAt: serverTimestamp() }));
  });

  it('pubblica traduzioni solo di contenuti verificati/pubblicati e con traduttore', async () => {
    await assertSucceeds(
      updateDoc(doc(ca(), 'contentItems/pub1/translations/fr'), { status: 'published', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(ca(), 'contentItems/draft1/translations/it'), { status: 'published', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(ca(), 'contentItems/pub1/translations/ar'), translation({ status: 'published', translator: '' })),
    );
    // senza riferimento o fonte della traduzione non si pubblica
    await assertFails(
      setDoc(doc(ca(), 'contentItems/pub1/translations/ar'), translation({ status: 'published', referenceLabel: '' })),
    );
    await assertFails(
      setDoc(doc(ca(), 'contentItems/pub1/translations/ar'), translation({ status: 'published', translationSource: '' })),
    );
  });

  it('nessuno cancella contenuti pubblici (si archivia)', async () => {
    await assertFails(deleteDoc(doc(ca(), 'contentItems/draft1')));
    await assertFails(deleteDoc(doc(withRole('superAdmin'), 'contentItems/pub1')));
    await assertFails(deleteDoc(doc(ca(), 'categories/catOff')));
    await assertSucceeds(
      updateDoc(doc(ca(), 'contentItems/pub1'), { status: 'archived', updatedAt: serverTimestamp() }),
    );
  });

  it('separazione dei ruoli: contentAdmin non scrive campagne, notificationAdmin non scrive contenuti', async () => {
    await assertFails(setDoc(doc(ca(), 'campaigns/c1'), campaign()));
    await assertSucceeds(setDoc(doc(ca(), 'categories/c1'), category()));
    await assertSucceeds(setDoc(doc(withRole('notificationAdmin'), 'campaigns/c1'), campaign()));
    await assertFails(setDoc(doc(withRole('notificationAdmin'), 'categories/c2'), category()));
    await assertFails(setDoc(doc(withRole('notificationAdmin'), 'contentItems/n1'), quran()));
    await assertFails(setDoc(doc(withRole('notificationAdmin'), 'campaigns/c2'), campaign({ active: 'yes' })));
  });

  it('modelli di notifica: campi usati dalla sync dell\'app, scritti solo da notificationAdmin', async () => {
    const tpl = {
      categoryId: 'kahf', section: 'weekly', channel: 'quran', contentType: null, sourceContentId: 'pub1',
      defaultSchedule: { schedule_type: 'weekly', time: '09:00', days_mask: 16 },
      editableByUser: true, seasonal: false, active: true,
      i18n: { it: { title: '[titolo]', body: '[testo]' } }, updatedAt: serverTimestamp(),
    };
    await assertSucceeds(setDoc(doc(withRole('notificationAdmin'), 'notificationTemplates/t1'), tpl));
    await assertFails(setDoc(doc(ca(), 'notificationTemplates/t2'), tpl));
    await assertFails(setDoc(doc(withRole('notificationAdmin'), 'notificationTemplates/t3'), { ...tpl, channel: 5 }));
    await assertFails(setDoc(doc(withRole('notificationAdmin'), 'notificationTemplates/t4'), { ...tpl, extra: 'x' }));
    // Gruppo e icona per "Aggiungi un promemoria" nell'app.
    await assertSucceeds(setDoc(doc(withRole('notificationAdmin'), 'notificationTemplates/t5'), { ...tpl, groupKey: 'weekly', icon: 'book' }));
    await assertSucceeds(setDoc(doc(withRole('notificationAdmin'), 'notificationTemplates/t6'), { ...tpl, groupKey: null }));
    await assertFails(setDoc(doc(withRole('notificationAdmin'), 'notificationTemplates/t7'), { ...tpl, groupKey: 'monthly' }));
    await assertFails(setDoc(doc(withRole('notificationAdmin'), 'notificationTemplates/t8'), { ...tpl, icon: 3 }));
  });

  it('topicContent: id = topicId_contentId e flag active obbligatorio', async () => {
    const base = { topicId: 't1', contentId: 'pub1', order: 1, active: true, updatedAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(ca(), 'topicContent/t1_pub1'), base));
    await assertFails(setDoc(doc(ca(), 'topicContent/qualcosa'), base));
    const { active, ...noActive } = base;
    await assertFails(setDoc(doc(ca(), 'topicContent/t1_pub1'), noActive));
  });
});

describe('Utente normale e ruoli', () => {
  it('un utente normale NON scrive contenuti, campagne, adminRoles', async () => {
    const db = user('alice');
    await assertFails(setDoc(doc(db, 'contentItems/x'), quran()));
    await assertFails(updateDoc(doc(db, 'contentItems/pub1'), { arabicText: 'manomesso', updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(db, 'contentItems/pub1/translations/de'), translation()));
    await assertFails(setDoc(doc(db, 'campaigns/c1'), campaign()));
    await assertFails(setDoc(doc(db, 'categories/c1'), category()));
    await assertFails(setDoc(doc(db, 'adminRoles/alice'), { role: 'superAdmin' }));
    await assertFails(setDoc(doc(anon(), 'contentItems/x'), quran()));
  });

  it('un ruolo inventato nei claims non dà privilegi', async () => {
    await assertFails(setDoc(doc(withRole('admin'), 'contentItems/x'), quran()));
    await assertFails(getDoc(doc(withRole('admin'), 'contentItems/draft1')));
  });

  it('adminRoles: leggibile dal proprietario o dal superAdmin, mai scrivibile', async () => {
    await assertSucceeds(getDoc(doc(withRole('contentAdmin'), 'adminRoles/contentAdmin-uid')));
    await assertSucceeds(getDoc(doc(withRole('superAdmin'), 'adminRoles/contentAdmin-uid')));
    await assertFails(getDoc(doc(user('alice'), 'adminRoles/contentAdmin-uid')));
    await assertFails(setDoc(doc(withRole('superAdmin'), 'adminRoles/alice'), { role: 'contentAdmin' }));
  });

  it('adminAudit: solo superAdmin legge, nessuno scrive', async () => {
    await assertSucceeds(getDoc(doc(withRole('superAdmin'), 'adminAudit/a1')));
    await assertFails(getDoc(doc(withRole('contentAdmin'), 'adminAudit/a1')));
    await assertFails(getDoc(doc(user('alice'), 'adminAudit/a1')));
    await assertFails(setDoc(doc(withRole('superAdmin'), 'adminAudit/a2'), { who: 'x' }));
  });
});

describe('Dati utente privati', () => {
  it('il proprietario legge e scrive i propri dati', async () => {
    const db = user('alice');
    await assertSucceeds(getDoc(doc(db, 'users/alice')));
    await assertSucceeds(setDoc(doc(db, 'users/alice'), { language: 'ar' }, { merge: true }));
    await assertSucceeds(getDoc(doc(db, 'users/alice/preferences/main')));
    await assertSucceeds(setDoc(doc(db, 'users/alice/location/main'), { city: 'Milano', latRounded: 45.46 }));
    await assertSucceeds(getDocs(collection(db, 'users/alice/reminders')));
  });

  it("l'utente A NON legge né scrive i dati dell'utente B", async () => {
    const db = user('bob');
    await assertFails(getDoc(doc(db, 'users/alice')));
    await assertFails(setDoc(doc(db, 'users/alice'), { language: 'fr' }));
    await assertFails(getDoc(doc(db, 'users/alice/reminders/r1')));
    await assertFails(getDocs(collection(db, 'users/alice/reminders')));
    await assertFails(setDoc(doc(db, 'users/alice/reminders/r2'), reminder()));
    await assertFails(getDoc(doc(db, 'users/alice/preferences/main')));
    await assertFails(deleteDoc(doc(db, 'users/alice/reminders/r1')));
    await assertFails(getDoc(doc(anon(), 'users/alice')));
  });

  it('nessun admin legge i dati degli utenti', async () => {
    for (const role of ['superAdmin', 'contentAdmin', 'notificationAdmin', 'translator']) {
      const db = withRole(role);
      await assertFails(getDoc(doc(db, 'users/alice')));
      await assertFails(getDoc(doc(db, 'users/alice/reminders/r1')));
      await assertFails(getDocs(collection(db, 'users/alice/reminders')));
      await assertFails(getDoc(doc(db, 'users/alice/preferences/main')));
      await assertFails(getDocs(collectionGroup(db, 'reminders')));
    }
  });

  it('un promemoria "struggle" viene rifiutato', async () => {
    const db = user('alice');
    await assertFails(setDoc(doc(db, 'users/alice/reminders/s1'), reminder({ kind: 'struggle', title: 'privato' })));
    await assertFails(setDoc(doc(db, 'users/alice/reminders/s1'), reminder({ kind: 'Struggle' })));
    await assertFails(updateDoc(doc(db, 'users/alice/reminders/r1'), { kind: 'struggle' }));
    await assertFails(setDoc(doc(db, 'users/alice/reminders/s2'), reminder({ kind: null })));
    await assertFails(setDoc(doc(db, 'users/alice/reminders/s3'), reminder({ syncPolicy: 'local_only' })));
    // né tramite una sottocollezione alternativa annidata
    await assertFails(setDoc(doc(db, 'users/alice/reminders/r1/copies/s1'), reminder({ kind: 'struggle' })));
  });

  it('un promemoria normale viene accettato e il proprietario può cancellarlo', async () => {
    const db = user('alice');
    await assertSucceeds(setDoc(doc(db, 'users/alice/reminders/r2'), reminder({ kind: 'prayer', syncPolicy: 'cloud' })));
    await assertSucceeds(updateDoc(doc(db, 'users/alice/reminders/r1'), { enabled: false, deleted: 1 }));
    await assertSucceeds(deleteDoc(doc(db, 'users/alice/reminders/r1')));
    await assertSucceeds(deleteDoc(doc(db, 'users/alice')));
  });

  it("l'utente non può creare una sottocollezione 'translations' (riservata, pubblica)", async () => {
    const db = user('alice');
    await assertFails(setDoc(doc(db, 'users/alice/translations/it'), translation({ status: 'published' })));
    // nemmeno annidata più in profondità (sarebbe letta dalla regola collection-group)
    await assertFails(
      setDoc(doc(db, 'users/alice/preferences/main/translations/it'), translation({ status: 'published' })),
    );
  });
});

describe('Tombstones', () => {
  it('lettura pubblica (get e query removedAt > X orderBy removedAt)', async () => {
    const db = anon();
    await assertSucceeds(getDoc(doc(db, 'tombstones/t1')));
    const snap = await assertSucceeds(
      getDocs(query(collection(db, 'tombstones'), where('removedAt', '>', PAST), orderBy('removedAt'))),
    );
    if (snap.size !== 1) throw new Error(`attesi 1 tombstone, trovati ${snap.size}`);
  });

  it('nessuna scrittura dai client, nemmeno superAdmin', async () => {
    const t = { collection: 'contentItems', docId: 'pub1', removedAt: serverTimestamp() };
    await assertFails(setDoc(doc(anon(), 'tombstones/t2'), t));
    await assertFails(setDoc(doc(user('alice'), 'tombstones/t2'), t));
    await assertFails(setDoc(doc(withRole('superAdmin'), 'tombstones/t2'), t));
    await assertFails(updateDoc(doc(withRole('contentAdmin'), 'tombstones/t1'), { docId: 'x' }));
    await assertFails(deleteDoc(doc(withRole('superAdmin'), 'tombstones/t1')));
  });
});

describe("Query della sync dell'app (apps/niyah, FirestoreContentSource)", () => {
  // updatedAt >= minimo, orderBy updatedAt poi id, startAfter (updatedAt, id).
  const MIN = new Timestamp(-62135596800, 0);
  const syncQuery = (db, coll, ...filter) =>
    query(collection(db, coll), ...filter, where('updatedAt', '>=', MIN), orderBy('updatedAt'), orderBy(documentId()),
      startAfter(new Timestamp(0, 0), 'a'), limit(100));

  it('anonima, con il filtro richiesto dalle regole', async () => {
    const snap = await assertSucceeds(getDocs(syncQuery(anon(), 'categories', where('active', '==', true))));
    assert.deepStrictEqual(snap.docs.map((d) => d.id), ['catOn']);
    await assertSucceeds(getDocs(syncQuery(anon(), 'notificationTemplates', where('active', '==', true))));
    await assertSucceeds(getDocs(syncQuery(anon(), 'contentItems', where('status', '==', 'published'))));
    await assertFails(getDocs(syncQuery(anon(), 'categories')));
    const tomb = await assertSucceeds(getDocs(query(collection(anon(), 'tombstones'), where('removedAt', '>=', MIN),
      orderBy('removedAt'), orderBy(documentId()), limit(100))));
    assert.strictEqual(tomb.size, 1);
  });
});

describe('Default deny', () => {
  it('una collezione sconosciuta è negata a tutti', async () => {
    for (const db of [anon(), user('alice'), withRole('superAdmin')]) {
      await assertFails(getDoc(doc(db, 'secretStuff/x')));
      await assertFails(getDocs(collection(db, 'secretStuff')));
      await assertFails(setDoc(doc(db, 'secretStuff/y'), { a: 1 }));
    }
  });

  it('sottocollezioni non previste sotto i contenuti sono negate', async () => {
    await assertFails(setDoc(doc(withRole('superAdmin'), 'contentItems/pub1/notes/n1'), { a: 1 }));
    await assertFails(setDoc(doc(withRole('superAdmin'), 'categories/catOn/extra/n1'), { a: 1 }));
  });
});
