import AVKit
import SwiftUI

/// Screen-07 parity — vertical stack of clip slots for today's blips.
/// Slots collapse: empty hours are hidden (per CLAUDE.md "hours where no member contributed are skipped").
struct BlipDetailView: View {
    let blip: Blip

    @EnvironmentObject private var auth: AuthService
    @StateObject private var clips = ClipsRepository()

    @State private var showShareSheet = false
    @State private var showMembers = false
    @State private var showCapture = false
    @State private var captionEditingClip: BlipClip?

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 8) {
                    // First slot is "you" — current hour, tap to capture
                    Button { showCapture = true } label: {
                        YourSlot(
                            uidInitials: currentUserInitials,
                            myClipThisHour: myClipThisHour
                        )
                    }
                    .buttonStyle(.plain)

                    // Posted clips for hours other than the current hour
                    ForEach(otherHoursWithClips, id: \.self) { hour in
                        ForEach(clips.clipsByHour[hour] ?? []) { clip in
                            PostedClipSlot(clip: clip)
                                .clipContextMenu(
                                    clip: clip,
                                    isAuthor: isAuthor(of: clip),
                                    onDelete: { Task { try? await clips.deleteClip(clip) } },
                                    onEditCaption: { captionEditingClip = clip }
                                )
                        }
                    }

                    // Invite-a-friend placeholders for empty member seats
                    ForEach(0..<emptySeatCount, id: \.self) { _ in
                        InviteSlot()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 64)
            }

            VStack {
                Spacer()
                TodayPill()
                    .padding(.bottom, 12)
            }
        }
        .task(id: blip.id) { clips.startListening(blip: blip) }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(blip.name)
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textPrimary)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    Button { showMembers = true } label: {
                        Image(systemName: "person.2")
                            .foregroundStyle(BlipColor.textPrimary)
                    }
                    Button { showShareSheet = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(BlipColor.textPrimary)
                    }
                    NavigationLink {
                        ChatView(blipId: blip.id)
                    } label: {
                        Image(systemName: "bubble.right")
                            .foregroundStyle(BlipColor.textPrimary)
                    }
                }
            }
        }
        .toolbarBackground(BlipColor.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: ["join my blip \"\(blip.name)\" — code: \(blip.joinCode)"])
        }
        .sheet(isPresented: $showMembers) {
            MembersSheet(blip: blip)
        }
        .fullScreenCover(isPresented: $showCapture) {
            NavigationStack {
                CaptureView(blip: blip, onPosted: { showCapture = false })
            }
        }
        .sheet(item: $captionEditingClip) { clip in
            EditCaptionSheet(clip: clip) { newCaption in
                try? await clips.updateCaption(clip, caption: newCaption)
            }
        }
    }

    private func isAuthor(of clip: BlipClip) -> Bool {
        guard case .signedIn(let uid) = auth.state else { return false }
        return clip.uid == uid
    }

    private var emptySeatCount: Int {
        max(0, blip.size - blip.members.count)
    }

    private var currentUserInitials: String {
        guard case .signedIn(let uid) = auth.state else { return "?" }
        return String(uid.prefix(2)).uppercased()
    }

    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    private var myClipThisHour: BlipClip? {
        guard case .signedIn(let uid) = auth.state else { return nil }
        return clips.clipsByHour[currentHour]?.first { $0.uid == uid }
    }

    /// Hours that have at least one clip, excluding the current hour (which is shown via YourSlot).
    private var otherHoursWithClips: [Int] {
        clips.clipsByHour.keys
            .filter { $0 != currentHour }
            .sorted(by: >)
    }
}

private struct YourSlot: View {
    let uidInitials: String
    let myClipThisHour: BlipClip?

    var body: some View {
        ZStack {
            if let clip = myClipThisHour {
                ClipPlayerView(url: clip.videoUrl)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        avatarBadge.padding(12)
                    }
                    .overlay(alignment: .top) {
                        Text(String(format: "%02d:00", clip.hour))
                            .font(BlipTypography.clipTimestamp)
                            .foregroundStyle(.white)
                            .shadow(radius: 4, y: 1)
                            .padding(.top, 14)
                    }
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BlipColor.surface)
                VStack(spacing: 12) {
                    HStack {
                        avatarBadge
                        Spacer()
                        Image(systemName: "ellipsis")
                            .foregroundStyle(BlipColor.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Text(currentHourString)
                        .font(BlipTypography.clipTimestamp)
                        .foregroundStyle(BlipColor.textPrimary.opacity(0.4))

                    Text("tap to capture")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(BlipColor.surfaceElevated, in: Capsule())
                        .padding(.bottom, 16)
                }
            }
        }
        .frame(height: 220)
    }

    private var avatarBadge: some View {
        Circle()
            .fill(BlipColor.accent)
            .frame(width: 24, height: 24)
            .overlay(
                Text(uidInitials)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black)
            )
    }

    private var currentHourString: String {
        let h = Calendar.current.component(.hour, from: Date())
        return String(format: "%02d:00", h)
    }
}

private struct PostedClipSlot: View {
    let clip: BlipClip

    var body: some View {
        ZStack {
            ClipPlayerView(url: clip.videoUrl)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(BlipColor.accent)
                .frame(width: 24, height: 24)
                .overlay(
                    Text(String(clip.uid.prefix(2)).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                )
                .padding(12)
        }
        .overlay(alignment: .top) {
            Text(String(format: "%02d:00", clip.hour))
                .font(BlipTypography.clipTimestamp)
                .foregroundStyle(.white)
                .shadow(radius: 4, y: 1)
                .padding(.top, 14)
        }
        .frame(height: 220)
    }
}

private struct InviteSlot: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BlipColor.surface)

            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(BlipColor.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(BlipColor.surfaceElevated, in: Circle())
                Text("invite a friend")
                    .font(BlipTypography.caption)
                    .foregroundStyle(BlipColor.textTertiary)
            }
        }
        .frame(height: 120)
    }
}

private struct TodayPill: View {
    var body: some View {
        Text("Today")
            .font(BlipTypography.caption)
            .foregroundStyle(BlipColor.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(BlipColor.surface, in: Capsule())
    }
}

/// Auto-loop video preview for a posted clip. Mutes audio so the grid doesn't blare.
private struct ClipPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false
        vc.videoGravity = .resizeAspectFill
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        player.play()
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
