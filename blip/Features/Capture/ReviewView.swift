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
                        ProgressView(value: vm.uploadProgress)
                            .tint(BlipColor.textPrimary)
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
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // The captured clip is landscape; re-assert the lock so playback fills
            // the screen. CaptureView (still in the nav stack underneath) is the
            // canonical lock owner — its onDisappear releases the lock back to
            // portrait when the whole capture flow tears down.
            AppDelegate.lockedOrientation = .landscape
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
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
