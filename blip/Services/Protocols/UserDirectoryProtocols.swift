import Foundation

// MARK: - UserDocFetching

/// Reads a single `/users/{uid}` doc, either as a one-shot or a live listener.
/// Used by ViewModels that render or react to a specific user's profile.
protocol UserDocFetching {
    /// One-shot fetch. Returns nil if the doc doesn't exist.
    func fetchUser(uid: String) async throws -> BlipUser?

    /// Live listener. Calls `onUpdate` with each snapshot's decoded user
    /// (or nil if the doc was removed) until the returned token is cancelled.
    func observeUser(uid: String, onUpdate: @MainActor @escaping (Result<BlipUser?, Error>) -> Void) -> UserDirectoryListener
}

// MARK: - UserSearching

/// Handle prefix search across the `/users` collection. Used by
/// `FriendSearchViewModel`.
protocol UserSearching {
    /// Returns up to `limit` users whose `handle` begins with `prefix`
    /// (Firestore range query). The prefix should already be normalized
    /// (lowercase, leading `@` stripped).
    func searchByHandle(prefix: String, limit: Int) async throws -> [BlipUser]
}

// MARK: - UserRanking

/// Live top-N query ordered by a stat field. Used by `LeaderboardViewModel`.
protocol UserRanking {
    func observeTopByTotalClips(limit: Int, onUpdate: @MainActor @escaping ([BlipUser]) -> Void) -> UserDirectoryListener
}

// MARK: - Listener handle

/// Type-erased handle for cancelling a user-directory subscription. Wraps
/// a Firestore `ListenerRegistration` in the concrete impl; tests can
/// substitute their own.
protocol UserDirectoryListener {
    func cancel()
}
