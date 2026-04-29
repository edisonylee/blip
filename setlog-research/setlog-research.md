# Setlog → US Version: Research & Strategy Doc

> Working doc for building a US-targeted version of Setlog, the Korean group-vlog app.
> Last updated: April 2026

---

## 1. App Overview

**What it is:** Setlog is a real-time group vlog app, popular in South Korea. Up to 12 friends share a "log" (room). Every hour, the app prompts each person to film a 2–4 second clip. At the end of the day (4AM reset), Setlog's algorithm auto-stitches everyone's hourly clips into a single split-screen "day-in-the-life" video.

**The core insight:** Eliminates editing. Removes the pressure to capture the perfect moment. Output feels authentic, low-stakes — the opposite of curated TikTok/Instagram content.

**Lineage:** Same authenticity-first lineage as BeReal (one daily prompt, simultaneous photo) and Locket (live photos to friends' home screens).

**Why it works in Korea:**
- "Forced synchronicity" — the hourly cadence creates a shared experience
- No-edit auto-stitch — output is shareable in one tap
- Group format (up to 12) — built for friend groups, not solo creators
- Cute, indie aesthetic — feels handmade, not corporate

**Korean user feedback themes (from the app's Instagram):**
- Strong demand for Android version
- Want calendar view of past logs
- Want directional arrows to nav to yesterday's log
- Want a "memory recap" feature across all clips ever
- Repeatedly described as "cute" and good for "building memories"

---

## 2. Current Flow (as documented from screenshots)

| # | Screen | What happens |
|---|--------|--------------|
| 01 | Home (empty state) | SETLOG header, "rotate to capture" hint, default solo "vlog" space, numbered tutorial (tap +, create or join, 2s clip per hour, day resets at 4AM). Camera/logs toggle at bottom. |
| 02 | + tapped | Small popover: "create a log" / "join a log" |
| 03 | Create a log | Name input + log size picker (2–12). One screen, very minimal. |
| 04 | Group created | Shows group name, join code (e.g. `# c9kz6il`), "invite a friend →", "done →" |
| 05 | Invite | Native iOS share sheet |
| 06 | Home with group | New group appears as a card under solo vlog |
| 07 | Inside the group | Header (group name, share, chat icon). Vertical stack of hour slots. Your slot says "tap to capture," empty slots say "invite a friend." "Today" pill at bottom. |
| 08 | Capture review | Recorded clip with "21:00" timestamp overlay. "send to:" with checkboxes (group + solo vlog). Cross-posting supported. |
| 09 | Posted | Clip fills your slot in the group view |
| 10 | Long-press menu | delete / edit caption / save |
| 11 | Group chat | Separate text chat thread alongside the visual log |

**Additional confirmed flows (not screenshotted):**
- **Export:** End-of-day stitched video compiles all members' hourly clips. One-tap share to TikTok / IG story / IG message.
- **Archive:** Past logs are accessible.
- **Hourly prompt:** Notification fires each hour with "time to log what you're doing" copy.

Screenshots are in `/screenshots/screen-01.png` through `screen-11.png`.

---

## 3. What's Working (Preserve in US Version)

**The aesthetic.** Black background, pink/teal SETLOG wordmark, monospace lowercase, doodle illustrations (turtle, UFO, star). Genuinely distinctive — handmade, Korean-indie energy. BeReal never had this. Don't sand it off when localizing; it's why people screenshot the UI.

**The forced synchronicity mechanic.** The hourly cadence is the moat. It's what makes the output feel like a shared day rather than a montage.

**Cross-posting on capture.** The "send to:" checkbox letting users post a clip to multiple logs (group + solo) is smart and underutilized — BeReal doesn't have this.

**One-tap share to TikTok/IG.** Critical. The exported video doing well on TikTok is the entire growth loop.

---

## 4. UX Gaps (Identified Issues)

### 4.1 Home tutorial does too much work
New users land on a wall of numbered instructions before they've felt anything. US users — especially Gen Z — bounce on tutorial walls. They want to *see* the output first.
**Fix direction:** First-launch autoplay of an example split-screen vlog. Show, don't tell.

### 4.2 Group card is visually inert
The group card on home looks identical to the solo vlog card. No signal of today's progress: how many hours captured, who's posted, time until next prompt. This is the dashboard moment people will check 10x/day; right now it's flat.
**Fix direction:** Live progress ring or hour-counter, member avatars showing who's posted, countdown to next slot.

### 4.3 The hour-slot grid feels empty
Inside a group, the core screen is a vertical stack of hour slots — most saying "invite a friend" with a `+` icon. For a 3-person group on hour 14, you see 3 small clips and 21 empty boxes. Discouraging ratio.
**Fix direction:** Collapse empty hours, show only active/upcoming, or switch to horizontal timeline.

### 4.4 Group code as primary invite mechanic
`# c9kz6il` is friction. US Gen Z expects username search, contact sync, or invite-via-link with deep linking. The iOS share sheet is fine as an option, but the code shouldn't be the mental model.
**Fix direction:** Deep-linked invite URLs as the default; keep code as a fallback.

### 4.5 Export screen is the product, but invisible in research
The auto-stitched split-screen vlog *is* the product. Where it lives in the UI, what the export screen looks like, and how cleanly it lands on TikTok — these determine virality. Need to capture and audit this flow next.

### 4.6 Hourly cadence may be too aggressive for US market
Americans showed limited tolerance for app-driven schedule pressure (BeReal burned that goodwill once a day). 16+ prompts/day may be too much.
**Fix direction:** Test 4–6 prompts/day vs. hourly. Possibly a "lite mode" for casual users vs. "full mode" for committed groups.

---

## 5. Strategic Questions (Open)

These materially change what gets built. Answers pending.

**Goal of the US version:**
- True 1:1 clone, just localized?
- Same core, better UX + US-native polish?
- Reimagine — fix what Setlog gets wrong?
- Fork the mechanic into a new product?

**Target user (first):**
- Gen Z friend groups (high school / college)?
- Millennials documenting family / partner life?
- Creators wanting low-effort daily content?
- Broad — like BeReal tried to be?

**What matters most to nail first (rank):**
- Virality — exported video must rip on TikTok
- Retention — daily habit that doesn't burn out
- Onboarding — getting friends in the group fast
- Aesthetic — visual identity people screenshot

---

## 6. Open Research Items

Flows not yet documented. Capture next:

1. **End-of-day stitched export screen** — what does the user see when the day's vlog is ready? Loading state? Preview? Edit/reorder options?
2. **TikTok/IG share handoff** — does it open the target app with the video pre-loaded? Watermark behavior?
3. **Archive / past logs view** — calendar? feed? per-group?
4. **Notification UI** — what does the hourly prompt look like on lock screen? Copy variants?
5. **Profile screen** (if exists) — settings, privacy, log memberships
6. **Solo vlog vs. group vlog** — does solo behavior differ from group? Korean users use solo logs without limits, per the home tutorial.
7. **What happens if you miss an hour** — empty slot? grace period? skip?

---

## 7. Next Steps

- [ ] Answer strategic questions above to lock target user + goal
- [ ] Capture missing flows (export, archive, notifications)
- [ ] Competitive teardown: BeReal (post-mortem on why it died), Locket, TikTok Now, Snapchat memories
- [ ] Sketch redesigned home + group dashboard
- [ ] Define MVP feature set vs. v2 roadmap
- [ ] Decide: rebuild from scratch vs. white-label vs. partner with Setlog Korea
- [ ] Test naming + brand direction (keep "Setlog"? new name for US?)

---

## 8. Reference Notes

**Original conversation context:**
- App is iOS-only currently; Korean users requesting Android
- Domain: setlog.kr
- Day boundary: 4AM to 4AM
- Group size: 2–12
- Clip length: 2–4 seconds
- Designed originally for groups of 3

**Conversation key takeaways:**
- The mechanic (forced synchronicity + auto-stitch) is the moat, not the visuals
- The visuals are the screenshot bait that drives organic discovery
- US version needs to decide between cloning vs. reimagining — these lead to different products
- The export → TikTok flow is the growth loop and must be polished above all else
