#!/usr/bin/env node
// Assegna il PRIMO superAdmin di un progetto (una volta sola per ambiente).
// Dopo, i ruoli si gestiscono solo dal pannello admin tramite setAdminRole.
//
// Uso (dal proprio computer, MAI dal client dell'app):
//   gcloud auth application-default login
//   node scripts/first-superadmin.js --project niyah-dev --email tua@email
//
// L'utente deve già esistere in Firebase Authentication (registrato dal
// pannello o creato dalla console). Lo script si rifiuta se il progetto ha già
// un superAdmin. Nessuna credenziale è salvata nel repository.

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 ? process.argv[i + 1] : undefined;
}

async function main() {
  const projectId = arg('project');
  const email = arg('email');
  if (!projectId || !email) {
    console.error('Uso: node scripts/first-superadmin.js --project <id-progetto> --email <email>');
    process.exit(2);
  }

  const app = initializeApp({ credential: applicationDefault(), projectId });
  const auth = getAuth(app);
  const db = getFirestore(app);

  const existing = await db.collection('adminRoles').where('role', '==', 'superAdmin').limit(1).get();
  if (!existing.empty) {
    console.error(`Il progetto ${projectId} ha già un superAdmin: usare il pannello admin (setAdminRole).`);
    process.exit(1);
  }

  const user = await auth.getUserByEmail(email);
  await auth.setCustomUserClaims(user.uid, { ...(user.customClaims ?? {}), role: 'superAdmin' });
  await db.doc(`adminRoles/${user.uid}`).set({ role: 'superAdmin', updatedAt: FieldValue.serverTimestamp(), updatedBy: 'first-superadmin-script' });
  await db.collection('adminAudit').add({
    action: 'setAdminRole',
    actor: 'first-superadmin-script',
    target: user.uid,
    from: user.customClaims?.role ?? null,
    to: 'superAdmin',
    sessionsRevoked: false,
    at: FieldValue.serverTimestamp(),
  });
  console.log(`${email} è superAdmin di ${projectId}. Esci e rientra nel pannello perché il ruolo diventi attivo.`);
}

main().catch((e) => {
  console.error(e.message ?? e);
  process.exit(1);
});
