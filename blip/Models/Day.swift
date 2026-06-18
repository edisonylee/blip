import Foundation

/// One day's worth of activity for a single blip. Documents live at blips/{blipId}/days/{yyyy-MM-dd}.
/// `dateKey` is anchored to the configured start hour in the blip's shared timezone.
struct BlipDay: Codable, Identifiable, Hashable {
    let id: String                  // "yyyy-MM-dd" key
    var dateKey: String { id }
    var stitchStatus: StitchStatus
    var stitchedVideoUrl: URL?
    var stitchedAt: Date?
    /// Total likes across all users. Denormalized counter written by the
    /// `onDayLike` Cloud Function. Client treats as read-only.
    var likeCount: Int = 0

    enum StitchStatus: String, Codable {
        case pending        // day not yet ended
        case queued         // end of the configured window queued a future daily stitch
        case running        // ffmpeg job in progress
        case ready          // stitched MP4 available
        case failed         // see Cloud Function logs
    }
}
