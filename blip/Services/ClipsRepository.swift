import FirebaseFirestore
import Foundation
import OSLog

private let log = Logger(subsystem: "app.blip.ios", category: "ClipsRepository")

/// Per-blip listener for today's clips. Backs both the BlipDetail hour-slot grid
/// and the HomeView BlipCard live progress.
///
/// The "day" is the blip's local 4AM-to-4AM window, so the dateKey we listen to
/// is computed in the blip's timezone (per CLAUDE.md day-boundary decision).
@MainActor
final class ClipsRepository: ObservableObject {
    @Published private(set) var clips: [Clip] = []
    @Published private(set) var lastError: String?

    /// Indexed by hour for fast lookup from views.
    @Published private(set) var clipsByHour: [Int: [Clip]] = [:]

    /// uids that have posted at least one clip in the current hour.
    @Published private(set) var postersThisHour: Set<String> = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private(set) var blipId: String?

    deinit {
        listener?.remove()
    }

    func startListening(blip: Blip) {
        listener?.remove()
        blipId = blip.id
        let tz = TimeZone(identifier: blip.timezoneIdentifier) ?? .current
        let dateKey = Self.dateKey(for: Date(), in: tz)
        log.info("startListening blip=\(blip.id, privacy: .public) date=\(dateKey, privacy: .public)")

        listener = db.collection("blips").document(blip.id)
            .collection("days").document(dateKey)
            .collection("clips")
            .addSnapshotListener { [weak self] snap, err in
                Task { @MainActor in
                    guard let self else { return }
                    if let err {
                        self.lastError = err.localizedDescription
                        log.error("listener error: \(err.localizedDescription, privacy: .public)")
                        return
                    }
                    let docs = snap?.documents ?? []
                    let decoded = docs.compactMap { Self.decode(doc: $0) }
                    self.clips = decoded.sorted { $0.createdAt > $1.createdAt }
                    self.clipsByHour = Dictionary(grouping: decoded, by: { $0.hour })
                    let nowHour = Calendar.current.component(.hour, from: Date())
                    self.postersThisHour = Set((self.clipsByHour[nowHour] ?? []).map { $0.uid })
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        clips = []
        clipsByHour = [:]
        postersThisHour = []
        blipId = nil
    }

    // MARK: - Helpers

    static func dateKey(for date: Date, in tz: TimeZone) -> String {
        // 4AM-to-4AM window: subtract 4 hours so a clip at 3AM still belongs to "yesterday's" key.
        let shifted = date.addingTimeInterval(-4 * 3600)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = tz
        return formatter.string(from: shifted)
    }

    private static func decode(doc: QueryDocumentSnapshot) -> Clip? {
        let data = doc.data()
        guard
            let uid = data["uid"] as? String,
            let hour = data["hour"] as? Int,
            let videoUrlString = data["videoUrl"] as? String,
            let videoUrl = URL(string: videoUrlString),
            let ts = data["createdAt"] as? Timestamp,
            let dur = data["durationSeconds"] as? Double
        else { return nil }
        let thumb = (data["thumbnailUrl"] as? String).flatMap(URL.init(string:))
        let caption = data["caption"] as? String
        let shared = data["sharedToBlipIds"] as? [String] ?? []
        let reportCount = data["reportCount"] as? Int ?? 0
        let hidden = data["hidden"] as? Bool ?? false
        return Clip(
            id: doc.documentID,
            uid: uid,
            hour: hour,
            videoUrl: videoUrl,
            thumbnailUrl: thumb,
            caption: caption,
            createdAt: ts.dateValue(),
            sharedToBlipIds: shared,
            durationSeconds: dur,
            reportCount: reportCount,
            hidden: hidden
        )
    }
}

// `Clip` is the existing model — alias to avoid import friction with `BlipClip`.
typealias Clip = BlipClip
