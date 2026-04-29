import Foundation

@MainActor
final class JoinBlipViewModel: ObservableObject {
    @Published var code: String = ""
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var didJoin = false

    // Join codes are exactly 7 lowercase alphanumeric characters.
    var canSubmit: Bool {
        code.trimmingCharacters(in: .whitespacesAndNewlines).count == 7
    }

    func submit(uid: String, repo: any BlipMutating) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 7 else {
            errorMessage = "codes are 7 characters — double-check and try again."
            return
        }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                _ = try await repo.joinBlip(code: trimmed, uid: uid)
                didJoin = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
