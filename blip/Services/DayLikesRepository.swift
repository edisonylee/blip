import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Reactive state for "is this stitched day liked by me + how many likes total".
/// One instance per surface (one Archive row, one ExportView ready-state).
///
/// Uses two Firestore listeners:
///  - the parent `days/{dateKey}` doc, for the denormalized `likeCount`
///    (written by the `onDayLike` Cloud Function).
///  - the single `days/{dateKey}/likes/{me}` doc, for whether *I* liked it.
///
/// `toggle()` is idempotent: the doc id == liker's uid, so a second tap from
/// the same user creates / deletes the same doc. The Cloud Function clamps
/// counters at zero on delete; the UI optimistically flips local state and
/// the listener corrects on reconciliation.
@MainActor
final class DayLikesRepository: ObservableObject {
    @Published private(set) var liked: Bool = false
    @Published private(set) var count: Int = 0
    @Published private(set) var isWriting: Bool = false

    private let db = Firestore.firestore()
    private var dayListener: ListenerRegistration?
    private var meListener: ListenerRegistration?
    private var blipId: String?
    private var dateKey: String?

    deinit {
        dayListener?.remove()
        meListener?.remove()
    }

    func startListening(blipId: String, dateKey: String) {
        // No-op if already pointed at this day.
        if self.blipId == blipId, self.dateKey == dateKey { return }
        stopListening()
        self.blipId = blipId
        self.dateKey = dateKey

        let dayRef = db.collection("blips").document(blipId)
            .collection("days").document(dateKey)

        dayListener = dayRef.addSnapshotListener { [weak self] snap, _ in
            Task { @MainActor in
                guard let self else { return }
                self.count = (snap?.data()?["likeCount"] as? Int) ?? 0
            }
        }

        guard let me = Auth.auth().currentUser?.uid else {
            liked = false
            return
        }
        meListener = dayRef.collection("likes").document(me)
            .addSnapshotListener { [weak self] snap, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.liked = snap?.exists ?? false
                }
            }
    }

    func stopListening() {
        dayListener?.remove()
        meListener?.remove()
        dayListener = nil
        meListener = nil
        blipId = nil
        dateKey = nil
        liked = false
        count = 0
    }

    /// Optimistic toggle. Flips local state immediately; listener reconciles
    /// once the write lands. Re-entrant safe — the doc id is the liker's uid
    /// so concurrent taps from the same account map to the same doc.
    func toggle() async {
        guard let blipId, let dateKey else { return }
        guard let me = Auth.auth().currentUser?.uid else { return }
        let likeRef = db.collection("blips").document(blipId)
            .collection("days").document(dateKey)
            .collection("likes").document(me)

        // Optimistic flip — listener will correct if the write fails.
        let willLike = !liked
        liked = willLike
        isWriting = true
        defer { isWriting = false }

        do {
            if willLike {
                try await likeRef.setData([
                    "uid": me,
                    "createdAt": FieldValue.serverTimestamp(),
                ])
            } else {
                try await likeRef.delete()
            }
        } catch {
            // Roll the optimistic flip back. The listener would also correct,
            // but doing it here keeps the UI in sync without waiting for the
            // server round-trip.
            liked = !willLike
        }
    }
}
