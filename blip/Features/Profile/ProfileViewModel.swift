import OSLog
import SwiftUI
import UIKit

private let log = Logger(subsystem: "app.blip.ios", category: "ProfileViewModel")

/// Drives async work for `ProfileView` — photo upload state machine, error
/// surfacing, and share-text composition. Reads of the user profile go
/// through `@EnvironmentObject UserRepository` directly in the view; this
/// VM owns only the bits that don't belong in `@State`.
///
/// Dependencies arrive as protocols (Dependency Inversion):
///   - `BlipUserMutating` for writing school / photo URL fields
///   - `ProfilePhotoUploading` for the Storage round-trip
@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var photoUploadState: PhotoUploadState = .idle
    @Published var pendingError: String?

    enum PhotoUploadState: Equatable {
        case idle
        case uploading
    }

    // MARK: - Dependencies

    private let uid: String
    private let userMutator: any BlipUserMutating
    private let photoUploader: any ProfilePhotoUploading

    // MARK: - Init

    init(
        uid: String,
        userMutator: any BlipUserMutating,
        photoUploader: any ProfilePhotoUploading
    ) {
        self.uid = uid
        self.userMutator = userMutator
        self.photoUploader = photoUploader
    }

    // MARK: - Photo upload

    /// Uploads the picked image to the user's avatar Storage slot and writes
    /// the resulting URL back to the user doc. Surfaces failures via
    /// `pendingError` for the view to render.
    func uploadPhoto(_ image: UIImage) async {
        guard photoUploadState == .idle else { return }
        photoUploadState = .uploading
        pendingError = nil
        do {
            let url = try await photoUploader.upload(image, uid: uid)
            try await userMutator.updatePhotoURL(url)
            log.info("avatar updated for uid=\(self.uid, privacy: .public)")
        } catch {
            pendingError = error.localizedDescription
            log.error("avatar upload failed: \(error.localizedDescription, privacy: .public)")
        }
        photoUploadState = .idle
    }

    var isUploadingPhoto: Bool { photoUploadState == .uploading }

    // MARK: - Share text

    /// Builds the share-sheet payload for "Share profile". Falls back to a
    /// generic prompt when the handle hasn't been claimed yet — the share
    /// sheet still opens so the gesture isn't a dead end.
    func shareItems(handle: String?) -> [Any] {
        let appURL = "https://apps.apple.com/app/blip"
        if let handle, !handle.isEmpty {
            return ["add me on blip — @\(handle)\n\(appURL)"]
        }
        return ["add me on blip\n\(appURL)"]
    }
}
