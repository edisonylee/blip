import Foundation
import SwiftUI

/// Business logic for HomeView. The view owns an instance as @StateObject
/// and reads from it instead of computing inline.
@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Card data

    func cardColor(for blip: Blip) -> Color {
        let index = abs(blip.id.hashValue) % BlipColor.cardPalette.count
        return BlipColor.cardPalette[index]
    }

    func cardMembers(for blip: Blip) -> [BlipCardMember] {
        blip.members.map { uid in
            BlipCardMember(id: uid, initials: String(uid.prefix(2)).uppercased())
        }
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
