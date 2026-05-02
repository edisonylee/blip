import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

/**
 * Callable function — fully removes the calling user's account and data.
 * Required by the App Store because we offer Sign in with Apple.
 *
 * Steps:
 *   1. read users/{uid} (need the handle BEFORE deleting the user doc)
 *   2. all clips authored by uid (across blips/{blipId}/days/{dateKey}/clips)
 *   3. arrayRemove uid from every blips/{blipId}.members
 *   4. all Storage objects under blips/<blipId>/days/<dateKey>/<uid>/
 *   5. usernames/{handle} index (frees the handle for reuse)
 *   6. blips/{*}/nudges/{*} where senderUid == uid
 *   7. friend_requests where fromUid == uid OR toUid == uid
 *   8. inverse friends (users/{otherUid}/friends/{uid}) and own subcollection
 *   9. RTDB /chats/{*}/messages/* authored by uid
 *  10. users/{uid} doc
 *  11. delete the Firebase Auth user
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
    const rtdb = admin.database();

    logger.info("deleteAccount start", { uid });

    // 1. Read user doc for the handle. Capture before deletion so we can
    //    free the usernames/{handle} index.
    const userSnap = await db.collection("users").doc(uid).get();
    const handle = userSnap.data()?.handle as string | undefined;

    // 2. Capture every blip the user is in. We need this BEFORE clip cleanup
    //    because clips are walked per-blip (collection-group queries on
    //    `uid` would require an explicit single-field index that we don't ship).
    const blipsSnap = await db
      .collection("blips")
      .where("members", "array-contains", uid)
      .get();

    // 3. Clips authored by the user — walk blips/{*}/days/{*}/clips and
    //    drop only those where uid matches.
    let clipCount = 0;
    const clipRefs: admin.firestore.DocumentReference[] = [];
    for (const blipDoc of blipsSnap.docs) {
      const daysSnap = await blipDoc.ref.collection("days").get();
      for (const dayDoc of daysSnap.docs) {
        const dayClips = await dayDoc.ref
          .collection("clips")
          .where("uid", "==", uid)
          .get();
        clipRefs.push(...dayClips.docs.map((d) => d.ref));
        clipCount += dayClips.size;
      }
    }
    await batchedDelete(db, clipRefs);

    // 4. Remove uid from every blip's members array.
    await Promise.all(
      blipsSnap.docs.map((doc) =>
        doc.ref.update({
          members: admin.firestore.FieldValue.arrayRemove(uid),
        }),
      ),
    );

    // 4. Storage cleanup — clip files live under blips/<blipId>/days/<dateKey>/<uid>/...
    //    A collection-group prefix walk would require knowing every (blipId, dateKey).
    //    Cheapest correct approach: list everything under blips/ filtered by /<uid>/ in the path.
    const [files] = await bucket.getFiles({ prefix: "blips/" });
    const userFiles = files.filter((f) => f.name.includes(`/${uid}/`));
    await Promise.all(userFiles.map((f) => f.delete({ ignoreNotFound: true })));

    // 5. usernames/{handle} index — only delete if the doc still points at this uid
    //    (defensive: if the handle was reassigned mid-request, leave it).
    if (handle) {
      const handleRef = db.collection("usernames").doc(handle);
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(handleRef);
        if (snap.exists && snap.data()?.uid === uid) {
          tx.delete(handleRef);
        }
      });
    }

    // 6. Nudges authored by the user. Collection-group queries with `where`
    //    need explicit single-field indexes, which we don't ship — walk each
    //    blip's nudges subcollection directly using the `blipsSnap` we already
    //    have. This list intentionally includes blips the user has just been
    //    arrayRemove'd from in step 3 (the nudge docs persist after membership
    //    changes).
    const nudgeRefs: admin.firestore.DocumentReference[] = [];
    let nudgeCount = 0;
    for (const blipDoc of blipsSnap.docs) {
      const nudgesSnap = await blipDoc.ref
        .collection("nudges")
        .where("senderUid", "==", uid)
        .get();
      nudgeRefs.push(...nudgesSnap.docs.map((d) => d.ref));
      nudgeCount += nudgesSnap.size;
    }
    await batchedDelete(db, nudgeRefs);

    // 7. Friend requests involving the user (either side).
    const [outgoingReqs, incomingReqs] = await Promise.all([
      db.collection("friend_requests").where("fromUid", "==", uid).get(),
      db.collection("friend_requests").where("toUid", "==", uid).get(),
    ]);
    await batchedDelete(db, [
      ...outgoingReqs.docs.map((d) => d.ref),
      ...incomingReqs.docs.map((d) => d.ref),
    ]);

    // 8. Friend graph — both sides. Read my friends list, delete the inverse
    //    edges first, then drop my own subcollection.
    const myFriendsSnap = await db
      .collection("users")
      .doc(uid)
      .collection("friends")
      .get();
    const friendUids = myFriendsSnap.docs.map((d) => d.id);
    const inverseRefs = friendUids.map((fUid) =>
      db.collection("users").doc(fUid).collection("friends").doc(uid),
    );
    await batchedDelete(db, [
      ...inverseRefs,
      ...myFriendsSnap.docs.map((d) => d.ref),
    ]);

    // 9. RTDB chat messages authored by the user. Walk every chat the user
    //    was a member of (we have the blip ids from step 3) and remove
    //    messages whose `uid` field matches.
    await Promise.all(
      blipsSnap.docs.map(async (blipDoc) => {
        const messagesRef = rtdb.ref(`chats/${blipDoc.id}/messages`);
        const snap = await messagesRef.once("value");
        const removals: Promise<unknown>[] = [];
        snap.forEach((child) => {
          if ((child.val() as { uid?: string })?.uid === uid) {
            removals.push(child.ref.remove());
          }
          return false;
        });
        await Promise.all(removals);
      }),
    );

    // 10. User profile doc.
    await db.collection("users").doc(uid).delete();

    // 11. Auth record (last — once gone, the client's token becomes invalid).
    await admin.auth().deleteUser(uid);

    logger.info("deleteAccount complete", {
      uid,
      handle: handle ?? null,
      clips: clipCount,
      blips: blipsSnap.size,
      files: userFiles.length,
      nudges: nudgeCount,
      friendRequests: outgoingReqs.size + incomingReqs.size,
      friends: friendUids.length,
    });

    return { ok: true };
  },
);

/**
 * Batch deletes refs in groups of 450 (Firestore's per-batch op limit is 500;
 * 450 leaves headroom for any other ops the caller might add).
 */
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
