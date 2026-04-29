import Foundation

struct BlipClip: Codable, Identifiable, Hashable {
    let id: String
    var uid: String                  // author's Firebase Auth uid
    var hour: Int                    // 0...23 in the log's timezone
    var videoUrl: URL
    var thumbnailUrl: URL?
    var caption: String?
    var createdAt: Date
    /// Cross-post fan-out targets — also includes this log's id.
    /// Setlog's "send to:" picker (screen-08) writes the same clip into multiple logs.
    var sharedToLogIds: [String]
    var durationSeconds: Double      // 2.0...4.0
}
