import AVKit
import SwiftUI

/// Past blips — list of stitched days for this blip, most recent first.
/// Korean Setlog users specifically asked for this (per research doc); v0 ships
/// list-of-rows; calendar grid is v0.5 polish.
struct ArchiveView: View {
    let blip: Blip

    @StateObject private var repo = ArchiveRepository()
    @State private var playing: BlipDay?

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            if repo.days.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(repo.days) { day in
                            Button { playing = day } label: {
                                ArchiveRow(day: day)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("archive").font(BlipTypography.body).foregroundStyle(BlipColor.textPrimary)
            }
        }
        .toolbarBackground(BlipColor.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: blip.id) { repo.startListening(blipId: blip.id) }
        .sheet(item: $playing) { day in
            if let url = day.stitchedVideoUrl {
                ArchivePlayerSheet(dateKey: day.id, url: url)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "calendar")
                .font(.title)
                .foregroundStyle(BlipColor.textTertiary)
            Text("no archive yet")
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textSecondary)
            Text("export a day to see it here.")
                .font(.caption)
                .foregroundStyle(BlipColor.textTertiary)
            Spacer()
        }
    }
}

private struct ArchiveRow: View {
    let day: BlipDay

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(BlipColor.surfaceElevated)
                    .frame(width: 56, height: 80)
                Image(systemName: "play.fill")
                    .foregroundStyle(BlipColor.textPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(day.id)
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textPrimary)
                if let stitchedAt = day.stitchedAt {
                    Text(relative(stitchedAt))
                        .font(.caption2)
                        .foregroundStyle(BlipColor.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(BlipColor.textTertiary)
        }
        .padding(12)
        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

private struct ArchivePlayerSheet: View {
    let dateKey: String
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ArchivePlayer(url: url)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("done") { dismiss() }
                        .foregroundStyle(BlipColor.textPrimary)
                }
                ToolbarItem(placement: .principal) {
                    Text(dateKey).font(BlipTypography.body).foregroundStyle(BlipColor.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showShare = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(BlipColor.textPrimary)
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showShare) {
                ShareSheet(activityItems: [url])
            }
        }
    }
}

private struct ArchivePlayer: UIViewControllerRepresentable {
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
