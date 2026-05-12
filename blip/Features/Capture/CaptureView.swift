import SwiftUI
import AVFoundation

/// Screen-08 parity — live preview + record-to-2s flow.
///
/// APP STORE — permissions are requested ONLY when the user taps record.
/// `AVCaptureDevice.requestAccess` and config never run from `.onAppear`.
struct CaptureView: View {
    let blip: Blip
    let onPosted: () -> Void

    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @StateObject private var session = CaptureSession()

    @State private var recordingURL: URL?
    /// Zoom factor at the start of the current pinch (committed when the gesture ends).
    @State private var baseZoom: CGFloat = 1.0
    @State private var currentTime: String = Self.formattedTime()

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                viewfinderArea
                    .padding(BlipSpacing.lg)
                    .frame(maxHeight: .infinity)
                bottomToolbar
            }
        }
        .navigationDestination(item: $recordingURL) { url in
            ReviewView(blip: blip, fileURL: url, onPosted: onPosted)
        }
        .onAppear {
            // Capture is landscape-native — sensor records 16:9 landscape, so we
            // rotate the device to match. App-wide orientation is portrait
            // otherwise; this gate flips the AppDelegate mask while we're on
            // screen and `requestGeometryUpdate` actually performs the rotation.
            AppDelegate.lockedOrientation = .landscape
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            }
        }
        .onDisappear {
            session.stop()
            AppDelegate.lockedOrientation = .portrait
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            currentTime = Self.formattedTime()
        }
    }

    // MARK: - Viewfinder

    private var viewfinderArea: some View {
        ZStack {
            // Preview only renders for real cameras. Synthetic mode = no preview, just the record button.
            // Landscape 16:9 — fills the screen when the device is rotated to landscape (the
            // capture flow forces .landscapeRight; portrait fallback letterboxes).
            if !session.useSynthetic && (session.state == .ready || session.state == .recording) {
                CapturePreview(session: session.session)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                session.setZoom(factor: baseZoom * scale)
                            }
                            .onEnded { scale in
                                baseZoom = max(1.0, baseZoom * scale)
                            }
                    )
            }

            #if DEBUG
            if session.useSynthetic && session.state != .idle {
                VStack(spacing: 6) {
                    Text("DEBUG: synthetic clip mode")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white.opacity(0.5))
                    Text("no camera available; record produces a 2s color clip")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 48)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            #endif

            statusOverlay

            if !session.availableLenses.isEmpty && session.state == .ready {
                lensButtonRow
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, BlipSpacing.md)
            }

            if session.state == .ready || session.state == .recording {
                Text(currentTime)
                    .font(BlipTypography.clipTimestamp)
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(90))
            }
        }
        .background(BlipColor.mediaBackdrop)
        .clipShape(RoundedRectangle(cornerRadius: BlipRadius.lg, style: .continuous))
        .overlay(alignment: .topTrailing) {
            BlipIconButton(systemName: "xmark", style: .dark) { dismiss() }
                .padding(12)
        }
    }

    // MARK: - Bottom toolbar

    private var bottomToolbar: some View {
        HStack {
            Spacer()
            BlipIconButton(systemName: "arrow.counterclockwise", style: .ghost) {}
            Spacer()
            BlipIconButton(systemName: "dial.medium", style: .ghost) {}
            Spacer()
            ZStack {
                recordButton
                if session.state == .recording {
                    // Accent ring sweeps as the 2-second cap counts down.
                    // sweepAngle = 360 at t=0, → 0 at the cap. trim() expects
                    // start/end in 0…1 of the circle.
                    Circle()
                        .trim(from: 0, to: max(0, min(1, 1 - session.recordingElapsed / CaptureSession.clipDuration)))
                        .stroke(BlipColor.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 84, height: 84)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: session.recordingElapsed)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .top) {
                if session.state == .recording {
                    let remaining = max(0, CaptureSession.clipDuration - session.recordingElapsed)
                    Text("REC · \(String(format: "%.1f", remaining))s left")
                        .font(.blip(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, BlipSpacing.md)
                        .padding(.vertical, BlipSpacing.xs)
                        .background(BlipColor.error, in: Capsule())
                        .offset(y: -28)
                        .allowsHitTesting(false)
                }
            }
            Spacer()
            BlipIconButton(systemName: "bolt", style: .ghost) {}
            Spacer()
            BlipIconButton(systemName: "arrow.2.circlepath", style: .ghost) {
                Task { await session.flipCamera() }
            }
            .disabled(session.state == .recording)
            Spacer()
        }
        .frame(height: 80)
        .background(BlipColor.background)
    }

    // MARK: - Lens row

    private var lensButtonRow: some View {
        HStack(spacing: BlipSpacing.sm) {
            ForEach(session.availableLenses) { lens in
                Button {
                    session.setZoom(factor: lens.zoomFactor, ramped: true)
                    baseZoom = lens.zoomFactor
                } label: {
                    Text(lens.label)
                        .font(.blip(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: BlipSpacing.tapTarget, height: BlipSpacing.tapTarget)
                        .background(
                            isActive(lens) ? .white.opacity(0.18) : BlipColor.surface,
                            in: Circle()
                        )
                        .overlay(
                            Circle()
                                .stroke(isActive(lens) ? .white : .clear, lineWidth: 1.5)
                        )
                }
                .accessibilityLabel("zoom \(lens.label)")
            }
        }
    }

    /// Highlight the lens whose zoom factor matches the active factor most
    /// closely — pinch can land between two lens thresholds, so we round-trip
    /// to the nearest one rather than requiring an exact float match.
    private func isActive(_ lens: CaptureSession.LensOption) -> Bool {
        guard let nearest = session.availableLenses.min(by: {
            abs($0.zoomFactor - session.currentZoomFactor)
                < abs($1.zoomFactor - session.currentZoomFactor)
        }) else { return false }
        return nearest.id == lens.id
    }

    // MARK: - Status overlay

    @ViewBuilder
    private var statusOverlay: some View {
        switch session.state {
        case .idle:
            VStack(spacing: BlipSpacing.sm) {
                Text("tap to capture")
                    .font(BlipTypography.title)
                    .foregroundStyle(.white)
                Text("a 2-second blip for \(blip.name)")
                    .font(BlipTypography.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        case .denied:
            VStack(spacing: BlipSpacing.sm) {
                Text("camera + mic access needed")
                    .font(BlipTypography.body)
                    .foregroundStyle(.white)
                Button("open settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundStyle(.white)
                .fontWeight(.semibold)
            }
        case .unavailable:
            Text("camera unavailable in this environment")
                .font(BlipTypography.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, BlipSpacing.xxl)
        case .error(let msg):
            Text(msg)
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.error)
                .padding(.horizontal, BlipSpacing.xxl)
        case .ready, .recording:
            EmptyView()
        }
    }

    // MARK: - Record button

    private var recordButton: some View {
        Button {
            Task { await onRecordTapped() }
        } label: {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.6), lineWidth: 4)
                    .frame(width: 84, height: 84)
                Circle()
                    .fill(session.state == .recording ? .red : .white)
                    .frame(width: session.state == .recording ? 36 : 68,
                           height: session.state == .recording ? 36 : 68)
                    .animation(.easeInOut(duration: 0.2), value: session.state)
            }
        }
        .disabled(disableRecord)
    }

    private var disableRecord: Bool {
        switch session.state {
        case .recording, .denied, .unavailable, .error: return true
        default: return false
        }
    }

    private func onRecordTapped() async {
        switch session.state {
        case .idle:
            // First tap: request permissions, configure, start running, then record.
            guard await session.requestPermissions() else { return }
            await session.configure()
            session.start()
            await recordOnce()
        case .ready:
            await recordOnce()
        default:
            break
        }
    }

    private func recordOnce() async {
        do {
            let url = try await session.record()
            recordingURL = url
        } catch {
            // Surface error in the overlay via state — the session already moved to .error or .ready.
        }
    }

    private static func formattedTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: Date()).lowercased()
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
