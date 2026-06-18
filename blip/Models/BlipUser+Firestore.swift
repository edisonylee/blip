import FirebaseFirestore
import Foundation

extension BlipUser {
    /// Single source of truth for `BlipUser` decoding from a Firestore data
    /// dictionary. Every Firestore listener / one-shot read of a `/users/{uid}`
    /// doc must funnel through this initializer so that field additions or
    /// renames are a one-place fix.
    init?(uid: String, firestoreData data: [String: Any]) {
        let handle = data["handle"] as? String
        let displayName = data["displayName"] as? String ?? ""
        let photoURL = (data["photoURL"] as? String).flatMap(URL.init(string:))
        let phone = data["phoneE164"] as? String
        let tokens = data["fcmTokens"] as? [String] ?? []
        let blocked = data["blockedUsers"] as? [String] ?? []
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
        let qhStart = data["quietHoursStart"] as? Int ?? 23
        let qhEnd = data["quietHoursEnd"] as? Int ?? 7
        let tz = data["timezoneIdentifier"] as? String ?? TimeZone.current.identifier
        let totalClips = data["totalClips"] as? Int ?? 0
        let streakCurrent = data["streakCurrent"] as? Int ?? 0
        let streakBest = data["streakBest"] as? Int ?? 0
        let lastClipDay = data["lastClipDay"] as? String
        let friendsCount = data["friendsCount"] as? Int ?? 0
        let likesCount = data["likesCount"] as? Int ?? 0
        let school = data["school"] as? String
        let referralsCount = data["referralsCount"] as? Int ?? 0
        let referredByUid = data["referredByUid"] as? String

        self.init(
            id: uid,
            handle: handle,
            displayName: displayName,
            photoURL: photoURL,
            phoneE164: phone,
            fcmTokens: tokens,
            createdAt: createdAt,
            updatedAt: updatedAt,
            blockedUsers: blocked,
            quietHoursStart: qhStart,
            quietHoursEnd: qhEnd,
            timezoneIdentifier: tz,
            totalClips: totalClips,
            streakCurrent: streakCurrent,
            streakBest: streakBest,
            lastClipDay: lastClipDay,
            friendsCount: friendsCount,
            likesCount: likesCount,
            school: school,
            referralsCount: referralsCount,
            referredByUid: referredByUid
        )
    }
}
