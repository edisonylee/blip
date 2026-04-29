import Foundation

// MARK: - Result row

/// Lightweight projection of a `BlipUser` doc for the search results list.
/// Carries only the fields the row renders, so the VM doesn't have to keep
/// full BlipUser instances in memory for results that won't be tapped.
struct FriendSearchResult: Identifiable, Hashable {
    let id: String          // uid
    let handle: String
}

// MARK: - ViewModel

/// Debounced handle-prefix search against `/users`. Lowercases the input,
/// strips a leading `@`, runs a Firestore range query, filters out the
/// current user, and surfaces up to 20 results.
///
/// Firestore is hit ad-hoc (one-shot `getDocuments`) — listener-based
/// reactivity isn't useful here because the query changes on every
/// keystroke. The 250ms debounce keeps cost roughly proportional to
/// pause-typing rate rather than character count.
@MainActor
final class FriendSearchViewModel: ObservableObject {

    // MARK: - Published state

    @Published var query: String = "" {
        didSet { scheduleSearch() }
    }
    @Published private(set) var results: [FriendSearchResult] = []
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var lastError: String?

    // MARK: - Inputs

    private let currentUid: String?

    // MARK: - Dependencies

    private let userDirectory: any UserSearching
    private var debounceTask: Task<Void, Never>?

    // MARK: - Constants

    private static let debounceMillis: UInt64 = 250
    private static let resultLimit: Int = 20

    // MARK: - Init

    init(currentUid: String?, userDirectory: any UserSearching) {
        self.currentUid = currentUid
        self.userDirectory = userDirectory
    }

    // MARK: - Search

    private func scheduleSearch() {
        debounceTask?.cancel()
        let prefix = Self.normalize(query)
        guard !prefix.isEmpty else {
            results = []
            isSearching = false
            return
        }
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceMillis * 1_000_000)
            if Task.isCancelled { return }
            await self?.runQuery(prefix: prefix)
        }
    }

    private func runQuery(prefix: String) async {
        isSearching = true
        lastError = nil
        defer { isSearching = false }

        do {
            let users = try await userDirectory.searchByHandle(prefix: prefix, limit: Self.resultLimit)
            let mapped: [FriendSearchResult] = users.compactMap { user in
                guard let handle = user.handle, !handle.isEmpty else { return nil }
                if let me = self.currentUid, user.id == me { return nil }
                return FriendSearchResult(id: user.id, handle: handle)
            }
            self.results = mapped
        } catch {
            self.lastError = error.localizedDescription
            self.results = []
        }
    }

    // MARK: - Helpers

    static func normalize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.hasPrefix("@") { s.removeFirst() }
        return s
    }
}
