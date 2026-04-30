import Foundation

/// A "blip" — a shared room of up to 12 friends.
/// Day boundary is 4AM in the blip's timezone (not per-user).
struct Blip: Identifiable, Hashable {
    let id: String
    var name: String
    var ownerUid: String
    var adminUids: [String]             // owner + anyone the owner promotes; owner is always implicitly admin
    var members: [String]               // Firebase Auth uids
    var size: Int                       // 2...10 (cap from grid layout spec)
    var joinCode: String                // legacy code (e.g. "c9kz6il"), still supported per parity
    var inviteUrl: URL?                 // Universal Link, primary mechanic in v0
    var timezoneIdentifier: String      // e.g. "America/New_York" — controls 4AM stitch boundary
    var createdAt: Date

    func isAdmin(_ uid: String) -> Bool {
        uid == ownerUid || adminUids.contains(uid)
    }
}

extension Blip: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, ownerUid, adminUids, members, size, joinCode, inviteUrl, timezoneIdentifier, createdAt
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        ownerUid = try c.decode(String.self, forKey: .ownerUid)
        adminUids = (try? c.decode([String].self, forKey: .adminUids)) ?? []
        members = try c.decode([String].self, forKey: .members)
        size = try c.decode(Int.self, forKey: .size)
        joinCode = try c.decode(String.self, forKey: .joinCode)
        inviteUrl = try? c.decode(URL.self, forKey: .inviteUrl)
        timezoneIdentifier = try c.decode(String.self, forKey: .timezoneIdentifier)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
}

extension Blip {
    var isSolo: Bool { size == 1 }
}
