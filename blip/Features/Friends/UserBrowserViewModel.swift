import FirebaseFirestore
import Foundation

/// Drives the paginated "browse all users" list in FriendsView.
///
/// Pagination:  10 users per page, ordered by handle, cursor-based via
///              DocumentSnapshot so pages never overlap or skip.
/// Search:      prefix match on `handle` field, 400 ms debounce, resets
///              cursor so pagination doesn't mix with search results.
/// Send request: thin wrapper around FriendMutating; tracks just-sent UIDs
///               locally so the button flips to "pending" immediately.
@MainActor
final class UserBrowserViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var users: [BlipUser] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = true
    @Published private(set) var errorMessage: String?
    /// UIDs the current session has sent a request to — gives instant feedback.
    @Published private(set) var justSentUids = Set<String>()

    // MARK: - Dependencies

    private let db = Firestore.firestore()
    private let friendsService: any FriendMutating
    private let pageSize = 10

    // MARK: - Cursor state

    private var lastDocument: DocumentSnapshot?
    private var isSearchMode = false
    private var searchTask: Task<Void, Never>?

    // MARK: - Init

    init(friendsService: any FriendMutating) {
        self.friendsService = friendsService
    }

    // MARK: - Browse (paginated)

    /// Fetch the first page — call once on appear.
    func loadFirstPage(excludeUid: String) async {
        guard !isLoading else { return }
        isSearchMode = false
        isLoading = true
        errorMessage = nil
        lastDocument = nil
        hasMore = true

        do {
            let snap = try await db.collection("users")
                .whereField("handle", isGreaterThan: "")   // only users with a handle
                .order(by: "handle")
                .limit(to: pageSize)
                .getDocuments()

            lastDocument = snap.documents.last
            hasMore = snap.documents.count == pageSize
            users = snap.documents
                .compactMap { BlipUser(uid: $0.documentID, firestoreData: $0.data()) }
                .filter { $0.id != excludeUid }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Load the next page — triggered when the last visible row appears.
    func loadNextPage(excludeUid: String) async {
        guard !isLoadingMore, hasMore, !isSearchMode else { return }
        guard let cursor = lastDocument else { return }

        isLoadingMore = true
        do {
            let snap = try await db.collection("users")
                .whereField("handle", isGreaterThan: "")
                .order(by: "handle")
                .start(afterDocument: cursor)
                .limit(to: pageSize)
                .getDocuments()

            lastDocument = snap.documents.last
            hasMore = snap.documents.count == pageSize
            let fresh = snap.documents
                .compactMap { BlipUser(uid: $0.documentID, firestoreData: $0.data()) }
                .filter { $0.id != excludeUid }
            users.append(contentsOf: fresh)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMore = false
    }

    // MARK: - Search (debounced prefix match)

    func search(prefix: String, excludeUid: String) {
        searchTask?.cancel()
        let q = prefix.lowercased().trimmingCharacters(in: .whitespaces)

        guard !q.isEmpty else {
            // Cleared — go back to browse mode
            isSearchMode = false
            Task { await loadFirstPage(excludeUid: excludeUid) }
            return
        }

        isSearchMode = true
        searchTask = Task {
            // 400 ms debounce
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }

            isLoading = true
            errorMessage = nil
            do {
                let snap = try await db.collection("users")
                    .whereField("handle", isGreaterThanOrEqualTo: q)
                    .whereField("handle", isLessThan: q + "\u{f8ff}")
                    .limit(to: 20)
                    .getDocuments()

                guard !Task.isCancelled else { return }
                users = snap.documents
                    .compactMap { BlipUser(uid: $0.documentID, firestoreData: $0.data()) }
                    .filter { $0.id != excludeUid }
                hasMore = false   // search results are one-shot, no pagination
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Send friend request

    func sendRequest(toUid: String) async {
        errorMessage = nil
        do {
            try await friendsService.sendRequest(toUid: toUid)
            justSentUids.insert(toUid)
        } catch FriendError.alreadyPending {
            justSentUids.insert(toUid)   // already sent — reflect in UI immediately
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
