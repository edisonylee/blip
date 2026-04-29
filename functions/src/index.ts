import * as admin from "firebase-admin";

admin.initializeApp();

// Function entry points are exported here.
// Implementations live in sibling modules and are imported once their architecture is locked.

export { onClipUpload } from "./onClipUpload";
export { onClipPosted } from "./onClipPosted";
export { exportStitch } from "./exportStitch";
export { sendHourlyPrompt } from "./sendHourlyPrompt";
export { deleteAccount } from "./deleteAccount";
export { onReport } from "./onReport";
export { onNudgeCreated } from "./onNudge";
export { onClipCreatedUpdateStats, onFriendshipChangeUpdateCount } from "./userStats";
export { onUserCreated } from "./onUserCreated";
export { claimReferral } from "./claimReferral";
