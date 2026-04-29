import Foundation

/// A pending or resolved friend request between two users.
///
/// The `id` is deterministic — `{fromUid}_{toUid}` — so a re-send from the same
/// sender to the same recipient collides with the existing doc and the create
/// rule denies the resulting update path. That collision is the dedupe (same
/// pattern as `/blips/{id}/nudges/{nudgeId}`).
///
/// Lifecycle: `pending` → (`accepted` | `rejected`). A rejected request stays
/// in place so the sender can't spam re-sends; the recipient owns the flip.
struct FriendRequest: Codable, Identifiable, Hashable {
    let id: String
    let fromUid: String
    let toUid: String
    var status: FriendRequestStatus
    var createdAt: Date
    var respondedAt: Date?
}

enum FriendRequestStatus: String, Codable {
    case pending
    case accepted
    case rejected
}

extension FriendRequest {
    /// Builds the deterministic doc id used in `/friend_requests/{id}`.
    static func makeId(fromUid: String, toUid: String) -> String {
        "\(fromUid)_\(toUid)"
    }
}
