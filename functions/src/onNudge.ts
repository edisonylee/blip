import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { isQuietHourForUser } from "./utils/quietHours";

/**
 * Peer nudge fan-out. Fires when a sender writes
 * `blips/{blipId}/nudges/{nudgeId}` with the deterministic id
 * `{dateKey}_{hour}_{senderUid}_{nudgeeUid}` (computed in the blipchat's TZ).
 *
 * The client-side throttle is the doc-id collision (security rules deny update),
 * so this trigger only ever runs once per (sender, recipient, blip-hour). It
 * does the minimum work: look up tokens, honor the recipient's quiet hours,
 * single multicast.
 */
export const onNudgeCreated = onDocumentCreated(
  {
    document: "blips/{blipId}/nudges/{nudgeId}",
    region: "us-central1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const { blipId } = event.params as { blipId: string };
    const data = snap.data();
    const senderUid = data.senderUid as string;
    const nudgeeUid = data.nudgeeUid as string;

    const db = admin.firestore();
    const messaging = admin.messaging();

    const [blipDoc, nudgeeDoc, senderDoc] = await Promise.all([
      db.collection("blips").doc(blipId).get(),
      db.collection("users").doc(nudgeeUid).get(),
      db.collection("users").doc(senderUid).get(),
    ]);

    if (!blipDoc.exists) {
      logger.warn("nudge for missing blip", { blipId });
      return;
    }
    if (!nudgeeDoc.exists) {
      logger.warn("nudge for missing nudgee", { nudgeeUid });
      return;
    }

    const blip = blipDoc.data() as admin.firestore.DocumentData;
    const nudgee = nudgeeDoc.data() as admin.firestore.DocumentData;

    const tokens: string[] = nudgee.fcmTokens ?? [];
    if (tokens.length === 0) {
      logger.info("nudge skipped, no tokens", { blipId, nudgeeUid });
      return;
    }
    if (isQuietHourForUser(nudgee)) {
      logger.info("nudge skipped, quiet hours", { blipId, nudgeeUid });
      return;
    }

    const senderName =
      (senderDoc.exists ? (senderDoc.data()?.displayName as string) : "") ||
      "someone";
    const blipName: string = blip.name ?? "your blip";

    const title = `${senderName} is waiting on you`;
    const body = `two seconds keeps ${blipName} alive this hour.`;

    await messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { deepLink: `blip://blip/${blipId}` },
    });

    logger.info("nudge sent", { blipId, senderUid, nudgeeUid });
  },
);
