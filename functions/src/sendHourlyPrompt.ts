import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

/**
 * Scheduled hourly. For each user with an active log membership and an FCM token,
 * send a "time to blip" notification with a deep link straight into the capture screen.
 *
 * Phase C — wire up after capture pipeline + FCM token registration land.
 */
export const sendHourlyPrompt = onSchedule(
  {
    schedule: "0 * * * *",
    timeZone: "UTC",
    region: "us-central1",
  },
  async () => {
    logger.info("sendHourlyPrompt tick");
    // TODO: iterate users, respect log timezones, batch FCM sends.
  },
);
