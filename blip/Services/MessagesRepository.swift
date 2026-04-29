import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class MessagesRepository: ObservableObject {
    @Published private(set) var messages: [BlipMessage] = []
    @Published private(set) var lastError: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private(set) var blipId: String?

    deinit { listener?.remove() }

    func startListening(blipId: String) {
        listener?.remove()
        self.blipId = blipId

        listener = db.collection("blips").document(blipId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snap, err in
                Task { @MainActor in
                    guard let self else { return }
                    if let err {
                        self.lastError = err.localizedDescription
                        return
                    }
                    self.messages = (snap?.documents ?? []).compactMap { Self.decode(doc: $0) }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        messages = []
        blipId = nil
    }

    func send(text: String) async throws {
        guard let blipId,
              let uid = Auth.auth().currentUser?.uid else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try await db.collection("blips").document(blipId)
            .collection("messages").addDocument(data: [
                "uid": uid,
                "text": trimmed,
                "createdAt": Timestamp(date: Date()),
            ])
    }

    private static func decode(doc: QueryDocumentSnapshot) -> BlipMessage? {
        let data = doc.data()
        guard
            let uid = data["uid"] as? String,
            let ts = data["createdAt"] as? Timestamp
        else { return nil }
        return BlipMessage(
            id: doc.documentID,
            uid: uid,
            text: data["text"] as? String,
            clipId: data["clipId"] as? String,
            createdAt: ts.dateValue()
        )
    }
}
