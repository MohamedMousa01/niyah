// Logica pura delle Cloud Functions di Niyah: decide COSA fare a fronte di una
// scrittura, senza toccare Firestore. Testata in test/unit.test.ts.

export type Data = Record<string, unknown>;

export const LANGS = ['it', 'en', 'ar', 'fr', 'es', 'de'] as const;

export const ADMIN_ROLES = ['superAdmin', 'contentAdmin', 'notificationAdmin', 'translator'] as const;
export type AdminRole = (typeof ADMIN_ROLES)[number];

/**
 * Collezioni sincronizzate dall'app e condizione che le rende visibili al
 * client (deve coincidere con firestore.rules e con sync_niyah_content.dart).
 */
export const SYNCED: Record<string, (d: Data) => boolean> = {
  contentItems: (d) => d.status === 'published',
  categories: (d) => d.active === true,
  topics: (d) => d.active === true,
  topicContent: (d) => d.active === true,
  notificationTemplates: (d) => d.active === true,
  islamicEvents: (d) => d.active === true,
};

export interface Tombstone {
  collection: string;
  docId: string;
  topicId?: string;
  contentId?: string;
}

export interface WriteDecision {
  /** Incrementare meta/contentVersion: i client devono sincronizzare. */
  bumpVersion: boolean;
  /** Il documento non è più visibile ai client: segnalarlo. */
  tombstone?: Tombstone;
}

/**
 * Un documento conta per i client solo se era o è visibile. Una bozza
 * modificata non costa nulla ai client; un documento ritirato produce una
 * tombstone, perché le regole impediscono al client di vederlo.
 */
export function decideOnWrite(collection: string, docId: string, before?: Data, after?: Data): WriteDecision {
  const visible = SYNCED[collection];
  if (!visible) return { bumpVersion: false };
  const was = before !== undefined && visible(before);
  const is = after !== undefined && visible(after);
  if (!was && !is) return { bumpVersion: false };
  if (was && !is) {
    const t: Tombstone = { collection, docId };
    if (collection === 'topicContent') {
      const src = before as Data;
      if (typeof src.topicId === 'string') t.topicId = src.topicId;
      if (typeof src.contentId === 'string') t.contentId = src.contentId;
    }
    return { bumpVersion: true, tombstone: t };
  }
  return { bumpVersion: true };
}

const nonEmpty = (v: unknown) => typeof v === 'string' && v.trim().length > 0;

/**
 * Seconda difesa oltre alle regole (l'Admin SDK e la console le ignorano):
 * un contenuto verified/published senza chi e quando l'ha verificato torna
 * in "review". Restituisce lo stato a cui riportarlo, oppure null.
 */
export function verificationGuard(after?: Data): 'review' | null {
  if (!after) return null;
  if (after.status !== 'verified' && after.status !== 'published') return null;
  const ok = nonEmpty(after.verifiedBy) && after.verifiedAt != null;
  return ok ? null : 'review';
}

/**
 * Quando un contenuto viene archiviato, le sue traduzioni pubblicate o
 * verificate vanno archiviate con lui (le regole non possono controllare
 * lo stato del padre nelle query pubbliche sulle traduzioni).
 */
export function shouldArchiveTranslations(before?: Data, after?: Data): boolean {
  const live = (d?: Data) => d !== undefined && (d.status === 'published' || d.status === 'verified');
  return live(before) && (after === undefined || after.status === 'archived');
}

/**
 * Una traduzione cambiata su un contenuto pubblicato: il padre va "toccato"
 * (updatedAt) perché la sync incrementale lo riscarichi.
 */
export function shouldTouchParent(parent: Data | undefined, before?: Data, after?: Data): boolean {
  if (!parent || parent.status !== 'published') return false;
  const fields = ['text', 'referenceLabel', 'translator', 'translationSource', 'status'];
  if (!before || !after) return true;
  return fields.some((f) => JSON.stringify(before[f]) !== JSON.stringify(after[f]));
}

export interface RoleRequest {
  callerUid: string | undefined;
  callerRole: unknown;
  targetUid: unknown;
  role: unknown;
}

export type RoleCheck =
  | { ok: true; targetUid: string; role: AdminRole | null }
  | { ok: false; code: 'unauthenticated' | 'permission-denied' | 'invalid-argument' | 'failed-precondition'; message: string };

/** Solo un superAdmin assegna o toglie ruoli, e non può togliere il proprio. */
export function checkRoleRequest(r: RoleRequest): RoleCheck {
  if (!r.callerUid) return { ok: false, code: 'unauthenticated', message: 'Accesso richiesto.' };
  if (r.callerRole !== 'superAdmin') return { ok: false, code: 'permission-denied', message: 'Solo un superAdmin può gestire i ruoli.' };
  if (typeof r.targetUid !== 'string' || r.targetUid.length === 0 || r.targetUid.length > 128) {
    return { ok: false, code: 'invalid-argument', message: 'uid non valido.' };
  }
  if (r.role !== null && !(ADMIN_ROLES as readonly unknown[]).includes(r.role)) {
    return { ok: false, code: 'invalid-argument', message: `Ruolo non valido. Valori ammessi: ${ADMIN_ROLES.join(', ')} o null.` };
  }
  if (r.targetUid === r.callerUid && r.role !== 'superAdmin') {
    return { ok: false, code: 'failed-precondition', message: 'Un superAdmin non può togliersi il ruolo da solo.' };
  }
  return { ok: true, targetUid: r.targetUid, role: r.role as AdminRole | null };
}

/** Custom claims risultanti: conserva gli altri claim, cambia solo `role`. */
export function nextClaims(current: Data | undefined, role: AdminRole | null): Data {
  const next: Data = { ...(current ?? {}) };
  if (role === null) delete next.role;
  else next.role = role;
  return next;
}
