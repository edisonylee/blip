import Foundation

// MARK: - Entry

/// One row of the leaderboard. Carries the minimal fields rendered: rank,
/// uid (for navigation), the optional handle (`nil` => "—"), and the
/// total clips count that drives the ordering.
struct LeaderboardEntry: Identifiable, Hashable {
    let id: String          // uid
    let rank: Int
    let handle: String?
    let totalClips: Int
}

// MARK: - ViewModel

/// Live top-N leaderboard ordered by `totalClips`. Listener-based so the
/// rank board updates as Cloud Functions write new clip totals.
///
/// Users without a handle are kept in the result set — the row renders
/// them with "—" rather than gating on handle existence.
@MainActor
final class LeaderboardViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var entries: [LeaderboardEntry] = []
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var lastError: String?

    // MARK: - Dependencies

    private let userDirectory: any UserRanking
    private var listener: UserDirectoryListener?

    /// Raw rows from the directory before block filtering. Kept so we can
    /// re-derive `entries` when the blocklist changes without re-listening.
    private var rawUsers: [BlipUser] = []
    private var blockedUsers: Set<String> = []

    /// Push the current blocklist in. View should call from
    /// `.onReceive(moderation.$blockedUsers)`.
    func setBlocklist(_ uids: Set<String>) {
        blockedUsers = uids
        recomputeEntries()
    }

    private func recomputeEntries() {
        let visible = rawUsers.filter { !blockedUsers.contains($0.id) }
        entries = visible.enumerated().map { idx, user in
            LeaderboardEntry(
                id: user.id,
                rank: idx + 1,
                handle: user.handle,
                totalClips: user.totalClips
            )
        }
    }

    // MARK: - Constants

    private static let resultLimit: Int = 50

    // MARK: - Init

    init(userDirectory: any UserRanking) {
        self.userDirectory = userDirectory
    }

    deinit {
        listener?.cancel()
    }

    // MARK: - Lifecycle

    func startListening() {
        listener?.cancel()
        isLoading = true
        listener = userDirectory.observeTopByTotalClips(limit: Self.resultLimit) { [weak self] users in
            guard let self else { return }
            self.isLoading = false
            self.rawUsers = users
            self.recomputeEntries()
        }
    }

    func stopListening() {
        listener?.cancel()
        listener = nil
    }
}
