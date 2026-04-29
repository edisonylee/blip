#!/usr/bin/env node
/**
 * Seeds a test blip + clips to verify the export pipeline end-to-end.
 *
 * Usage:
 *   cd functions && node scripts/seed-export-test.js
 *   USER_UID=<your_uid> node scripts/seed-export-test.js
 *
 * Auth: uses Application Default Credentials (`gcloud auth application-default login`).
 *
 * Side effects:
 *   - Creates Firestore docs at blips/<new-blip-id>/...
 *   - Uploads .mov files to Storage at blips/<new-blip-id>/days/<date>/<uid>/<hour>.mov
 *
 * After running, open the iOS app (you'll be a member of the new blip), tap into
 * "export-verify", tap the film icon, run export. Inspect the resulting stitched.mp4.
 *
 *   hour A (current hour):   all 4 members posted   → expect 1×4 grid, no black cells
 *   hour B (current hour-1): only members 0 and 2   → expect 1×4 grid with black at seats 1,3
 */

const admin = require("firebase-admin");
const { spawnSync } = require("node:child_process");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");

const PROJECT_ID = "blip-4a5dc";
const STORAGE_BUCKET = "blip-4a5dc.firebasestorage.app";
const TIMEZONE = "America/New_York";
const DEFAULT_USER_UID = "wUVuqLbLJYVfbdFwKcJHKOrKFEK2";

const userUid = process.env.USER_UID || DEFAULT_USER_UID;

admin.initializeApp({
  projectId: PROJECT_ID,
  storageBucket: STORAGE_BUCKET,
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

// Mirror functions/src/exportStitch.ts:todaysDateKey — same 4AM shift + tz.
function todaysDateKey(tz) {
  const now = new Date(Date.now() - 4 * 60 * 60 * 1000);
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

const SEAT_COLORS = ["0xFF6B6B", "0x4ECDC4", "0xFFE66D", "0xA8E6CF"];
const SEAT_LABELS = ["MEMBER 1", "MEMBER 2", "MEMBER 3", "MEMBER 4"];

function generateClip(seatIdx, outPath) {
  const args = [
    "-y",
    "-f", "lavfi",
    "-i", `color=c=${SEAT_COLORS[seatIdx]}:s=1280x720:d=2:r=30`,
    "-vf",
    `drawtext=fontfile=/System/Library/Fonts/Helvetica.ttc:` +
      `text='${SEAT_LABELS[seatIdx]}':fontsize=120:fontcolor=white:` +
      `x=(w-text_w)/2:y=(h-text_h)/2`,
    "-c:v", "libx264", "-pix_fmt", "yuv420p",
    "-movflags", "+faststart",
    outPath,
  ];
  const res = spawnSync("ffmpeg", args, { stdio: ["ignore", "ignore", "pipe"] });
  if (res.status !== 0) {
    throw new Error(`ffmpeg failed for seat ${seatIdx}: ${res.stderr.toString().slice(-400)}`);
  }
}

async function main() {
  console.log("seed: starting");

  const blipRef = db.collection("blips").doc();
  const blipId = blipRef.id;
  // Mock uids for the other 3 seats. Storage rules normally block writes for
  // these (no matching auth.uid), but admin SDK bypasses rules.
  const mockUids = ["seed_mock_uid_1", "seed_mock_uid_2", "seed_mock_uid_3"];
  const members = [userUid, ...mockUids];
  const dateKey = todaysDateKey(TIMEZONE);
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), `seed-${blipId}-`));

  console.log(`seed: blipId=${blipId} dateKey=${dateKey}`);

  await blipRef.set({
    name: "export-verify",
    ownerUid: userUid,
    members,
    size: 4,
    joinCode: "verify",
    timezoneIdentifier: TIMEZONE,
    createdAt: admin.firestore.Timestamp.fromDate(new Date()),
  });
  console.log("seed: blip doc written");

  console.log("seed: generating 4 synthetic clips with ffmpeg");
  const localClips = members.map((uid, i) => {
    const out = path.join(tmpdir, `${uid}.mov`);
    generateClip(i, out);
    return { uid, localPath: out, seatIdx: i };
  });

  const currentHour = new Date().getHours();
  const hourA = currentHour;
  const hourB = (currentHour - 1 + 24) % 24;
  const plan = [
    { hour: hourA, posters: [0, 1, 2, 3], label: "A (full)" },
    { hour: hourB, posters: [0, 2], label: "B (sparse: seats 1,3 missing)" },
  ];

  const batch = db.batch();
  for (const { hour, posters, label } of plan) {
    console.log(`seed: hour ${hour} ${label}`);
    for (const idx of posters) {
      const clip = localClips[idx];
      const storagePath = `blips/${blipId}/days/${dateKey}/${clip.uid}/${hour}.mov`;
      // Use a Firebase Storage download token (same format the iOS SDK produces
      // via downloadURL()). getSignedUrl() needs service-account creds; ADC
      // user creds can't sign. Token URLs are unauthenticated GETs once issued.
      const downloadToken = crypto.randomUUID();
      await bucket.upload(clip.localPath, {
        destination: storagePath,
        metadata: {
          contentType: "video/quicktime",
          metadata: { firebaseStorageDownloadTokens: downloadToken },
        },
      });
      const url =
        `https://firebasestorage.googleapis.com/v0/b/${STORAGE_BUCKET}/o/` +
        `${encodeURIComponent(storagePath)}?alt=media&token=${downloadToken}`;
      const clipDoc = db
        .collection("blips").doc(blipId)
        .collection("days").doc(dateKey)
        .collection("clips").doc(`${clip.uid}_${hour}`);
      batch.set(clipDoc, {
        uid: clip.uid,
        hour,
        videoUrl: url,
        caption: null,
        createdAt: admin.firestore.Timestamp.fromDate(new Date()),
        sharedToBlipIds: [blipId],
        durationSeconds: 2.0,
        reportCount: 0,
        hidden: false,
      });
      console.log(`  uid=${clip.uid.slice(0, 12)} hour=${hour} → ${storagePath}`);
    }
  }
  await batch.commit();
  console.log("seed: firestore clip docs committed");

  fs.rmSync(tmpdir, { recursive: true, force: true });

  console.log("\n=== seed complete ===");
  console.log(`blipId:  ${blipId}`);
  console.log(`dateKey: ${dateKey}`);
  console.log(`hour A:  ${hourA} (4 posters — should render full 1×4)`);
  console.log(`hour B:  ${hourB} (2 posters at seats 0,2 — should render 1×4 with black at seats 1,3)`);
  console.log("\nNext:");
  console.log("  1. Open the iOS app — \"export-verify\" should appear in your list");
  console.log("  2. Tap into it → tap the film icon → run export");
  console.log("  3. Inspect the resulting stitched.mp4");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("seed: failed", err);
    process.exit(1);
  });
