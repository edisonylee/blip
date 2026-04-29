import Foundation

@MainActor
final class CreateBlipViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var size: Int = 4
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var createdBlip: Blip?

    let sizeOptions = Array(2...12)

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
                    timezoneIdentifier: TimeZone.current.identifier
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
        case 8...10: return "big group"
        default: return "whole crew"
        }
    }
}
