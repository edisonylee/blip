import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { spawn } from "node:child_process";
import { promises as fs } from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import ffmpegStatic from "ffmpeg-static";

import { gridFor, CANVAS } from "./utils/gridLayout";

/**
 * Callable: exportStitch({ blipId })
 *
 * Per CLAUDE.md core mechanic:
 *   - Export is on-demand, current day only (4AM-to-4AM in the blip's timezone).
 *   - Hours where no member contributed are dropped.
 *   - Per-hour grid layout: 1×1, 1×2, 2×2 (3–4), 3×2 (5–6), 3×3 (7–9), 4×3 (10+).
 *
 * Pipeline:
 *   1. Auth + member check.
 *   2. Compute today's dateKey in the blip's TZ (4AM shift).
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
    if (typeof blipId !== "string" || blipId.length === 0) {
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
    const tz: string = blip.timezoneIdentifier ?? "UTC";
    const dateKey = todaysDateKey(tz);

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
    const sortedHours = [...byHour.keys()].sort((a, b) => a - b);

    const workdir = await fs.mkdtemp(path.join(os.tmpdir(), `stitch-${blipId}-`));
    try {
      // Download each unique clip exactly once.
      const clipPathById = new Map<string, string>();
      const downloads: Promise<void>[] = [];
      for (const arr of byHour.values()) {
        for (const c of arr) {
          if (clipPathById.has(c.clipId)) continue;
          const local = path.join(workdir, `clip-${c.clipId}.mov`);
          clipPathById.set(c.clipId, local);
          downloads.push(downloadToFile(c.videoUrl, local));
        }
      }
      await Promise.all(downloads);

      // Per-hour grid mp4s.
      const hourOutputs: string[] = [];
      for (const hour of sortedHours) {
        const clipsThisHour = byHour.get(hour)!;
        clipsThisHour.sort((a, b) => (a.uid + a.clipId).localeCompare(b.uid + b.clipId));
        const inputs = clipsThisHour.map((c) => clipPathById.get(c.clipId)!);
        const out = path.join(workdir, `hour-${hour}.mp4`);
        await composeHour(inputs, out);
        hourOutputs.push(out);
      }

      // Concat hour outputs.
      const finalPath = path.join(workdir, "stitched.mp4");
      await concatHours(hourOutputs, workdir, finalPath);

      // Upload + persist URL.
      const remotePath = `blips/${blipId}/days/${dateKey}/stitched.mp4`;
      await bucket.upload(finalPath, {
        destination: remotePath,
        metadata: { contentType: "video/mp4" },
      });
      const [signedUrl] = await bucket.file(remotePath).getSignedUrl({
        action: "read",
        expires: Date.now() + 7 * 24 * 60 * 60 * 1000,
      });

      await db.collection("blips").doc(blipId)
        .collection("days").doc(dateKey)
        .set({
          stitchStatus: "ready",
          stitchedVideoUrl: signedUrl,
          stitchedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

      logger.info("exportStitch done", {
        blipId,
        dateKey,
        hours: sortedHours.length,
        clips: clipsSnap.size,
      });

      return { url: signedUrl, dateKey, hours: sortedHours.length };
    } finally {
      await fs.rm(workdir, { recursive: true, force: true });
    }
  },
);

// MARK: - Helpers

function todaysDateKey(tz: string): string {
  const now = new Date(Date.now() - 4 * 60 * 60 * 1000);
  const fmt = new Intl.DateTimeFormat("en-CA", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return fmt.format(now); // en-CA gives YYYY-MM-DD
}

async function downloadToFile(url: string, dest: string): Promise<void> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`download ${res.status} ${url}`);
  const buf = Buffer.from(await res.arrayBuffer());
  await fs.writeFile(dest, buf);
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

async function composeHour(inputs: string[], outPath: string): Promise<void> {
  if (inputs.length === 0) throw new Error("no inputs for hour");
  if (inputs.length === 1) {
    await runFFmpeg([
      "-y", "-i", inputs[0],
      "-vf",
      `scale=${CANVAS.width}:${CANVAS.height}:force_original_aspect_ratio=increase,` +
      `crop=${CANVAS.width}:${CANVAS.height}`,
      "-r", "30", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-an",
      outPath,
    ]);
    return;
  }

  const grid = gridFor(inputs.length);
  const filterParts: string[] = [];

  inputs.forEach((_, i) => {
    filterParts.push(
      `[${i}:v]scale=${grid.cellWidth}:${grid.cellHeight}:force_original_aspect_ratio=increase,` +
      `crop=${grid.cellWidth}:${grid.cellHeight},setpts=PTS-STARTPTS[v${i}]`
    );
  });

  const stackInputs = inputs.map((_, i) => `[v${i}]`).join("");
  filterParts.push(
    `${stackInputs}xstack=inputs=${inputs.length}:layout=${grid.xstackLayout}:fill=black[stack]`
  );
  filterParts.push(
    `[stack]pad=${CANVAS.width}:${CANVAS.height}:0:0:black[v]`
  );

  const args: string[] = ["-y"];
  for (const inp of inputs) {
    args.push("-i", inp);
  }
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
