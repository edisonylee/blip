import FirebaseFirestore
import Foundation

/// Reactive cache of `users/{uid}` profile docs keyed by uid. Used by views that
/// render multiple members and need real display names (avatars, member lists,
/// nudge prompts) instead of falling back to the uid prefix.
///
/// SRP: this repository's only job is loading + caching profile docs for a set
/// of uids. The single-user `UserRepository` keeps owning the *current* user's
/// profile and writes (FCM tokens, quiet hours) — the two are intentionally
/// separate so this stays read-only and listener-cheap.
@MainActor
final class UserProfilesRepository: ObservableObject {
    /// uid → decoded profile. Views read via `displayName(for:)` / `initials(for:)`
    /// rather than touching this directly so the fallbacks live in one place.
    @Published private(set) var profiles: [String: BlipUser] = [:]

    @Published private(set) var blockedUsers: Set<String> = []

    /// Push the current blocklist in. Owning view should call from
    /// `.onReceive(moderation.$blockedUsers)`.
    func setBlocklist(_ uids: Set<String>) {
        blockedUsers = uids
    }

    /// True if a uid is blocked by the current user. Public accessors short-circuit
    /// on this so blocked profiles render as unknown across every consuming view.
    func isBlocked(_ uid: String) -> Bool {
        blockedUsers.contains(uid)
    }

    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]

    /// Avatar fallback when the user doc hasn't loaded yet (or has no displayName).
    /// A neutral mid-dot keeps the seat visually balanced without leaking the uid.
    private static let unknownInitials = "·"

    /// Initials length cap — "Edison Lee" → "EL", "Madonna" → "M".
    private static let maxInitials = 2

    deinit {
        listeners.values.forEach { $0.remove() }
    }

    /// Idempotently subscribe to `users/{uid}` for every uid in `uids`. Already-tracked
    /// uids are skipped so re-calling on each `.task` (e.g. when blip.members updates)
    /// doesn't tear down + rebuild listeners.
    func observe(uids: [String]) {
        for uid in uids where listeners[uid] == nil {
            listeners[uid] = db.collection("users").document(uid)
                .addSnapshotListener { [weak self] snapshot, _ in
                    Task { @MainActor in
                        guard let self else { return }
                        guard let data = snapshot?.data() else { return }
                        if let user = BlipUser(uid: uid, firestoreData: data) {
                            self.profiles[uid] = user
                        }
                    }
                }
        }
    }

    func stopListening() {
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
        profiles.removeAll()
    }

    func displayName(for uid: String) -> String? {
        if isBlocked(uid) { return nil }
        guard let name = profiles[uid]?.displayName, !name.isEmpty else { return nil }
        return name
    }

    /// @handle for the uid, nil if not claimed.
    func handle(for uid: String) -> String? {
        if isBlocked(uid) { return nil }
        return profiles[uid]?.handle
    }

    /// Best short label for a chat participant: displayName → @handle → phone → "anon".
    func chatLabel(for uid: String) -> String {
        if isBlocked(uid) { return "blocked" }
        if let name = displayName(for: uid) { return name }
        if let h = handle(for: uid) { return "@\(h)" }
        if let phone = profiles[uid]?.phoneE164, !phone.isEmpty { return phone }
        return "anon"
    }

    /// First whitespace-separated token of displayName. Used for second-person prompts
    /// like "send a nudge to {firstName}?".
    func firstName(for uid: String) -> String? {
        guard let full = displayName(for: uid) else { return nil }
        return full.split(separator: " ").first.map(String.init)
    }

    /// Two-letter avatar initials derived from displayName. Falls back to a neutral
    /// dot when the profile hasn't loaded — never leaks a uid prefix into the UI.
    func initials(for uid: String) -> String {
        if isBlocked(uid) { return Self.unknownInitials }
        guard let name = displayName(for: uid) else { return Self.unknownInitials }
        let tokens = name.split(separator: " ").prefix(Self.maxInitials)
        let letters = tokens.compactMap { $0.first }.map { String($0) }.joined()
        let trimmed = letters.uppercased()
        return trimmed.isEmpty ? Self.unknownInitials : trimmed
    }

}
