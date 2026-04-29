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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Preview only renders for real cameras. Synthetic mode = no preview, just the record button.
            // Landscape 16:9 letterbox, centered. Black bars top/bottom in portrait orientation.
            if !session.useSynthetic && (session.state == .ready || session.state == .recording) {
                CapturePreview(session: session.session)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                recordButton
                    .padding(.bottom, 40)
            }
        }
        .navigationDestination(item: $recordingURL) { url in
            ReviewView(blip: blip, fileURL: url, onPosted: onPosted)
        }
        .onDisappear { session.stop() }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .accessibilityLabel("Dismiss")
            Spacer()
            Text(blip.name)
                .font(BlipTypography.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.4), in: Capsule())
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch session.state {
        case .idle:
            VStack(spacing: 8) {
                Text("tap to capture")
                    .font(BlipTypography.title)
                    .foregroundStyle(.white)
                Text("a 2-second blip for \(blip.name)")
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
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
