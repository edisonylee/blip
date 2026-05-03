import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

/**
 * Callable function — adds the caller to a blip identified by its joinCode.
 *
 * Why a function and not a client write? Firestore rules keep blip reads
 * restricted to current members (`request.auth.uid in resource.data.members`),
 * so a non-member can't even discover a blip via `whereField("joinCode", ...)`.
 * Loosening the read rule to allow joinCode lookups would leak blip metadata
 * to anyone who guesses a 7-char code. Server-side via admin SDK keeps the
 * read rule strict while preserving the join UX.
 *
 * Idempotent: re-joining a blip you're already in is a no-op success.
 */
export const joinBlip = onCall(
  { region: "us-central1", timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }

    const code = String(request.data?.code ?? "").trim().toLowerCase();
    if (!code) {
      throw new HttpsError("invalid-argument", "Code is required.");
    }

    const db = admin.firestore();
    const snap = await db
      .collection("blips")
      .where("joinCode", "==", code)
      .limit(1)
      .get();

    if (snap.empty) {
      throw new HttpsError("not-found", "No blip with that code.");
    }

    const blipRef = snap.docs[0].ref;
    let resultData: FirebaseFirestore.DocumentData = {};

    await db.runTransaction(async (tx) => {
      const doc = await tx.get(blipRef);
      if (!doc.exists) {
        throw new HttpsError("not-found", "Blip no longer exists.");
      }
      const data = doc.data() ?? {};
      const members = (data.members as string[] | undefined) ?? [];
      // Idempotent: already a member, just return the doc.
      if (members.includes(callerUid)) {
        resultData = data;
        return;
      }
      const size = (data.size as number | undefined) ?? 0;
      if (size > 0 && members.length >= size) {
        throw new HttpsError("failed-precondition", "This blip is full.");
      }
      tx.update(blipRef, {
        members: admin.firestore.FieldValue.arrayUnion(callerUid),
      });
      resultData = {
        ...data,
        members: [...members, callerUid],
      };
    });

    logger.info("joinBlip success", {
      callerUid,
      blipId: blipRef.id,
    });

    return { blipId: blipRef.id, ...resultData };
  },
);
