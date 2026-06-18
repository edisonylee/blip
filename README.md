# blip

A group-vlog app for friends. Everyone in a group records a 2-second clip every hour, and at any moment anyone can export a single stitched video of the day.

The core experience is the **export** — a TikTok-ready highlight reel of your group's day, automatically. The hourly cadence is the forcing function; the stitch is the payoff.

## Status

Pre-MVP. Phase B in progress (capture + clip pipeline + chat + export). US-only at launch. Targeting Gen Z friend groups (HS/college, 3–6 people).

## Core mechanic

1. A user creates a **blipchat** (a group of up to 12) and invites friends.
2. Every hour, each member records a **2-second** clip of what they're doing.
3. Hours where **no** member contributed are auto-skipped on export.
4. Anyone can **export** the blip at any time → a single stitched video.
5. The grid layout adapts to participant count: 1×1, 2×1, 2×2, growing for larger groups.
6. Each blip has one shared timezone and a creator-selected daily recording window.
   The start hour anchors its day key; equal start/end means a 24-hour window.

## Stack

- **iOS:** Swift / SwiftUI, iOS 17+, native
- **Backend:** Firebase (Auth, Firestore, Storage, Cloud Functions, FCM)
- **Auth:** Sign in with Apple (default), phone (SMS OTP) fallback
- **Stitching:** Server-side `ffmpeg` in Cloud Functions (TypeScript)
- **Project generation:** XcodeGen (`project.yml` is canonical)

## Repo layout

```
blip/                  iOS app
├── App/               app entry, root view, env objects
├── Features/          one folder per surface (Capture, Chat, Export, Home, …)
├── Services/          Firebase repositories + service clients
├── Models/            Codable models (Blip, Clip, Message, User, Day)
├── DesignSystem/      typography, color, shared components
└── Resources/         GoogleService-Info.plist (gitignored), assets

functions/             Cloud Functions (TypeScript)
├── src/
│   ├── onClipUpload.ts        ingest + transcode trigger
│   ├── onClipPosted.ts        fanout to blip members
│   ├── exportStitch.ts        ffmpeg grid stitch, on demand
│   ├── sendHourlyPrompt.ts    hourly FCM push to record
│   ├── onReport.ts            moderation report handler
│   └── deleteAccount.ts       App Store-required account deletion

firestore.rules        security rules
storage.rules          storage rules
project.yml            XcodeGen config (canonical)
CLAUDE.md              project memory for AI-assisted dev
```

## Getting started

### Prerequisites

- macOS with Xcode 16+ (Xcode 26 required for App Store submission on/after 2026-04-28)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Node 20+ for Cloud Functions
- Firebase CLI: `npm install -g firebase-tools`
- A Firebase project with Auth, Firestore, Storage, Functions, and FCM enabled

### iOS app

```bash
# Generate the Xcode project from project.yml
xcodegen generate

# Open in Xcode
open blip.xcodeproj
```

Drop your own `GoogleService-Info.plist` into `blip/Resources/` (gitignored — never commit).

### Cloud Functions

```bash
cd functions
npm install
npm run build
npx firebase-tools deploy --only functions
```

### Security rules

```bash
npx firebase-tools deploy --only firestore:rules,storage
```

## App Store readiness

Apple is strict on social/UGC apps. Building these in from day one:

- **Privacy Manifest** (`PrivacyInfo.xcprivacy`) declared
- **Contextual permission prompts** — camera/mic requested only on tap, never at launch
- **Reactive moderation** — report on every clip, block on every user, in-app account deletion
- **Demo account + 60-second walkthrough video** for App Review
- **TestFlight first** → ~50 testers → public submission

## Conventions

- `project.yml` is canonical; `.xcodeproj` is generated and gitignored.
- Cloud Functions are TypeScript, deployed via `npx firebase-tools`.
- Server-side stitch is the source of truth. On-device `AVMutableComposition` is preview-only.
- Lowercase, sentence-case copy throughout (Lane A voice — warm, observational, group-first).

## License

Private / unlicensed. Pre-launch.
