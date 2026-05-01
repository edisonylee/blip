import UIKit

/// Write-only contract for uploading a user's avatar image.
///
/// ViewModels depend on `any ProfilePhotoUploading` so the Storage call can
/// be swapped in tests / previews without dragging Firebase in. Mirrors
/// `ClipUploading` / `BlipMutating`.
@MainActor
protocol ProfilePhotoUploading {
    /// Compresses + uploads the image to the user's avatar slot in Storage,
    /// returning the resulting download URL. The caller persists the URL on
    /// the user doc via `BlipUserMutating.updatePhotoURL(_:)`.
    func upload(_ image: UIImage, uid: String) async throws -> URL
}
