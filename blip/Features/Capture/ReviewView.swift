import AVKit
import SwiftUI

/// Post-record screen — playback + destination picker + post.
struct ReviewView: View {
    let blip: Blip
    let fileURL: URL
    let onPosted: () -> Void

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm: ReviewViewModel

    init(blip: Blip, fileURL: URL, onPosted: @escaping () -> Void) {
        self.blip = blip
        self.fileURL = fileURL
        self.onPosted = onPosted
        _vm = StateObject(wrappedValue: ReviewViewModel(blip: blip))
    }

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(spacing: 16) {
                clipPreview
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    Text("send to:")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textPrimary)

                    blipPicker

                    if vm.isUploading {
                        GradientUploadBar(progress: vm.uploadProgress)
                            .padding(.top, 6)
                    }

                    ErrorText(message: vm.errorMessage)
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 12)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").foregroundStyle(BlipColor.textPrimary)
                }
                .disabled(vm.isUploading)
                .accessibilityLabel("close")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: post) {
                    if vm.isUploading {
                        ProgressView().tint(BlipColor.textPrimary)
                    } else {
                        Image(systemName: "arrow.up")
                            .foregroundStyle(vm.canPost ? BlipColor.textPrimary : BlipColor.textTertiary)
                            .fontWeight(.semibold)
                    }
                }
                .disabled(!vm.canPost || vm.isUploading)
                .accessibilityLabel("post")
            }
        }
        .toolbarBackground(BlipColor.background, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Recording is landscape-native, but the review/upload screen should
            // be back in portrait so the user can read the destination picker and
            // progress bar comfortably.  CaptureView already released the lock in
            // its own onDisappear; we just confirm portrait here.
            AppDelegate.lockedOrientation = .portrait
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        }
        .onDisappear {
            // Ensure portrait is restored whether the user dismisses via X,
            // swipes back (retake), or posts — CaptureView.onAppear will
            // re-lock to landscape for retake; for the post path this is final.
            AppDelegate.lockedOrientation = .portrait
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        }
    }

    private var clipPreview: some View {
        VideoPreview(url: fileURL)
            .overlay {
                ClipTimestampLabel(hour: BlipHour.currentHour(in: blip.timezoneIdentifier))
            }
    }

    private var blipPicker: some View {
        VStack(spacing: 8) {
            ForEach(allDestinations) { dest in
                Button {
                    vm.toggleDestination(dest.id)
                } label: {
                    HStack {
                        Image(systemName: vm.sendToBlipIds.contains(dest.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(vm.sendToBlipIds.contains(dest.id) ? BlipColor.textPrimary : BlipColor.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dest.name)
                                .font(BlipTypography.body)
                                .foregroundStyle(BlipColor.textPrimary)
                            Text(dest.subtitle)
                                .font(.caption2)
                                .foregroundStyle(BlipColor.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!dest.isActive)
                .opacity(dest.isActive ? 1 : 0.55)
            }
        }
    }

    private struct Destination: Identifiable {
        let id: String
        let name: String
        let subtitle: String
        let isActive: Bool
    }

    private var allDestinations: [Destination] {
        var list = [Destination(
            id: blip.id,
            name: blip.name,
            subtitle: "this blip",
            isActive: blip.isActive()
        )]
        for other in repo.blips where other.id != blip.id {
            let subtitle = other.isActive()
                ? "\(other.members.count) members"
                : "opens at \(BlipHour.hourLabel(other.activeStartHour)) group time"
            list.append(Destination(id: other.id, name: other.name, subtitle: subtitle, isActive: other.isActive()))
        }
        return list
    }

    private func post() {
        guard case .signedIn(let uid) = auth.state else { return }
        Task {
            await vm.post(uid: uid, fileURL: fileURL, availableBlips: repo.blips)
            if vm.errorMessage == nil { onPosted() }
        }
    }
}

// MARK: - Gradient upload progress bar

/// Animated gradient progress bar with a pulsing glow dot and live percentage.
/// Replaces the plain system ProgressView in ReviewView.
private struct GradientUploadBar: View {
    let progress: Double          // 0.0 … 1.0

    @State private var pulsing = false

    // Rose gradient matching the app accent
    private let fillGradient = LinearGradient(
        colors: [
            Color(hex: 0xFDA4AF),  // rose-300
            Color(hex: 0xF43F5E),  // rose-500
            Color(hex: 0xBE123C),  // rose-700
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 10) {

            // ── Label row ──────────────────────────────────────────────
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // Pulsing live dot
                Circle()
                    .fill(Color(hex: 0xF43F5E))
                    .frame(width: 7, height: 7)
                    .scaleEffect(pulsing ? 1.45 : 1.0)
                    .opacity(pulsing ? 0.65 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.65).repeatForever(autoreverses: true),
                        value: pulsing
                    )

                Text("uploading blip")
                    .font(.blip(size: 13, weight: .semibold))
                    .foregroundStyle(BlipColor.textSecondary)

                Spacer()

                // Live percentage — flips with a numeric transition
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: 0xF43F5E))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8),
                               value: Int(progress * 100))
            }

            // ── Progress track + fill ──────────────────────────────────
            GeometryReader { geo in
                let trackW  = geo.size.width
                let fillW   = max(10, trackW * CGFloat(progress))

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.black.opacity(0.07))
                        .frame(height: 8)

                    // Gradient fill — spring-animated so it eases in smoothly
                    Capsule()
                        .fill(fillGradient)
                        .frame(width: fillW, height: 8)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.78),
                            value: progress
                        )

                    // Glowing tip dot
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(Color(hex: 0xF43F5E).opacity(pulsing ? 0.30 : 0.15))
                            .frame(width: 20, height: 20)
                        // White core
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .shadow(
                                color: Color(hex: 0xF43F5E).opacity(0.65),
                                radius: pulsing ? 7 : 3,
                                x: 0, y: 0
                            )
                    }
                    // Centre the dot on the fill's right edge
                    .offset(x: fillW - 10, y: -1)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.78),
                        value: progress
                    )
                }
            }
            .frame(height: 18)  // enough room for the glow halo
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.75))
                .shadow(color: Color(hex: 0xF43F5E).opacity(0.10), radius: 10, x: 0, y: 4)
        )
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.65).repeatForever(autoreverses: true)
            ) { pulsing = true }
        }
    }
}

// MARK: - Video preview

private struct VideoPreview: UIViewControllerRepresentable {
    let url: URL

    final class Coordinator {
        var looper: AVPlayerLooper?
        var queuePlayer: AVQueuePlayer?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        context.coordinator.queuePlayer = queuePlayer
        context.coordinator.looper = looper

        let vc = AVPlayerViewController()
        vc.player = queuePlayer
        vc.showsPlaybackControls = false
        vc.videoGravity = .resizeAspect
        queuePlayer.play()
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    // Tear down the AVQueuePlayer + looper when the review screen dismisses.
    // The looper holds a strong reference to the queue player, which holds the
    // AVPlayerItem — leaving them alive keeps the file open and decoder armed.
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.queuePlayer?.pause()
        coordinator.looper?.disableLooping()
        coordinator.looper = nil
        coordinator.queuePlayer = nil
        uiViewController.player = nil
    }
}
