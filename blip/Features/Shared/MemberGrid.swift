import AVKit
import SwiftUI

// MARK: - Grid layout (Swift mirror of functions/src/utils/gridLayout.ts)

/// Cell layout derived from `blip.size`, matching the export pipeline so the
/// in-app preview is positionally faithful to the stitched output.
///
///   1     -> 1 row, 1 cell (full canvas)
///   2..5  -> N rows × 1 col (landscape clips fill full-width rows)
///   6     -> 3 rows × 2 cols
///   7     -> 3 doubled rows + 1 lone full-width row    (4 rows total)
///   8     -> 4 rows × 2 cols
///   9     -> 4 doubled rows + 1 lone full-width row    (5 rows total)
///  10     -> 5 rows × 2 cols
///  11     -> 5 doubled rows + 1 lone full-width row    (6 rows total)
///  12     -> 6 rows × 2 cols                            (12 = hard cap)
///
/// Every row has equal height; columns split each row's width evenly. The
/// "lone row" pattern handles odd member counts ≥ 7 — the last person gets a
/// full-width row instead of leaving a blank cell. Mirrors
/// `functions/src/utils/gridLayout.ts` — keep both in sync so preview ==
/// export.
struct MemberGridLayout {
    /// Per-seat rectangles in canvas (1080×1920) pixel coords. Index = seat
    /// order, so `cells[i]` is the rect for the i-th member in `blip.members`.
    let cells: [Cell]
    /// Row decomposition for view rendering: each row is the list of seat
    /// indices it contains, left-to-right. All rows have equal height.
    let rows: [[Int]]

    static let canvasWidth: CGFloat = 1080
    static let canvasHeight: CGFloat = 1920
    static let canvasAspect: CGFloat = canvasWidth / canvasHeight

    struct Cell: Equatable {
        let x: CGFloat
        let y: CGFloat
        let w: CGFloat
        let h: CGFloat
    }

    static func layout(for memberCapacity: Int) -> MemberGridLayout {
        let count = max(1, memberCapacity)
        let W = canvasWidth
        let H = canvasHeight

        var cells: [Cell] = []
        var rows: [[Int]] = []

        if count == 1 {
            // 1 person → a single 16:9 landscape cell centered vertically in
            // the 9:16 canvas. The clip is recorded landscape; this preserves
            // its native framing with black bars top + bottom rather than
            // cropping to a portrait full-canvas cell.
            let cellW = W
            let cellH = (W * 9.0 / 16.0).rounded()
            let yOffset = ((H - cellH) / 2).rounded()
            cells.append(Cell(x: 0, y: yOffset, w: cellW, h: cellH))
            rows.append([0])
        } else if count <= 5 {
            let cellH = H / CGFloat(count)
            for i in 0..<count {
                cells.append(Cell(x: 0, y: CGFloat(i) * cellH, w: W, h: cellH))
                rows.append([i])
            }
        } else {
            // 6+: two columns, with an optional lone full-width row at the
            // bottom when the member count is odd.
            let isOdd = count % 2 != 0
            let fullRows = isOdd ? (count - 1) / 2 : count / 2
            let totalRows = isOdd ? fullRows + 1 : fullRows
            let rowH = H / CGFloat(totalRows)
            let colW = W / 2
            var idx = 0
            for r in 0..<fullRows {
                cells.append(Cell(x: 0, y: CGFloat(r) * rowH, w: colW, h: rowH))
                cells.append(Cell(x: colW, y: CGFloat(r) * rowH, w: colW, h: rowH))
                rows.append([idx, idx + 1])
                idx += 2
            }
            if isOdd {
                // Lone cell is the same size as a doubled cell (half-width)
                // and horizontally centered — black bars on either side in
                // the export, equal flex spacers in the SwiftUI preview.
                cells.append(Cell(x: (W - colW) / 2, y: CGFloat(fullRows) * rowH, w: colW, h: rowH))
                rows.append([idx])
            }
        }

        return MemberGridLayout(cells: cells, rows: rows)
    }
}

// MARK: - Seat model

private enum Seat {
    case posted(BlipClip, isMine: Bool, initials: String)
    case recordPrompt(initials: String)              // current hour, you, no clip yet
    case waiting(uid: String, initials: String)      // current hour, member, no clip yet
    case blackScreen(uid: String, initials: String)  // past hour, member, no clip
    case invite                                      // empty seat (group not full)
}

// MARK: - Member grid

/// Single source of truth for the per-hour grid. Used by `BlipDetailView`
/// (interactive: record, invite, context menu, optional nudge) and
/// `ExportView` (read-only preview of the stitch composition).
struct MemberGrid: View {
    let blip: Blip
    let hour: Int
    let clipsForHour: [BlipClip]
    let currentUid: String?
    let isCurrentHour: Bool
    let onRecord: () -> Void
    let onInvite: () -> Void
    let isAuthor: (BlipClip) -> Bool
    let onDelete: (BlipClip) -> Void
    let onEditCaption: (BlipClip) -> Void
    /// When set, a `.waiting` seat (current hour, member, no clip yet) becomes
    /// a tappable nudge button that calls back with the member uid. The detail
    /// view wires this to a confirm sheet → NudgeService write. ExportView
    /// leaves this nil and the seat stays decorative.
    var onNudge: ((String) -> Void)? = nil
    /// uid → two-letter avatar initials. Defaults to a uid-prefix fallback so
    /// callers that don't yet plumb `UserProfilesRepository` keep working.
    /// BlipDetailView passes `profiles.initials(for:)` to render real names.
    var initialsForUid: (String) -> String = { String($0.prefix(2)).uppercased() }
    /// Detail screens can show capacity as invite seats. Export preview passes
    /// false so its geometry is based on actual members, exactly like ffmpeg.
    var showsOpenSeats = true

    var body: some View {
        let seats = computeSeats()
        let layout = MemberGridLayout.layout(for: seats.count)

        // Each cell is positioned absolutely in canvas-pixel coordinates and
        // scaled to the rendered container size. This handles every layout
        // pattern uniformly — equal grid rows, the half-width centered lone
        // cell (odd N ≥ 7), and the N=1 landscape-letterbox case — without
        // per-pattern row math. The grid backing is transparent so the
        // surrounding chat background shows through the rounded-corner gaps
        // between cells (in both dark and light themes). The export pipeline
        // still pads with `pad=black` server-side; this is preview-only.
        GeometryReader { geo in
            let scale = geo.size.width / MemberGridLayout.canvasWidth
            ZStack(alignment: .topLeading) {
                Color.clear
                ForEach(Array(seats.enumerated()), id: \.offset) { idx, seat in
                    let cell = layout.cells[idx]
                    SeatView(
                        seat: seat,
                        onRecord: onRecord,
                        onInvite: onInvite,
                        isAuthor: isAuthor,
                        onDelete: onDelete,
                        onEditCaption: onEditCaption,
                        onNudge: onNudge,
                        onReRecord: isCurrentHour ? onRecord : nil
                    )
                    .frame(width: cell.w * scale, height: cell.h * scale)
                    .offset(x: cell.x * scale, y: cell.y * scale)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .aspectRatio(MemberGridLayout.canvasAspect, contentMode: .fit)
    }

    /// One seat per `blip.size` slot, in stable order:
    ///   1. members (in `blip.members` insertion order) → poster's clip OR a state
    ///      derived from current/past hour
    ///   2. unfilled seats → invite cell
    private func computeSeats() -> [Seat] {
        var seats: [Seat] = []
        seats.reserveCapacity(blip.size)

        let clipByUid: [String: BlipClip] = Dictionary(
            clipsForHour.map { ($0.uid, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for memberUid in blip.members.prefix(blip.size) {
            let initials = initialsForUid(memberUid)
            if let clip = clipByUid[memberUid] {
                seats.append(.posted(clip, isMine: memberUid == currentUid, initials: initials))
            } else if isCurrentHour {
                if memberUid == currentUid {
                    seats.append(.recordPrompt(initials: initials))
                } else {
                    seats.append(.waiting(uid: memberUid, initials: initials))
                }
            } else {
                seats.append(.blackScreen(uid: memberUid, initials: initials))
            }
        }

        if showsOpenSeats {
            let unfilled = max(0, blip.size - blip.members.count)
            for _ in 0..<unfilled { seats.append(.invite) }
        }

        return seats
    }

    /// Two-letter avatar text from a uid. Real display-name lookup is a follow-up.
    private static func initials(for uid: String) -> String {
        String(uid.prefix(2)).uppercased()
    }
}

// MARK: - Seat cells

private struct SeatView: View {
    let seat: Seat
    let onRecord: () -> Void
    let onInvite: () -> Void
    let isAuthor: (BlipClip) -> Bool
    let onDelete: (BlipClip) -> Void
    let onEditCaption: (BlipClip) -> Void
    let onNudge: ((String) -> Void)?
    /// Non-nil only on the current hour and only for the author's own seat —
    /// surfaces a "re-record" option in the context menu so the action is
    /// discoverable beyond the bare tap-the-tile gesture.
    let onReRecord: (() -> Void)?

    var body: some View {
        Group {
            switch seat {
            case .posted(let clip, let isMine, let initials):
                PostedSeat(
                    clip: clip,
                    initials: initials,
                    isMine: isMine,
                    onTapMine: onRecord
                )
                .clipContextMenu(
                    clip: clip,
                    isAuthor: isAuthor(clip),
                    onDelete: { onDelete(clip) },
                    onEditCaption: { onEditCaption(clip) },
                    onReRecord: (isMine && onReRecord != nil) ? onReRecord : nil
                )

            case .recordPrompt(let initials):
                RecordPromptSeat(initials: initials, onRecord: onRecord)

            case .waiting(let uid, let initials):
                WaitingSeat(
                    initials: initials,
                    onTap: onNudge.map { handler in { handler(uid) } }
                )

            case .blackScreen(_, let initials):
                BlackSeat(initials: initials)

            case .invite:
                InviteSeat(onInvite: onInvite)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct PostedSeat: View {
    let clip: BlipClip
    let initials: String
    let isMine: Bool
    let onTapMine: () -> Void

    var body: some View {
        ZStack {
            ClipPlayerView(url: clip.videoUrl)
                .allowsHitTesting(false)

            // Centered both horizontally and vertically over the entire clip frame.
            ClipTimestampLabel(hour: clip.hour)
        }
        .overlay(alignment: .topLeading) {
            AvatarView(initials: isMine ? "me" : initials, hasPosted: true, size: 22)
                .padding(8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap your own clip to re-record this hour. For past hours the
            // parent's `onRecord` is a no-op (BlipDetailView only wires it for
            // the current hour; ExportView leaves it empty entirely).
            if isMine { onTapMine() }
        }
    }
}

private struct RecordPromptSeat: View {
    let initials: String
    let onRecord: () -> Void

    var body: some View {
        Button(action: onRecord) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BlipColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(BlipColor.accent.opacity(0.45), lineWidth: 1)
                    )

                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.blip(size: 18, weight: .semibold))
                        .foregroundStyle(BlipColor.accentNeutralOn)
                        .frame(width: 38, height: 38)
                        .background(BlipColor.accent, in: Circle())
                    Text("record 2s")
                        .font(.blip(size: 12, weight: .semibold))
                        .foregroundStyle(BlipColor.textSecondary)
                }
            }
            .overlay(alignment: .topLeading) {
                AvatarView(initials: "me", hasPosted: false, size: 22)
                    .padding(8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Record your 2-second clip")
    }
}

private struct WaitingSeat: View {
    let initials: String
    /// When set, the seat is a tappable nudge button. When nil (preview-edit
    /// mode in ExportView), it stays decorative.
    let onTap: (() -> Void)?

    var body: some View {
        if let onTap {
            Button(action: onTap) { content(label: "nudge") }
                .buttonStyle(.plain)
                .accessibilityLabel("Nudge \(initials) to post their clip")
        } else {
            content(label: "waiting…")
        }
    }

    private func content(label: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BlipColor.surface)

            VStack(spacing: 6) {
                AvatarView(initials: initials, hasPosted: false, size: 30)
                Text(label)
                    .font(.blip(size: 11, weight: .medium))
                    .foregroundStyle(BlipColor.textTertiary)
            }
        }
    }
}

private struct BlackSeat: View {
    let initials: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BlipColor.blackCell)
        }
        .overlay(alignment: .topLeading) {
            AvatarView(initials: initials, hasPosted: false, size: 22)
                .padding(8)
                .opacity(0.55)
        }
    }
}

private struct InviteSeat: View {
    let onInvite: () -> Void

    var body: some View {
        Button(action: onInvite) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BlipColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                            .foregroundStyle(BlipColor.border)
                    )

                VStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.blip(size: 16, weight: .semibold))
                        .foregroundStyle(BlipColor.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(BlipColor.surfaceElevated, in: Circle())
                    Text("invite")
                        .font(.blip(size: 11, weight: .medium))
                        .foregroundStyle(BlipColor.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Invite a friend")
    }
}

// MARK: - Auto-loop player

/// Auto-loop video preview for a posted clip. Mutes audio so the grid doesn't blare.
/// Uses `AVPlayerLooper` + `AVQueuePlayer` (Apple-recommended pattern) — the
/// looper handles seek timing and end-of-content edge cases that the older
/// notification-based loop hit on iOS 26 + audio-session changes.
private struct ClipPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        context.coordinator.queuePlayer = queuePlayer
        context.coordinator.looper = looper

        let vc = AVPlayerViewController()
        vc.player = queuePlayer
        vc.showsPlaybackControls = false
        vc.videoGravity = .resizeAspectFill
        // AVPlayerViewController's view defaults to opaque black, which bleeds
        // through at every rounded corner of the seat clipShape. Clearing the
        // backgrounds lets the SwiftUI clipShape do its job cleanly.
        vc.view.backgroundColor = .clear
        vc.contentOverlayView?.backgroundColor = .clear
        queuePlayer.play()
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.tearDown()
        uiViewController.player = nil
    }

    final class Coordinator {
        var queuePlayer: AVQueuePlayer?
        var looper: AVPlayerLooper?

        func tearDown() {
            queuePlayer?.pause()
            looper?.disableLooping()
            looper = nil
            queuePlayer = nil
        }

        deinit { tearDown() }
    }
}

