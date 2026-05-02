import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

/**
 * Like-count aggregation for stitched days. Watches:
 *   blips/{blipId}/days/{dateKey}/likes/{uid}
 *
 * On create:
 *   - blips/{blipId}/days/{dateKey}.likeCount += 1
 *   - users/{ownerUid}.likesCount += 1   (ownerUid = blip owner — see attribution note)
 * On delete:
 *   - both counters are decremented, transaction-clamped at 0 so racing
 *     toggles from the same uid (which the doc-id design already prevents
 *     client-side) never drop below zero.
 * On update:
 *   - no-op. Like docs are immutable per `firestore.rules` (`allow update: if false`).
 *
 * Attribution: a blip can have multiple authors contributing clips to a day,
 * but for v0 we credit the **blip owner** as the "creator" of the day so
 * `users.likesCount` is single-attributed. If multi-author attribution
 * matters we revisit by writing to every contributor in `clips` for the day.
 */
export const onDayLike = onDocumentWritten(
  {
    document: "blips/{blipId}/days/{dateKey}/likes/{uid}",
    region: "us-central1",
  },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    const beforeExists = before?.exists ?? false;
    const afterExists = after?.exists ?? false;

    if (beforeExists === afterExists) {
      // Nothing actionable: either it's an update of an existing like (rules
      // forbid this, but be defensive) or both sides are missing.
      return;
    }

    const { blipId, dateKey } = event.params as {
      blipId: string;
      dateKey: string;
      uid: string;
    };

    const db = admin.firestore();
    const dayRef = db.collection("blips").doc(blipId)
      .collection("days").doc(dateKey);
    const blipRef = db.collection("blips").doc(blipId);

    // Resolve the day's "creator" for the user-level counter. Blip owner for
    // v0 — see attribution note above.
    const blipSnap = await blipRef.get();
    const ownerUid = blipSnap.data()?.ownerUid as string | undefined;
    if (!ownerUid) {
      logger.warn("onDayLike: blip has no ownerUid, skipping user denorm", {
        blipId,
        dateKey,
      });
    }
    const userRef = ownerUid
      ? db.collection("users").doc(ownerUid)
      : null;

    if (!beforeExists && afterExists) {
      // Like added.
      const ops: Promise<unknown>[] = [
        dayRef.set(
          { likeCount: admin.firestore.FieldValue.increment(1) },
          { merge: true },
        ),
      ];
      if (userRef) {
        ops.push(
          userRef.set(
            { likesCount: admin.firestore.FieldValue.increment(1) },
            { merge: true },
          ),
        );
      }
      await Promise.all(ops);
      logger.info("dayLike +1", { blipId, dateKey, ownerUid });
      return;
    }

    if (beforeExists && !afterExists) {
      // Like removed — clamp both counters at zero via transactions.
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(dayRef);
        const current = (snap.data()?.likeCount as number | undefined) ?? 0;
        const next = Math.max(0, current - 1);
        tx.set(dayRef, { likeCount: next }, { merge: true });
      });
      if (userRef) {
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(userRef);
          const current = (snap.data()?.likesCount as number | undefined) ?? 0;
          const next = Math.max(0, current - 1);
          tx.set(userRef, { likesCount: next }, { merge: true });
        });
      }
      logger.info("dayLike -1 (clamped)", { blipId, dateKey, ownerUid });
    }
  },
);
