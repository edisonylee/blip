import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

/**
 * Referral attribution — fires on `users/{uid}` create. If the new doc carries
 * a `referredByUid` (stashed by the iOS DeepLinkRouter from a
 * `blip://invite?ref=UID` deep link before the user signed up), atomically
 * credit the referrer's `referralsCount` by 1.
 *
 * Idempotent by construction: doc-create only fires once per uid, so no
 * additional dedupe is needed.
 *
 * Guards:
 *   - missing `referredByUid`     → no-op
 *   - `referredByUid === uid`     → self-loop, ignored (rules block this too)
 *   - referrer doc doesn't exist  → ignored (don't auto-create a phantom user)
 */
export const onUserCreated = onDocumentCreated(
  {
    document: "users/{uid}",
    region: "us-central1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const referredByUid = data?.referredByUid as string | undefined;
    const { uid } = event.params as { uid: string };

    if (!referredByUid) return;
    if (referredByUid === uid) {
      logger.warn("self-referral rejected", { uid });
      return;
    }

    const db = admin.firestore();
    const referrerRef = db.collection("users").doc(referredByUid);
    const referrerSnap = await referrerRef.get();
    if (!referrerSnap.exists) {
      logger.warn("referrer doc missing, skipping credit", {
        uid,
        referredByUid,
      });
      return;
    }

    await referrerRef.set(
      {
        referralsCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    logger.info("referralsCount +1", {
      referrer: referredByUid,
      newUser: uid,
    });
  },
);
