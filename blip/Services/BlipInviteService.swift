import FirebaseFirestore
import Foundation
import OSLog

private let log = Logger(subsystem: "app.blip.ios", category: "BlipInviteService")

/// Sends a pending blip invite to another user identified by their @handle.
///
/// Flow:
///   1. Resolve handle → uid via `usernames/{handle}`.
///   2. Guard: invitee not already a member, not self.
///   3. Write to `users/{inviteeUid}/blipInvites/{blipId}` with the blip's
///      join code so the invitee can call `joinBlip` on acceptance.
///
/// The invitee's profile page reads this subcollection to surface pending
/// invites. Acceptance calls the existing `joinBlip` Cloud Function with the
/// stored join code.
@MainActor
final class BlipInviteService: ObservableObject {

    // MARK: - Published state

    @Published private(set) var isSending = false
    @Published var errorMessage: String?
    /// Set to the resolved @handle on a successful send, nil otherwise.
    @Published private(set) var sentToHandle: String?

    // MARK: - Dependencies

    private let db = Firestore.firestore()

    // MARK: - Handle lookup

    /// Returns the normalised handle if it exists in the `usernames` collection.
    /// Throws `InviteError.handleNotFound` when there is no such user.
    func resolveHandle(_ raw: String) async throws -> (uid: String, handle: String) {
        let normalized = Handle.normalize(raw)
        guard Handle.isValid(normalized) else { throw InviteError.invalidHandle }
        let doc = try await db.collection("usernames").document(normalized).getDocument()
        guard doc.exists, let uid = doc.data()?["uid"] as? String else {
            throw InviteError.handleNotFound
        }
        return (uid, normalized)
    }

    // MARK: - Send invite

    /// Writes a pending invite document to the invitee's subcollection.
    /// Rejects self-invites, blip-full invites, and already-members.
    func sendInvite(
        handle: String,
        blip: Blip,
        inviterUid: String,
        inviterHandle: String?
    ) async throws {
        isSending = true
        errorMessage = nil
        sentToHandle = nil
        defer { isSending = false }

        let (inviteeUid, normalized) = try await resolveHandle(handle)
        guard inviteeUid != inviterUid else { throw InviteError.cannotInviteSelf }
        guard !blip.members.contains(inviteeUid) else { throw InviteError.alreadyMember }
        guard blip.members.count < blip.size else { throw InviteError.blipFull }

        let payload: [String: Any] = [
            "blipId":        blip.id,
            "blipName":      blip.name,
            "joinCode":      blip.joinCode,
            "inviterUid":    inviterUid,
            "inviterHandle": inviterHandle as Any,
            "createdAt":     FieldValue.serverTimestamp(),
            "status":        "pending",
        ]

        // One invite per blip per invitee — overwriting is idempotent.
        try await db.collection("users")
            .document(inviteeUid)
            .collection("blipInvites")
            .document(blip.id)
            .setData(payload)

        sentToHandle = normalized
        log.info("invite sent to=@\(normalized, privacy: .public) blip=\(blip.id, privacy: .public)")
    }
}

// MARK: - Errors

enum InviteError: LocalizedError {
    case invalidHandle
    case handleNotFound
    case alreadyMember
    case cannotInviteSelf
    case blipFull

    var errorDescription: String? {
        switch self {
        case .invalidHandle:    return "invalid handle — must be 3–15 lowercase letters."
        case .handleNotFound:   return "no user with that handle."
        case .alreadyMember:    return "that user is already in this blip."
        case .cannotInviteSelf: return "you can't invite yourself."
        case .blipFull:         return "this blip is full."
        }
    }
}
