import FirebaseFirestore
import Foundation
import OSLog

/// Reactive view of the current user's friend graph.
///
/// **Why subcollection-scoped friendships (`/users/{uid}/friends/{friendUid}`)?**
/// 1. Listener queries are trivial — just listen on your own `/friends`
///    subcollection. No composite `array-contains` index on a top-level
///    collection, no fan-in query cost as the graph grows.
/// 2. Read scoping is a single rule check (`request.auth.uid == uid`). A
///    top-level `/friendships/{pairId}` collection would need every read to
///    pull the doc body and check membership — more expensive and harder
///    to audit.
/// 3. The Phase 2 `friendsCount` Cloud Function gets a clean trigger surface
///    — `onCreate`/`onDelete` on `users/{uid}/friends/{friendUid}` increments
///    or decrements `users/{uid}.friendsCount` directly, no extra lookup.
///
/// Friend *requests* live in a top-level `/friend_requests/{id}` collection
/// because the sender and recipient both need to read the same doc; a
/// subcollection would force one side to peek into the other's namespace.
private let log = Logger(subsystem: "app.blip.ios", category: "FriendsRepository")

@MainActor
final class FriendsRepository: ObservableObject, FriendsRepositoryProtocol {

    // MARK: - Published state

    @Published private(set) var incomingRequests: [FriendRequest] = []
    @Published private(set) var outgoingRequests: [FriendRequest] = []
    @Published private(set) var friends: [String] = []
    @Published private(set) var lastError: String?

    // MARK: - Dependencies

    private let db = Firestore.firestore()
    private var incomingListener: ListenerRegistration?
    private var outgoingListener: ListenerRegistration?
    private var friendsListener: ListenerRegistration?

    // MARK: - Lifecycle

    deinit {
        incomingListener?.remove()
        outgoingListener?.remove()
        friendsListener?.remove()
    }

    func startListening(for uid: String) {
        stopListening()
        log.info("startListening uid=\(uid, privacy: .public)")

        incomingListener = db.collection(Self.requestsCollection)
            .whereField(Self.toUidField, isEqualTo: uid)
            .whereField(Self.statusField, isEqualTo: FriendRequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.lastError = error.localizedDescription
                        log.error("incoming listener error: \(error.localizedDescription, privacy: .public)")
                        return
                    }
                    let docs = snapshot?.documents ?? []
                    self.incomingRequests = docs.compactMap { Self.decodeRequest(doc: $0) }
                }
            }

        outgoingListener = db.collection(Self.requestsCollection)
            .whereField(Self.fromUidField, isEqualTo: uid)
            .whereField(Self.statusField, isEqualTo: FriendRequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.lastError = error.localizedDescription
                        log.error("outgoing listener error: \(error.localizedDescription, privacy: .public)")
                        return
                    }
                    let docs = snapshot?.documents ?? []
                    self.outgoingRequests = docs.compactMap { Self.decodeRequest(doc: $0) }
                }
            }

        friendsListener = db.collection(Self.usersCollection).document(uid)
            .collection(Self.friendsSubcollection)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.lastError = error.localizedDescription
                        log.error("friends listener error: \(error.localizedDescription, privacy: .public)")
                        return
                    }
                    let docs = snapshot?.documents ?? []
                    self.friends = docs.compactMap { $0.data()[Self.uidField] as? String }
                }
            }
    }

    func stopListening() {
        incomingListener?.remove()
        outgoingListener?.remove()
        friendsListener?.remove()
        incomingListener = nil
        outgoingListener = nil
        friendsListener = nil
        incomingRequests = []
        outgoingRequests = []
        friends = []
    }

    // MARK: - Helpers

    static let requestsCollection = "friend_requests"
    static let usersCollection = "users"
    static let friendsSubcollection = "friends"

    static let fromUidField = "fromUid"
    static let toUidField = "toUid"
    static let statusField = "status"
    static let uidField = "uid"
    static let createdAtField = "createdAt"
    static let respondedAtField = "respondedAt"
    static let sinceField = "since"

    private static func decodeRequest(doc: QueryDocumentSnapshot) -> FriendRequest? {
        let data = doc.data()
        guard
            let fromUid = data[fromUidField] as? String,
            let toUid = data[toUidField] as? String,
            let statusRaw = data[statusField] as? String,
            let status = FriendRequestStatus(rawValue: statusRaw),
            let createdAt = (data[createdAtField] as? Timestamp)?.dateValue()
        else { return nil }
        let respondedAt = (data[respondedAtField] as? Timestamp)?.dateValue()
        return FriendRequest(
            id: doc.documentID,
            fromUid: fromUid,
            toUid: toUid,
            status: status,
            createdAt: createdAt,
            respondedAt: respondedAt
        )
    }
}
