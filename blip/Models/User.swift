import Foundation

struct BlipUser: Codable, Identifiable, Hashable {
    let id: String              // Firebase Auth uid
    /// Snapchat-style username, lowercase. Nil until the user claims one.
    /// Uniqueness is enforced via the /usernames/{handle} lock collection.
    var handle: String?
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

    // Stats — written by Cloud Functions (clip-create trigger + friendship trigger).
    // The client treats them as read-only.
    var totalClips: Int = 0
    var streakCurrent: Int = 0
    var streakBest: Int = 0
    /// YYYY-MM-DD of the user's most recent clip in their local TZ.
    /// The streak trigger compares this to today to decide continue / break.
    var lastClipDay: String?
    var friendsCount: Int = 0

    /// Total likes across all stitched days the user owns. Written by the
    /// `onDayLike` Cloud Function (admin SDK; client treats as read-only).
    var likesCount: Int = 0

    // Optional profile fields editable by the user.
    /// Free-form school name — surfaced under the @handle on the profile screen.
    var school: String?

    // Referrals — written by the `onUserCreated` Cloud Function trigger.
    // Each new uid that signs up via this user's invite link increments the
    // referrer's count by 1 (idempotent: doc-create only fires once per uid).
    // The client treats `referralsCount` as read-only.
    var referralsCount: Int = 0
    /// Set once at first-sign-in if a `blip://invite?ref=UID` deep link landed
    /// before signup. Immutable after create — see firestore.rules.
    var referredByUid: String?
}

extension BlipUser {
    /// How many blipchats the user is allowed to create.
    /// 1 free slot, +1 unlocked for every 4 successful referrals.
    var unlockedBlipSlots: Int { 1 + referralsCount / 4 }

    /// Referrals still needed to unlock the next slot. Always 1...4 unless the
    /// user is already at a fresh multiple of 4 (then it's 4).
    var referralsToNextSlot: Int { 4 - (referralsCount % 4) }
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
