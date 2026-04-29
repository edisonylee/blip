import Foundation

/// Write-only contract for clip uploads.
///
/// ViewModels depend on `any ClipUploading` rather than the concrete `ClipUploader` so
/// the upload pipeline can be swapped in tests / previews without dragging Firebase in.
/// Mirrors `BlipMutating` — no `ObservableObject` so it can be stored as `any`.
@MainActor
protocol ClipUploading {
    var isUploading: Bool { get }
    var progress: Double { get }

    /// Upload the local recording to Storage and write a clip doc into every
    /// blip in `sharedToBlipIds` (which must contain `primaryBlipId`).
    /// Re-posting within the same hour replaces the prior doc per the
    /// deterministic `{uid}_{hour}` clipId in `ClipUploader`.
    func upload(
        fileURL: URL,
        uid: String,
        primaryBlipId: String,
        sharedToBlipIds: [String],
        caption: String?
    ) async throws
}
