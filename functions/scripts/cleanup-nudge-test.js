#!/usr/bin/env node
/**
 * Deletes the orphan nudge-test blip seeded under the wrong uid.
 * Usage: cd functions && node scripts/cleanup-nudge-test.js
 */
const admin = require("firebase-admin");
admin.initializeApp({ projectId: "blip-4a5dc" });

const ORPHAN_BLIP_ID = "3yeFYKcnzrXo6AHaFOIp";

async function main() {
  const db = admin.firestore();
  // Recursive delete (handles any nudges/clips/messages subcollections too).
  const ref = db.collection("blips").doc(ORPHAN_BLIP_ID);
  await db.recursiveDelete(ref);
  console.log(`deleted blips/${ORPHAN_BLIP_ID}`);
}

main().then(() => process.exit(0)).catch((e) => {
  console.error(e);
  process.exit(1);
});
