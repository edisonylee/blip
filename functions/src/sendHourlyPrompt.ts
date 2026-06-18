import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { isQuietHourForUser } from "./utils/quietHours";
import { hourInTimezone, isActiveHour, scheduleFrom } from "./utils/blipSchedule";

/**
 * Scheduled hourly. For each user with an active blip membership and an FCM token,
 * send a "time to blip" notification with a deep link straight into the capture screen.
 *
 * Skips users whose local hour falls inside their quiet-hours window
 * (`quietHoursStart`–`quietHoursEnd` on the user doc, default 23–7).
 */
export const sendHourlyPrompt = onSchedule(
  {
    schedule: "0 * * * *",
    timeZone: "UTC",
    region: "us-central1",
  },
  async () => {
    const db = admin.firestore();
    const messaging = admin.messaging();

    const [usersSnap, blipsSnap] = await Promise.all([
      db.collection("users").get(),
      db.collection("blips").get(),
    ]);
    const activeMemberUids = new Set<string>();
    const now = new Date();
    for (const blipDoc of blipsSnap.docs) {
      const blip = blipDoc.data();
      const schedule = scheduleFrom(blip);
      const groupHour = hourInTimezone(now, schedule.timezoneIdentifier);
      if (!isActiveHour(groupHour, schedule.activeStartHour, schedule.activeEndHour)) {
        continue;
      }
      for (const memberUid of (blip.members as string[] | undefined) ?? []) {
        activeMemberUids.add(memberUid);
      }
    }
    let skippedQuiet = 0;
    let skippedNoToken = 0;
    let sent = 0;

    const sends: Promise<unknown>[] = [];
    for (const doc of usersSnap.docs) {
      if (!activeMemberUids.has(doc.id)) continue;
      const data = doc.data();
      const tokens: string[] = data.fcmTokens ?? [];
      if (tokens.length === 0) {
        skippedNoToken++;
        continue;
      }

      if (isQuietHourForUser(data)) {
        skippedQuiet++;
        continue;
      }

      sends.push(
        messaging.sendEachForMulticast({
          tokens,
          notification: {
            title: "time to blip",
            body: "two seconds. capture what you're up to.",
          },
          data: { deepLink: "blip://capture" },
        }),
      );
      sent++;
    }

    await Promise.all(sends);
    logger.info("sendHourlyPrompt done", {
      total: usersSnap.size,
      activeMembers: activeMemberUids.size,
      sent,
      skippedQuiet,
      skippedNoToken,
    });
  },
);
