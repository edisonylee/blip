import FirebaseAuth
import FirebaseFirestore
import Foundation
import OSLog

private let log = Logger(subsystem: "app.blip.ios", category: "FriendsService")

// MARK: - Errors

enum FriendError: LocalizedError {
    case notSignedIn
    case selfFriend
    case alreadyPending
    case requestNotFound
    case wrongRecipient
    case wrongSender
    case notPending

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "you need to be signed in."
        case .selfFriend:
            return "you can't friend yourself."
        case .alreadyPending:
            return "request already pending."
        case .requestNotFound:
            return "that request is gone."
        case .wrongRecipient:
            return "only the recipient can respond to this."
        case .wrongSender:
            return "you can only cancel your own requests."
        case .notPending:
            return "this request was already answered."
        }
    }
}

// MARK: - Service

/// One-shot writes for the friend graph: send / accept / reject / cancel
/// requests, and unfriend. No published state, no listeners — read-side
/// reactivity lives in `FriendsRepository`.
///
/// Acceptance and unfriend run in transactions because they touch multiple
/// docs (the request + both subcollection halves of the friendship). All
/// other mutations are single-doc writes.
@MainActor
final class FriendsService: ObservableObject, FriendMutating {

    // MARK: - Dependencies

    private let db: Firestore
    private let auth: Auth

    init(db: Firestore = .firestore(), auth: Auth = .auth()) {
        self.db = db
        self.auth = auth
    }

    // MARK: - sendRequest

    func sendRequest(toUid: String) async throws {
        guard let uid = auth.currentUser?.uid else { throw FriendError.notSignedIn }
        guard uid != toUid else { throw FriendError.selfFriend }

        let id = FriendRequest.makeId(fromUid: uid, toUid: toUid)
        let ref = db.collection(FriendsRepository.requestsCollection).document(id)

        log.info("sendRequest from=\(uid, privacy: .public) to=\(toUid, privacy: .public)")
        do {
            try await ref.setData([
                FriendsRepository.fromUidField: uid,
                FriendsRepository.toUidField: toUid,
                FriendsRepository.statusField: FriendRequestStatus.pending.rawValue,
                FriendsRepository.createdAtField: FieldValue.serverTimestamp(),
            ])
        } catch {
            // Permission-denied here means a doc with this id already exists in
            // a non-pending state — surface as alreadyPending.
            let nsErr = error as NSError
            let isPermissionDenied =
                nsErr.domain == FirestoreErrorDomain
                && nsErr.code == FirestoreErrorCode.permissionDenied.rawValue
            if isPermissionDenied {
                throw FriendError.alreadyPending
            }
            throw error
        }
    }

    // MARK: - acceptRequest

    func acceptRequest(_ request: FriendRequest) async throws {
        guard let uid = auth.currentUser?.uid else { throw FriendError.notSignedIn }
        guard uid == request.toUid else { throw FriendError.wrongRecipient }

        let requestRef = db.collection(FriendsRepository.requestsCollection)
            .document(request.id)
        let myFriendRef = db.collection(FriendsRepository.usersCollection)
            .document(uid)
            .collection(FriendsRepository.friendsSubcollection)
            .document(request.fromUid)
        let theirFriendRef = db.collection(FriendsRepository.usersCollection)
            .document(request.fromUid)
            .collection(FriendsRepository.friendsSubcollection)
            .document(uid)

        log.info("acceptRequest id=\(request.id, privacy: .public)")
        _ = try await db.runTransaction { txn, errPtr in
            let snap: DocumentSnapshot
            do {
                snap = try txn.getDocument(requestRef)
            } catch {
                errPtr?.pointee = error as NSError
                return nil
            }

            guard snap.exists else {
                errPtr?.pointee = NSError(
                    domain: FriendErrorDomain.name,
                    code: FriendErrorDomain.requestNotFound,
                    userInfo: [NSLocalizedDescriptionKey: "requestNotFound"]
                )
                return nil
            }
            let currentStatus = snap.data()?[FriendsRepository.statusField] as? String
            guard currentStatus == FriendRequestStatus.pending.rawValue else {
                errPtr?.pointee = NSError(
                    domain: FriendErrorDomain.name,
                    code: FriendErrorDomain.notPending,
                    userInfo: [NSLocalizedDescriptionKey: "notPending"]
                )
                return nil
            }

            txn.updateData([
                FriendsRepository.statusField: FriendRequestStatus.accepted.rawValue,
                FriendsRepository.respondedAtField: FieldValue.serverTimestamp(),
            ], forDocument: requestRef)

            txn.setData([
                FriendsRepository.uidField: request.fromUid,
                FriendsRepository.sinceField: FieldValue.serverTimestamp(),
            ], forDocument: myFriendRef)

            txn.setData([
                FriendsRepository.uidField: uid,
                FriendsRepository.sinceField: FieldValue.serverTimestamp(),
            ], forDocument: theirFriendRef)

            return nil
        }
    }

    // MARK: - rejectRequest

    func rejectRequest(_ request: FriendRequest) async throws {
        guard let uid = auth.currentUser?.uid else { throw FriendError.notSignedIn }
        guard uid == request.toUid else { throw FriendError.wrongRecipient }

        let ref = db.collection(FriendsRepository.requestsCollection).document(request.id)
        log.info("rejectRequest id=\(request.id, privacy: .public)")
        try await ref.updateData([
            FriendsRepository.statusField: FriendRequestStatus.rejected.rawValue,
            FriendsRepository.respondedAtField: FieldValue.serverTimestamp(),
        ])
    }

    // MARK: - cancelRequest

    func cancelRequest(toUid: String) async throws {
        guard let uid = auth.currentUser?.uid else { throw FriendError.notSignedIn }
        guard uid != toUid else { throw FriendError.selfFriend }

        let id = FriendRequest.makeId(fromUid: uid, toUid: toUid)
        let ref = db.collection(FriendsRepository.requestsCollection).document(id)
        log.info("cancelRequest id=\(id, privacy: .public)")
        try await ref.delete()
    }

    // MARK: - unfriend

    func unfriend(uid otherUid: String) async throws {
        guard let uid = auth.currentUser?.uid else { throw FriendError.notSignedIn }
        guard uid != otherUid else { throw FriendError.selfFriend }

        let myFriendRef = db.collection(FriendsRepository.usersCollection)
            .document(uid)
            .collection(FriendsRepository.friendsSubcollection)
            .document(otherUid)
        let theirFriendRef = db.collection(FriendsRepository.usersCollection)
            .document(otherUid)
            .collection(FriendsRepository.friendsSubcollection)
            .document(uid)

        log.info("unfriend me=\(uid, privacy: .public) other=\(otherUid, privacy: .public)")
        _ = try await db.runTransaction { txn, _ in
            txn.deleteDocument(myFriendRef)
            txn.deleteDocument(theirFriendRef)
            return nil
        }
    }
}

// MARK: - NSError bridging for transaction errors

private enum FriendErrorDomain {
    static let name = "Friend"
    static let requestNotFound = 1
    static let notPending = 2
}
