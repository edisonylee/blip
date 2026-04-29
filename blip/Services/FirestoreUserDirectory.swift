import FirebaseFirestore
import Foundation

/// Single-purpose Firestore-backed user-directory service: ad-hoc reads and
/// listeners against `/users` for the screens that need them
/// (`UserProfileView`, `FriendsView`, `FriendSearchView`, `LeaderboardView`).
///
/// Conforms to three thin protocols (`UserDocFetching`, `UserSearching`,
/// `UserRanking`) so the consuming ViewModels never depend on the concrete
/// type and can be mocked in tests by injecting any conforming stand-in.
@MainActor
final class FirestoreUserDirectory: ObservableObject, UserDocFetching, UserSearching, UserRanking {

    // MARK: - Dependencies

    private let db: Firestore

    init(db: Firestore = .firestore()) {
        self.db = db
    }

    // MARK: - Constants

    private static let usersCollection = "users"
    /// Unicode private-use sentinel — Firestore range queries pair `prefix`
    /// with `prefix + "\u{f8ff}"` to capture every key that starts with prefix.
    private static let prefixCeiling = "\u{f8ff}"

    // MARK: - UserDocFetching

    func fetchUser(uid: String) async throws -> BlipUser? {
        let snap = try await db.collection(Self.usersCollection).document(uid).getDocument()
        guard let data = snap.data() else { return nil }
        return BlipUser(uid: uid, firestoreData: data)
    }

    func observeUser(
        uid: String,
        onUpdate: @MainActor @escaping (Result<BlipUser?, Error>) -> Void
    ) -> UserDirectoryListener {
        let registration = db.collection(Self.usersCollection).document(uid)
            .addSnapshotListener { snapshot, error in
                Task { @MainActor in
                    if let error {
                        onUpdate(.failure(error))
                        return
                    }
                    guard let data = snapshot?.data() else {
                        onUpdate(.success(nil))
                        return
                    }
                    onUpdate(.success(BlipUser(uid: uid, firestoreData: data)))
                }
            }
        return FirestoreListenerToken(registration: registration)
    }

    // MARK: - UserSearching

    func searchByHandle(prefix: String, limit: Int) async throws -> [BlipUser] {
        let snap = try await db.collection(Self.usersCollection)
            .whereField("handle", isGreaterThanOrEqualTo: prefix)
            .whereField("handle", isLessThan: prefix + Self.prefixCeiling)
            .limit(to: limit)
            .getDocuments()
        return snap.documents.compactMap { BlipUser(uid: $0.documentID, firestoreData: $0.data()) }
    }

    // MARK: - UserRanking

    func observeTopByTotalClips(
        limit: Int,
        onUpdate: @MainActor @escaping ([BlipUser]) -> Void
    ) -> UserDirectoryListener {
        let registration = db.collection(Self.usersCollection)
            .order(by: "totalClips", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, _ in
                Task { @MainActor in
                    let users = snapshot?.documents.compactMap {
                        BlipUser(uid: $0.documentID, firestoreData: $0.data())
                    } ?? []
                    onUpdate(users)
                }
            }
        return FirestoreListenerToken(registration: registration)
    }
}

// MARK: - Listener token

private struct FirestoreListenerToken: UserDirectoryListener {
    let registration: ListenerRegistration
    func cancel() { registration.remove() }
}
