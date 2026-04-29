import AVFoundation
import FirebaseFirestore
import FirebaseStorage
import Foundation
import OSLog

private let log = Logger(subsystem: "app.blip.ios", category: "ClipUploader")

/// Uploads a recorded clip to Firebase Storage and writes the corresponding
/// Firestore clip document. Cross-posts via the `sharedToBlipIds` array — the
/// same Storage object is referenced from each target blip's clips subcollection.
@MainActor
final class ClipUploader: ObservableObject, ClipUploading {
    @Published private(set) var isUploading = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var lastError: String?

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    /// - Parameters:
    ///   - fileURL: local path to the recorded `.mov`
    ///   - uid: author's Firebase Auth uid
    ///   - primaryBlipId: blip that "owns" the canonical Storage object
    ///   - sharedToBlipIds: every blip to write a clip doc into (must include `primaryBlipId`)
    ///   - caption: optional caption (long-press → edit caption, parity with screen-10)
    func upload(
        fileURL: URL,
        uid: String,
        primaryBlipId: String,
        sharedToBlipIds: [String],
        caption: String?
    ) async throws {
        precondition(sharedToBlipIds.contains(primaryBlipId), "sharedToBlipIds must include primaryBlipId")

        isUploading = true
        progress = 0
        lastError = nil
        defer { isUploading = false }

        let now = Date()
        let dateKey = Self.dateKey(for: now)
        let hour = Calendar.current.component(.hour, from: now)
        let storagePath = "blips/\(primaryBlipId)/days/\(dateKey)/\(uid)/\(hour).mov"
        let storageRef = storage.reference().child(storagePath)

        let metadata = StorageMetadata()
        metadata.contentType = "video/quicktime"

        // 1. Upload to Storage with progress reporting.
        let videoUrlString = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            let task = storageRef.putFile(from: fileURL, metadata: metadata) { meta, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                Task {
                    do {
                        let url = try await storageRef.downloadURL()
                        cont.resume(returning: url.absoluteString)
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
            task.observe(.progress) { [weak self] snap in
                guard let self, let p = snap.progress else { return }
                let fraction = p.totalUnitCount > 0 ? Double(p.completedUnitCount) / Double(p.totalUnitCount) : 0
                Task { @MainActor in self.progress = fraction }
            }
        }

        // 2. Probe the local file for duration so the rule's 1.8...2.5s check passes.
        let durationSeconds = await Self.probeDuration(fileURL: fileURL)

        // 3. Write a clip doc into each target blip's clips subcollection.
        // Deterministic clipId per (uid, hour) so reposting within the hour
        // replaces the prior doc instead of stacking duplicates in the grid.
        let batch = db.batch()
        let clipId = "\(uid)_\(hour)"
        for blipId in sharedToBlipIds {
            let ref = db.collection("blips").document(blipId)
                .collection("days").document(dateKey)
                .collection("clips").document(clipId)
            let payload: [String: Any] = [
                "uid": uid,
                "hour": hour,
                "videoUrl": videoUrlString,
                "caption": caption as Any,
                "createdAt": Timestamp(date: now),
                "sharedToBlipIds": sharedToBlipIds,
                "durationSeconds": durationSeconds,
                "reportCount": 0,
                "hidden": false,
            ]
            batch.setData(payload, forDocument: ref)
        }
        try await batch.commit()

        log.info("uploaded clip path=\(storagePath, privacy: .public) blips=\(sharedToBlipIds.count, privacy: .public)")
    }

    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    private static func probeDuration(fileURL: URL) async -> Double {
        let asset = AVURLAsset(url: fileURL)
        do {
            let duration = try await asset.load(.duration)
            return duration.seconds
        } catch {
            return CaptureSession.clipDuration  // fall back to nominal 2.0
        }
    }
}
