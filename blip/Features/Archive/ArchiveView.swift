import AVKit
import SwiftUI

// MARK: - Archive screen
//
// Shows past stitched days for a blip, most recent first.
// Each row reflects the stitch status:
//   .ready     → tappable, shows play button + date
//   .running / .queued → spinner + "processing" label (not tappable)
//   .pending   → clock icon + "not yet stitched"
//   .failed    → warning icon + "export failed"

struct ArchiveView: View {
    let blip: Blip

    @EnvironmentObject private var auth: AuthService
    @StateObject private var repo = ArchiveRepository()
    @State private var playing: BlipDay?

    var body: some View {
        ZStack {
            BlipColor.backgroundGradient.ignoresSafeArea()

            Group {
                if repo.isLoading && repo.days.isEmpty {
                    loadingState
                } else if let err = repo.lastError {
                    errorState(err)
                } else if repo.days.isEmpty {
                    emptyState
                } else {
                    dayList
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("archive")
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textPrimary)
            }
        }
        .toolbarBackground(BlipColor.background, for: .navigationBar)
        .task(id: blip.id) {
            guard case .signedIn(let uid) = auth.state else { return }
            repo.startListening(blip: blip, uid: uid)
        }
        .onDisappear { repo.stopListening() }
        .sheet(item: $playing) { day in
            switch day.stitchStatus {
            case .ready:
                if let url = day.stitchedVideoUrl {
                    ArchivePlayerSheet(dateKey: day.id, url: url)
                }
            case .running, .queued:
                processingSheet(day: day)
            default:
                EmptyView()
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView().tint(BlipColor.accent)
            Text("loading archive…")
                .font(.blip(size: 13))
                .foregroundStyle(BlipColor.textTertiary)
            Spacer()
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(BlipColor.error)
            Text("couldn't load archive")
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textPrimary)
            Text(message)
                .font(.blip(size: 12))
                .foregroundStyle(BlipColor.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(BlipColor.textTertiary)
            Text("no archive yet")
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textSecondary)
            Text("tap Export in the group detail to stitch a day.\nit will appear here once it's ready.")
                .font(.blip(size: 13))
                .foregroundStyle(BlipColor.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var dayList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(repo.days) { day in
                    ArchiveRow(blipId: blip.id, day: day) {
                        // Only open the player/processing sheet for these statuses
                        let tappable = day.stitchStatus == .ready
                                    || day.stitchStatus == .running
                                    || day.stitchStatus == .queued
                        if tappable { playing = day }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Processing sheet (shown when user taps a day that's still stitching)

    private func processingSheet(day: BlipDay) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().tint(BlipColor.accent).controlSize(.large)
            Text("stitching \(formatDateKey(day.id))…")
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textPrimary)
            Text("this usually takes 30–90 seconds.\ncheck back in a moment.")
                .font(.blip(size: 13))
                .foregroundStyle(BlipColor.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .presentationDetents([.medium])
    }
}

// MARK: - Archive row

private struct ArchiveRow: View {
    let blipId: String
    let day: BlipDay
    let onTap: () -> Void

    @StateObject private var likes = DayLikesRepository()

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    statusThumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDateKey(day.id))
                            .font(.blip(size: 15, weight: .semibold))
                            .foregroundStyle(BlipColor.textPrimary)
                        statusLabel
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .disabled(day.stitchStatus == .pending || day.stitchStatus == .failed)

            // Heart — only for ready days
            if day.stitchStatus == .ready {
                HeartButton(
                    liked: likes.liked,
                    count: likes.count,
                    isWriting: likes.isWriting,
                    onTap: { Task { await likes.toggle() } }
                )
            }
        }
        .padding(14)
        .background(BlipColor.surface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .task(id: day.id) {
            if day.stitchStatus == .ready {
                likes.startListening(blipId: blipId, dateKey: day.id)
            }
        }
    }

    // MARK: Thumbnail / status icon

    @ViewBuilder
    private var statusThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(thumbnailBg)
                .frame(width: 56, height: 80)

            thumbnailIcon
        }
    }

    private var thumbnailBg: Color {
        switch day.stitchStatus {
        case .ready:    return BlipColor.accentNeutral.opacity(0.12)
        case .running, .queued: return BlipColor.accent.opacity(0.10)
        case .failed:   return BlipColor.error.opacity(0.10)
        case .pending:  return BlipColor.border.opacity(0.3)
        }
    }

    @ViewBuilder
    private var thumbnailIcon: some View {
        switch day.stitchStatus {
        case .ready:
            Image(systemName: "play.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BlipColor.accentNeutral)
        case .running, .queued:
            ProgressView().tint(BlipColor.accent).scaleEffect(0.8)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(BlipColor.error)
        case .pending:
            Image(systemName: "clock")
                .font(.system(size: 18))
                .foregroundStyle(BlipColor.textTertiary)
        }
    }

    // MARK: Status sub-label

    @ViewBuilder
    private var statusLabel: some View {
        switch day.stitchStatus {
        case .ready:
            if let at = day.stitchedAt {
                Text(relativeDate(at))
                    .font(.blip(size: 11))
                    .foregroundStyle(BlipColor.textTertiary)
                    .lineLimit(1)
            }
        case .running, .queued:
            Text("stitching…")
                .font(.blip(size: 11))
                .foregroundStyle(BlipColor.accent)
                .lineLimit(1)
        case .failed:
            Text("export failed — re-stitch from group")
                .font(.blip(size: 11))
                .foregroundStyle(BlipColor.error)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        case .pending:
            Text("not yet stitched")
                .font(.blip(size: 11))
                .foregroundStyle(BlipColor.textTertiary)
                .lineLimit(1)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Player sheet

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
                    Button("done") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .principal) {
                    Text(formatDateKey(dateKey))
                        .font(BlipTypography.body)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showShare = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("share")
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

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: ()) {
        uiViewController.player?.pause()
        uiViewController.player = nil
    }
}

// MARK: - Shared date formatter

/// Converts a raw `yyyy-MM-dd` dateKey into a readable string like "Monday, June 21".
private func formatDateKey(_ dateKey: String) -> String {
    let parser = DateFormatter()
    parser.dateFormat = "yyyy-MM-dd"
    parser.locale = .current
    guard let date = parser.date(from: dateKey) else { return dateKey }
    let display = DateFormatter()
    display.dateFormat = "EEEE, MMMM d"
    return display.string(from: date)
}
