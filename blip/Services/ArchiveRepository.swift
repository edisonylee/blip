import FirebaseFirestore
import Foundation

@MainActor
final class ArchiveRepository: ObservableObject {
    @Published private(set) var days: [BlipDay] = []
    @Published private(set) var lastError: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    func startListening(blipId: String) {
        listener?.remove()
        listener = db.collection("blips").document(blipId)
            .collection("days")
            .whereField("stitchStatus", isEqualTo: "ready")
            .addSnapshotListener { [weak self] snap, err in
                Task { @MainActor in
                    guard let self else { return }
                    if let err {
                        self.lastError = err.localizedDescription
                        return
                    }
                    let docs = snap?.documents ?? []
                    self.days = docs.compactMap { Self.decode(doc: $0) }
                        // Most recent first, current day excluded so it doesn't duplicate today's export.
                        .filter { $0.id != Self.todayKey() }
                        .sorted { $0.id > $1.id }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        days = []
    }

    private static func todayKey() -> String {
        let shifted = Date().addingTimeInterval(-4 * 3600)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: shifted)
    }

    private static func decode(doc: QueryDocumentSnapshot) -> BlipDay? {
        let data = doc.data()
        guard
            let statusRaw = data["stitchStatus"] as? String,
            let status = BlipDay.StitchStatus(rawValue: statusRaw)
        else { return nil }
        let url = (data["stitchedVideoUrl"] as? String).flatMap(URL.init(string:))
        let stitchedAt = (data["stitchedAt"] as? Timestamp)?.dateValue()
        return BlipDay(
            id: doc.documentID,
            stitchStatus: status,
            stitchedVideoUrl: url,
            stitchedAt: stitchedAt
        )
    }
}
