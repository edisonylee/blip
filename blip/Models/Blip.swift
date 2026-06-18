import Foundation

/// A "blip" — a shared room of up to 12 friends.
/// The timezone and daily active window belong to the group, not each member.
struct Blip: Identifiable, Hashable {
    let id: String
    var name: String
    var ownerUid: String
    var adminUids: [String]             // owner + anyone the owner promotes; owner is always implicitly admin
    var members: [String]               // Firebase Auth uids
    var size: Int                       // 2...12
    var joinCode: String                // legacy code (e.g. "c9kz6il"), still supported per parity
    var inviteUrl: URL?                 // Universal Link, primary mechanic in v0
    var timezoneIdentifier: String      // e.g. "America/New_York" — shared by every member
    var activeStartHour: Int            // local group hour, inclusive
    var activeEndHour: Int              // local group hour, exclusive; equal to start means 24h
    var createdAt: Date

    func isAdmin(_ uid: String) -> Bool {
        uid == ownerUid || adminUids.contains(uid)
    }
}

extension Blip: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, ownerUid, adminUids, members, size, joinCode, inviteUrl
        case timezoneIdentifier, activeStartHour, activeEndHour, createdAt
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
        activeStartHour = (try? c.decode(Int.self, forKey: .activeStartHour)) ?? 4
        activeEndHour = (try? c.decode(Int.self, forKey: .activeEndHour)) ?? 4
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
}

extension Blip {
    var isSolo: Bool { size == 1 }

    func isActive(at date: Date = Date()) -> Bool {
        BlipHour.isActive(
            at: date,
            timezoneIdentifier: timezoneIdentifier,
            startHour: activeStartHour,
            endHour: activeEndHour
        )
    }
}
