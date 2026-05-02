import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation
import OSLog

private let log = Logger(subsystem: "app.blip.ios", category: "BlipRepository")

@MainActor
final class BlipRepository: ObservableObject, BlipRepositoryProtocol, BlipMutating {
    @Published private(set) var blips: [Blip] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    /// Subscribe to all blips the current user is a member of. Reactive via Firestore snapshot listener.
    func startListening(for uid: String) {
        listener?.remove()
        isLoading = true
        log.info("startListening uid=\(uid, privacy: .public)")

        listener = db.collection("blips")
            .whereField("members", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        log.error("listener error: \(error.localizedDescription, privacy: .public)")
                        self.lastError = error.localizedDescription
                        return
                    }
                    let docs = snapshot?.documents ?? []
                    log.info("snapshot fired — \(docs.count, privacy: .public) docs")
                    let decoded = docs.compactMap { Self.decode(doc: $0) }
                    if decoded.count != docs.count {
                        let keys = docs.map { $0.data().keys.sorted() }
                        log.error("decode failure — \(docs.count - decoded.count, privacy: .public) doc(s) dropped; keys=\(keys, privacy: .public)")
                    }
                    self.blips = decoded.sorted { $0.createdAt > $1.createdAt }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        blips = []
    }

    // MARK: - Mutations

    func createBlip(name: String, size: Int, ownerUid: String, timezoneIdentifier: String) async throws -> Blip {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BlipRepoError.emptyName }
        guard (2...12).contains(size) else { throw BlipRepoError.invalidSize }

        let joinCode = Self.generateJoinCode()
        let now = Date()
        let docRef = db.collection("blips").document()

        let payload: [String: Any] = [
            "name": trimmed,
            "ownerUid": ownerUid,
            "adminUids": [ownerUid],
            "members": [ownerUid],
            "size": size,
            "joinCode": joinCode,
            "timezoneIdentifier": timezoneIdentifier,
            "createdAt": Timestamp(date: now),
        ]
        try await docRef.setData(payload)

        return Blip(
            id: docRef.documentID,
            name: trimmed,
            ownerUid: ownerUid,
            adminUids: [ownerUid],
            members: [ownerUid],
            size: size,
            joinCode: joinCode,
            inviteUrl: nil,
            timezoneIdentifier: timezoneIdentifier,
            createdAt: now
        )
    }

    /// Owner-only reorder of `members`. The array order is the seat order used by the
    /// stitched export and `MemberGrid`, so writing it back makes the new order visible
    /// everywhere the next snapshot tick lands.
    /// Length is preserved — the `isLeavingSelf` rule branch can't apply, so this only
    /// passes the firestore.rules owner branch.
    func updateMemberOrder(blipId: String, members: [String]) async throws {
        guard !blipId.isEmpty else { throw BlipRepoError.emptyBlipId }
        guard !members.isEmpty else { throw BlipRepoError.emptyMembers }

        log.info("updateMemberOrder blipId=\(blipId, privacy: .public) count=\(members.count, privacy: .public)")
        try await db.collection("blips").document(blipId).updateData([
            "members": members
        ])
    }

    /// Join via legacy code (parity). Calls the `joinBlip` Cloud Function so the
    /// joinCode lookup and members-write happen under admin SDK — Firestore read
    /// rules keep blip docs members-only, so a non-member can't query joinCodes
    /// directly. After the function returns, we fetch the blip doc by id (we're
    /// now a member, so the read rule passes).
    func joinBlip(code: String, uid: String) async throws -> Blip {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { throw BlipRepoError.emptyCode }

        let functions = Functions.functions(region: "us-central1")
        let result: HTTPSCallableResult
        do {
            result = try await functions
                .httpsCallable("joinBlip")
                .call(["code": normalized])
        } catch {
            throw Self.mapJoinError(error)
        }

        guard
            let payload = result.data as? [String: Any],
            let blipId = payload["blipId"] as? String
        else {
            throw BlipRepoError.codeNotFound
        }

        let docSnap = try await db.collection("blips").document(blipId).getDocument()
        guard
            let queryDoc = docSnap as DocumentSnapshot?,
            let blip = Self.decodeJoinedBlip(snapshot: queryDoc)
        else {
            throw BlipRepoError.codeNotFound
        }
        return blip
    }

    /// Map `Functions` error codes to the existing `BlipRepoError` cases so the
    /// UI's error-text path stays unified.
    private static func mapJoinError(_ error: Error) -> BlipRepoError {
        let nsErr = error as NSError
        let code = FunctionsErrorCode(rawValue: nsErr.code)
        switch code {
        case .notFound: return .codeNotFound
        case .failedPrecondition: return .blipFull
        case .invalidArgument: return .emptyCode
        default: return .codeNotFound
        }
    }

    /// `decode(doc:)` requires a `QueryDocumentSnapshot`; this variant accepts a
    /// general `DocumentSnapshot` (what `.getDocument()` returns) and adapts.
    private static func decodeJoinedBlip(snapshot: DocumentSnapshot) -> Blip? {
        guard let data = snapshot.data() else { return nil }
        guard
            let name = data["name"] as? String,
            let ownerUid = data["ownerUid"] as? String,
            let members = data["members"] as? [String],
            let size = data["size"] as? Int,
            let joinCode = data["joinCode"] as? String,
            let tz = data["timezoneIdentifier"] as? String,
            let ts = data["createdAt"] as? Timestamp
        else { return nil }
        let inviteUrl = (data["inviteUrl"] as? String).flatMap(URL.init(string:))
        let adminUids = (data["adminUids"] as? [String]) ?? [ownerUid]
        return Blip(
            id: snapshot.documentID,
            name: name,
            ownerUid: ownerUid,
            adminUids: adminUids,
            members: members,
            size: size,
            joinCode: joinCode,
            inviteUrl: inviteUrl,
            timezoneIdentifier: tz,
            createdAt: ts.dateValue()
        )
    }

    /// Owner-only: grant or revoke admin role for a member.
    func setAdmin(blipId: String, uid: String, grant: Bool) async throws {
        guard !blipId.isEmpty else { throw BlipRepoError.emptyBlipId }
        let update = grant
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid])
        try await db.collection("blips").document(blipId).updateData([
            "adminUids": update
        ])
    }

    /// Any member can leave a blip. Two cascades:
    ///  - **Last member leaving:** the entire blip + its data is torn down via the
    ///    `deleteBlip` Cloud Function. This is the only path where a non-owner is
    ///    allowed to call delete (the function recognises the "last member" case).
    ///  - **Owner leaving with others present:** disallowed. The owner must either
    ///    promote a successor first (existing admin flow) and re-call leave, or
    ///    delete the blip outright.
    func leaveBlip(blipId: String, uid: String) async throws {
        guard !blipId.isEmpty else { throw BlipRepoError.emptyBlipId }
        let ref = db.collection("blips").document(blipId)
        let snap = try await ref.getDocument()
        guard let data = snap.data() else { throw BlipRepoError.blipNotFound }
        let ownerUid = data["ownerUid"] as? String
        let members = (data["members"] as? [String]) ?? []
        guard members.contains(uid) else { return }

        // Last member out — call the server-side delete to clean up clips,
        // messages, nudges, and storage in one shot.
        if members.count == 1 {
            try await deleteBlip(blipId: blipId)
            return
        }

        // Owner can't simply leave when others remain — force them to delete
        // the blip or transfer admin first.
        if ownerUid == uid {
            throw BlipRepoError.ownerCannotLeave
        }

        try await ref.updateData([
            "members": FieldValue.arrayRemove([uid]),
            "adminUids": FieldValue.arrayRemove([uid]),
        ])
    }

    /// Owner-only delete (server-enforced). Tears down the blip doc, clips,
    /// nudges, RTDB chat, and storage. The Cloud Function also accepts calls
    /// from the *only remaining member* so the last-leaver cascade works.
    func deleteBlip(blipId: String) async throws {
        guard !blipId.isEmpty else { throw BlipRepoError.emptyBlipId }
        let functions = Functions.functions(region: "us-central1")
        _ = try await functions
            .httpsCallable("deleteBlip")
            .call(["blipId": blipId])
    }

    // MARK: - Helpers

    private static func decode(doc: QueryDocumentSnapshot) -> Blip? {
        let data = doc.data()
        guard
            let name = data["name"] as? String,
            let ownerUid = data["ownerUid"] as? String,
            let members = data["members"] as? [String],
            let size = data["size"] as? Int,
            let joinCode = data["joinCode"] as? String,
            let tz = data["timezoneIdentifier"] as? String,
            let ts = data["createdAt"] as? Timestamp
        else { return nil }

        let inviteUrl = (data["inviteUrl"] as? String).flatMap(URL.init(string:))
        let adminUids = (data["adminUids"] as? [String]) ?? [ownerUid]
        return Blip(
            id: doc.documentID,
            name: name,
            ownerUid: ownerUid,
            adminUids: adminUids,
            members: members,
            size: size,
            joinCode: joinCode,
            inviteUrl: inviteUrl,
            timezoneIdentifier: tz,
            createdAt: ts.dateValue()
        )
    }

    private static func generateJoinCode(length: Int = 7) -> String {
        // Lowercase alphanumerics, no ambiguous chars (0/o/1/l). Matches the Setlog "c9kz6il" feel.
        let charset = Array("23456789abcdefghijkmnpqrstuvwxyz")
        return String((0..<length).map { _ in charset.randomElement()! })
    }
}

enum BlipRepoError: LocalizedError {
    case emptyName
    case invalidSize
    case emptyCode
    case codeNotFound
    case blipFull
    case emptyBlipId
    case emptyMembers
    case blipNotFound
    case ownerCannotLeave

    var errorDescription: String? {
        switch self {
        case .emptyName: return "name your blip first."
        case .invalidSize: return "blip size must be 2 to 12."
        case .emptyCode: return "enter a code."
        case .codeNotFound: return "no blip with that code."
        case .blipFull: return "this blip is full."
        case .emptyBlipId: return "missing blip id."
        case .emptyMembers: return "members list can't be empty."
        case .blipNotFound: return "blip no longer exists."
        case .ownerCannotLeave: return "you own this blip — delete it or hand it off first."
        }
    }
}
