import AVKit
import SwiftUI

/// Preview-then-stitch.
///
/// Flow:
///   .preview   — every hour with ≥1 clip rendered as a `MemberGrid`. Read-only;
///                CTA stitches the full set. (Per-clip editing is a follow-up; the
///                "edit" affordance on the ready screen is a placeholder for it.)
///   .stitching — Cloud Function running (30–90s for a full day).
///   .ready     — looping playback + share + disabled "edit" placeholder.
///   .failed    — error + back-to-preview.
struct ExportView: View {
    let blip: Blip

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var moderation: ModerationService
    @StateObject private var service = ExportService()
    @StateObject private var clips = ClipsRepository()
    @StateObject private var likes = DayLikesRepository()

    @State private var showShare = false
    /// MP4 downloaded from the stitched URL into the app's tmp directory. We
    /// share the LOCAL URL, not the remote one — share-sheet extensions
    /// (Photos save, TikTok, Instagram) need a real file to attach. Sharing the
    /// remote `https://` URL would only paste a link string.
    @State private var localVideoURL: URL?
    /// True between entering .ready and finishing the local download. The share
    /// + Instagram buttons stay disabled until the file is ready locally.
    @State private var isPreparingLocal = false

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            switch service.status {
            case .idle:
                previewState
            case .stitching:
                stitchingState
            case .ready(let url, let dateKey, let hours):
                readyState(url: url, dateKey: dateKey, hours: hours)
            case .failed(let msg):
                failedState(msg: msg)
            }
        }
        .task(id: blip.id) {
            clips.startListening(blip: blip)
            clips.setBlocklist(moderation.blockedUsers)
        }
        .onReceive(moderation.$blockedUsers) { clips.setBlocklist($0) }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("export").font(BlipTypography.body).foregroundStyle(BlipColor.textPrimary)
            }
        }
        .toolbarBackground(BlipColor.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Preview

    private var previewState: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCopy

                    if hoursWithClips.isEmpty {
                        emptyState
                    } else {
                        ForEach(hoursWithClips, id: \.self) { hour in
                            MemberGrid(
                                blip: blip,
                                hour: hour,
                                clipsForHour: clips.clipsByHour[hour] ?? [],
                                currentUid: currentUid,
                                isCurrentHour: false,  // preview: render every hour as past-style
                                onRecord: {},
                                onInvite: {},
                                isAuthor: { _ in false },
                                onDelete: { _ in },
                                onEditCaption: { _ in },
                                showsOpenSeats: false
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 120)  // room for sticky CTA
            }

            stitchCTABar
        }
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("today, stitched")
                .font(BlipTypography.title)
                .foregroundStyle(BlipColor.textPrimary)
            Text("preview the cut, then stitch.")
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 80)
            Text("no clips today yet")
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textSecondary)
            Text("record at least one to enable export.")
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var stitchCTABar: some View {
        Button {
            Task { await service.stitch(blipId: blip.id) }
        } label: {
            Text(stitchButtonLabel)
                .font(BlipTypography.body)
                .tracking(BlipTypography.titleTracking)
                .foregroundStyle(BlipColor.accentNeutralOn)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    BlipColor.accentNeutral.opacity(clipCount == 0 ? 0.4 : 1.0),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
        }
        .disabled(clipCount == 0)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .padding(.top, 12)
        .background(BlipColor.background)
    }

    // MARK: - Other states

    private var stitchingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(BlipColor.textPrimary)
            Text("stitching today's blips…")
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.textSecondary)
            Text("this can take a minute for a full day.")
                .font(.caption2)
                .foregroundStyle(BlipColor.textTertiary)
            Spacer()
        }
    }

    @ViewBuilder
    private func readyState(url: URL, dateKey: String, hours: Int) -> some View {
        VStack(spacing: 12) {
            ExportPlayerView(url: url)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 8)

            HStack(spacing: 8) {
                Text(dateKey)
                Text("·")
                Text("\(hours) hour\(hours == 1 ? "" : "s")")
                if isPreparingLocal {
                    Text("·")
                    Text("preparing…")
                }
                Spacer()
                HeartButton(
                    liked: likes.liked,
                    count: likes.count,
                    isWriting: likes.isWriting,
                    onTap: { Task { await likes.toggle() } }
                )
            }
            .font(BlipTypography.caption)
            .foregroundStyle(BlipColor.textTertiary)
            .padding(.horizontal, 16)

            HStack(spacing: 10) {
                shareButton
                if InstagramStoryShare.isAvailable {
                    instagramStoryButton
                }
                tikTokShareButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .task(id: url) { await downloadForSharing(remoteURL: url) }
        .task(id: dateKey) { likes.startListening(blipId: blip.id, dateKey: dateKey) }
        .sheet(isPresented: $showShare) {
            // Always pass the local file when we have it — that's what unlocks
            // Save Video / TikTok / etc. Fall back to the remote URL only if
            // the local download somehow failed (rare; user can still copy link).
            ShareSheet(activityItems: [localVideoURL ?? url])
        }
    }

    private var shareButton: some View {
        Button { showShare = true } label: {
            Label("share", systemImage: "square.and.arrow.up")
                .font(BlipTypography.body)
                .tracking(BlipTypography.titleTracking)
                .foregroundStyle(BlipColor.accentNeutralOn)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    BlipColor.accentNeutral.opacity(localVideoURL == nil ? 0.4 : 1.0),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
        }
        .disabled(localVideoURL == nil)
    }

    private var instagramStoryButton: some View {
        Button {
            guard let local = localVideoURL else { return }
            try? InstagramStoryShare.share(videoFileURL: local)
        } label: {
            Image(systemName: "circle.dashed.inset.filled")
                .font(.body)
                .foregroundStyle(BlipColor.textPrimary)
                .frame(width: 44, height: 44)
                .background(BlipColor.surface, in: Circle())
        }
        .disabled(localVideoURL == nil)
        .accessibilityLabel("Share to Instagram story")
    }

    /// TikTok share — virality is the #1 product priority (CLAUDE.md). Opens
    /// the iOS share sheet, which surfaces TikTok automatically when the app is
    /// installed and the activity item is a real `.mp4` file. The dedicated
    /// button gives the destination prominence the generic share button doesn't.
    private var tikTokShareButton: some View {
        Button { showShare = true } label: {
            Image(systemName: "music.note")
                .font(.body)
                .foregroundStyle(BlipColor.textPrimary)
                .frame(width: 44, height: 44)
                .background(BlipColor.surface, in: Circle())
        }
        .disabled(localVideoURL == nil)
        .accessibilityLabel("Share to TikTok")
    }

    /// Pull the stitched MP4 to a tmp file so the share sheet can attach it
    /// as a real video. Idempotent for the same URL — re-entering .ready with
    /// an unchanged URL skips the download.
    private func downloadForSharing(remoteURL: URL) async {
        // Already have it for this URL? Bail. (.task(id:) already filters most
        // duplicates, but being defensive is cheap.)
        if let existing = localVideoURL,
           existing.lastPathComponent.contains(remoteURL.lastPathComponent) {
            return
        }
        isPreparingLocal = true
        defer { isPreparingLocal = false }
        do {
            let (tmpURL, _) = try await URLSession.shared.download(from: remoteURL)
            // URLSession picks an opaque tmp name; rename so iOS detects the
            // .mp4 extension and shows the right share-sheet affordances.
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("blip-export-\(UUID().uuidString).mp4")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmpURL, to: dest)
            localVideoURL = dest
        } catch {
            // Leave localVideoURL nil — share button stays disabled, user can
            // re-stitch. Could surface a toast here later.
            localVideoURL = nil
        }
    }

    @ViewBuilder
    private func failedState(msg: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(BlipColor.error)
            Text(msg)
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("back to preview") { service.reset() }
                .foregroundStyle(BlipColor.textPrimary)
            Spacer()
        }
    }

    // MARK: - Derived

    private var currentUid: String? {
        if case .signedIn(let uid) = auth.state { return uid }
        return nil
    }

    /// Hours of the configured blip-day sorted chronologically. We render
    /// every hour that has at least one clip — the export drops empty hours, so
    /// hiding them from the preview keeps signal:noise high.
    private var hoursWithClips: [Int] {
        clips.clipsByHour.keys.sorted { lhs, rhs in
            BlipHour.sortIndex(for: lhs, startHour: blip.activeStartHour)
                < BlipHour.sortIndex(for: rhs, startHour: blip.activeStartHour)
        }
    }

    private var clipCount: Int { clips.clips.count }

    private var stitchButtonLabel: String {
        if clipCount == 0 { return "no clips yet" }
        if clipCount == 1 { return "stitch 1 clip" }
        return "stitch \(clipCount) clips"
    }
}

private struct ExportPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        let vc = AVPlayerViewController()
        vc.player = player
        vc.videoGravity = .resizeAspectFill
        player.play()
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    // Without this, dismissing the export preview leaves the AVPlayer + its
    // Storage download alive in the background. The export file is large; a
    // leak here costs both memory and egress.
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: ()) {
        uiViewController.player?.pause()
        uiViewController.player = nil
    }
}
