#!/usr/bin/env node
/**
 * Seeds a 4-member blip with NO clips so the 3 mock members render as
 * tappable `.waiting` seats in BlipDetailView. Lets you exercise the nudge
 * UI end-to-end on a single phone:
 *
 *   - your own seat → `.recordPrompt` (camera tile)
 *   - mock seats 1–3 → `.waiting` (tappable "nudge" tile)
 *
 * Tap any waiting seat → "send a nudge?" sheet → "send nudge". The Cloud
 * Function will fire on the doc create. The mock members have no FCM tokens
 * so no push actually delivers, but the function logs ("nudge skipped, no
 * tokens") and the Firestore doc lands at:
 *
 *   blips/{blipId}/nudges/{dateKey}_{hour}_{yourUid}_{mockUid}
 *
 * Watch logs in another terminal:
 *   npx firebase-tools functions:log --only onNudgeCreated
 *
 * Usage:
 *   cd functions && node scripts/seed-nudge-test.js
 *   USER_UID=<your_uid> node scripts/seed-nudge-test.js
 *
 * Auth: Application Default Credentials (`gcloud auth application-default login`).
 */

const admin = require("firebase-admin");

const PROJECT_ID = "blip-4a5dc";
const TIMEZONE = "America/New_York";
const DEFAULT_USER_UID = "wUVuqLbLJYVfbdFwKcJHKOrKFEK2";

const userUid = process.env.USER_UID || DEFAULT_USER_UID;

admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

async function main() {
  const blipRef = db.collection("blips").doc();
  const blipId = blipRef.id;
  const mockUids = ["nudge_mock_1", "nudge_mock_2", "nudge_mock_3"];
  const members = [userUid, ...mockUids];

  await blipRef.set({
    name: "nudge-test",
    ownerUid: userUid,
    members,
    size: 4,
    joinCode: "nudgex",
    timezoneIdentifier: TIMEZONE,
    createdAt: admin.firestore.Timestamp.fromDate(new Date()),
  });

  console.log("\n=== seed complete ===");
  console.log(`blipId:  ${blipId}`);
  console.log(`members: ${members.join(", ")}`);
  console.log("\nNext:");
  console.log("  1. Open the iOS app → \"nudge-test\" should appear in your list");
  console.log("  2. Tap into it → 3 mock seats render as tappable 'nudge' tiles");
  console.log("  3. Tap any one → confirm sheet → send nudge");
  console.log("  4. Verify in Firebase Console (Firestore):");
  console.log(`     blips/${blipId}/nudges/  ← a doc should appear`);
  console.log("  5. Tail Cloud Function logs:");
  console.log("     npx firebase-tools functions:log --only onNudgeCreated");
  console.log("     (expect: \"nudge skipped, no tokens\" — mocks don't have FCM tokens)");
  console.log("  6. Tap the same seat again → no new doc (deterministic-id throttle).\n");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("seed: failed", err);
    process.exit(1);
  });
