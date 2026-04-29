import SwiftUI

/// Reusable card used on the Home screen for both the solo "vlog" and group blips.
/// When `progress` is provided, the §4.2 live treatment renders (ring + member dots + countdown).
struct BlipCard: View {
    let title: String
    let subtitle: String
    let progress: BlipCardProgress?

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(BlipTypography.title)
                    .foregroundStyle(BlipColor.textPrimary)
                Text(subtitle)
                    .font(BlipTypography.caption)
                    .foregroundStyle(BlipColor.textSecondary)
            }

            Spacer()

            if let progress {
                LiveProgressIndicator(progress: progress)
            }
        }
        .padding(16)
        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct BlipCardProgress {
    /// 0...1 fraction of members who have posted in the current hour.
    var hourCompletion: Double
    /// Member display info for avatar dots.
    var members: [Member]
    /// Seconds until the next hourly prompt.
    var secondsToNextPrompt: Int

    struct Member: Identifiable {
        let id: String
        let initials: String
        let hasPostedThisHour: Bool
    }
}

private struct LiveProgressIndicator: View {
    let progress: BlipCardProgress

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ZStack {
                Circle()
                    .stroke(BlipColor.progressTrack, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress.hourCompletion)
                    .stroke(BlipColor.progressFill, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress.hourCompletion * 100))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(BlipColor.textPrimary)
            }
            .frame(width: 36, height: 36)

            Text(formatCountdown(progress.secondsToNextPrompt))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(BlipColor.textTertiary)
        }
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        let s = max(0, seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

#Preview("Solo (no progress)") {
    BlipCard(title: "vlog", subtitle: "your space. each day runs 4am to 4am.", progress: nil)
        .padding()
        .background(Color.black)
}

#Preview("Group (live)") {
    BlipCard(
        title: "spring break crew",
        subtitle: "4 of 6 captured this hour",
        progress: BlipCardProgress(
            hourCompletion: 4.0 / 6.0,
            members: [
                .init(id: "1", initials: "ED", hasPostedThisHour: true),
                .init(id: "2", initials: "LJ", hasPostedThisHour: true),
                .init(id: "3", initials: "AM", hasPostedThisHour: false),
            ],
            secondsToNextPrompt: 23 * 60 + 47
        )
    )
    .padding()
    .background(Color.black)
}
