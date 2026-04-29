import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

const AUTO_HIDE_THRESHOLD = 3;

/**
 * Triggered when a user files a report at reports/{reportId}.
 * Increments the offending clip's reportCount and auto-hides at threshold.
 *
 * Document shape (written by client):
 *   {
 *     clipId: string,             // doc id of the clip
 *     clipPath: string,           // full Firestore path so we can resolve it (collection groups)
 *     reporterId: string,         // calling user's uid
 *     authorId: string,           // clip author's uid
 *     category: "spam" | "harassment" | "nudity" | "violence" | "other",
 *     createdAt: Timestamp,
 *   }
 */
export const onReport = onDocumentCreated(
  {
    document: "reports/{reportId}",
    region: "us-central1",
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { clipPath, reporterId, authorId, category } = data as {
      clipPath?: string;
      reporterId?: string;
      authorId?: string;
      category?: string;
    };

    logger.info("report filed", {
      reportId: event.params.reportId,
      reporterId,
      authorId,
      category,
      clipPath,
    });

    if (!clipPath) return;

    const db = admin.firestore();
    const clipRef = db.doc(clipPath);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(clipRef);
      if (!snap.exists) return;

      const current = (snap.data()?.reportCount as number | undefined) ?? 0;
      const next = current + 1;
      const update: Record<string, unknown> = {
        reportCount: next,
        lastReportedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (next >= AUTO_HIDE_THRESHOLD) {
        update.hidden = true;
      }
      tx.update(clipRef, update);
    });
  },
);
