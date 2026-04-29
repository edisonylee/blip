import Foundation

// MARK: - Friendship state

/// Friendship status between the current user (`me`) and the target profile.
/// `requestReceived` carries the underlying `FriendRequest` so the view can
/// hand it back to the service when the user taps accept / ignore.
enum FriendshipState: Equatable {
    case self_
    case none
    case requestSent
    case requestReceived(FriendRequest)
    case friends
}

// MARK: - ViewModel

/// Drives `UserProfileView`. Owns:
/// - a Firestore listener on `/users/{targetUid}` so the displayed profile
///   stays live (handle change, stat updates from Cloud Functions).
/// - a derived `FriendshipState` computed from a `FriendsRepositoryProtocol`
///   that the parent already maintains for the signed-in user.
///
/// Mutations (`sendRequest`, `acceptRequest`, `unfriend`, `cancelRequest`)
/// delegate to a `FriendMutating` injected via init — the VM never touches
/// Auth or instantiates a service itself.
@MainActor
final class UserProfileViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var profile: BlipUser?
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var notFound: Bool = false
    @Published private(set) var lastError: String?

    /// Snapshots of the friend graph used to derive `FriendshipState`. The
    /// view passes these in by observing the parent `FriendsRepository`.
    @Published var incomingRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []
    @Published var friendUids: [String] = []

    // MARK: - Inputs

    let targetUid: String
    let currentUid: String?

    // MARK: - Dependencies

    private let friendsService: any FriendMutating
    private let userDirectory: any UserDocFetching
    private var profileListener: UserDirectoryListener?

    // MARK: - Init

    init(
        targetUid: String,
        currentUid: String?,
        friendsService: any FriendMutating,
        friends: any FriendsRepositoryProtocol,
        userDirectory: any UserDocFetching
    ) {
        self.targetUid = targetUid
        self.currentUid = currentUid
        self.friendsService = friendsService
        self.userDirectory = userDirectory

        // Seed from the live snapshot. The view re-pushes on observed change.
        self.incomingRequests = friends.incomingRequests
        self.outgoingRequests = friends.outgoingRequests
        self.friendUids = friends.friends
    }

    deinit {
        profileListener?.cancel()
    }

    // MARK: - Lifecycle

    func startListening() {
        profileListener?.cancel()
        isLoading = true
        notFound = false
        profileListener = userDirectory.observeUser(uid: targetUid) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            switch result {
            case .failure(let error):
                self.lastError = error.localizedDescription
            case .success(let user):
                self.profile = user
                self.notFound = user == nil
            }
        }
    }

    func stopListening() {
        profileListener?.cancel()
        profileListener = nil
    }

    // MARK: - Derived state

    var friendshipState: FriendshipState {
        guard let me = currentUid else { return .none }
        if me == targetUid { return .self_ }
        if friendUids.contains(targetUid) { return .friends }
        if let received = incomingRequests.first(where: { $0.fromUid == targetUid && $0.status == .pending }) {
            return .requestReceived(received)
        }
        if outgoingRequests.contains(where: { $0.toUid == targetUid && $0.status == .pending }) {
            return .requestSent
        }
        return .none
    }

    var daysSinceJoinedText: String? {
        guard let profile else { return nil }
        let days = max(0, Calendar.current.dateComponents([.day], from: profile.createdAt, to: Date()).day ?? 0)
        if days == 0 { return "joined today" }
        if days == 1 { return "joined 1 day ago" }
        return "joined \(days) days ago"
    }

    var handleDisplay: String {
        if let h = profile?.handle, !h.isEmpty { return "@\(h)" }
        return "—"
    }

    // MARK: - Actions

    func sendRequest() async {
        lastError = nil
        do {
            try await friendsService.sendRequest(toUid: targetUid)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func acceptRequest(_ request: FriendRequest) async {
        lastError = nil
        do {
            try await friendsService.acceptRequest(request)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func ignoreRequest(_ request: FriendRequest) async {
        lastError = nil
        do {
            try await friendsService.rejectRequest(request)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func cancelRequest() async {
        lastError = nil
        do {
            try await friendsService.cancelRequest(toUid: targetUid)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func unfriend() async {
        lastError = nil
        do {
            try await friendsService.unfriend(uid: targetUid)
        } catch {
            lastError = error.localizedDescription
        }
    }

}
