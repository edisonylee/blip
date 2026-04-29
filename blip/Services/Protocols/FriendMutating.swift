import Foundation

/// Write-side contract for friend-graph mutations.
/// Does NOT inherit `ObservableObject` so it can be used as `any FriendMutating`
/// in ViewModels without boxing an associated-type publisher. Read-side /
/// reactive access stays in `FriendsRepositoryProtocol`.
@MainActor
protocol FriendMutating {
    /// Sends a pending request from the current user to `toUid`. Throws if
    /// `toUid` is the caller, or if Firestore rejects (e.g. duplicate id).
    func sendRequest(toUid: String) async throws

    /// Accepts a pending request. Atomically flips the request to `accepted`
    /// and writes both halves of the friendship subcollection.
    func acceptRequest(_ request: FriendRequest) async throws

    /// Rejects a pending request — sets status to `rejected` and stamps
    /// `respondedAt`. The doc stays so the sender can't spam re-sends.
    func rejectRequest(_ request: FriendRequest) async throws

    /// Cancels an outgoing pending request from the current user to `toUid`.
    /// Deletes the doc; only valid while status is still `pending`.
    func cancelRequest(toUid: String) async throws

    /// Removes the friendship in both directions. Atomic.
    func unfriend(uid otherUid: String) async throws
}
