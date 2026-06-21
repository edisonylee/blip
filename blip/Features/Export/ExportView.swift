import AVKit
import Photos
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
    @State private var localVideoURL: URL?
    @State private var isPreparingLocal = false
    @State private var downloadError: String?
    @State private var isSavingToPhotos = false
    @State private var savedToPhotos = false
    @State private var showPhotoPermissionAlert = false

    /// Hour currently shown in the preview slider. Initialised to the most
    /// recent hour with clips once the listener fires.
    @State private var selectedHour: Int = 0

    var body: some View {
        ZStack {
            BlipColor.backgroundGradient.ignoresSafeArea()

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
        // Default selectedHour to the latest hour with clips when data arrives
        .onChange(of: hoursWithClips) { _, hours in
            if !hours.isEmpty && !hours.contains(selectedHour) {
                selectedHour = hours.last ?? hours[0]
            }
        }
        .onReceive(moderation.$blockedUsers) { clips.setBlocklist($0) }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("export").font(BlipTypography.body).foregroundStyle(BlipColor.textPrimary)
            }
        }
        .toolbarBackground(BlipColor.background, for: .navigationBar)
        
    }

    // MARK: - Preview (timeline slider design)

    private var previewState: some View {
        VStack(spacing: 0) {
            if hoursWithClips.isEmpty {
                emptyState
            } else {
                // ── Hour label + clip count ───────────────────────────────
                hourHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // ── Swipeable MemberGrid (one hour at a time) ─────────────
                // TabView page style lets the user swipe between hours;
                // the HourSlider below stays in sync via $selectedHour.
                TabView(selection: $selectedHour) {
                    ForEach(hoursWithClips, id: \.self) { hour in
                        MemberGrid(
                            blip: blip,
                            hour: hour,
                            clipsForHour: clips.clipsByHour[hour] ?? [],
                            currentUid: currentUid,
                            isCurrentHour: false,
                            onRecord: {},
                            onInvite: {},
                            isAuthor: { _ in false },
                            onDelete: { _ in },
                            onEditCaption: { _ in },
                            showsOpenSeats: false
                        )
                        .padding(.horizontal, 16)
                        .tag(hour)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.38, dampingFraction: 0.8), value: selectedHour)

                // ── Timeline slider ───────────────────────────────────────
                VStack(spacing: 6) {
                    HourSlider(
                        hours: hoursWithClips,
                        currentHour: currentHour,
                        selectedHour: $selectedHour
                    )
                    .padding(.horizontal, 20)

                    // Prev / next hour quick-tap buttons
                    HStack {
                        Button {
                            if let idx = hoursWithClips.firstIndex(of: selectedHour),
                               idx > 0 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedHour = hoursWithClips[idx - 1]
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(canGoPrev ? BlipColor.textSecondary : BlipColor.border)
                        }
                        .disabled(!canGoPrev)

                        Spacer()

                        // Hour range label
                        Text("\(hoursWithClips.count) hour\(hoursWithClips.count == 1 ? "" : "s") recorded today")
                            .font(.blip(size: 11))
                            .foregroundStyle(BlipColor.textTertiary)

                        Spacer()

                        Button {
                            if let idx = hoursWithClips.firstIndex(of: selectedHour),
                               idx < hoursWithClips.count - 1 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedHour = hoursWithClips[idx + 1]
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(canGoNext ? BlipColor.textSecondary : BlipColor.border)
                        }
                        .disabled(!canGoNext)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 12)
                .background(BlipColor.surface.opacity(0.7))
                .overlay(alignment: .top) {
                    Rectangle().fill(BlipColor.border).frame(height: 0.5)
                }
            }

            // ── Stitch CTA ────────────────────────────────────────────────
            stitchCTABar
        }
    }

    // MARK: - Hour header

    private var hourHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(hourLabel(for: selectedHour))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(BlipColor.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedHour)

                let clipsThisHour = clips.clipsByHour[selectedHour]?.count ?? 0
                Text("\(clipsThisHour) clip\(clipsThisHour == 1 ? "" : "s") recorded")
                    .font(.blip(size: 13))
                    .foregroundStyle(BlipColor.textTertiary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35), value: selectedHour)
            }

            Spacer()

            // Dot indicator: which hour in the sequence
            if hoursWithClips.count > 1,
               let idx = hoursWithClips.firstIndex(of: selectedHour) {
                Text("\(idx + 1) / \(hoursWithClips.count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(BlipColor.textTertiary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Empty / CTA / helpers

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "camera.badge.clock")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(BlipColor.textTertiary)
            Text("no clips today yet")
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textSecondary)
            Text("record a blip this hour to enable export.")
                .font(.blip(size: 13))
                .foregroundStyle(BlipColor.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var stitchCTABar: some View {
        Button {
            Task { await service.stitch(blipId: blip.id) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 16))
                Text(stitchButtonLabel)
                    .font(BlipTypography.body)
                    .tracking(BlipTypography.titleTracking)
            }
            .foregroundStyle(BlipColor.accentNeutralOn)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                BlipColor.accentNeutral.opacity(clipCount == 0 ? 0.4 : 1.0),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .disabled(clipCount == 0)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .padding(.top, 12)
        .background(BlipColor.surface.opacity(0.7))
    }

    private var canGoPrev: Bool {
        (hoursWithClips.firstIndex(of: selectedHour) ?? 0) > 0
    }

    private var canGoNext: Bool {
        guard let idx = hoursWithClips.firstIndex(of: selectedHour) else { return false }
        return idx < hoursWithClips.count - 1
    }

    private func hourLabel(for hour: Int) -> String {
        if hour == currentHour { return "now" }
        var c = DateComponents(); c.hour = hour
        let date = Calendar.current.date(from: c) ?? Date()
        let f = DateFormatter(); f.dateFormat = "h a"
        return f.string(from: date).lowercased()
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

            // Meta row
            HStack(spacing: 8) {
                Text(dateKey)
                Text("·")
                Text("\(hours) hour\(hours == 1 ? "" : "s")")
                if isPreparingLocal {
                    Text("·")
                    ProgressView().scaleEffect(0.6).tint(BlipColor.accent)
                    Text("downloading…")
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

            // Download error banner
            if let err = downloadError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(BlipColor.error)
                    Text(err)
                        .font(.blip(size: 12))
                        .foregroundStyle(BlipColor.error)
                        .lineLimit(2)
                    Spacer()
                    Button { Task { await downloadForSharing(remoteURL: url) } } label: {
                        Text("retry")
                            .font(.blip(size: 12, weight: .semibold))
                            .foregroundStyle(BlipColor.accentNeutral)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(BlipColor.error.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
            }

            // Action buttons
            VStack(spacing: 10) {
                // 1. Save to Camera Roll
                saveToPhotosButton

                // 2. Share (local .mp4 only — shows TikTok, Instagram, Facebook etc.)
                shareButton

                // 3. Social quick-access row
                socialRow
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .task(id: url) {
            downloadError = nil
            await downloadForSharing(remoteURL: url)
        }
        .task(id: dateKey) { likes.startListening(blipId: blip.id, dateKey: dateKey) }
        // IMPORTANT: only pass the local file — remote URL makes social apps
        // paste a link string instead of uploading the actual video.
        .sheet(isPresented: $showShare) {
            if let local = localVideoURL {
                ShareSheet(activityItems: [local])
            }
        }
        .alert("photo library access needed", isPresented: $showPhotoPermissionAlert) {
            Button("open settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("allow blip to add videos to your photo library in Settings.")
        }
    }

    // MARK: - Save to Photos

    private var saveToPhotosButton: some View {
        Button {
            Task { await saveToPhotos() }
        } label: {
            HStack(spacing: 8) {
                if isSavingToPhotos {
                    ProgressView().tint(BlipColor.accentNeutralOn).scaleEffect(0.8)
                } else if savedToPhotos {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BlipColor.accentNeutralOn)
                } else {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(BlipColor.accentNeutralOn)
                }
                Text(savedToPhotos ? "saved to photos!" : "save to photos")
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.accentNeutralOn)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                savedToPhotos
                    ? Color(red: 0.2, green: 0.78, blue: 0.45)
                    : BlipColor.accentNeutral.opacity(localVideoURL == nil ? 0.4 : 1.0),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .animation(.spring(response: 0.3), value: savedToPhotos)
        }
        .disabled(localVideoURL == nil || isSavingToPhotos || savedToPhotos)
    }

    private func saveToPhotos() async {
        guard let local = localVideoURL else { return }
        isSavingToPhotos = true
        defer { isSavingToPhotos = false }

        // Check / request permission
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .denied || status == .restricted {
            showPhotoPermissionAlert = true
            return
        }
        if status == .notDetermined {
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard granted == .authorized || granted == .limited else {
                showPhotoPermissionAlert = true
                return
            }
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: local)
            }
            savedToPhotos = true
            // Reset the tick after 3 s so the user can save again if needed
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                savedToPhotos = false
            }
        } catch {
            downloadError = "couldn't save to photos: \(error.localizedDescription)"
        }
    }

    // MARK: - Share button (local file only)

    private var shareButton: some View {
        Button { showShare = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("share video")
            }
            .font(BlipTypography.body)
            .foregroundStyle(localVideoURL != nil ? BlipColor.textPrimary : BlipColor.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                localVideoURL != nil
                    ? BlipColor.surface
                    : BlipColor.surface.opacity(0.5),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(BlipColor.border, lineWidth: 1)
            )
        }
        .disabled(localVideoURL == nil)
    }

    // MARK: - Social quick-access row
    //
    // All buttons except Instagram Stories use the iOS Share Sheet with the
    // LOCAL .mp4 file. When TikTok / Instagram / Facebook are installed they
    // appear in the system share sheet and receive the actual video file — NOT
    // a URL link. Instagram Stories uses the direct pasteboard API so it opens
    // the story camera with the video pre-loaded.

    private var socialRow: some View {
        HStack(spacing: 0) {
            // Instagram Stories — pasteboard API (opens story camera directly)
            socialPill(
                label: "IG Story",
                icon: "camera.viewfinder",
                tint: Color(hex: 0xE1306C),
                isReady: localVideoURL != nil
            ) {
                guard let local = localVideoURL else { return }
                try? InstagramStoryShare.share(videoFileURL: local)
            }

            socialDivider

            // TikTok — system share sheet (TikTok appears if installed)
            socialPill(
                label: "TikTok",
                icon: "music.note",
                tint: Color.black,
                isReady: localVideoURL != nil
            ) { showShare = true }

            socialDivider

            // Instagram Feed / Reels — system share sheet
            socialPill(
                label: "Instagram",
                icon: "photo.on.rectangle.angled",
                tint: Color(hex: 0xE1306C),
                isReady: localVideoURL != nil
            ) { showShare = true }

            socialDivider

            // Facebook / Meta — system share sheet
            socialPill(
                label: "Facebook",
                icon: "person.2.wave.2.fill",
                tint: Color(hex: 0x1877F2),
                isReady: localVideoURL != nil
            ) { showShare = true }
        }
        .background(BlipColor.surface,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BlipColor.border, lineWidth: 1)
        )
    }

    private func socialPill(
        label: String,
        icon: String,
        tint: Color,
        isReady: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isReady ? tint : BlipColor.textTertiary)
                Text(label)
                    .font(.blip(size: 10, weight: .medium))
                    .foregroundStyle(isReady ? BlipColor.textSecondary : BlipColor.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isReady)
    }

    private var socialDivider: some View {
        Rectangle()
            .fill(BlipColor.border)
            .frame(width: 0.5)
            .padding(.vertical, 8)
    }

    /// Downloads the stitched MP4 to a local tmp file so Share / Save-to-Photos
    /// work with a real file path (remote https:// URLs don't work for those).
    private func downloadForSharing(remoteURL: URL) async {
        // Skip if we already have this exact file cached.
        if localVideoURL != nil { return }

        isPreparingLocal = true
        downloadError = nil
        defer { isPreparingLocal = false }

        do {
            // Use URLSession with a longer timeout — export files can be large.
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest  = 120
            config.timeoutIntervalForResource = 300
            let session = URLSession(configuration: config)

            let (tmpURL, response) = try await session.download(from: remoteURL)

            // Validate HTTP status
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw URLError(
                    .badServerResponse,
                    userInfo: [NSLocalizedDescriptionKey:
                        "server returned \(http.statusCode) — the export link may have expired. try re-stitching."]
                )
            }

            // Rename with .mp4 so iOS picks the right codec + share options.
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("blip-export-\(UUID().uuidString).mp4")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmpURL, to: dest)

            localVideoURL = dest
        } catch {
            localVideoURL  = nil
            downloadError  = "download failed — \(error.localizedDescription)"
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

    private var currentHour: Int {
        BlipHour.currentHour(in: blip.timezoneIdentifier)
    }

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
