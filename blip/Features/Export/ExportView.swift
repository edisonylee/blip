import AVKit
import SwiftUI

/// Priority-1 screen — on-demand stitched export of today's blips.
///
/// Flow:
///   1. .stitching while the Cloud Function runs (can take 30–90s for a full day)
///   2. .ready with looping playback + share button
///   3. .failed with retry
struct ExportView: View {
    let blip: Blip

    @StateObject private var service = ExportService()
    @State private var showShare = false

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            switch service.status {
            case .idle:
                idleState
            case .stitching:
                stitchingState
            case .ready(let url, let dateKey, let hours):
                readyState(url: url, dateKey: dateKey, hours: hours)
            case .failed(let msg):
                failedState(msg: msg)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("export").font(BlipTypography.body).foregroundStyle(BlipColor.textPrimary)
            }
        }
        .toolbarBackground(BlipColor.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var idleState: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("today, stitched")
                .font(BlipTypography.title)
                .foregroundStyle(BlipColor.textPrimary)
            Text("compile every blip from \(blip.name) into one savable video.")
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task { await service.stitch(blipId: blip.id) }
            } label: {
                Text("stitch today")
                    .font(BlipTypography.body)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(BlipColor.accent, in: Capsule())
            }
            Spacer()
        }
        .padding()
    }

    private var stitchingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(BlipColor.accent)
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

            HStack(spacing: 8) {
                Text(dateKey)
                Text("·")
                Text("\(hours) hour\(hours == 1 ? "" : "s")")
            }
            .font(BlipTypography.caption)
            .foregroundStyle(BlipColor.textTertiary)

            HStack(spacing: 12) {
                Button { showShare = true } label: {
                    Label("share", systemImage: "square.and.arrow.up")
                        .font(BlipTypography.body)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(BlipColor.accent, in: Capsule())
                }

                Button {
                    Task { await service.stitch(blipId: blip.id) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                        .foregroundStyle(BlipColor.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(BlipColor.surface, in: Circle())
                }
            }
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(activityItems: [url])
        }
    }

    @ViewBuilder
    private func failedState(msg: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.red)
            Text(msg)
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("try again") {
                Task { await service.stitch(blipId: blip.id) }
            }
            .foregroundStyle(BlipColor.accent)
            Spacer()
        }
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
}
