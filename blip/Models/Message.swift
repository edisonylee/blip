import Foundation

/// Group chat message — separate text thread alongside the visual log (parity with screen-11).
struct BlipMessage: Codable, Identifiable, Hashable {
    let id: String
    var uid: String
    var text: String?
    var clipId: String?              // optional reference to a posted clip (screen-11 shows clip embeds)
    var createdAt: Date
}
