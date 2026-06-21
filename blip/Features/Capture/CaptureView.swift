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

    var body: some View {
        ZStack {
            BlipColor.mediaBackdrop.ignoresSafeArea()

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
                .padding(.top, 88)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            #endif

            VStack {
                topBar
                Spacer()
                statusOverlay
                Spacer()
                if !session.availableLenses.isEmpty && session.state == .ready {
                    lensButtonRow
                        .padding(.bottom, 12)
                }
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
                .padding(.bottom, 40)
                .overlay(alignment: .top) {
                    if session.state == .recording {
                        let remaining = max(0, CaptureSession.clipDuration - session.recordingElapsed)
                        Text("REC · \(String(format: "%.1f", remaining))s left")
                            .font(.blip(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(BlipColor.error, in: Capsule())
                            .offset(y: -28)
                            .allowsHitTesting(false)
                    }
                }
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
            // onDisappear stops the AVCaptureSession when ReviewView is pushed.
            // Restart it here so the preview and retake work when the user
            // pops back without posting.
            if session.state == .ready {
                session.start()
            }
        }
        .onDisappear {
            session.stop()
            AppDelegate.lockedOrientation = .portrait
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                // Reset orientation BEFORE dismiss so it takes effect during
                // the dismissal animation, not after — which was causing the
                // "stays landscape" bug when cancelling out of the capture screen.
                AppDelegate.lockedOrientation = .portrait
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                }
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .accessibilityLabel("close")
            Spacer()
            Text(blip.name)
                .font(BlipTypography.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.4), in: Capsule())
            Spacer()
            Button {
                Task { await session.flipCamera() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .accessibilityLabel("flip camera")
            .disabled(session.state == .recording)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var lensButtonRow: some View {
        HStack(spacing: 8) {
            ForEach(session.availableLenses) { lens in
                Button {
                    session.setZoom(factor: lens.zoomFactor, ramped: true)
                    baseZoom = lens.zoomFactor
                } label: {
                    Text(lens.label)
                        .font(.blip(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            isActive(lens) ? .white.opacity(0.18) : .black.opacity(0.4),
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

    @ViewBuilder
    private var statusOverlay: some View {
        switch session.state {
        case .idle:
            VStack(spacing: 8) {
                Text(blip.isActive() ? "tap to capture" : "recording is closed")
                    .font(BlipTypography.title)
                    .foregroundStyle(.white)
                Text(blip.isActive() ? "a 2-second blip for \(blip.name)" : scheduleText)
                    .font(BlipTypography.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        case .denied:
            VStack(spacing: 8) {
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
                .padding(.horizontal, 32)
        case .error(let msg):
            Text(msg)
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.error)
                .padding(.horizontal, 32)
        case .ready, .recording:
            EmptyView()
        }
    }

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
        if !blip.isActive() { return true }
        switch session.state {
        case .recording, .denied, .unavailable, .error: return true
        default: return false
        }
    }

    private func onRecordTapped() async {
        guard blip.isActive() else { return }
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

    private var scheduleText: String {
        "\(BlipHour.hourLabel(blip.activeStartHour)) to \(BlipHour.hourLabel(blip.activeEndHour)) in group time"
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
