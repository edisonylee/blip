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
    ///   - primaryBlip: blip that owns the canonical Storage object
    ///   - destinations: every blip receiving the clip, with its group schedule
    ///   - caption: optional caption
    func upload(
        fileURL: URL,
        uid: String,
        primaryBlip: Blip,
        destinations: [Blip],
        caption: String?
    ) async throws {
        precondition(destinations.contains(where: { $0.id == primaryBlip.id }), "destinations must include primaryBlip")

        isUploading = true
        progress = 0
        lastError = nil
        defer { isUploading = false }

        let capturedAt = Self.creationDate(for: fileURL) ?? Date()
        guard destinations.allSatisfy({ $0.isActive(at: capturedAt) }) else {
            throw ClipUploadError.outsideActiveWindow
        }
        let primarySlot = Self.slot(for: primaryBlip, at: capturedAt)
        let storagePath = "blips/\(primaryBlip.id)/days/\(primarySlot.dateKey)/\(uid)/\(primarySlot.hour).mov"
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
            primaryBlipId: primaryBlip.id,
            hour: primarySlot.hour
        )

        let (videoUrlString, thumbnailUrlString) = try await (videoUrlTask, thumbnailTask)

        // 2. Probe duration for the Firestore storage rules check (1.8–2.5 s).
        let durationSeconds = await Self.probeDuration(fileURL: fileURL)

        // 3. Write clip doc into each target blip's clips subcollection.
        let sharedToBlipIds = destinations.map(\.id)
        var clipIdByBlipId: [String: String] = [:]

        for destination in destinations {
            let slot = Self.slot(for: destination, at: capturedAt)
            let clipId = "\(uid)_\(slot.hour)"
            clipIdByBlipId[destination.id] = clipId

            let ref = db.collection("blips").document(destination.id)
                .collection("days").document(slot.dateKey)
                .collection("clips").document(clipId)

            var payload: [String: Any] = [
                "uid": uid,
                "hour": slot.hour,
                "videoUrl": videoUrlString,
                "caption": caption as Any,
                "createdAt": Timestamp(date: capturedAt),
                "sharedToBlipIds": sharedToBlipIds,
                "durationSeconds": durationSeconds
            ]
            if let thumbnailUrlString { payload["thumbnailUrl"] = thumbnailUrlString }

            let existing = try? await ref.getDocument()
            if existing?.exists == true {
                // Re-record: skip moderation fields. The rule rejects any update
                // that mutates `hidden` or `reportCount` from a non-server actor.
                try await ref.updateData(payload)
            } else {
                payload["hidden"] = false
                payload["reportCount"] = 0
                try await ref.setData(payload)
            }
        }

        // 4. Post a clip card message to each blip's group chat.
        let senderName = await fetchSenderName(uid: uid)
        for destination in destinations {
            let slot = Self.slot(for: destination, at: capturedAt)
            let clipId = clipIdByBlipId[destination.id] ?? "\(uid)_\(slot.hour)"
            MessagesRepository.postClipMessage(
                blipId: destination.id,
                blipName: destination.name,
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

    private static func slot(for blip: Blip, at date: Date) -> (dateKey: String, hour: Int) {
        let timezone = TimeZone(identifier: blip.timezoneIdentifier) ?? .current
        return (
            BlipHour.dateKey(for: date, in: timezone, startHour: blip.activeStartHour),
            BlipHour.hour(for: date, in: timezone)
        )
    }

    private static func creationDate(for fileURL: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return attributes?[.creationDate] as? Date
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

enum ClipUploadError: LocalizedError {
    case outsideActiveWindow

    var errorDescription: String? {
        "this blip is outside its daily recording window."
    }
}
