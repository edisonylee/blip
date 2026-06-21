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

                // ── Single MemberGrid for the selected hour ──────────────
                // IMPORTANT: TabView(.page) was here before but it pre-creates
                // ALL hours' MemberGrids simultaneously. Each grid contains
                // AVQueuePlayer instances per clip cell — N hours × M members
                // = N×M active video players → resource exhaustion crash.
                //
                // Solution: show exactly ONE grid at a time, keyed by the hour
                // so SwiftUI tears down the old grid (stops its AVPlayers) and
                // creates a fresh one when the selected hour changes.
                MemberGrid(
                    blip: blip,
                    hour: selectedHour,
                    clipsForHour: clips.clipsByHour[selectedHour] ?? [],
                    currentUid: currentUid,
                    isCurrentHour: false,
                    onRecord: {},
                    onInvite: {},
                    isAuthor: { _ in false },
                    onDelete: { _ in },
                    onEditCaption: { _ in },
                    showsOpenSeats: false
                )
                .id(selectedHour)   // force teardown + recreation on hour change
                .padding(.horizontal, 16)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.38, dampingFraction: 0.8), value: selectedHour)
                // Swipe left/right to change hours (replaces the TabView swipe)
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { v in
                            guard let idx = hoursWithClips.firstIndex(of: selectedHour) else { return }
                            if v.translation.width < -40 && idx < hoursWithClips.count - 1 {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                                    selectedHour = hoursWithClips[idx + 1]
                                }
                            } else if v.translation.width > 40 && idx > 0 {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                                    selectedHour = hoursWithClips[idx - 1]
                                }
                            }
                        }
                )

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

            // ── Stitched video player ──────────────────────────────────
            ExportPlayerView(url: localVideoURL ?? url)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // ── Hour chips row — shows each hour included in the stitch ─
            // Uses hoursWithClips (from the live clips listener) so the user
            // can see exactly which hours are represented back-to-back.
            if !hoursWithClips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(hoursWithClips, id: \.self) { hour in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(BlipColor.accent)
                                    .frame(width: 5, height: 5)
                                Text(hourLabelShort(for: hour))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(BlipColor.textPrimary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(BlipColor.surface,
                                        in: Capsule())
                            .overlay(Capsule().stroke(BlipColor.border, lineWidth: 1))
                        }
                        // Arrow chips hint at sequential order
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
            }

            // ── Meta row ───────────────────────────────────────────────
            HStack(spacing: 8) {
                Text(dateKey)
                Text("·")
                Text("\(hours) hour\(hours == 1 ? "" : "s") stitched")
                if isPreparingLocal {
                    Text("·")
                    ProgressView().scaleEffect(0.6).tint(BlipColor.accent)
                    Text("processing…")
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
                // socialPill takes a sync closure — wrap the async call in Task
                Task { try? await InstagramStoryShare.share(videoFileURL: local) }
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

    /// Downloads the stitched MP4, burns hour-label chips into each segment,
    /// then sets localVideoURL to the labeled file ready for sharing / saving.
    private func downloadForSharing(remoteURL: URL) async {
        if localVideoURL != nil { return }

        isPreparingLocal = true
        downloadError = nil
        defer { isPreparingLocal = false }

        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest  = 120
            config.timeoutIntervalForResource = 300
            let session = URLSession(configuration: config)

            let (tmpURL, response) = try await session.download(from: remoteURL)

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw URLError(.badServerResponse, userInfo: [
                    NSLocalizedDescriptionKey:
                        "server returned \(http.statusCode) — export link may have expired, try re-stitching."
                ])
            }

            // Move to a stable path first
            let raw = FileManager.default.temporaryDirectory
                .appendingPathComponent("blip-export-raw-\(UUID().uuidString).mp4")
            try? FileManager.default.removeItem(at: raw)
            try FileManager.default.moveItem(at: tmpURL, to: raw)

            // Burn hour labels using CoreImage (no CALayer/animation — was crashing)
            let labeled = await burnHourLabels(into: raw)
            localVideoURL = labeled
        } catch {
            localVideoURL = nil
            downloadError = "download failed — \(error.localizedDescription)"
        }
    }

    // MARK: - Hour label burning (CoreImage — no CALayer, no animation tool)

    /// Composites hour-label chips onto each segment of the stitched video.
    /// Uses AVVideoComposition(asset:applyingCIFiltersWithHandler:) + CISourceOverCompositing.
    /// This avoids AVVideoCompositionCoreAnimationTool which crashed on device.
    private func burnHourLabels(into sourceURL: URL) async -> URL {
        let hours   = hoursWithClips
        let curHour = currentHour
        guard !hours.isEmpty else { return sourceURL }
        return await Task.detached(priority: .userInitiated) {
            await Self.ciComposeHourLabels(sourceURL: sourceURL, hours: hours, currentHour: curHour)
        }.value
    }

    private static func ciComposeHourLabels(
        sourceURL: URL, hours: [Int], currentHour: Int
    ) async -> URL {
        do {
            let asset = AVURLAsset(url: sourceURL)
            let vtracks = try await asset.loadTracks(withMediaType: .video)
            guard let vt = vtracks.first else { return sourceURL }
            let duration    = try await asset.load(.duration)
            let naturalSize = try await vt.load(.naturalSize)
            let transform   = try await vt.load(.preferredTransform)

            let totalSec = CMTimeGetSeconds(duration)
            guard totalSec > 0 else { return sourceURL }

            let swapped    = (transform.a == 0 && transform.d == 0)
            let rawSize    = swapped
                ? CGSize(width: naturalSize.height, height: naturalSize.width)
                : naturalSize
            // H.264 needs even pixel counts
            let renderSize = CGSize(
                width:  floor(rawSize.width  / 2) * 2,
                height: floor(rawSize.height / 2) * 2
            )

            let secPerHour = totalSec / Double(hours.count)
            let chipH  = max(40.0, renderSize.height * 0.07)
            let fontSize = chipH * 0.50
            let padH   = renderSize.width  * 0.035
            let padV   = renderSize.height * 0.025

            // Pre-render each hour's label chip as a CIImage (nonisolated CoreGraphics)
            var chips: [Int: CIImage] = [:]
            for hour in hours {
                let label = Self.hourLabel(hour, currentHour: currentHour)
                let chipW = CGFloat(label.count) * fontSize * 0.68 + 24
                if let ci = Self.renderChipCI(label: label, w: chipW, h: chipH, fontSize: fontSize) {
                    // CoreImage origin is bottom-left → place chip at top-right
                    let x = renderSize.width  - chipW - padH
                    let y = renderSize.height - chipH - padV
                    chips[hour] = ci.transformed(by: CGAffineTransform(translationX: x, y: y))
                }
            }

            // Build composition (video + audio)
            let comp = AVMutableComposition()
            guard let cvt = comp.addMutableTrack(withMediaType: .video,
                                                  preferredTrackID: kCMPersistentTrackID_Invalid)
            else { return sourceURL }
            try cvt.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: vt, at: .zero)
            cvt.preferredTransform = transform

            let atracks = try await asset.loadTracks(withMediaType: .audio)
            if let at = atracks.first {
                let ca = comp.addMutableTrack(withMediaType: .audio,
                                              preferredTrackID: kCMPersistentTrackID_Invalid)
                try ca?.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: at, at: .zero)
            }

            // CIFilter-based composition — ONE frame at a time, no CALayer involved
            let vc = AVVideoComposition(asset: comp) { request in
                let src  = request.sourceImage.clampedToExtent()
                let tSec = CMTimeGetSeconds(request.compositionTime)
                let idx  = min(max(0, Int(tSec / secPerHour)), hours.count - 1)

                guard let chip = chips[hours[idx]],
                      let over = CIFilter(name: "CISourceOverCompositing",
                                          parameters: [kCIInputImageKey: chip,
                                                       kCIInputBackgroundImageKey: src])?.outputImage
                else {
                    request.finish(with: src.cropped(to: request.sourceImage.extent), context: nil)
                    return
                }
                request.finish(with: over.cropped(to: request.sourceImage.extent), context: nil)
            }

            let out = FileManager.default.temporaryDirectory
                .appendingPathComponent("blip-labeled-\(UUID().uuidString).mp4")
            try? FileManager.default.removeItem(at: out)

            guard let ex = AVAssetExportSession(asset: comp,
                                                presetName: AVAssetExportPreset1280x720)
            else { return sourceURL }
            ex.outputURL              = out
            ex.outputFileType         = .mp4
            ex.videoComposition       = vc
            ex.shouldOptimizeForNetworkUse = true
            await ex.export()
            return ex.status == .completed ? out : sourceURL
        } catch {
            return sourceURL
        }
    }

    /// Render a text chip using CoreGraphics + CoreText (nonisolated, no UIKit).
    nonisolated private static func renderChipCI(
        label: String, w: CGFloat, h: CGFloat, fontSize: CGFloat
    ) -> CIImage? {
        let scale: Int = 3
        let pw = Int(w * CGFloat(scale)); let ph = Int(h * CGFloat(scale))
        guard pw > 0, ph > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: pw * ph * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &pixels, width: pw, height: ph,
                                  bitsPerComponent: 8, bytesPerRow: pw * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

        // Rounded-rect background
        let rr = CGPath(roundedRect: CGRect(x: 0, y: 0, width: w, height: h),
                        cornerWidth: h / 2, cornerHeight: h / 2, transform: nil)
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.60))
        ctx.addPath(rr); ctx.fillPath()

        // White text centred via CoreText
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
        let atts: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        ]
        let aStr = CFAttributedStringCreate(nil, label as CFString, atts as CFDictionary)!
        let line = CTLineCreateWithAttributedString(aStr)
        let tb   = CTLineGetBoundsWithOptions(line, [])
        ctx.textPosition = CGPoint(x: (w - tb.width) / 2 - tb.minX,
                                   y: (h - tb.height) / 2 - tb.minY)
        CTLineDraw(line, ctx)

        guard let cg = ctx.makeImage() else { return nil }
        // Scale back down so the CIImage is in video-pixel coordinates
        return CIImage(cgImage: cg)
            .transformed(by: CGAffineTransform(scaleX: 1 / CGFloat(scale),
                                               y: 1 / CGFloat(scale)))
    }

    nonisolated private static func hourLabel(_ hour: Int, currentHour: Int) -> String {
        if hour == currentHour { return "NOW" }
        var c = DateComponents(); c.hour = hour
        let date = Calendar.current.date(from: c) ?? Date()
        let f = DateFormatter(); f.dateFormat = "h a"
        return f.string(from: date).uppercased()
    }

    private func hourLabelShort(for hour: Int) -> String {
        Self.hourLabel(hour, currentHour: currentHour)
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
