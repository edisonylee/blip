import Foundation

/// A "log" — Setlog's term for a shared room of up to 12 friends.
/// Day boundary is 4AM in the log's timezone (not per-user).
struct BlipLog: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var ownerUid: String
    var members: [String]               // Firebase Auth uids
    var size: Int                       // 2...12
    var joinCode: String                // legacy code (e.g. "c9kz6il"), still supported per parity
    var inviteUrl: URL?                 // Universal Link, primary mechanic in v0
    var timezoneIdentifier: String      // e.g. "America/New_York" — controls 4AM stitch boundary
    var createdAt: Date
}

extension BlipLog {
    /// True for the special solo "vlog" space that's auto-created per user (parity with screen-01).
    var isSolo: Bool { size == 1 }
}
