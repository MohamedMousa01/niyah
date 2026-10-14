// Test della logica pura (nessun emulatore): npm run test:unit

import assert from 'node:assert/strict';

import {
  checkRoleRequest,
  decideOnWrite,
  nextClaims,
  shouldArchiveTranslations,
  shouldTouchParent,
  verificationGuard,
} from '../src/logic';

const verified = { verifiedBy: 'uid-revisore', verifiedAt: new Date('2026-10-01T10:00:00Z') };

describe('decideOnWrite', () => {
  it('ignora le collezioni non sincronizzate', () => {
    assert.deepEqual(decideOnWrite('campaigns', 'c1', undefined, { active: true }), { bumpVersion: false });
    assert.deepEqual(decideOnWrite('users', 'u1', undefined, { a: 1 }), { bumpVersion: false });
  });

  it('una bozza mai visibile non costa nulla ai client', () => {
    assert.deepEqual(decideOnWrite('contentItems', 'x', undefined, { status: 'draft' }), { bumpVersion: false });
    assert.deepEqual(decideOnWrite('contentItems', 'x', { status: 'draft' }, { status: 'review' }), { bumpVersion: false });
    assert.deepEqual(decideOnWrite('categories', 'x', { active: false }, { active: false, icon: 'a' }), { bumpVersion: false });
    assert.deepEqual(decideOnWrite('categories', 'x', { active: false }, undefined), { bumpVersion: false });
  });

  it('pubblicazione e modifica di un documento visibile: nuova versione, nessuna tombstone', () => {
    assert.deepEqual(decideOnWrite('contentItems', 'x', { status: 'verified' }, { status: 'published' }), { bumpVersion: true });
    assert.deepEqual(decideOnWrite('contentItems', 'x', { status: 'published' }, { status: 'published' }), { bumpVersion: true });
    assert.deepEqual(decideOnWrite('topics', 't', undefined, { active: true }), { bumpVersion: true });
  });

  it('ritiro, disattivazione o cancellazione: tombstone', () => {
    assert.deepEqual(decideOnWrite('contentItems', 'x', { status: 'published' }, { status: 'archived' }), {
      bumpVersion: true,
      tombstone: { collection: 'contentItems', docId: 'x' },
    });
    assert.deepEqual(decideOnWrite('notificationTemplates', 'n', { active: true }, { active: false }), {
      bumpVersion: true,
      tombstone: { collection: 'notificationTemplates', docId: 'n' },
    });
    assert.deepEqual(decideOnWrite('islamicEvents', 'e', { active: true }, undefined), {
      bumpVersion: true,
      tombstone: { collection: 'islamicEvents', docId: 'e' },
    });
  });

  it('la tombstone di topicContent porta topicId e contentId', () => {
    const before = { active: true, topicId: 'pazienza', contentId: 'q_2_153' };
    assert.deepEqual(decideOnWrite('topicContent', 'pazienza_q_2_153', before, { ...before, active: false }), {
      bumpVersion: true,
      tombstone: { collection: 'topicContent', docId: 'pazienza_q_2_153', topicId: 'pazienza', contentId: 'q_2_153' },
    });
  });

  it('active deve essere proprio true', () => {
    assert.deepEqual(decideOnWrite('categories', 'x', undefined, { active: 'true' }), { bumpVersion: false });
  });
});

describe('verificationGuard', () => {
  it('lascia stare bozze, revisioni, archiviati e cancellazioni', () => {
    for (const status of ['draft', 'review', 'archived']) assert.equal(verificationGuard({ status }), null);
    assert.equal(verificationGuard(undefined), null);
  });

  it('accetta verified/published con chi e quando', () => {
    assert.equal(verificationGuard({ status: 'published', ...verified }), null);
    assert.equal(verificationGuard({ status: 'verified', ...verified }), null);
  });

  it('riporta in review se manca chi o quando', () => {
    assert.equal(verificationGuard({ status: 'published' }), 'review');
    assert.equal(verificationGuard({ status: 'published', verifiedBy: '  ', verifiedAt: verified.verifiedAt }), 'review');
    assert.equal(verificationGuard({ status: 'verified', verifiedBy: 'uid' }), 'review');
    assert.equal(verificationGuard({ status: 'published', verifiedBy: 'uid', verifiedAt: null }), 'review');
  });
});

describe('shouldArchiveTranslations', () => {
  it('quando un contenuto vivo viene archiviato o cancellato', () => {
    assert.equal(shouldArchiveTranslations({ status: 'published' }, { status: 'archived' }), true);
    assert.equal(shouldArchiveTranslations({ status: 'verified' }, { status: 'archived' }), true);
    assert.equal(shouldArchiveTranslations({ status: 'published' }, undefined), true);
  });

  it('non negli altri casi', () => {
    assert.equal(shouldArchiveTranslations({ status: 'draft' }, { status: 'archived' }), false);
    assert.equal(shouldArchiveTranslations({ status: 'published' }, { status: 'review' }), false);
    assert.equal(shouldArchiveTranslations(undefined, { status: 'archived' }), false);
  });
});

describe('shouldTouchParent', () => {
  const parent = { status: 'published' };
  const t = { status: 'published', text: 'segnaposto', referenceLabel: 'rif', translator: 'tr', translationSource: 'fonte' };

  it('solo se il padre è pubblicato', () => {
    assert.equal(shouldTouchParent(undefined, t, { ...t, text: 'altro' }), false);
    assert.equal(shouldTouchParent({ status: 'review' }, t, { ...t, text: 'altro' }), false);
  });

  it('creazione, cancellazione o campi visibili cambiati', () => {
    assert.equal(shouldTouchParent(parent, undefined, t), true);
    assert.equal(shouldTouchParent(parent, t, undefined), true);
    for (const f of ['text', 'referenceLabel', 'translator', 'translationSource', 'status']) {
      assert.equal(shouldTouchParent(parent, t, { ...t, [f]: 'cambiato' }), true, f);
    }
  });

  it('non per campi interni', () => {
    assert.equal(shouldTouchParent(parent, t, { ...t, notes: 'nota interna', updatedAt: 1 }), false);
  });
});

describe('checkRoleRequest', () => {
  const ok = { callerUid: 'boss', callerRole: 'superAdmin', targetUid: 'u2', role: 'contentAdmin' };

  it('serve un utente autenticato superAdmin', () => {
    assert.equal((checkRoleRequest({ ...ok, callerUid: undefined }) as { code: string }).code, 'unauthenticated');
    for (const callerRole of [undefined, '', 'contentAdmin', 'translator', 'SuperAdmin']) {
      assert.equal((checkRoleRequest({ ...ok, callerRole }) as { code: string }).code, 'permission-denied');
    }
  });

  it('valida uid e ruolo', () => {
    for (const targetUid of [undefined, '', 42, 'x'.repeat(129)]) {
      assert.equal((checkRoleRequest({ ...ok, targetUid }) as { code: string }).code, 'invalid-argument');
    }
    for (const role of ['admin', 'owner', 1, {}]) {
      assert.equal((checkRoleRequest({ ...ok, role }) as { code: string }).code, 'invalid-argument');
    }
  });

  it('un superAdmin non si toglie il ruolo da solo', () => {
    assert.equal((checkRoleRequest({ ...ok, targetUid: 'boss', role: null }) as { code: string }).code, 'failed-precondition');
    assert.equal((checkRoleRequest({ ...ok, targetUid: 'boss', role: 'translator' }) as { code: string }).code, 'failed-precondition');
    assert.deepEqual(checkRoleRequest({ ...ok, targetUid: 'boss', role: 'superAdmin' }), { ok: true, targetUid: 'boss', role: 'superAdmin' });
  });

  it('assegna e toglie ruoli', () => {
    assert.deepEqual(checkRoleRequest(ok), { ok: true, targetUid: 'u2', role: 'contentAdmin' });
    assert.deepEqual(checkRoleRequest({ ...ok, role: null }), { ok: true, targetUid: 'u2', role: null });
  });
});

describe('nextClaims', () => {
  it('cambia solo role e conserva gli altri claim', () => {
    assert.deepEqual(nextClaims({ beta: true, role: 'translator' }, 'contentAdmin'), { beta: true, role: 'contentAdmin' });
    assert.deepEqual(nextClaims({ beta: true, role: 'translator' }, null), { beta: true });
    assert.deepEqual(nextClaims(undefined, 'superAdmin'), { role: 'superAdmin' });
  });
});
