import Foundation

struct BlipUser: Codable, Identifiable, Hashable {
    let id: String              // Firebase Auth uid
    var displayName: String
    var photoURL: URL?
    var phoneE164: String?
    var fcmTokens: [String]
    var createdAt: Date
    var updatedAt: Date
}
