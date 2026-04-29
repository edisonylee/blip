import { onObjectFinalized } from "firebase-functions/v2/storage";
import * as logger from "firebase-functions/logger";

/**
 * Triggered when a raw clip is uploaded to:
 *   blips/{blipId}/days/{dateKey}/{uid}/{hour}.mov
 *
 * Responsibilities (Phase B):
 *  - Generate thumbnail (ffmpeg single-frame extract)
 *  - Write Firestore clip document at blips/{blipId}/days/{dateKey}/clips/{clipId}
 *  - Fan-out FCM push to peer members ("X just blipped")
 *
 * Stub for now — wire up after Phase B capture pipeline lands.
 */
export const onClipUpload = onObjectFinalized(
  {
    region: "us-east1",
    memory: "1GiB",
    timeoutSeconds: 60,
  },
  async (event) => {
    const path = event.data.name;
    if (!path?.startsWith("blips/")) return;
    logger.info("clip uploaded", { path });
    // TODO: implement
  },
);
