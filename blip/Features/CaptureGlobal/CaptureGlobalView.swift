import SwiftUI

/// Snapchat-style global capture surface — opens record-first; on stop presents a
/// multi-select picker that fans the just-recorded 2s clip out to any subset of
/// blipchats the user is in.
///
/// APP STORE — camera + mic permissions are requested ONLY when the user taps record,
/// never on `.onAppear`. Reuses the existing `CaptureSession` permission flow.
struct CaptureGlobalView: View {

    // MARK: - Inputs

    let uid: String
    let onSent: () -> Void

    // MARK: - Environment

    @EnvironmentObject private var repo: BlipRepository
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @StateObject private var session = CaptureSession()
    @StateObject private var vm: CaptureGlobalViewModel

    @State private var showPicker = false
    /// Zoom level committed at the start of the current pinch — same pattern as CaptureView.
    @State private var baseZoom: CGFloat = 1.0

    // MARK: - Layout constants

    private static let recordButtonOuter: CGFloat = 84
    private static let recordButtonInnerIdle: CGFloat = 68
    private static let recordButtonInnerRec: CGFloat = 36
    private static let recordButtonStroke: CGFloat = 4
    private static let dismissButtonSize: CGFloat = 44
    private static let dismissIconBackgroundSize: CGFloat = 36
    private static let recordBottomPadding: CGFloat = 40
    private static let aspectLandscape: CGFloat = 16.0 / 9.0
    private static let recordButtonAnimationDuration: Double = 0.2

    init(uid: String, uploader: any ClipUploading, onSent: @escaping () -> Void) {
        self.uid = uid
        self.onSent = onSent
        _vm = StateObject(wrappedValue: CaptureGlobalViewModel(uploader: uploader))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            BlipColor.mediaBackdrop.ignoresSafeArea()
            cameraSurface

            VStack {
                topBar
                Spacer()
                statusOverlay
                Spacer()
                // Lens selector — only visible when ready and device has multiple lenses
                if !session.availableLenses.isEmpty && session.state == .ready {
                    lensButtonRow
                        .padding(.bottom, 12)
                }
                // Record button with countdown ring + REC label (matches CaptureView)
                ZStack {
                    recordButton

                    if session.state == .recording {
                        Circle()
                            .trim(from: 0, to: max(0, min(1, 1 - session.recordingElapsed / CaptureSession.clipDuration)))
                            .stroke(BlipColor.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: Self.recordButtonOuter, height: Self.recordButtonOuter)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.1), value: session.recordingElapsed)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.bottom, Self.recordBottomPadding)
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
        .preferredColorScheme(.dark)
        .onAppear {
            // Lock to landscape so the recording experience matches CaptureView
            // (group blip camera). The sensor is landscape-native; portrait mode
            // letterboxes the preview.
            AppDelegate.lockedOrientation = .landscape
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            }
        }
        .onDisappear {
            session.stop()
            // Release orientation lock so the app returns to portrait after
            // the camera cover dismisses (matches CaptureView behaviour).
            AppDelegate.lockedOrientation = .portrait
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        }
        .onChange(of: vm.recordingURL) { _, url in
            // When a recording finishes, surface the picker. Closing it without sending
            // returns to the camera (vm.discardRecording) so the user can re-record.
            showPicker = url != nil
        }
        .sheet(isPresented: $showPicker, onDismiss: handlePickerDismiss) {
            BlipPickerView(
                blips: repo.blips,
                selected: $vm.selectedBlipIds,
                isSending: vm.isSending,
                errorMessage: vm.errorMessage,
                onCancel: { showPicker = false },
                onSend: handleSend
            )
            .presentationDetents([.large])
            .interactiveDismissDisabled(vm.isSending)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var cameraSurface: some View {
        // Preview only renders for real cameras. Synthetic mode = no preview, just the record button.
        if !session.useSynthetic && (session.state == .ready || session.state == .recording) {
            CapturePreview(session: session.session)
                .aspectRatio(Self.aspectLandscape, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(
                    MagnificationGesture()
                        .onChanged { scale in session.setZoom(factor: baseZoom * scale) }
                        .onEnded   { scale in baseZoom = max(1.0, baseZoom * scale) }
                )
        }

        #if DEBUG
        if session.useSynthetic && session.state != .idle {
            VStack(spacing: 6) {
                Text("DEBUG: synthetic clip mode")
                    .font(.blip(size: 11, design: .monospaced))
                    .foregroundStyle(BlipColor.textPrimary.opacity(0.5))
                Text("no camera available; record produces a 2s color clip")
                    .font(.blip(size: 11, design: .monospaced))
                    .foregroundStyle(BlipColor.textPrimary.opacity(0.4))
            }
            .padding(.top, 88)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        #endif
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(BlipColor.surface.opacity(0.4))
                        .frame(width: Self.dismissIconBackgroundSize, height: Self.dismissIconBackgroundSize)
                    Image(systemName: "xmark")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textPrimary)
                }
                .frame(minWidth: Self.dismissButtonSize, minHeight: Self.dismissButtonSize)
            }
            .accessibilityLabel("close camera")

            Spacer()

            Text("camera")
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(BlipColor.surface.opacity(0.4), in: Capsule())

            Spacer()

            Button {
                Task { await session.flipCamera() }
            } label: {
                ZStack {
                    Circle()
                        .fill(BlipColor.surface.opacity(0.4))
                        .frame(width: Self.dismissIconBackgroundSize, height: Self.dismissIconBackgroundSize)
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textPrimary)
                }
                .frame(minWidth: Self.dismissButtonSize, minHeight: Self.dismissButtonSize)
            }
            .accessibilityLabel("flip camera")
            .disabled(session.state == .recording)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch session.state {
        case .idle:
            VStack(spacing: 8) {
                Text(hasActiveBlip ? "tap to record" : "no blips are open")
                    .font(BlipTypography.title)
                    .foregroundStyle(BlipColor.textPrimary)
                Text(hasActiveBlip ? "a 2s clip — pick who sees it next" : "check each group's daily window")
                    .font(BlipTypography.caption)
                    .foregroundStyle(BlipColor.textPrimary.opacity(0.7))
            }
        case .denied:
            VStack(spacing: 8) {
                Text("camera + mic access needed")
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textPrimary)
                Button("open settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundStyle(BlipColor.textPrimary)
                .fontWeight(.semibold)
            }
        case .unavailable:
            Text("camera unavailable in this environment")
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.textPrimary.opacity(0.6))
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
                    .stroke(BlipColor.textPrimary.opacity(0.6), lineWidth: Self.recordButtonStroke)
                    .frame(width: Self.recordButtonOuter, height: Self.recordButtonOuter)
                Circle()
                    .fill(session.state == .recording ? BlipColor.error : BlipColor.textPrimary)
                    .frame(
                        width: session.state == .recording ? Self.recordButtonInnerRec : Self.recordButtonInnerIdle,
                        height: session.state == .recording ? Self.recordButtonInnerRec : Self.recordButtonInnerIdle
                    )
                    .animation(.easeInOut(duration: Self.recordButtonAnimationDuration), value: session.state)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(session.state == .recording ? "recording" : "record")
        .disabled(disableRecord)
    }

    // MARK: - Lens row (matches CaptureView)

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
                            isActiveLens(lens) ? Color.white.opacity(0.18) : Color.black.opacity(0.4),
                            in: Circle()
                        )
                        .overlay(Circle().stroke(isActiveLens(lens) ? Color.white : Color.clear, lineWidth: 1.5))
                }
                .accessibilityLabel("zoom \(lens.label)")
            }
        }
    }

    private func isActiveLens(_ lens: CaptureSession.LensOption) -> Bool {
        guard let nearest = session.availableLenses.min(by: {
            abs($0.zoomFactor - session.currentZoomFactor) < abs($1.zoomFactor - session.currentZoomFactor)
        }) else { return false }
        return nearest.id == lens.id
    }

    // MARK: - Helpers

    private var disableRecord: Bool {
        if !hasActiveBlip { return true }
        switch session.state {
        case .recording, .denied, .unavailable, .error: return true
        case .idle, .ready: return false
        }
    }

    private var hasActiveBlip: Bool {
        repo.blips.contains(where: { $0.isActive() })
    }

    private func onRecordTapped() async {
        guard hasActiveBlip else { return }
        switch session.state {
        case .idle:
            // First tap: request permissions, configure, start running, then record.
            guard await session.requestPermissions() else { return }
            await session.configure()
            session.start()
            await recordOnce()
        case .ready:
            await recordOnce()
        case .recording, .denied, .unavailable, .error:
            break
        }
    }

    private func recordOnce() async {
        do {
            let url = try await session.record()
            vm.recordingURL = url
        } catch {
            // Surface error in the overlay via state — the session already moved to .error or .ready.
        }
    }

    private func handlePickerDismiss() {
        // Sheet got dismissed (swipe-down or cancel). If we still have a recording
        // that wasn't sent, drop it so the user can record fresh.
        if vm.recordingURL != nil && !vm.isSending {
            vm.discardRecording()
        }
    }

    private func handleSend() {
        Task {
            let success = await vm.send(uid: uid, blips: repo.blips)
            if success {
                showPicker = false
                onSent()
            }
        }
    }
}
