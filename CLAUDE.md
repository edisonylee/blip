# Project: Setlog US

Building a US-targeted version of Setlog (Korean group-vlog app).
See setlog-research/setlog-research.md for full context.

## Core mechanic

1. User creates a group chat ("blip") and invites friends.
2. Every hour, each member records a **2-second** video clip of what they're doing.
3. Hours where **no** member contributed are **skipped** on export (auto-removed from the stitched video).
4. Anyone can **export** the blip at any time → a single savable video stitched from every contributed hour's clips.
5. **Layout grid** within an hour adapts to participant count: 1×1 (1), 2×1 (2), 2×2 (3–4), and **dynamically grows columns/rows past 4** (e.g. 3-wide for 5–6, etc.) so larger groups still fit cleanly.

## Active decisions

- **Target user:** Gen Z friend groups (HS/college, groups of 3–6)
- **Goal:** Reimagine for US — keep mechanic, rethink UX where US-specific gaps show up
- **First priority:** Virality — the stitched export must rip on TikTok
- **Stack:** iOS native (Swift / SwiftUI), iOS 17+
- **Backend:** Firebase (Auth, Firestore, Storage, Functions, FCM)
- **Auth:** Sign in with Apple (default), phone (SMS OTP) fallback on first invite/contact-sync
- **Cadence:** Hourly (Setlog parity) — accept §4.6 retention risk; cadence experiment is first v0.5 lever if data shows burnout
- **MVP scope:** Full Setlog parity (all 11 documented flows + export + archive)
- **v0 UX divergence:** §4.2 live group card only — other §4 fixes deferred
- **Brand:** US-native original identity (not Korean-indie homage)
- **Day boundary:** 4AM in the *blip's* timezone (not per-user) — set at blip creation, defaults to creator's TZ

## Reference

- Plan: [/Users/edisonlee/.claude/plans/i-m-building-a-blip-delightful-cat.md](/Users/edisonlee/.claude/plans/i-m-building-a-blip-delightful-cat.md)
- Research + screenshots: [setlog-research/](setlog-research/)
- Setlog export flow is **undocumented** — open research item, gates the export screen design

## Conventions

- Project generation via XcodeGen (`project.yml` is canonical; `.xcodeproj` is generated)
- Cloud Functions: TypeScript, deployed via `npx firebase-tools`
- Stitch is server-side only (`ffmpeg` in Cloud Functions); on-device `AVMutableComposition` is for preview iteration only

## App Store submission requirements (UGC/social)

Apple is strict on social apps. Build these in from day one — retrofitting after rejection costs weeks.

### Build/SDK
- **iOS 26 SDK + Xcode 26 required** for any binary submitted on/after **2026-04-28**. Bump `project.yml` deployment target and CI Xcode version before final build.
- **Privacy Manifest** (`PrivacyInfo.xcprivacy`) is **mandatory** — declare data collected, sensitive APIs used, and tracking SDKs. Top rejection reason in 2026. Verify Firebase's manifest is current (it has been).
- **Contextual permission prompts only.** Never request camera/mic at launch — only when the user taps to capture. `NSCameraUsageDescription` / `NSMicrophoneUsageDescription` must clearly explain why.

### UGC moderation (non-negotiable)
- **Report button** on every clip.
- **Block button** on every user.
- **Account deletion** in-app.
- **Reactive moderation** (human review after reports) is sufficient for v1 — no proactive AI filter required.
- Document the moderation flow in App Review Notes.

### Age & geography
- **Age rating: plan for 17+** unless moderation is airtight.
- **Australia (effective 2025-12-10):** under-16s blocked from social accounts — needs real age verification, not a checkbox. **US-only at launch** sidesteps this.
- **EU:** GDPR + DMA + age rules — defer post-MVP. Ship US-only first.

### Submission package
- **Demo account credentials** in Review Notes (reviewers will try to use the social features).
- **60-second demo video** linked in Review Notes — the hourly/2-sec mechanic is unusual; reviewers will not figure it out cold.
- **Real screenshots**, not mockups.
- **Privacy policy URL** live before submission (Termly/iubenda is fine).
- **Backend up during review window**; if any IP-blocking is in place, allowlist Apple's review IP range.

### Launch path
- **TestFlight first** → ~50 active testers → fix → App Store proper. Don't go straight to App Store with a social app.
