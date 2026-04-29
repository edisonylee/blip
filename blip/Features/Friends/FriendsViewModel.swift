import Foundation

// MARK: - Friend display

/// View-layer projection of a friend or request-sender. Carries only the
/// fields the row renders. Resolved from the lookup cache below.
struct FriendDisplay: Identifiable, Hashable {
    let id: String       // uid
    let handle: String?
}

// MARK: - ViewModel

/// Drives `FriendsView`. Two responsibilities:
/// 1. Convert raw uids from `FriendsRepository` (friend list + incoming
///    request senders) into `FriendDisplay` rows by looking up each uid's
///    handle in `/users/{uid}`.
/// 2. Mediate accept / reject calls to `FriendMutating`.
///
/// Handle resolution is fetch-on-demand and cached for the lifetime of
/// the VM. The cache is a `[String: BlipUser?]` — `nil` means "we tried,
/// the doc is missing, don't refetch." This avoids re-fetching every uid
/// on every `@Published` push from the parent repo.
@MainActor
final class FriendsViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var profileCache: [String: BlipUser?] = [:]
    @Published private(set) var lastError: String?

    // MARK: - Inputs

    let currentUid: String?

    // MARK: - Dependencies

    private let friendsService: any FriendMutating
    private let userDirectory: any UserDocFetching
    private var inFlight: Set<String> = []

    // MARK: - Init

    init(
        currentUid: String?,
        friendsService: any FriendMutating,
        userDirectory: any UserDocFetching
    ) {
        self.currentUid = currentUid
        self.friendsService = friendsService
        self.userDirectory = userDirectory
    }

    // MARK: - Lookup

    /// Returns the cached `FriendDisplay` for `uid` if available, otherwise
    /// kicks off a one-shot fetch and returns a placeholder. Repeat calls
    /// for the same `uid` are deduped via `inFlight`.
    func display(for uid: String) -> FriendDisplay {
        if let cached = profileCache[uid] {
            return FriendDisplay(id: uid, handle: cached?.handle)
        }
        Task { await fetchProfileIfNeeded(uid: uid) }
        return FriendDisplay(id: uid, handle: nil)
    }

    func ensureProfilesLoaded(uids: [String]) {
        for uid in uids {
            if profileCache[uid] == nil && !inFlight.contains(uid) {
                Task { await fetchProfileIfNeeded(uid: uid) }
            }
        }
    }

    private func fetchProfileIfNeeded(uid: String) async {
        if profileCache[uid] != nil { return }
        if inFlight.contains(uid) { return }
        inFlight.insert(uid)
        defer { inFlight.remove(uid) }

        do {
            let user = try await userDirectory.fetchUser(uid: uid)
            profileCache[uid] = .some(user)
        } catch {
            // Swallow — leave the cache empty so a later retry can succeed.
            // Errors here are best-effort UI hydration; they don't surface.
            #if DEBUG
            print("[friends-vm] profile fetch failed for \(uid): \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Actions

    func accept(_ request: FriendRequest) async {
        lastError = nil
        do {
            try await friendsService.acceptRequest(request)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func reject(_ request: FriendRequest) async {
        lastError = nil
        do {
            try await friendsService.rejectRequest(request)
        } catch {
            lastError = error.localizedDescription
        }
    }

}
