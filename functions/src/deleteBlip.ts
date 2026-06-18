import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

/**
 * Callable function — fully removes a blip and all of its data.
 *
 * Authorization: only the blip's `ownerUid` may delete. Members who want out
 * call the client-side `leaveBlip` (arrayRemove) instead.
 *
 * Last-member auto-cleanup: if every member leaves, the client also calls
 * this function on behalf of the leaver (the leaver is briefly the owner-of-record
 * for an empty blip in that path; rules permit it because they are the last
 * member). See `BlipRepository.leaveBlip` for the cascade.
 *
 * Steps:
 *   1. Auth check: caller is `ownerUid` (or the only remaining member)
 *   2. Delete every clip under blips/{blipId}/days/{*}/clips/{*}
 *   3. Delete every nudge under blips/{blipId}/nudges/{*}
 *   4. Delete every Storage object under blips/{blipId}/...
 *   5. Delete RTDB /chats/{blipId}
 *   6. Delete the blip doc itself
 */
export const deleteBlip = onCall(
  { region: "us-central1", timeoutSeconds: 540, memory: "512MiB" },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }

    const blipId = (request.data?.blipId as string | undefined) ?? "";
    if (!blipId) {
      throw new HttpsError("invalid-argument", "blipId is required.");
    }

    const db = admin.firestore();
    const bucket = admin.storage().bucket();
    const rtdb = admin.database();

    const blipRef = db.collection("blips").doc(blipId);
    const blipSnap = await blipRef.get();
    if (!blipSnap.exists) {
      throw new HttpsError("not-found", "Blip not found.");
    }
    const blipData = blipSnap.data() ?? {};
    const ownerUid = blipData.ownerUid as string | undefined;
    const members = (blipData.members as string[] | undefined) ?? [];

    // Caller must be the owner OR the only remaining member.
    const isOwner = ownerUid === callerUid;
    const isLastMember = members.length <= 1 && members.includes(callerUid);
    if (!isOwner && !isLastMember) {
      throw new HttpsError(
        "permission-denied",
        "Only the owner can delete this blip.",
      );
    }

    logger.info("deleteBlip start", { blipId, callerUid, isOwner, isLastMember });

    // 1. All clips under the blip. Clips don't denormalize blipId (it's
    //    structural in the path), so a collection-group `where("blipId")`
    //    won't work — walk days/{dateKey}/clips/* directly.
    const daysSnap = await blipRef.collection("days").get();
    const clipRefs: admin.firestore.DocumentReference[] = [];
    for (const dayDoc of daysSnap.docs) {
      const dayClips = await dayDoc.ref.collection("clips").get();
      clipRefs.push(...dayClips.docs.map((d) => d.ref));
    }
    // Day docs themselves also get deleted so the subcollection is fully empty.
    clipRefs.push(...daysSnap.docs.map((d) => d.ref));
    await batchedDelete(db, clipRefs);

    // 2. Nudges.
    const nudgesSnap = await blipRef.collection("nudges").get();
    await batchedDelete(db, nudgesSnap.docs.map((d) => d.ref));

    // 3. Storage objects under blips/{blipId}/.
    const [files] = await bucket.getFiles({ prefix: `blips/${blipId}/` });
    await Promise.all(files.map((f) => f.delete({ ignoreNotFound: true })));

    // 4. RTDB chat.
    await rtdb.ref(`chats/${blipId}`).remove();

    // 5. Blip doc itself.
    await blipRef.delete();

    logger.info("deleteBlip complete", {
      blipId,
      clips: clipRefs.length,
      nudges: nudgesSnap.size,
      files: files.length,
    });

    return { ok: true };
  },
);

async function batchedDelete(
  db: admin.firestore.Firestore,
  refs: admin.firestore.DocumentReference[],
): Promise<void> {
  if (refs.length === 0) return;
  const batches: admin.firestore.WriteBatch[] = [];
  let batch = db.batch();
  let opCount = 0;
  for (const ref of refs) {
    batch.delete(ref);
    opCount++;
    if (opCount >= 450) {
      batches.push(batch);
      batch = db.batch();
      opCount = 0;
    }
  }
  if (opCount > 0) batches.push(batch);
  await Promise.all(batches.map((b) => b.commit()));
}
