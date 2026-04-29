import Foundation

/// Reactive contract for the friends graph.
/// Concrete: `FriendsRepository`. SwiftUI views observing the friends list
/// (Phase 3) depend on this so the UI layer never imports FirebaseFirestore.
@MainActor
protocol FriendsRepositoryProtocol: ObservableObject {
    var incomingRequests: [FriendRequest] { get }
    var outgoingRequests: [FriendRequest] { get }
    var friends: [String] { get }
    var lastError: String? { get }

    func startListening(for uid: String)
    func stopListening()
}
