import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { isQuietHourForUser } from "./utils/quietHours";

/**
 * Progressive completion notifications. Fires when a clip doc lands at
 * blips/{blipId}/days/{dateKey}/clips/{clipId}.
 *
 * Throttle (per CLAUDE.md "Progressive completion notifications"):
 *   - 2–4 member blipchat: notify remaining on every post
 *   - 5+ member blipchat:  notify only at halfway crossing and last-one
 *   - Last-one always fires regardless of size
 *   - Group complete (remaining = 0): silent
 *
 * Recipient quiet hours are honored individually.
 */
export const onClipPosted = onDocumentCreated(
  {
    document: "blips/{blipId}/days/{dateKey}/clips/{clipId}",
    region: "us-central1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const clip = snap.data();
    const { blipId, dateKey } = event.params as { blipId: string; dateKey: string };
    const posterUid = clip.uid as string;
    const hour = clip.hour as number;

    const db = admin.firestore();
    const messaging = admin.messaging();

    const blipDoc = await db.collection("blips").doc(blipId).get();
    if (!blipDoc.exists) return;
    const blip = blipDoc.data() as admin.firestore.DocumentData;
    const members: string[] = blip.members ?? [];
    const total = members.length;
    const blipName: string = blip.name ?? "your blip";

    // Posters in this hour bucket = distinct uids on clips with the same `hour` field
    // for this blipchat-day. The clip's hour is the poster's local hour; for nudges we
    // bucket by clip.hour (matches what the in-app hourly grid will show).
    const clipsInHour = await db
      .collection("blips").doc(blipId)
      .collection("days").doc(dateKey)
      .collection("clips")
      .where("hour", "==", hour)
      .get();
    const posters = new Set<string>(
      clipsInHour.docs.map((d) => d.data().uid as string),
    );
    const postersCount = posters.size;
    const remaining = members.filter((m) => !posters.has(m));

    if (remaining.length === 0) {
      logger.info("group complete, silent", { blipId, hour, postersCount, total });
      return;
    }

    const isLastOne = remaining.length === 1;
    const halfwayThreshold = Math.ceil(total / 2);
    // Use >= since the tier-doc create-once below handles dedup under parallel writes.
    const justCrossedHalfway = postersCount >= halfwayThreshold;

    let shouldNotify: boolean;
    if (isLastOne) shouldNotify = true;
    else if (total <= 4) shouldNotify = true;
    else shouldNotify = justCrossedHalfway;

    if (!shouldNotify) {
      logger.info("throttled", { blipId, hour, postersCount, total });
      return;
    }

    // Tier-doc idempotency: under parallel writes, two invocations may both observe
    // the threshold. Try to claim the tier doc with create(); ALREADY_EXISTS (code 6)
    // means another invocation already fired this tier — skip silently.
    // Every-post tier (2–4 members) does not dedupe — every post is a distinct ping.
    const tier: "halfway" | "last-one" | "every-post" =
      isLastOne ? "last-one" : total <= 4 ? "every-post" : "halfway";
    if (tier === "halfway" || tier === "last-one") {
      const tierKey = tier === "halfway" ? `${hour}_halfway` : `${hour}_lastone`;
      const tierRef = db
        .collection("blips").doc(blipId)
        .collection("days").doc(dateKey)
        .collection("notified").doc(tierKey);
      try {
        await tierRef.create({
          tier,
          hour,
          firedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (err) {
        const code = (err as { code?: number }).code;
        if (code === 6) {
          logger.info("tier already fired, skip", { blipId, hour, tier });
          return;
        }
        throw err;
      }
    }

    // Best-effort poster name for the per-post copy
    let posterName = "someone";
    const posterDoc = await db.collection("users").doc(posterUid).get();
    if (posterDoc.exists) {
      posterName = (posterDoc.data()?.displayName as string) || posterName;
    }

    const title: string = isLastOne ? `you're the last one in ${blipName}` : blipName;
    const body: string = (() => {
      if (isLastOne) return "two seconds locks the hour.";
      if (total <= 4) return `${posterName} blipped. ${postersCount} of ${total} this hour.`;
      return `halfway there — ${postersCount} of ${total} blipped this hour.`;
    })();

    const sends: Promise<unknown>[] = [];
    let skippedQuiet = 0;
    let skippedNoToken = 0;
    let sent = 0;

    for (const uid of remaining) {
      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists) {
        skippedNoToken++;
        continue;
      }
      const u = userDoc.data() as admin.firestore.DocumentData;
      const tokens: string[] = u.fcmTokens ?? [];
      if (tokens.length === 0) {
        skippedNoToken++;
        continue;
      }
      if (isQuietHourForUser(u)) {
        skippedQuiet++;
        continue;
      }

      sends.push(
        messaging.sendEachForMulticast({
          tokens,
          notification: { title, body },
          data: { deepLink: `blip://blip/${blipId}` },
        }).catch((err) => {
          logger.warn("send failed", { uid, err: String(err) });
        }),
      );
      sent++;
    }

    await Promise.all(sends);
    logger.info("onClipPosted notified", {
      blipId,
      hour,
      postersCount,
      total,
      remaining: remaining.length,
      tier,
      sent,
      skippedQuiet,
      skippedNoToken,
    });
  },
);
