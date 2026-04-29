import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

/**
 * Callable: exportStitch({ logId, range })
 *
 * Per CLAUDE.md core mechanic:
 *   - Export is on-demand by any member (NOT a 4AM cron).
 *   - Hours with zero contributions are skipped.
 *   - Per-hour grid layout: 1×1, 2×1, 2×2 (3–4), then dynamically grows columns/rows past 4.
 *
 * Open architectural question (deferred — see project memory):
 *   - Does `range` mean "today" (current day boundary in log TZ) or "all-time"?
 *   - Confirm with user before implementing.
 *
 * When implemented:
 *   1. Fetch clips for range from Firestore
 *   2. Group by hour, drop empty hours
 *   3. For each non-empty hour, compose grid via ffmpeg (xstack filter)
 *   4. Concatenate hour-clips end-to-end into a single 1080×1920 vertical MP4
 *   5. Upload to logs/{logId}/days/{dateKey}/stitched.mp4 (or a per-export path if all-time)
 *   6. Return downloadable URL
 */
export const exportStitch = onCall(
  {
    region: "us-central1",
    memory: "4GiB",
    timeoutSeconds: 540,
    cpu: 2,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }
    const { logId, range } = request.data ?? {};
    if (typeof logId !== "string") {
      throw new HttpsError("invalid-argument", "logId required");
    }
    logger.info("exportStitch invoked", { logId, range, uid: request.auth.uid });
    // TODO: implement once stitch range semantics are confirmed
    throw new HttpsError("unimplemented", "exportStitch is not implemented yet.");
  },
);
