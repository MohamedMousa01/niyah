// Cloud Functions di Niyah (architettura §4.4).
//
// - Ogni modifica visibile ai client incrementa meta/contentVersion: l'app fa
//   1 sola lettura all'avvio e scarica qualcosa solo se la versione è cambiata.
// - Un documento ritirato (non più pubblicato o disattivato) produce una
//   tombstone, perché le regole impediscono all'app di vederlo.
// - Nessun contenuto resta verified/published senza chi e quando l'ha verificato.
// - Le traduzioni seguono il loro contenuto quando viene archiviato.
// - Solo un superAdmin assegna i ruoli admin (custom claims).

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';

import {
  checkRoleRequest,
  Data,
  decideOnWrite,
  LANGS,
  nextClaims,
  shouldArchiveTranslations,
  shouldTouchParent,
  SYNCED,
  verificationGuard,
} from './logic';

initializeApp();
const db = getFirestore();

// ⚠️ La regione delle funzioni deve essere compatibile con la posizione del
// database Firestore scelta alla creazione del progetto (es. eur3 → europe-west1).
setGlobalOptions({ region: 'europe-west1', maxInstances: 10 });

async function applyDecision(collection: string, docId: string, before?: Data, after?: Data): Promise<void> {
  const d = decideOnWrite(collection, docId, before, after);
  if (!d.bumpVersion) return;
  const batch = db.batch();
  batch.set(
    db.doc('meta/contentVersion'),
    {
      version: Object.fromEntries(LANGS.map((l) => [l, FieldValue.increment(1)])),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  if (d.tombstone) {
    batch.create(db.collection('tombstones').doc(), { ...d.tombstone, removedAt: FieldValue.serverTimestamp() });
  }
  await batch.commit();
}

// ── Contenuti ──────────────────────────────────────────────────────────────

export const onContentItemWrite = onDocumentWritten('contentItems/{id}', async (event) => {
  const id = event.params.id;
  const before = event.data?.before.data();
  const after = event.data?.after.data();

  if (verificationGuard(after)) {
    // Gli eventi possono arrivare in ritardo: si ricontrolla lo stato attuale
    // in una transazione, per non annullare una correzione già fatta.
    const ref = event.data!.after.ref;
    const reverted = await db.runTransaction(async (tx) => {
      const current = (await tx.get(ref)).data();
      const to = verificationGuard(current);
      if (!to) return false;
      tx.update(ref, { status: to, updatedAt: FieldValue.serverTimestamp() });
      tx.create(db.collection('adminAudit').doc(), {
        action: 'verificationGuard',
        target: `contentItems/${id}`,
        from: current?.status,
        to,
        at: FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (reverted) logger.warn('Contenuto senza verifica riportato in review', { id, status: after?.status });
    // La scrittura "→ review" fa ripartire questa funzione: sarà quella a
    // incrementare la versione e a scrivere la tombstone se il documento era
    // già visibile. Qui non si fa altro, così non nascono doppioni.
    return;
  }

  if (shouldArchiveTranslations(before, after)) {
    const live = await db.collection(`contentItems/${id}/translations`).where('status', 'in', ['published', 'verified']).get();
    const batch = db.batch();
    live.docs.forEach((t) => batch.update(t.ref, { status: 'archived', updatedAt: FieldValue.serverTimestamp() }));
    if (!live.empty) await batch.commit();
  }

  await applyDecision('contentItems', id, before, after);
});

export const onTranslationWrite = onDocumentWritten('contentItems/{id}/translations/{lang}', async (event) => {
  const parentRef = db.doc(`contentItems/${event.params.id}`);
  const parent = (await parentRef.get()).data();
  if (!shouldTouchParent(parent, event.data?.before.data(), event.data?.after.data())) return;
  // Aggiornare il padre fa scattare onContentItemWrite → nuova versione.
  try {
    await parentRef.update({ updatedAt: FieldValue.serverTimestamp() });
  } catch (e) {
    // Padre cancellato nel frattempo: la sua tombstone basta.
    if ((e as { code?: number }).code !== 5) throw e;
  }
});

// ── Altre collezioni sincronizzate ─────────────────────────────────────────

function syncedTrigger(collection: string) {
  return onDocumentWritten(`${collection}/{id}`, async (event) => {
    await applyDecision(collection, event.params.id, event.data?.before.data(), event.data?.after.data());
  });
}

export const onCategoryWrite = syncedTrigger('categories');
export const onTopicWrite = syncedTrigger('topics');
export const onTopicContentWrite = syncedTrigger('topicContent');
export const onNotificationTemplateWrite = syncedTrigger('notificationTemplates');
export const onIslamicEventWrite = syncedTrigger('islamicEvents');

// Verifica in fase di caricamento: ogni collezione sincronizzata ha il suo trigger.
const covered = ['contentItems', 'categories', 'topics', 'topicContent', 'notificationTemplates', 'islamicEvents'];
for (const c of Object.keys(SYNCED)) {
  if (!covered.includes(c)) throw new Error(`Collezione sincronizzata senza trigger: ${c}`);
}

// ── Ruoli admin ────────────────────────────────────────────────────────────

/**
 * Chiamabile solo da un superAdmin. Dati: { uid: string, role: ruolo | null }.
 * Il nuovo ruolo vale dal prossimo rinnovo del token dell'utente; quando un
 * ruolo viene tolto o ridotto le sessioni dell'utente vengono revocate.
 */
export const setAdminRole = onCall(async (request) => {
  const data = (request.data ?? {}) as Data;
  const check = checkRoleRequest({
    callerUid: request.auth?.uid,
    callerRole: request.auth?.token?.role,
    targetUid: data.uid,
    role: data.role === undefined ? null : data.role,
  });
  if (!check.ok) throw new HttpsError(check.code, check.message);

  const auth = getAuth();
  const user = await auth.getUser(check.targetUid).catch(() => {
    throw new HttpsError('not-found', 'Utente non trovato.');
  });
  const previous = (user.customClaims?.role as string | undefined) ?? null;
  await auth.setCustomUserClaims(check.targetUid, nextClaims(user.customClaims, check.role));

  const roleRef = db.doc(`adminRoles/${check.targetUid}`);
  if (check.role === null) {
    await roleRef.delete();
  } else {
    await roleRef.set({ role: check.role, updatedAt: FieldValue.serverTimestamp(), updatedBy: request.auth!.uid });
  }
  // Un ruolo esistente tolto o cambiato: le sessioni vanno chiuse, così i
  // vecchi permessi non sopravvivono al rinnovo del token.
  const revoked = previous !== null && previous !== check.role;
  if (revoked) await auth.revokeRefreshTokens(check.targetUid);

  await db.collection('adminAudit').add({
    action: 'setAdminRole',
    actor: request.auth!.uid,
    target: check.targetUid,
    from: previous,
    to: check.role,
    sessionsRevoked: revoked,
    at: FieldValue.serverTimestamp(),
  });
  return { uid: check.targetUid, role: check.role };
});
