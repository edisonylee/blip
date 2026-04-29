import Foundation

/// Write-side contract for blip operations.
/// Does NOT inherit ObservableObject so it can be used as `any BlipMutating` in ViewModels
/// without boxing an associated-type publisher. Read-side / reactive access stays in BlipRepositoryProtocol.
@MainActor
protocol BlipMutating {
    func createBlip(name: String, size: Int, ownerUid: String, timezoneIdentifier: String) async throws -> Blip
    func joinBlip(code: String, uid: String) async throws -> Blip
    func updateMemberOrder(blipId: String, members: [String]) async throws
}
