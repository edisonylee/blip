import FirebaseFirestore
import Foundation
import OSLog

private let log = Logger(subsystem: "app.blip.ios", category: "ClipsRepository")

/// Per-blip listener for today's clips. Backs both the BlipDetail hour-slot grid
/// and the HomeView BlipCard live progress.
///
/// The "day" uses the blip's shared timezone and configured start hour.
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

    // Blip configuration used for date/hour calculations
    private var blipTimezone: TimeZone = .current
    private var activeStartHour: Int = 0

    /// Raw clips from Firestore before block + hidden filtering.
    /// Kept so we can re-derive `clips` when the blocklist changes without re-listening.
    private var rawClips: [Clip] = []
    private var blockedUsers: Set<String> = []

    deinit {
        listener?.remove()
    }

    /// Push the current blocklist in. Owning view should call from
    /// `.onReceive(moderation.$blockedUsers)`.
    func setBlocklist(_ uids: Set<String>) {
        blockedUsers = uids
        recomputeFiltered()
    }

    func startListening(blip: Blip) {
        listener?.remove()
        blipId = blip.id
        let tz = TimeZone(identifier: blip.timezoneIdentifier) ?? .current
        blipTimezone = tz
        activeStartHour = blip.activeStartHour
        let dateKey = BlipHour.dateKey(for: Date(), in: tz, startHour: activeStartHour)
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
                    self.rawClips = docs.compactMap { Self.decode(doc: $0) }
                    self.recomputeFiltered()
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        rawClips = []
        clips = []
        clipsByHour = [:]
        postersThisHour = []
        blipId = nil
        blipTimezone = .current
        activeStartHour = 0
    }

    private func recomputeFiltered() {
        let visible = rawClips.filter { !$0.hidden && !blockedUsers.contains($0.uid) }
        clips = visible.sorted { $0.createdAt > $1.createdAt }
        clipsByHour = Dictionary(grouping: visible, by: { $0.hour })
        let nowHour = Calendar.current.component(.hour, from: Date())
        postersThisHour = Set((clipsByHour[nowHour] ?? []).map { $0.uid })
    }

    // MARK: - Mutations (long-press menu, screen-10 parity)

    func deleteClip(_ clip: BlipClip) async throws {
        guard let blipId else { return }
        let dateKey = BlipHour.dateKey(for: clip.createdAt, in: blipTimezone, startHour: activeStartHour)
        try await db.collection("blips").document(blipId)
            .collection("days").document(dateKey)
            .collection("clips").document(clip.id)
            .delete()
    }

    func updateCaption(_ clip: BlipClip, caption: String) async throws {
        guard let blipId else { return }
        let dateKey = BlipHour.dateKey(for: clip.createdAt, in: blipTimezone, startHour: activeStartHour)
        try await db.collection("blips").document(blipId)
            .collection("days").document(dateKey)
            .collection("clips").document(clip.id)
            .updateData(["caption": caption])
    }

    // MARK: - Helpers

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

