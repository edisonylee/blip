import Foundation

/// Write-only contract for the signed-in user's profile.
///
/// ViewModels depend on `any BlipUserMutating` rather than the concrete
/// `UserRepository` so the write surface is decoupled from the reactive
/// read surface (`@Published profile`). Mirrors `BlipMutating` /
/// `ClipUploading` — no `ObservableObject` so it can be stored as `any`.
@MainActor
protocol BlipUserMutating {
    func updateSchool(_ school: String?) async throws
    func updatePhotoURL(_ url: URL) async throws
}
