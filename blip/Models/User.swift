import Foundation

struct BlipUser: Codable, Identifiable, Hashable {
    let id: String              // Firebase Auth uid
    var displayName: String
    var photoURL: URL?
    var phoneE164: String?
    var fcmTokens: [String]
    var createdAt: Date
    var updatedAt: Date
    /// uids this user has blocked. Feed/clip queries client-filter against this set.
    var blockedUsers: [String] = []
    /// Quiet hours in the user's local TZ. The hourly push cron skips sends when
    /// the user's local hour is in [start, end). Default 23–7 (11pm to 7am).
    /// Wraps midnight when start > end.
    var quietHoursStart: Int = 23
    var quietHoursEnd: Int = 7
    var timezoneIdentifier: String = TimeZone.current.identifier
}

extension BlipUser {
    /// True if `hour` (0-23, in user's local TZ) is inside the quiet window.
    func isQuietHour(_ hour: Int) -> Bool {
        if quietHoursStart == quietHoursEnd { return false }
        if quietHoursStart < quietHoursEnd {
            return hour >= quietHoursStart && hour < quietHoursEnd
        }
        // wraps midnight (e.g. 23–7)
        return hour >= quietHoursStart || hour < quietHoursEnd
    }
}
