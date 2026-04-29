# Project: Setlog US

Building a US-targeted version of Setlog (Korean group-vlog app).
See setlog-research/setlog-research.md for full context.

## Core mechanic

1. User creates a blipchat (group chat where every member contributes 2-sec clips) and invites friends. A "blip" = the blipchat itself; a "blip clip" = the 2-sec video.
2. Every hour, each member records a **2-second** video clip of what they're doing.
3. Hours where **no** member contributed are **skipped** on export (auto-removed from the stitched video).
4. Anyone can **export** the blip at any time → a single savable video stitched from every contributed hour's clips.
5. **Layout grid** within an hour adapts to participant count: 1×1 (1), 2×1 (2), 2×2 (3–4), and **dynamically grows columns/rows past 4** (e.g. 3-wide for 5–6, etc.) so larger groups still fit cleanly.

## Progressive completion notifications

When a member posts a clip in a blipchat, the remaining members get a fan-out push that surfaces the running count for the current hour. The final unposted member gets a dedicated "last one" callout — that's the conversion lever for filling the hour.

- **Bucket:** "this hour" = the **blipchat's local hour** at the time of the post (single source of truth — same hour the stitch uses). A clip's `hour` field is the poster's local hour and stays as-is for grid/export, but the nudge groups by blipchat TZ.
- **Self-suppress:** the poster never gets a nudge for their own post.
- **Throttle by group size:**
  - **2–4 members:** notify on every post (small enough that each ping carries signal).
  - **5+ members:** notify only at milestones — *halfway* (≥50% posted) and *last one*. Avoids 9 pings in a 10-person blipchat.
  - **Last-one** always fires, regardless of size — that's the highest-value moment.
- **Group complete:** silent — don't ping after 100%. The in-app card already reflects it; an extra push is noise.
- **Hourly base prompt** (top of hour, from `sendHourlyPrompt`) only fires for members who haven't posted yet in the current blipchat-TZ hour; the body includes the running count.
- **Quiet hours:** every notification path respects the recipient's quiet window (already enforced in the cron; same check applies in the per-post fan-out).

Copy lives in [.claude/agents/copy-writer.md](.claude/agents/copy-writer.md) — Lane A voice, group-first.

## Camera-tab capture flow (global capture)

Snapchat-style. Bottom-left "camera" tab on Home opens a record-first surface; on stop, a multi-select picker lists every blipchat the user is in. Fan-out writes one clip doc per selected blipchat (`sharedToBlipIds` already models this).

- **Capture order:** record → pick blipchats → send.
- **Default selection:** all unchecked.
- **Hour binding:** the clip lands in the **user's local hour** at upload time. Each blipchat's stitch boundary is its own TZ, but the clip's `hour` is the *poster's* hour — sleep hours just become empty hours that the export auto-skips per core mechanic.
- **Re-record window:** until the user's local hour rolls over, posting again replaces the previous clip in any blipchat selected this hour.
- **Source:** camera capture only — no library import in v1.

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

## SOLID principles (enforced on every PR)

Every Swift file — Views, ViewModels, Services, Repositories — must satisfy these five rules. Violations are caught in code review and must be fixed before merge.

### S — Single Responsibility
- Each type does one thing. A `View` renders UI. A `ViewModel` holds state and drives business logic. A `Repository` owns data access. A `Service` owns a single external concern (auth, upload, notifications).
- **Checklist:** if a file imports both `SwiftUI` and `FirebaseFirestore`, it is almost certainly violating SRP. Views must never call Firestore, Auth, or Storage directly — those calls belong in a ViewModel or Service.
- `@State` in a view is fine for pure UI state (sheet open/closed, focus). It is wrong for async work, error messages, or network responses — those go in a `@StateObject` ViewModel.

### O — Open / Closed
- Add behaviour by adding new types, not by editing existing ones. New clip types, new notification strategies, new auth providers — each gets its own conforming type, not a new `if/else` branch in an existing class.
- Use `switch` over enums exhaustively so the compiler catches missing cases when variants are added.

### L — Liskov Substitution
- Every protocol conformance must be honest: a mock or test double must be a valid substitute for the real thing in every context where the protocol is used.
- Never have a conforming type `fatalError` or `return []` to satisfy a protocol it doesn't actually implement — that makes the protocol useless for substitution.

### I — Interface Segregation
- Protocols are small and focused. If a ViewModel only needs `createBlip` and `joinBlip`, it depends on `BlipMutating` — not on the full `BlipRepositoryProtocol` (which also includes `@Published` properties the ViewModel doesn't need).
- `ObservableObject` protocols (`BlipRepositoryProtocol`, `AuthServiceProtocol`) are for SwiftUI views that observe published state. ViewModels that only call methods use the thin, non-`ObservableObject` protocol variants.

### D — Dependency Inversion
- ViewModels never instantiate their own dependencies. Dependencies arrive via initialiser parameters typed as protocols, not concrete classes.
- **Concrete types banned in ViewModel init/function signatures:** `BlipRepository`, `AuthService`, `ClipUploader`, `Firestore`, `Storage`. Use `any BlipMutating`, `uid: String`, etc.
- The view resolves concrete objects from the environment and passes them down — it is the composition root for that screen.

---

## Clean code & layout rules

### Swift / general
- **No magic numbers.** Extract constants (`CaptureSession.clipDuration`, `BlipCard.cornerRadius`) — never inline `2.0`, `220`, `14` without a name.
- **No raw colour literals.** Always use `BlipColor.*` tokens. Never `.red`, `.blue`, or `Color(hex:)` inline in a view.
- **No hardcoded copy in views.** String literals that the user sees ("tap to record", "invite a friend") must match the Lane A copy doc — run the copy-writer agent before shipping any new screen.
- **Debug prints must be wrapped** in `#if DEBUG / #endif`. Production builds must produce zero console output from `print()`.
- **One public type per file.** Private helpers and sub-views can live in the same file but must be `private`.
- **Mark sections with `// MARK: -`.** Use `Header`, `Body`, `Footer`, `Helpers`, `Actions`, `Subviews` — whichever sections apply.

### SwiftUI layout
- **Design system first.** Before writing a new button, field, card, or error label, check `DesignSystem/` — `BlipButton`, `BlipTextField`, `BlipCard`, `ErrorText`, `AvatarView` must be used instead of re-implementing.
- **Tap targets ≥ 44pt.** Every tappable element must have `frame(minWidth: 44, minHeight: 44)` or be at least 44×44 in its rendered size (iOS HIG).
- **Accessibility labels on icon-only controls.** Any `Button` or `NavigationLink` whose label is only an `Image(systemName:)` must have `.accessibilityLabel("…")`.
- **No `DoodleBackground`.** The Korean-indie doodle layer is out of brand for Lane A. Remove it from any screen where it appears.
- **Adaptive grids, not fixed columns.** When displaying a collection that can grow (clip grid, member list), use the column-count helper from `HourClipGrid` — never hardcode a `LazyVGrid` column count.
- **No fixed heights that kill grids.** `.frame(height: 220)` inside a reusable slot component means that component cannot be used in a grid. Fixed heights belong at the call site, not inside the component.

### File & folder layout
```
Features/
  <FeatureName>/
    <FeatureName>View.swift       — SwiftUI view, no business logic
    <FeatureName>ViewModel.swift  — @MainActor ObservableObject, owns state + async
    (sub-views stay in the View file as private structs)

Services/
  <Name>Repository.swift          — reactive data (ObservableObject, Firestore listeners)
  <Name>Service.swift             — one-shot operations (upload, auth, notifications)
  Protocols/
    <Name>Protocol.swift          — full reactive protocol (inherits ObservableObject)
    <Name>Mutating.swift          — thin write-only protocol (no ObservableObject)

DesignSystem/
  Blip<ComponentName>.swift       — reusable UI atoms (BlipButton, BlipTextField, …)
  BlipColor.swift                 — all colour tokens
  BlipTypography.swift            — all font tokens
```
New features always get their own folder under `Features/`. Never add feature-specific code to an existing feature's folder.

## Conventions

- Project generation via XcodeGen (`project.yml` is canonical; `.xcodeproj` is generated)
- Cloud Functions: TypeScript, deployed via `npx firebase-tools`
- Stitch is server-side only (`ffmpeg` in Cloud Functions); on-device `AVMutableComposition` is for preview iteration only

### XcodeGen workflow (MUST follow to avoid duplicate Compile Sources entries)

Whenever you create, rename, or delete a Swift file:
1. **Close Xcode first** — if Xcode is open it auto-detects new files and adds them to the project; XcodeGen then adds them again, creating duplicate Compile Sources entries that break the build.
2. Run `xcodegen generate` in the repo root.
3. Reopen `blip.xcodeproj`.

**Never create a file that already exists.** Before writing any new Swift file, run:
```
find /Volumes/SANJUG_SSD/blip -name "<FileName>.swift"
```
If it already exists, edit the existing file — do not create a second copy. Duplicate Swift types (`Invalid redeclaration of 'X'`) are always caused by two files defining the same type, either at different paths or as Xcode-generated `"Name 2.swift"` copies.

**Detecting and fixing duplicates:**
- `find /Volumes/SANJUG_SSD/blip -name "* 2.swift"` — lists any Xcode-generated copies; delete them all.
- `grep -c "<TypeName>" blip.xcodeproj/project.pbxproj` — should return exactly 4 for each file (file ref, build file, compile source, group). 8 = duplicated; delete the extra physical file then re-run `xcodegen generate`.
- If Compile Sources still shows a duplicate after deleting the file: Xcode → target → Build Phases → Compile Sources → select duplicate → **−** → **Shift+Cmd+K** → **Cmd+B**.

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
