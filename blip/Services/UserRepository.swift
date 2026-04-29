import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class UserRepository: ObservableObject {
    @Published private(set) var profile: BlipUser?
    @Published private(set) var lastError: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(for uid: String) {
        listener?.remove()
        listener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.lastError = error.localizedDescription
                        return
                    }
                    guard let data = snapshot?.data() else {
                        self.profile = nil
                        return
                    }
                    self.profile = Self.decode(uid: uid, data: data)
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        profile = nil
    }

    func updateQuietHours(start: Int, end: Int) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await db.collection("users").document(uid).setData([
            "quietHoursStart": start,
            "quietHoursEnd": end,
            "timezoneIdentifier": TimeZone.current.identifier,
            "updatedAt": Timestamp(date: Date()),
        ], merge: true)
    }

    private static func decode(uid: String, data: [String: Any]) -> BlipUser? {
        let displayName = data["displayName"] as? String ?? ""
        let photoURL = (data["photoURL"] as? String).flatMap(URL.init(string:))
        let phone = data["phoneE164"] as? String
        let tokens = data["fcmTokens"] as? [String] ?? []
        let blocked = data["blockedUsers"] as? [String] ?? []
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
        let qhStart = data["quietHoursStart"] as? Int ?? 23
        let qhEnd = data["quietHoursEnd"] as? Int ?? 7
        let tz = data["timezoneIdentifier"] as? String ?? TimeZone.current.identifier
        return BlipUser(
            id: uid,
            displayName: displayName,
            photoURL: photoURL,
            phoneE164: phone,
            fcmTokens: tokens,
            createdAt: createdAt,
            updatedAt: updatedAt,
            blockedUsers: blocked,
            quietHoursStart: qhStart,
            quietHoursEnd: qhEnd,
            timezoneIdentifier: tz
        )
    }
}
