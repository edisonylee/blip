import SwiftUI

struct BlipCard: View {
    let title: String
    let subtitle: String
    let memberCount: Int
    let progress: BlipCardProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(BlipColor.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(BlipColor.textSecondary)
                }

                Spacer()

                if let progress {
                    LiveRing(progress: progress)
                }
            }

            if let progress, !progress.members.isEmpty {
                HStack {
                    AvatarRow(
                        members: progress.members.map {
                            AvatarRowMember(id: $0.id, initials: $0.initials, hasPosted: $0.hasPostedThisHour)
                        },
                        maxVisible: 7,
                        size: 24
                    )
                    Spacer()
                    if progress.secondsToNextPrompt > 0 {
                        Text(formatCountdown(progress.secondsToNextPrompt))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(BlipColor.textTertiary)
                    }
                }
            }
        }
        .padding(16)
        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BlipColor.border, lineWidth: 0.5)
        )
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        let s = max(0, seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Sub-components

private struct LiveRing: View {
    let progress: BlipCardProgress

    var body: some View {
        if let completion = progress.hourCompletion {
            ZStack {
                Circle()
                    .stroke(BlipColor.progressTrack, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: completion)
                    .stroke(
                        completion >= 1 ? Color.green : BlipColor.progressFill,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.6), value: completion)
                Text("\(Int(completion * 100))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(BlipColor.textPrimary)
            }
            .frame(width: 34, height: 34)
        }
    }
}

// MARK: - Data

struct BlipCardProgress {
    /// nil = completion unknown (no clip data loaded); ring is hidden.
    var hourCompletion: Double?
    var members: [Member]
    var secondsToNextPrompt: Int

    struct Member: Identifiable {
        let id: String
        let initials: String
        let hasPostedThisHour: Bool
    }
}

// MARK: - Previews

#Preview("Empty hour") {
    BlipCard(
        title: "spring break crew",
        subtitle: "0 of 4 posted",
        memberCount: 4,
        progress: BlipCardProgress(
            hourCompletion: nil,
            members: [
                .init(id: "1", initials: "ED", hasPostedThisHour: false),
                .init(id: "2", initials: "LJ", hasPostedThisHour: false),
                .init(id: "3", initials: "AM", hasPostedThisHour: false),
                .init(id: "4", initials: "KR", hasPostedThisHour: false),
            ],
            secondsToNextPrompt: 23 * 60 + 47
        )
    )
    .padding()
    .background(Color.black)
}

#Preview("In progress") {
    BlipCard(
        title: "spring break crew",
        subtitle: "3 of 4 posted this hour",
        memberCount: 4,
        progress: BlipCardProgress(
            hourCompletion: 3.0 / 4.0,  // known value — ring shows
            members: [
                .init(id: "1", initials: "ED", hasPostedThisHour: true),
                .init(id: "2", initials: "LJ", hasPostedThisHour: true),
                .init(id: "3", initials: "AM", hasPostedThisHour: true),
                .init(id: "4", initials: "KR", hasPostedThisHour: false),
            ],
            secondsToNextPrompt: 12 * 60 + 5
        )
    )
    .padding()
    .background(Color.black)
}
