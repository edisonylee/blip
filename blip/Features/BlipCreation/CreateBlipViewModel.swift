import Foundation

@MainActor
final class CreateBlipViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var size: Int = 4
    @Published var timezoneIdentifier: String = TimeZone.current.identifier
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var createdBlip: Blip?

    let sizeOptions = Array(2...10)

    /// Timezone choices for the picker. Top entry is always the device's
    /// current zone (per CLAUDE.md: defaults to creator's TZ); the rest cover
    /// the common US spread + a few global anchors so a Korean exchange student
    /// or someone abroad isn't stuck with the device default.
    var timezoneOptions: [String] {
        let device = TimeZone.current.identifier
        let curated = [
            "America/Los_Angeles",
            "America/Denver",
            "America/Chicago",
            "America/New_York",
            "America/Anchorage",
            "Pacific/Honolulu",
            "Europe/London",
            "Asia/Seoul",
            "Asia/Tokyo",
            "Australia/Sydney",
        ]
        var seen = Set<String>()
        return ([device] + curated).filter { seen.insert($0).inserted }
    }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func submit(uid: String, repo: any BlipMutating) {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                createdBlip = try await repo.createBlip(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    size: size,
                    ownerUid: uid,
                    timezoneIdentifier: timezoneIdentifier
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    /// Short label like "Los Angeles" or "Seoul" — last `/`-segment with
    /// underscores swapped for spaces.
    func timezoneShortName(_ identifier: String) -> String {
        let tail = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return tail.replacingOccurrences(of: "_", with: " ")
    }

    func sizeDescription(_ n: Int) -> String {
        switch n {
        case 2: return "just you two"
        case 3...4: return "small crew"
        case 5...7: return "squad"
        default: return "big group"
        }
    }
}
