import FirebaseStorage
import Foundation
import OSLog
import UIKit

private let log = Logger(subsystem: "app.blip.ios", category: "ProfilePhotoUploader")

/// Single-purpose uploader for the signed-in user's avatar image.
///
/// Resizes to a square thumbnail, JPEG-encodes, writes to a deterministic
/// Storage path (`users/{uid}/avatar.jpg`) so re-uploads overwrite the prior
/// blob, and returns the freshly-issued download URL. Persisting that URL
/// to the user doc is the caller's responsibility — see `ProfileViewModel`.
@MainActor
final class ProfilePhotoUploader: ProfilePhotoUploading {

    // MARK: - Constants

    private static let maxEdge: CGFloat = 512
    private static let jpegQuality: CGFloat = 0.8
    private static let contentType = "image/jpeg"

    // MARK: - Dependencies

    private let storage: Storage

    init(storage: Storage = .storage()) {
        self.storage = storage
    }

    // MARK: - ProfilePhotoUploading

    func upload(_ image: UIImage, uid: String) async throws -> URL {
        guard !uid.isEmpty else { throw UploadError.notSignedIn }

        let resized = Self.resize(image, maxEdge: Self.maxEdge)
        guard let data = resized.jpegData(compressionQuality: Self.jpegQuality) else {
            throw UploadError.encodingFailed
        }

        let ref = storage.reference().child("users/\(uid)/avatar.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = Self.contentType

        let url: URL = try await withCheckedThrowingContinuation { cont in
            ref.putData(data, metadata: metadata) { _, error in
                if let error { cont.resume(throwing: error); return }
                Task {
                    do {
                        let downloadURL = try await ref.downloadURL()
                        cont.resume(returning: downloadURL)
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
        }

        log.info("uploaded avatar uid=\(uid, privacy: .public)")
        return url
    }

    // MARK: - Helpers

    /// Aspect-fit downscale to `maxEdge` on the longer side. No-op when the
    /// image is already small enough. UIKit's `draw(in:)` handles orientation.
    private static func resize(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxEdge else { return image }
        let scale = maxEdge / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    enum UploadError: LocalizedError {
        case notSignedIn
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .notSignedIn:    return "you need to be signed in to upload a photo."
            case .encodingFailed: return "couldn't encode that image. try a different one."
            }
        }
    }
}
