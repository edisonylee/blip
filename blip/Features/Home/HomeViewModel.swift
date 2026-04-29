import Foundation

/// Business logic for HomeView. The view owns an instance as @StateObject
/// and reads from it instead of computing inline.
@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Derived display helpers

    func subtitle(for blip: Blip) -> String {
        "\(blip.members.count) of \(blip.size) members"
    }

    func progress(for blip: Blip) -> BlipCardProgress {
        BlipCardProgress(
            hourCompletion: nil,
            members: blip.members.map { uid in
                BlipCardProgress.Member(
                    id: uid,
                    initials: String(uid.prefix(2)).uppercased(),
                    hasPostedThisHour: false
                )
            },
            secondsToNextPrompt: secondsUntilNextHour()
        )
    }

    func currentUid(from state: AuthState) -> String {
        if case .signedIn(let uid) = state { return uid }
        return "—"
    }

    // MARK: - Helpers

    private func secondsUntilNextHour() -> Int {
        let now = Date()
        guard let next = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return 0 }
        return Int(next.timeIntervalSince(now))
    }
}
