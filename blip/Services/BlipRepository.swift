import FirebaseAuth
import FirebaseFirestore
import Foundation
import OSLog

private let log = Logger(subsystem: "app.blip.ios", category: "BlipRepository")

@MainActor
final class BlipRepository: ObservableObject {
    @Published private(set) var blips: [Blip] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    /// Subscribe to all blips the current user is a member of. Reactive via Firestore snapshot listener.
    func startListening(for uid: String) {
        listener?.remove()
        isLoading = true
        log.info("startListening uid=\(uid, privacy: .public)")

        listener = db.collection("blips")
            .whereField("members", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        log.error("listener error: \(error.localizedDescription, privacy: .public)")
                        self.lastError = error.localizedDescription
                        return
                    }
                    let docs = snapshot?.documents ?? []
                    log.info("snapshot fired — \(docs.count, privacy: .public) docs")
                    let decoded = docs.compactMap { Self.decode(doc: $0) }
                    if decoded.count != docs.count {
                        let keys = docs.map { $0.data().keys.sorted() }
                        log.error("decode failure — \(docs.count - decoded.count, privacy: .public) doc(s) dropped; keys=\(keys, privacy: .public)")
                    }
                    self.blips = decoded.sorted { $0.createdAt > $1.createdAt }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        blips = []
    }

    // MARK: - Mutations

    func createBlip(name: String, size: Int, ownerUid: String, timezoneIdentifier: String) async throws -> Blip {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BlipRepoError.emptyName }
        guard (2...12).contains(size) else { throw BlipRepoError.invalidSize }

        let joinCode = Self.generateJoinCode()
        let now = Date()
        let docRef = db.collection("blips").document()

        let payload: [String: Any] = [
            "name": trimmed,
            "ownerUid": ownerUid,
            "members": [ownerUid],
            "size": size,
            "joinCode": joinCode,
            "timezoneIdentifier": timezoneIdentifier,
            "createdAt": Timestamp(date: now),
        ]
        try await docRef.setData(payload)

        return Blip(
            id: docRef.documentID,
            name: trimmed,
            ownerUid: ownerUid,
            members: [ownerUid],
            size: size,
            joinCode: joinCode,
            inviteUrl: nil,
            timezoneIdentifier: timezoneIdentifier,
            createdAt: now
        )
    }

    /// Join via the legacy code (parity). Universal Link join lands when DeepLinkRouter ships.
    func joinBlip(code: String, uid: String) async throws -> Blip {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { throw BlipRepoError.emptyCode }

        let snapshot = try await db.collection("blips")
            .whereField("joinCode", isEqualTo: normalized)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first, var blip = Self.decode(doc: doc) else {
            throw BlipRepoError.codeNotFound
        }
        guard blip.members.count < blip.size else { throw BlipRepoError.blipFull }
        if blip.members.contains(uid) { return blip }

        try await db.collection("blips").document(blip.id).updateData([
            "members": FieldValue.arrayUnion([uid])
        ])
        blip.members.append(uid)
        return blip
    }

    // MARK: - Helpers

    private static func decode(doc: QueryDocumentSnapshot) -> Blip? {
        let data = doc.data()
        guard
            let name = data["name"] as? String,
            let ownerUid = data["ownerUid"] as? String,
            let members = data["members"] as? [String],
            let size = data["size"] as? Int,
            let joinCode = data["joinCode"] as? String,
            let tz = data["timezoneIdentifier"] as? String,
            let ts = data["createdAt"] as? Timestamp
        else { return nil }

        let inviteUrl = (data["inviteUrl"] as? String).flatMap(URL.init(string:))
        return Blip(
            id: doc.documentID,
            name: name,
            ownerUid: ownerUid,
            members: members,
            size: size,
            joinCode: joinCode,
            inviteUrl: inviteUrl,
            timezoneIdentifier: tz,
            createdAt: ts.dateValue()
        )
    }

    private static func generateJoinCode(length: Int = 7) -> String {
        // Lowercase alphanumerics, no ambiguous chars (0/o/1/l). Matches the Setlog "c9kz6il" feel.
        let charset = Array("23456789abcdefghijkmnpqrstuvwxyz")
        return String((0..<length).map { _ in charset.randomElement()! })
    }
}

enum BlipRepoError: LocalizedError {
    case emptyName
    case invalidSize
    case emptyCode
    case codeNotFound
    case blipFull

    var errorDescription: String? {
        switch self {
        case .emptyName: return "name your blip first."
        case .invalidSize: return "blip size must be 2 to 12."
        case .emptyCode: return "enter a code."
        case .codeNotFound: return "no blip with that code."
        case .blipFull: return "this blip is full."
        }
    }
}
