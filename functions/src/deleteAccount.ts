import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

/**
 * Callable function — fully removes the calling user's account and data.
 * Required by the App Store because we offer Sign in with Apple.
 *
 * Steps:
 *   1. users/{uid} doc
 *   2. all clips authored by uid (across blips/{blipId}/days/{dateKey}/clips)
 *   3. all Storage objects under blips/<blipId>/days/<dateKey>/<uid>/
 *   4. arrayRemove uid from every blips/{blipId}.members
 *   5. delete the Firebase Auth user
 */
export const deleteAccount = onCall(
  { region: "us-central1", timeoutSeconds: 540, memory: "512MiB" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }

    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    logger.info("deleteAccount start", { uid });

    // 1. Clips authored by the user (collection group across all blips).
    const clipsSnap = await db
      .collectionGroup("clips")
      .where("uid", "==", uid)
      .get();
    const clipBatches: admin.firestore.WriteBatch[] = [];
    let batch = db.batch();
    let opCount = 0;
    for (const doc of clipsSnap.docs) {
      batch.delete(doc.ref);
      opCount++;
      if (opCount >= 450) {
        clipBatches.push(batch);
        batch = db.batch();
        opCount = 0;
      }
    }
    if (opCount > 0) clipBatches.push(batch);
    await Promise.all(clipBatches.map((b) => b.commit()));

    // 2. Remove uid from every blip's members array.
    const blipsSnap = await db
      .collection("blips")
      .where("members", "array-contains", uid)
      .get();
    await Promise.all(
      blipsSnap.docs.map((doc) =>
        doc.ref.update({
          members: admin.firestore.FieldValue.arrayRemove(uid),
        }),
      ),
    );

    // 3. Storage cleanup — clip files live under blips/<blipId>/days/<dateKey>/<uid>/...
    //    A collection-group prefix walk would require knowing every (blipId, dateKey).
    //    Cheapest correct approach: list everything under blips/ filtered by /<uid>/ in the path.
    const [files] = await bucket.getFiles({ prefix: "blips/" });
    const userFiles = files.filter((f) => f.name.includes(`/${uid}/`));
    await Promise.all(userFiles.map((f) => f.delete({ ignoreNotFound: true })));

    // 4. User profile doc.
    await db.collection("users").doc(uid).delete();

    // 5. Auth record (last — once gone, the client's token becomes invalid).
    await admin.auth().deleteUser(uid);

    logger.info("deleteAccount complete", {
      uid,
      clips: clipsSnap.size,
      blips: blipsSnap.size,
      files: userFiles.length,
    });

    return { ok: true };
  },
);
