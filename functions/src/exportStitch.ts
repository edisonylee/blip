import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { promises as fs } from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import ffmpegStatic from "ffmpeg-static";

import { gridFor, CANVAS } from "./utils/gridLayout";
import {
  dateKeyFor,
  isActiveHour,
  orderedHours,
  scheduleFrom,
} from "./utils/blipSchedule";

/**
 * Callable: exportStitch({ blipId })
 *
 * Per CLAUDE.md core mechanic:
 *   - Export is on-demand for the current group day and configured daily window.
 *   - Hours where no member contributed are dropped.
 *   - Per-hour grid layout: 1×1, vertical 1×2, then two seats per row up to 12.
 *
 * Pipeline:
 *   1. Auth + member check.
 *   2. Compute today's dateKey from the blip's shared timezone and start hour.
 *   3. Read clips from Firestore, group by hour, drop empty hours.
 *   4. Download every clip from Storage to /tmp.
 *   5. For each non-empty hour: ffmpeg `xstack` with pre-scaled inputs to a
 *      per-hour 1080×1920 grid mp4.
 *   6. Concat per-hour mp4s end-to-end into the final stitched export.
 *   7. Upload to blips/{blipId}/days/{date}/stitched.mp4 and persist URL on the
 *      day doc.
 *
 * Constraints:
 *   - Cloud Functions hard limit 540s timeout, 4GB memory (set below).
 *   - Real-world cap: ~24 hours × ~12 members ≈ 288 clips × ~1MB ≈ 300MB I/O.
 *     Fits comfortably for v0; revisit on Cloud Run if it ever exceeds limits.
 */
export const exportStitch = onCall(
  {
    region: "us-central1",
    memory: "4GiB",
    timeoutSeconds: 540,
    cpu: 2,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const blipId = request.data?.blipId;
    if (typeof blipId !== "string" || blipId.length === 0 || blipId.length > 64) {
      throw new HttpsError("invalid-argument", "blipId required");
    }

    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    const blipDoc = await db.collection("blips").doc(blipId).get();
    if (!blipDoc.exists) {
      throw new HttpsError("not-found", "blip not found");
    }
    const blip = blipDoc.data() as admin.firestore.DocumentData;
    const members: string[] = blip.members ?? [];
    if (!members.includes(uid)) {
      throw new HttpsError("permission-denied", "not a member");
    }
    if (members.length === 0 || members.length > 12) {
      throw new HttpsError("failed-precondition", "blip must have 1 to 12 members");
    }
    const schedule = scheduleFrom(blip);
    const dateKey = dateKeyFor(
      new Date(),
      schedule.timezoneIdentifier,
      schedule.activeStartHour,
    );

    // Rate-limit + in-progress lock. The lock doc lives at
    // `users/{uid}/exportLocks/{blipId}_{dateKey}` and serves two purposes:
    //   (1) cooldown — reject calls within COOLDOWN_MS of a successful run
    //   (2) concurrency — reject overlapping calls already running
    // ffmpeg + I/O for a single export is expensive enough that an unbounded
    // tap-loop on the export button would otherwise rack up real money.
    const COOLDOWN_MS = 30_000;
    const STALE_LOCK_MS = 540_000; // function timeout
    const lockRef = db
      .collection("users").doc(uid)
      .collection("exportLocks").doc(`${blipId}_${dateKey}`);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(lockRef);
      const now = Date.now();
      const data = snap.data();
      if (data) {
        const startedAt: number | undefined = data.startedAtMs;
        const finishedAt: number | undefined = data.finishedAtMs;
        const state: string | undefined = data.state;
        if (state === "running" && typeof startedAt === "number"
            && now - startedAt < STALE_LOCK_MS) {
          throw new HttpsError("aborted", "export already in progress");
        }
        if (state === "done" && typeof finishedAt === "number"
            && now - finishedAt < COOLDOWN_MS) {
          throw new HttpsError(
            "resource-exhausted",
            "wait a moment before exporting again",
          );
        }
      }
      tx.set(lockRef, {
        state: "running",
        startedAtMs: now,
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    logger.info("exportStitch start", { blipId, uid, dateKey });

    const clipsSnap = await db
      .collection("blips").doc(blipId)
      .collection("days").doc(dateKey)
      .collection("clips")
      .where("hidden", "==", false)
      .get();

    if (clipsSnap.empty) {
      throw new HttpsError("failed-precondition", "no clips today yet");
    }

    type ClipMeta = {
      clipId: string;
      uid: string;
      hour: number;
      videoUrl: string;
    };
    const byHour = new Map<number, ClipMeta[]>();
    for (const doc of clipsSnap.docs) {
      const d = doc.data();
      const hour = d.hour as number;
      if (!isActiveHour(hour, schedule.activeStartHour, schedule.activeEndHour)) {
        continue;
      }
      const meta: ClipMeta = {
        clipId: doc.id,
        uid: d.uid as string,
        hour,
        videoUrl: d.videoUrl as string,
      };
      const arr = byHour.get(hour) ?? [];
      arr.push(meta);
      byHour.set(hour, arr);
    }
    if (byHour.size === 0) {
      throw new HttpsError("failed-precondition", "no clips in this blip window yet");
    }
    const availableHours = new Set(byHour.keys());
    const sortedHours = orderedHours(
      schedule.activeStartHour,
      schedule.activeEndHour,
    ).filter((hour) => availableHours.has(hour));

    const workdir = await fs.mkdtemp(path.join(os.tmpdir(), `stitch-${blipId}-`));
    let exportFailed = false;
    try {
      // Download each unique clip exactly once via the admin SDK directly from
      // the bucket. We deliberately don't use the public `videoUrl` token here:
      // tokens can be revoked or rendered stale by overwrites, and the new
      // `firebasestorage.app` domain has surfaced intermittent 403s on token reads.
      const clipPathById = new Map<string, string>();
      const downloads: Promise<void>[] = [];
      for (const arr of byHour.values()) {
        for (const c of arr) {
          if (clipPathById.has(c.clipId)) continue;
          const local = path.join(workdir, `clip-${c.clipId}.mov`);
          clipPathById.set(c.clipId, local);
          const objectPath = storagePathFromVideoUrl(c.videoUrl);
          downloads.push(bucket.file(objectPath).download({ destination: local }).then(() => undefined));
        }
      }
      await Promise.all(downloads);

      // Per-hour grid mp4s — every hour with ≥1 clip renders all member slots,
      // with non-posters filled by a black cell so seat positions stay stable.
      const hourOutputs: string[] = [];
      for (const hour of sortedHours) {
        const clipsThisHour = byHour.get(hour)!;
        const clipByUid = new Map<string, string>();
        for (const c of clipsThisHour) {
          // If a member has multiple clips for an hour (legacy data), keep the first.
          if (!clipByUid.has(c.uid)) {
            clipByUid.set(c.uid, clipPathById.get(c.clipId)!);
          }
        }
        const out = path.join(workdir, `hour-${hour}.mp4`);
        await composeHour(members, clipByUid, out);
        hourOutputs.push(out);
      }

      // Concat hour outputs.
      const finalPath = path.join(workdir, "stitched.mp4");
      await concatHours(hourOutputs, workdir, finalPath);

      // Upload + persist URL. Per-user export path so each member's curated
      // stitch is independent — hiding clips never affects another member's
      // export. We attach a Firebase Storage download token in object metadata
      // and construct the public token URL directly (same format the iOS SDK
      // produces). This avoids getSignedUrl(), which needs
      // `iam.serviceAccounts.signBlob` and isn't granted to the default compute
      // service account.
      const remotePath = `blips/${blipId}/days/${dateKey}/exports/${uid}/stitched.mp4`;
      const downloadToken = randomUUID();
      await bucket.upload(finalPath, {
        destination: remotePath,
        metadata: {
          contentType: "video/mp4",
          metadata: { firebaseStorageDownloadTokens: downloadToken },
        },
      });
      const stitchedUrl =
        `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
        `${encodeURIComponent(remotePath)}?alt=media&token=${downloadToken}`;

      // Persist each member's latest export independently so Archive can list it
      // without making one member's future curation overwrite another's.
      const dayRef = db.collection("blips").doc(blipId).collection("days").doc(dateKey);
      await dayRef.set({ dateKey }, { merge: true });
      await dayRef.update(
        new admin.firestore.FieldPath("exportsByUid", uid),
        {
          stitchStatus: "ready",
          stitchedVideoUrl: stitchedUrl,
          stitchedAt: admin.firestore.FieldValue.serverTimestamp(),
          hours: sortedHours.length,
        },
      );

      logger.info("exportStitch done", {
        blipId,
        dateKey,
        hours: sortedHours.length,
        clips: clipsSnap.size,
      });

      return { url: stitchedUrl, dateKey, hours: sortedHours.length };
    } catch (e) {
      exportFailed = true;
      throw e;
    } finally {
      await fs.rm(workdir, { recursive: true, force: true });
      // Release the lock — `done` triggers the cooldown for subsequent calls;
      // `failed` clears the lock so the user can retry without waiting.
      await lockRef.set(
        {
          state: exportFailed ? "failed" : "done",
          finishedAtMs: Date.now(),
          finishedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      ).catch((err) => logger.warn("export lock release failed", { err }));
    }
  },
);

// MARK: - Helpers

// Parse the storage object path out of a Firebase Storage download URL.
// Expected shape: https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<encoded-path>?alt=media&token=...
// We don't care about the bucket — admin SDK already targets the project bucket.
function storagePathFromVideoUrl(videoUrl: string): string {
  const marker = "/o/";
  const idx = videoUrl.indexOf(marker);
  if (idx < 0) throw new Error(`unrecognized videoUrl: ${videoUrl}`);
  const after = videoUrl.slice(idx + marker.length);
  const queryIdx = after.indexOf("?");
  const encoded = queryIdx >= 0 ? after.slice(0, queryIdx) : after;
  return decodeURIComponent(encoded);
}

function ffmpegBin(): string {
  if (!ffmpegStatic) throw new Error("ffmpeg-static missing");
  return ffmpegStatic;
}

function runFFmpeg(args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const proc = spawn(ffmpegBin(), args, { stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    proc.stderr.on("data", (chunk) => { stderr += chunk.toString(); });
    proc.on("error", reject);
    proc.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`ffmpeg exit ${code}: ${stderr.slice(-500)}`));
    });
  });
}

const CLIP_DURATION_SEC = 2;

async function composeHour(
  members: string[],
  clipByUid: Map<string, string>,
  outPath: string,
): Promise<void> {
  if (members.length === 0) throw new Error("composeHour called with no members");

  // Single-member fast path. `gridFor(1)` now returns a 16:9 landscape cell
  // centered vertically in the 9:16 canvas, so we aspect-fill the clip into
  // that cell and pad the rest of the canvas black. Bypasses xstack (invalid
  // for inputs=1) but still honours the same layout math as multi-member.
  if (members.length === 1) {
    const only = clipByUid.get(members[0]);
    if (!only) throw new Error("single-member hour with no clip");
    const cell = gridFor(1).cells[0];
    await runFFmpeg([
      "-y", "-i", only,
      "-vf",
      `scale=${cell.w}:${cell.h}:force_original_aspect_ratio=increase,` +
      `crop=${cell.w}:${cell.h},` +
      `pad=${CANVAS.width}:${CANVAS.height}:${cell.x}:${cell.y}:black`,
      "-r", "30", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-an",
      outPath,
    ]);
    return;
  }

  const grid = gridFor(members.length);
  const args: string[] = ["-y"];
  const filterParts: string[] = [];

  members.forEach((uid, i) => {
    // Each seat is scaled to its own cell rect — the lone full-width row
    // (odd counts ≥ 7) needs a wider scale than the doubled rows above it.
    const cell = grid.cells[i];
    const clipPath = clipByUid.get(uid);
    if (clipPath) {
      args.push("-i", clipPath);
    } else {
      // lavfi black source sized to this cell so xstack timing/dims align.
      args.push(
        "-f", "lavfi",
        "-t", String(CLIP_DURATION_SEC),
        "-i", `color=c=black:s=${cell.w}x${cell.h}:r=30`,
      );
    }
    filterParts.push(
      `[${i}:v]scale=${cell.w}:${cell.h}:force_original_aspect_ratio=increase,` +
      `crop=${cell.w}:${cell.h},setpts=PTS-STARTPTS[v${i}]`
    );
  });

  const stackInputs = members.map((_, i) => `[v${i}]`).join("");
  filterParts.push(
    `${stackInputs}xstack=inputs=${members.length}:layout=${grid.xstackLayout}:fill=black[stack]`
  );
  filterParts.push(
    `[stack]pad=${CANVAS.width}:${CANVAS.height}:0:0:black[v]`
  );

  args.push(
    "-filter_complex", filterParts.join(";"),
    "-map", "[v]",
    "-r", "30",
    "-c:v", "libx264",
    "-pix_fmt", "yuv420p",
    "-an",
    outPath,
  );
  await runFFmpeg(args);
}

async function concatHours(hourPaths: string[], workdir: string, outPath: string): Promise<void> {
  if (hourPaths.length === 1) {
    await fs.copyFile(hourPaths[0], outPath);
    return;
  }
  const list = hourPaths.map((p) => `file '${p.replace(/'/g, "'\\''")}'`).join("\n");
  const listPath = path.join(workdir, "concat.txt");
  await fs.writeFile(listPath, list);
  await runFFmpeg([
    "-y", "-f", "concat", "-safe", "0", "-i", listPath,
    "-c", "copy", outPath,
  ]);
}
