import FirebaseFirestore
import Foundation

@MainActor
final class ArchiveRepository: ObservableObject {
    @Published private(set) var days: [BlipDay] = []
    @Published private(set) var lastError: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    func startListening(blip: Blip, uid: String) {
        listener?.remove()
        let timezone = TimeZone(identifier: blip.timezoneIdentifier) ?? .current
        let currentDateKey = BlipHour.dateKey(
            for: Date(),
            in: timezone,
            startHour: blip.activeStartHour
        )
        listener = db.collection("blips").document(blip.id)
            .collection("days")
            .addSnapshotListener { [weak self] snap, err in
                Task { @MainActor in
                    guard let self else { return }
                    if let err {
                        self.lastError = err.localizedDescription
                        return
                    }
                    let docs = snap?.documents ?? []
                    self.days = docs.compactMap { Self.decode(doc: $0, uid: uid) }
                        // Most recent first, current day excluded so it doesn't duplicate today's export.
                        .filter { $0.id != currentDateKey }
                        .sorted { $0.id > $1.id }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        days = []
    }

    private static func decode(doc: QueryDocumentSnapshot, uid: String) -> BlipDay? {
        let data = doc.data()
        if let exports = data["exportsByUid"] as? [String: Any],
           let mine = exports[uid] as? [String: Any],
           let day = decodeExport(data: mine, dateKey: doc.documentID) {
            return day
        }
        return decodeExport(data: data, dateKey: doc.documentID)
    }

    private static func decodeExport(data: [String: Any], dateKey: String) -> BlipDay? {
        guard
            let statusRaw = data["stitchStatus"] as? String,
            let status = BlipDay.StitchStatus(rawValue: statusRaw)
        else { return nil }
        let url = (data["stitchedVideoUrl"] as? String).flatMap(URL.init(string:))
        let stitchedAt = (data["stitchedAt"] as? Timestamp)?.dateValue()
        let likeCount = data["likeCount"] as? Int ?? 0
        return BlipDay(
            id: dateKey,
            stitchStatus: status,
            stitchedVideoUrl: url,
            stitchedAt: stitchedAt,
            likeCount: likeCount
        )
    }
}
