import { onDocumentCreated, onDocumentWritten } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

/**
 * Returns the YYYY-MM-DD calendar date in the given IANA timezone for `date`.
 * Uses the en-CA locale because that locale formats as YYYY-MM-DD natively,
 * which sidesteps manual zero-padding / parsing.
 */
function dateKeyInTimezone(date: Date, timeZone: string): string {
  return date.toLocaleDateString("en-CA", { timeZone });
}

/** Yesterday's YYYY-MM-DD relative to `today` in the given timezone. */
function yesterdayKeyInTimezone(today: Date, timeZone: string): string {
  const MS_PER_DAY = 24 * 60 * 60 * 1000;
  const yesterday = new Date(today.getTime() - MS_PER_DAY);
  return dateKeyInTimezone(yesterday, timeZone);
}

/**
 * Stat aggregation when a clip lands at:
 *   blips/{blipId}/days/{dateKey}/clips/{clipId}
 *
 * Updates the poster's user doc with:
 *   - totalClips:    monotonically incremented per clip
 *   - streakCurrent: consecutive calendar days posted in the user's TZ
 *   - streakBest:    max(streakBest, streakCurrent)
 *   - lastClipDay:   today's YYYY-MM-DD in the user's TZ
 *
 * The "day" here is the user's calendar day in their own TZ — midnight to
 * midnight. This is intentionally separate from the blipchat's 4 AM stitch
 * boundary; users think about streaks in normal calendar terms.
 */
export const onClipCreatedUpdateStats = onDocumentCreated(
  {
    document: "blips/{blipId}/days/{dateKey}/clips/{clipId}",
    region: "us-central1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const clip = snap.data();
    const posterUid = clip.uid as string | undefined;
    if (!posterUid) {
      logger.warn("clip missing uid, skipping stats", {
        path: snap.ref.path,
      });
      return;
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(posterUid);

    // Read TZ outside the txn — the user doc rarely changes TZ between read
    // and txn, and we keep the txn read/write tight per admin-SDK rules.
    const userSnap = await userRef.get();
    const timeZone: string =
      (userSnap.data()?.timezoneIdentifier as string | undefined) ?? "UTC";

    const now = new Date();
    const todayKey = dateKeyInTimezone(now, timeZone);
    const yesterdayKey = yesterdayKeyInTimezone(now, timeZone);

    await db.runTransaction(async (tx) => {
      const txSnap = await tx.get(userRef);
      const data = txSnap.data();

      // Defensive default — ensureUserDoc should already have written this on
      // sign-in, but if it hasn't we treat the post as their first clip.
      if (!data) {
        tx.set(
          userRef,
          {
            totalClips: 1,
            streakCurrent: 1,
            streakBest: 1,
            lastClipDay: todayKey,
          },
          { merge: true },
        );
        return;
      }

      const prevTotal = (data.totalClips as number | undefined) ?? 0;
      const prevStreak = (data.streakCurrent as number | undefined) ?? 0;
      const prevBest = (data.streakBest as number | undefined) ?? 0;
      const lastClipDay = data.lastClipDay as string | undefined;

      let nextStreak: number;
      if (lastClipDay === todayKey) {
        // Already posted today — streak unchanged.
        nextStreak = prevStreak === 0 ? 1 : prevStreak;
      } else if (lastClipDay === yesterdayKey) {
        // Posted yesterday — extend the streak.
        nextStreak = prevStreak + 1;
      } else {
        // First clip ever, or gap > 1 day — restart the streak.
        nextStreak = 1;
      }

      const nextBest = Math.max(prevBest, nextStreak);

      tx.set(
        userRef,
        {
          totalClips: prevTotal + 1,
          streakCurrent: nextStreak,
          streakBest: nextBest,
          lastClipDay: todayKey,
        },
        { merge: true },
      );
    });

    logger.info("user stats updated", {
      uid: posterUid,
      timeZone,
      todayKey,
    });
  },
);

/**
 * Friendship count aggregation. Watches:
 *   users/{uid}/friends/{friendUid}
 *
 * - Create  → users/{uid}.friendsCount += 1   (FieldValue.increment)
 * - Delete  → users/{uid}.friendsCount  = max(0, current - 1)  (transaction
 *             so a racing pair of decrements can't drop it below zero)
 * - Update  → no-op
 */
export const onFriendshipChangeUpdateCount = onDocumentWritten(
  {
    document: "users/{uid}/friends/{friendUid}",
    region: "us-central1",
  },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    const beforeExists = before?.exists ?? false;
    const afterExists = after?.exists ?? false;

    const { uid } = event.params as { uid: string; friendUid: string };
    const userRef = admin.firestore().collection("users").doc(uid);

    if (!beforeExists && afterExists) {
      // Friendship added.
      await userRef.set(
        { friendsCount: admin.firestore.FieldValue.increment(1) },
        { merge: true },
      );
      logger.info("friendsCount +1", { uid });
      return;
    }

    if (beforeExists && !afterExists) {
      // Friendship removed — clamp at zero via transaction.
      await admin.firestore().runTransaction(async (tx) => {
        const snap = await tx.get(userRef);
        const current = (snap.data()?.friendsCount as number | undefined) ?? 0;
        const next = Math.max(0, current - 1);
        tx.set(userRef, { friendsCount: next }, { merge: true });
      });
      logger.info("friendsCount -1 (clamped)", { uid });
      return;
    }

    // Update of an existing friendship doc — count unchanged.
  },
);
