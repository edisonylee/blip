import Foundation

struct BlipClip: Codable, Identifiable, Hashable {
    let id: String
    var uid: String                  // author's Firebase Auth uid
    var hour: Int                    // 0...23 in the blip's timezone
    var videoUrl: URL
    var thumbnailUrl: URL?
    var caption: String?
    var createdAt: Date
    /// Cross-post fan-out targets — also includes this blip's id.
    /// Setlog's "send to:" picker (screen-08) writes the same clip into multiple blips.
    var sharedToBlipIds: [String]
    var durationSeconds: Double      // 2.0...4.0
    /// Moderation — incremented by `onReport` Cloud Function. `hidden` flips at threshold.
    var reportCount: Int = 0
    var hidden: Bool = false
}
