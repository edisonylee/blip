import Foundation

/// Contract for blip data access.
/// Concrete: `BlipRepository`. ViewModels depend on this so the UI layer
/// never imports FirebaseFirestore directly.
@MainActor
protocol BlipRepositoryProtocol: ObservableObject {
    var blips: [Blip] { get }
    var isLoading: Bool { get }
    var lastError: String? { get }

    func startListening(for uid: String)
    func stopListening()
    func createBlip(name: String, size: Int, ownerUid: String, timezoneIdentifier: String) async throws -> Blip
    func joinBlip(code: String, uid: String) async throws -> Blip
}
