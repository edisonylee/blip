import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

/**
 * Callable referral claim for users who tapped an invite link AFTER signing
 * up (the `onUserCreated` onCreate trigger only fires for brand-new accounts,
 * so the after-sign-in path needs its own credit channel).
 *
 * Atomic guards in a single transaction:
 *   - caller must be signed in
 *   - `ref` must be a non-empty string and ≠ caller uid (self-loop block)
 *   - caller's user doc must NOT already have `referredByUid` set
 *   - referrer's user doc must exist
 *
 * On success: writes `referredByUid` to caller's doc and increments
 * `referralsCount` on referrer's doc, both inside one transaction.
 *
 * Idempotent by construction: a second call from the same caller hits the
 * "already credited" branch and throws `failed-precondition`.
 */
export const claimReferral = onCall(
  {
    region: "us-central1",
    memory: "256MiB",
    timeoutSeconds: 30,
  },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "you must be signed in.");
    }

    const ref = (request.data?.ref as string | undefined)?.trim();
    if (!ref) {
      throw new HttpsError("invalid-argument", "missing referrer uid.");
    }
    if (ref === callerUid) {
      throw new HttpsError("invalid-argument", "you can't refer yourself.");
    }

    const db = admin.firestore();
    const callerRef = db.collection("users").doc(callerUid);
    const referrerRef = db.collection("users").doc(ref);

    try {
      await db.runTransaction(async (txn) => {
        const callerSnap = await txn.get(callerRef);
        const referrerSnap = await txn.get(referrerRef);

        if (callerSnap.data()?.referredByUid) {
          throw new HttpsError(
            "failed-precondition",
            "referral already credited.",
          );
        }
        if (!referrerSnap.exists) {
          throw new HttpsError("not-found", "referrer not found.");
        }

        txn.set(
          callerRef,
          {
            referredByUid: ref,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        txn.set(
          referrerRef,
          {
            referralsCount: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      });
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("claimReferral failed", { callerUid, ref, err });
      throw new HttpsError("internal", "couldn't credit referral.");
    }

    logger.info("referral credited via callable", {
      caller: callerUid,
      referrer: ref,
    });
    return { credited: true };
  },
);
