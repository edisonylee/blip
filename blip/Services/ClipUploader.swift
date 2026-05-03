import AVFoundation
import FirebaseFirestore
import FirebaseStorage
import Foundation
import OSLog
import UIKit

private let log = Logger(subsystem: "app.blip.ios", category: "ClipUploader")

/// Uploads a recorded clip to Firebase Storage and writes the corresponding
/// Firestore clip document. Cross-posts via the `sharedToBlipIds` array — the
/// same Storage object is referenced from each target blip's clips subcollection.
/// After a successful upload, posts a clip-type message to each blip's RTDB chat.
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
    ///   - caption: optional caption
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

        // 1. Upload video + generate thumbnail concurrently.
        async let videoUrlTask: String = uploadVideo(
            fileURL: fileURL, ref: storageRef, metadata: metadata
        )
        async let thumbnailTask: String? = generateAndUploadThumbnail(
            fileURL: fileURL,
            uid: uid,
            primaryBlipId: primaryBlipId,
            hour: hour
        )

        let (videoUrlString, thumbnailUrlString) = try await (videoUrlTask, thumbnailTask)

        // 2. Probe duration for the Firestore storage rules check (1.8–2.5 s).
        let durationSeconds = await Self.probeDuration(fileURL: fileURL)

        // 3. Write clip doc into each target blip's clips subcollection.
        // Deterministic clipId per (uid, hour) — repost within the hour replaces
        // the prior doc. On re-record, we preserve `hidden` and `reportCount`
        // so a re-record can't un-hide a previously flagged clip; the Firestore
        // rule (`/clips/{clipId}` update) enforces the same invariant server-side.
        let clipId = "\(uid)_\(hour)"
        let basePayload: [String: Any] = {
            var p: [String: Any] = [
                "uid": uid,
                "hour": hour,
                "videoUrl": videoUrlString,
                "caption": caption as Any,
                "createdAt": Timestamp(date: now),
                "sharedToBlipIds": sharedToBlipIds,
                "durationSeconds": durationSeconds,
            ]
            if let thumbnailUrlString { p["thumbnailUrl"] = thumbnailUrlString }
            return p
        }()

        for blipId in sharedToBlipIds {
            let ref = db.collection("blips").document(blipId)
                .collection("days").document(dateKey)
                .collection("clips").document(clipId)
            let existing = try? await ref.getDocument()
            if existing?.exists == true {
                // Re-record: skip moderation fields. The rule rejects any update
                // that mutates `hidden` or `reportCount` from a non-server actor.
                try await ref.updateData(basePayload)
            } else {
                var fresh = basePayload
                fresh["hidden"] = false
                fresh["reportCount"] = 0
                try await ref.setData(fresh)
            }
        }

        // 4. Post a clip card message to each blip's group chat.
        let blipNames = await fetchBlipNames(ids: sharedToBlipIds)
        let senderName = await fetchSenderName(uid: uid)
        for blipId in sharedToBlipIds {
            MessagesRepository.postClipMessage(
                blipId: blipId,
                blipName: blipNames[blipId],
                senderName: senderName,
                uid: uid,
                thumbnailUrl: thumbnailUrlString,
                videoUrl: videoUrlString,
                caption: caption,
                clipId: clipId
            )
        }

        log.info("uploaded clip path=\(storagePath, privacy: .public) blips=\(sharedToBlipIds.count, privacy: .public)")
    }

    private func fetchBlipNames(ids: [String]) async -> [String: String] {
        var names: [String: String] = [:]
        for id in ids {
            do {
                let snap = try await db.collection("blips").document(id).getDocument()
                if let name = snap.data()?["name"] as? String {
                    names[id] = name
                }
            } catch {
                log.error("failed to fetch blip name id=\(id, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            }
        }
        return names
    }

    private func fetchSenderName(uid: String) async -> String {
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            let data = snap.data() ?? [:]
            if let displayName = data["displayName"] as? String, !displayName.isEmpty {
                return displayName
            }
            if let handle = data["handle"] as? String, !handle.isEmpty {
                return "@\(handle)"
            }
            if let phone = data["phoneE164"] as? String, !phone.isEmpty {
                return phone
            }
        } catch {
            log.error("failed to fetch sender name uid=\(uid, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        }
        return "anon"
    }

    // MARK: - Video upload helper

    private func uploadVideo(
        fileURL: URL,
        ref: StorageReference,
        metadata: StorageMetadata
    ) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            let task = ref.putFile(from: fileURL, metadata: metadata) { _, error in
                if let error { cont.resume(throwing: error); return }
                Task {
                    do {
                        let url = try await ref.downloadURL()
                        cont.resume(returning: url.absoluteString)
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
            task.observe(.progress) { [weak self] snap in
                guard let self, let p = snap.progress else { return }
                let fraction = p.totalUnitCount > 0
                    ? Double(p.completedUnitCount) / Double(p.totalUnitCount)
                    : 0
                Task { @MainActor in self.progress = fraction }
            }
        }
    }

    // MARK: - Thumbnail

    private func generateAndUploadThumbnail(
        fileURL: URL,
        uid: String,
        primaryBlipId: String,
        hour: Int
    ) async -> String? {
        guard let image = await Self.generateThumbnail(fileURL: fileURL),
              let jpegData = image.jpegData(compressionQuality: 0.75)
        else { return nil }

        let thumbRef = storage.reference()
            .child("blips/\(primaryBlipId)/thumbnails/\(uid)/\(hour).jpg")
        let thumbMeta = StorageMetadata()
        thumbMeta.contentType = "image/jpeg"

        return await withCheckedContinuation { cont in
            thumbRef.putData(jpegData, metadata: thumbMeta) { _, err in
                guard err == nil else { cont.resume(returning: nil); return }
                Task {
                    let url = try? await thumbRef.downloadURL()
                    cont.resume(returning: url?.absoluteString)
                }
            }
        }
    }

    private static func generateThumbnail(fileURL: URL) async -> UIImage? {
        let asset = AVURLAsset(url: fileURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: time)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    // MARK: - Shared helpers

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
            return CaptureSession.clipDuration
        }
    }
}
