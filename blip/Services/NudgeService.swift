import FirebaseFirestore
import Foundation
import OSLog

private let log = Logger(subsystem: "app.blip.ios", category: "NudgeService")

/// Writes a `blips/{blipId}/nudges/{nudgeId}` doc that fans out a push via the
/// `onNudgeCreated` Cloud Function.
///
/// Throttle is encoded in the doc id: `{dateKey}_{hour}_{senderUid}_{nudgeeUid}`
/// in the blipchat's local TZ. A second nudge from the same sender to the same
/// recipient in the same blip-hour collides with the existing doc; the create
/// rule denies the resulting update so the recipient gets at most one push per
/// (sender, blip-hour) pair. The client treats permission-denied here as a
/// silent success — the user already nudged.
final class NudgeService: NudgeServicing, ObservableObject {
    private let db: Firestore

    init(db: Firestore = .firestore()) {
        self.db = db
    }

    func sendNudge(
        blipId: String,
        blipTimezone: String,
        senderUid: String,
        nudgeeUid: String
    ) async throws {
        let hour = BlipHour.currentHour(in: blipTimezone)
        let dateKey = BlipHour.currentDateKey(in: blipTimezone)
        let nudgeId = "\(dateKey)_\(hour)_\(senderUid)_\(nudgeeUid)"

        do {
            try await db.collection("blips").document(blipId)
                .collection("nudges").document(nudgeId)
                .setData([
                    "senderUid": senderUid,
                    "nudgeeUid": nudgeeUid,
                    "createdAt": FieldValue.serverTimestamp(),
                ])
            log.info("nudge sent blip=\(blipId, privacy: .public) hour=\(hour)")
        } catch {
            // Already-nudged-this-hour: rules deny the update path → swallow.
            // Any other Firestore error is real and should bubble up.
            let nsErr = error as NSError
            let isPermissionDenied =
                nsErr.domain == FirestoreErrorDomain
                && nsErr.code == FirestoreErrorCode.permissionDenied.rawValue
            if isPermissionDenied {
                log.info("nudge already sent for this hour blip=\(blipId, privacy: .public) hour=\(hour)")
                return
            }
            throw error
        }
    }
}
