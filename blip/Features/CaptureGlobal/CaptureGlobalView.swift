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
    @State private var currentTime: String = Self.formattedTime()

    // MARK: - Layout constants

    private static let recordButtonOuter: CGFloat = 84
    private static let recordButtonInnerIdle: CGFloat = 68
    private static let recordButtonInnerRec: CGFloat = 36
    private static let recordButtonStroke: CGFloat = 4
    private static let recordButtonAnimationDuration: Double = 0.2

    init(uid: String, uploader: any ClipUploading, onSent: @escaping () -> Void) {
        self.uid = uid
        self.onSent = onSent
        _vm = StateObject(wrappedValue: CaptureGlobalViewModel(uploader: uploader))
    }

    // MARK: - Body

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
        .preferredColorScheme(.dark)
        .onDisappear { session.stop() }
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
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            currentTime = Self.formattedTime()
        }
    }

    // MARK: - Viewfinder

    private var viewfinderArea: some View {
        ZStack {
            cameraSurface
            statusOverlay

            if session.state == .ready || session.state == .recording {
                Text(currentTime)
                    .font(BlipTypography.clipTimestamp)
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(90))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BlipColor.mediaBackdrop)
        .clipShape(RoundedRectangle(cornerRadius: BlipRadius.lg, style: .continuous))
        .overlay(alignment: .topTrailing) {
            BlipIconButton(systemName: "xmark", style: .dark) { dismiss() }
                .padding(12)
        }
    }

    @ViewBuilder
    private var cameraSurface: some View {
        // Preview only renders for real cameras. Synthetic mode = no preview, just the record button.
        if !session.useSynthetic && (session.state == .ready || session.state == .recording) {
            CapturePreview(session: session.session)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .padding(.top, 48)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        #endif
    }

    // MARK: - Bottom toolbar

    private var bottomToolbar: some View {
        HStack {
            Spacer()
            BlipIconButton(systemName: "timer", style: .dark) {}
            Spacer()
            BlipIconButton(systemName: "dial.medium", style: .dark) {}
            Spacer()
            recordButton
            Spacer()
            BlipIconButton(systemName: "bolt", style: .dark) {}
            Spacer()
            BlipIconButton(systemName: "arrow.2.circlepath", style: .dark) {}
            Spacer()
        }
        .frame(height: 80)
        .background(BlipColor.background)
    }

    // MARK: - Status overlay

    @ViewBuilder
    private var statusOverlay: some View {
        switch session.state {
        case .idle:
            VStack(spacing: BlipSpacing.sm) {
                Text("tap to record")
                    .font(BlipTypography.title)
                    .foregroundStyle(BlipColor.textPrimary)
            }
        case .denied:
            VStack(spacing: BlipSpacing.sm) {
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
            .frame(minWidth: BlipSpacing.tapTarget, minHeight: BlipSpacing.tapTarget)
        }
        .accessibilityLabel(session.state == .recording ? "recording" : "record")
        .disabled(disableRecord)
    }

    // MARK: - Helpers

    private var disableRecord: Bool {
        switch session.state {
        case .recording, .denied, .unavailable, .error: return true
        case .idle, .ready: return false
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
            let success = await vm.send(uid: uid)
            if success {
                showPicker = false
                onSent()
            }
        }
    }

    private static func formattedTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: Date()).lowercased()
    }
}
