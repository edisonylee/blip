import Foundation

@MainActor
final class CreateBlipViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var size: Int = 4
    @Published var activeStartHour: Int = 4
    @Published var activeEndHour: Int = 4
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var createdBlip: Blip?

    let sizeOptions = Array(2...12)
    let hourOptions = Array(0...23)
    let timezoneIdentifier = TimeZone.current.identifier

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
                    timezoneIdentifier: timezoneIdentifier,
                    activeStartHour: activeStartHour,
                    activeEndHour: activeEndHour
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    func sizeDescription(_ n: Int) -> String {
        switch n {
        case 2: return "just you two"
        case 3...4: return "small crew"
        case 5...7: return "squad"
        default: return "big group"
        }
    }

    var scheduleDescription: String {
        if activeStartHour == activeEndHour { return "24 hours" }
        let count = (activeEndHour - activeStartHour + 24) % 24
        return "\(count) hour\(count == 1 ? "" : "s") daily"
    }
}
