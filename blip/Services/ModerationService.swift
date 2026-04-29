import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Report + Block — required by App Store for any UGC-bearing app.
@MainActor
final class ModerationService: ObservableObject {
    /// uids the current user has blocked. Subscribe in views to filter feeds reactively.
    @Published private(set) var blockedUsers: Set<String> = []

    private let db = Firestore.firestore()
    private var blockedListener: ListenerRegistration?

    deinit {
        blockedListener?.remove()
    }

    // MARK: - Subscription

    func startListening(for uid: String) {
        blockedListener?.remove()
        blockedListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snap, _ in
                Task { @MainActor in
                    let arr = (snap?.data()?["blockedUsers"] as? [String]) ?? []
                    self?.blockedUsers = Set(arr)
                }
            }
    }

    func stopListening() {
        blockedListener?.remove()
        blockedListener = nil
        blockedUsers = []
    }

    // MARK: - Report

    enum ReportCategory: String, CaseIterable, Identifiable {
        case spam, harassment, nudity, violence, other
        var id: String { rawValue }
        var label: String {
            switch self {
            case .spam: return "spam"
            case .harassment: return "harassment / bullying"
            case .nudity: return "nudity / sexual content"
            case .violence: return "violence / dangerous"
            case .other: return "something else"
            }
        }
    }

    /// Files a report against a clip. Picked up by the `onReport` Cloud Function.
    func report(clipPath: String, clipId: String, authorId: String, category: ReportCategory) async throws {
        guard let reporterId = Auth.auth().currentUser?.uid else {
            throw ModerationError.notSignedIn
        }
        try await db.collection("reports").addDocument(data: [
            "clipPath": clipPath,
            "clipId": clipId,
            "authorId": authorId,
            "reporterId": reporterId,
            "category": category.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
        ])
    }

    // MARK: - Block

    func block(uid blockedUid: String) async throws {
        guard let me = Auth.auth().currentUser?.uid else {
            throw ModerationError.notSignedIn
        }
        guard blockedUid != me else { return }
        try await db.collection("users").document(me).setData([
            "blockedUsers": FieldValue.arrayUnion([blockedUid]),
            "updatedAt": FieldValue.serverTimestamp(),
        ], merge: true)
    }

    func unblock(uid blockedUid: String) async throws {
        guard let me = Auth.auth().currentUser?.uid else {
            throw ModerationError.notSignedIn
        }
        try await db.collection("users").document(me).setData([
            "blockedUsers": FieldValue.arrayRemove([blockedUid]),
            "updatedAt": FieldValue.serverTimestamp(),
        ], merge: true)
    }

    func isBlocked(_ uid: String) -> Bool {
        blockedUsers.contains(uid)
    }
}

enum ModerationError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You're not signed in."
        }
    }
}
