#!/usr/bin/env node
/**
 * Lists Firebase Auth users + their Firestore profile so you can identify
 * which uid to seed test data against.
 *
 * Usage: cd functions && node scripts/list-users.js
 */
const admin = require("firebase-admin");

admin.initializeApp({ projectId: "blip-4a5dc" });

async function main() {
  const auth = admin.auth();
  const db = admin.firestore();

  const list = await auth.listUsers(50);
  console.log(`\nfound ${list.users.length} auth users:\n`);

  for (const u of list.users) {
    const profile = (await db.collection("users").doc(u.uid).get()).data() || {};
    const tokenCount = (profile.fcmTokens ?? []).length;
    console.log(
      `uid: ${u.uid}\n  phone: ${u.phoneNumber || "—"}` +
      `  email: ${u.email || "—"}` +
      `  displayName: ${profile.displayName || u.displayName || "—"}` +
      `  fcmTokens: ${tokenCount}` +
      `  lastSignIn: ${u.metadata.lastSignInTime}\n`
    );
  }
}

main().then(() => process.exit(0)).catch((e) => {
  console.error(e);
  process.exit(1);
});
