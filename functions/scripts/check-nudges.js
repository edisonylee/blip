#!/usr/bin/env node
/**
 * Lists nudges in the nudge-test blip + tails recent onNudgeCreated logs.
 * Usage: cd functions && node scripts/check-nudges.js
 */
const admin = require("firebase-admin");
admin.initializeApp({ projectId: "blip-4a5dc" });

const BLIP_ID = "uC3nrAK44WCjvVSAHjac";

async function main() {
  const db = admin.firestore();
  const snap = await db.collection("blips").doc(BLIP_ID)
    .collection("nudges").get();

  console.log(`\nblips/${BLIP_ID}/nudges/ — ${snap.size} doc(s)\n`);
  if (snap.size === 0) {
    console.log("  (empty — no nudge writes have landed)");
  } else {
    for (const d of snap.docs) {
      const data = d.data();
      const created = data.createdAt?.toDate?.()?.toISOString() ?? "—";
      console.log(`  ${d.id}`);
      console.log(`    senderUid: ${data.senderUid}`);
      console.log(`    nudgeeUid: ${data.nudgeeUid}`);
      console.log(`    createdAt: ${created}\n`);
    }
  }
}

main().then(() => process.exit(0)).catch((e) => {
  console.error(e);
  process.exit(1);
});
