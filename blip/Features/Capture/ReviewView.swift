import AVKit
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

/// Screen-08 parity (post-record half) — playback + timestamp overlay + "send to:" picker + post.
struct ReviewView: View {
    let blip: Blip
    let fileURL: URL
    let onPosted: () -> Void

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @Environment(\.dismiss) private var dismiss

    @StateObject private var uploader = ClipUploader()
    @State private var sendToBlipIds: Set<String>
    @State private var caption: String = ""
    @State private var postError: String?

    init(blip: Blip, fileURL: URL, onPosted: @escaping () -> Void) {
        self.blip = blip
        self.fileURL = fileURL
        self.onPosted = onPosted
        _sendToBlipIds = State(initialValue: [blip.id])
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

                    if uploader.isUploading {
                        ProgressView(value: uploader.progress)
                            .tint(BlipColor.accent)
                    }
                    if let postError {
                        Text(postError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
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
                .disabled(uploader.isUploading)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: post) {
                    if uploader.isUploading {
                        ProgressView().tint(BlipColor.accent)
                    } else {
                        Image(systemName: "arrow.up")
                            .foregroundStyle(canPost ? BlipColor.accent : BlipColor.textTertiary)
                    }
                }
                .disabled(!canPost || uploader.isUploading)
            }
        }
        .toolbarBackground(BlipColor.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private var clipPreview: some View {
        VideoPreview(url: fileURL)
            .overlay(alignment: .top) {
                Text(currentHourString)
                    .font(BlipTypography.clipTimestamp)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                    .padding(.top, 16)
            }
    }

    private var blipPicker: some View {
        // Slice A scope: send-to lists the current blip + every other blip the user is in.
        VStack(spacing: 8) {
            ForEach(allDestinations) { dest in
                Button {
                    if sendToBlipIds.contains(dest.id) {
                        sendToBlipIds.remove(dest.id)
                    } else {
                        sendToBlipIds.insert(dest.id)
                    }
                } label: {
                    HStack {
                        Image(systemName: sendToBlipIds.contains(dest.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(sendToBlipIds.contains(dest.id) ? BlipColor.accent : BlipColor.textTertiary)
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
            }
        }
    }

    private struct Destination: Identifiable {
        let id: String
        let name: String
        let subtitle: String
    }

    private var allDestinations: [Destination] {
        var list = [Destination(id: blip.id, name: blip.name, subtitle: "this blip")]
        for other in repo.blips where other.id != blip.id {
            list.append(Destination(id: other.id, name: other.name, subtitle: "\(other.members.count) members"))
        }
        return list
    }

    private var canPost: Bool { !sendToBlipIds.isEmpty }

    private var currentHourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: Date()).lowercased()
    }

    private func post() {
        guard case .signedIn(let uid) = auth.state else {
            postError = "not signed in"
            return
        }
        postError = nil

        // Pre-flight membership check. Re-fetches the blip so a stale local copy
        // can't smuggle the upload past Storage rules with a clearer error here.
        Task {
            do {
                let snapshot = try await Firestore.firestore()
                    .collection("blips").document(blip.id).getDocument()
                let liveMembers = (snapshot.data()?["members"] as? [String]) ?? []
                let sdkUid = Auth.auth().currentUser?.uid ?? "<nil>"

                print("[blip-diag] AuthService.state uid: \(uid)")
                print("[blip-diag] SDK currentUser uid:  \(sdkUid)")
                print("[blip-diag] State==SDK?           \(uid == sdkUid)")
                print("[blip-diag] blipId:               \(blip.id)")
                print("[blip-diag] liveMembers:          \(liveMembers)")
                for (idx, m) in liveMembers.enumerated() {
                    let same = m == uid
                    print("[blip-diag]   members[\(idx)] match=\(same) value=\(m)")
                    if !same {
                        print("[blip-diag]   uid bytes:    \(uid.unicodeScalars.map { String(format: "%02X", $0.value) }.joined(separator: " "))")
                        print("[blip-diag]   member bytes: \(m.unicodeScalars.map { String(format: "%02X", $0.value) }.joined(separator: " "))")
                    }
                }

                guard liveMembers.contains(uid) else {
                    postError = "you're not a member of this blip — try the join code."
                    return
                }

                try await uploader.upload(
                    fileURL: fileURL,
                    uid: uid,
                    primaryBlipId: blip.id,
                    sharedToBlipIds: Array(sendToBlipIds),
                    caption: caption.isEmpty ? nil : caption
                )
                onPosted()
            } catch {
                postError = error.localizedDescription
            }
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
}
