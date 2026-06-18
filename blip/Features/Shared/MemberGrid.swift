import AVKit
import SwiftUI

// MARK: - Grid layout (Swift mirror of functions/src/utils/gridLayout.ts)

/// Cell layout matching the server export: one full-width column for one or two
/// members, then two seats per row through the 12-member cap.
struct MemberGridLayout {
    let cols: Int
    let rows: Int
    let cellAspect: CGFloat  // width / height — matches export cell pixel ratio
    let centersFinalSeat: Bool

    static func layout(for seatCount: Int) -> MemberGridLayout {
        let count = min(12, max(1, seatCount))
        let (cols, rows): (Int, Int)
        if count <= 2 {
            (cols, rows) = (1, count)
        } else {
            (cols, rows) = (2, Int(ceil(Double(count) / 2.0)))
        }
        let canvasWidth: CGFloat = 1080
        let canvasHeight: CGFloat = 1920
        let cellW = canvasWidth / CGFloat(cols)
        let cellH = canvasHeight / CGFloat(rows)
        return MemberGridLayout(
            cols: cols,
            rows: rows,
            cellAspect: cellW / cellH,
            centersFinalSeat: cols == 2 && count.isMultiple(of: 2) == false
        )
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

        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(0..<layout.rows, id: \.self) { row in
                let start = row * layout.cols
                let end = min(start + layout.cols, seats.count)
                let rowSeats = Array(seats[start..<end])

                GridRow {
                    if layout.cols == 1 {
                        seatView(rowSeats[0], layout: layout)
                            .gridCellColumns(4)
                    } else if rowSeats.count == 1 && layout.centersFinalSeat {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        seatView(rowSeats[0], layout: layout)
                            .gridCellColumns(2)
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    } else {
                        ForEach(Array(rowSeats.enumerated()), id: \.offset) { _, seat in
                            seatView(seat, layout: layout)
                                .gridCellColumns(2)
                        }
                    }
                }
            }
        }
    }

    private func seatView(_ seat: Seat, layout: MemberGridLayout) -> some View {
        SeatView(
            seat: seat,
            cellAspect: layout.cellAspect,
            onRecord: onRecord,
            onInvite: onInvite,
            isAuthor: isAuthor,
            onDelete: onDelete,
            onEditCaption: onEditCaption,
            onNudge: onNudge
        )
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
    let cellAspect: CGFloat
    let onRecord: () -> Void
    let onInvite: () -> Void
    let isAuthor: (BlipClip) -> Bool
    let onDelete: (BlipClip) -> Void
    let onEditCaption: (BlipClip) -> Void
    let onNudge: ((String) -> Void)?

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
                    onEditCaption: { onEditCaption(clip) }
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
        .aspectRatio(cellAspect, contentMode: .fit)
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
/// Coordinator owns the loop observer and pauses/tears down the player on dismantle
/// so off-screen cells don't keep decoding.
private struct ClipPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false
        vc.videoGravity = .resizeAspectFill
        context.coordinator.attach(player: player)
        player.play()
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.tearDown()
        uiViewController.player?.pause()
        uiViewController.player = nil
    }

    final class Coordinator {
        private var loopToken: NSObjectProtocol?
        private weak var player: AVPlayer?

        func attach(player: AVPlayer) {
            self.player = player
            loopToken = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }

        func tearDown() {
            if let token = loopToken {
                NotificationCenter.default.removeObserver(token)
                loopToken = nil
            }
            player?.pause()
        }

        deinit { tearDown() }
    }
}
