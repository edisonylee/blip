import Foundation

/// State + async work for the Snapchat-style global capture surface.
///
/// Flow: record → review/picker → fan-out send.
/// Owns the resulting clip URL and the chosen Set<String> of blipIds. Hour binding is
/// the user's local hour at upload time — `ClipUploader` derives `hour` and `dateKey`
/// from `Date()` and writes one clip doc per selected blip.
@MainActor
final class CaptureGlobalViewModel: ObservableObject {

    // MARK: - Published state

    /// Local file URL of the most recent recording. Nil while the user is still on
    /// the camera surface; non-nil once recording finishes (review/picker shows).
    @Published var recordingURL: URL?

    /// Multi-select destination set. Default empty per spec: "all unchecked".
    @Published var selectedBlipIds: Set<String> = []

    @Published var errorMessage: String?
    @Published private(set) var isSending = false

    // MARK: - Dependencies

    private let uploader: any ClipUploading

    init(uploader: any ClipUploading) {
        self.uploader = uploader
    }

    // MARK: - Derived

    var canSend: Bool { !selectedBlipIds.isEmpty && !isSending && recordingURL != nil }
    var sendButtonLabel: String {
        let n = selectedBlipIds.count
        if n == 0 { return "pick a blip" }
        if n == 1 { return "send to 1 blip" }
        return "send to \(n) blips"
    }

    // MARK: - Actions

    func toggle(_ blipId: String) {
        if selectedBlipIds.contains(blipId) { selectedBlipIds.remove(blipId) }
        else { selectedBlipIds.insert(blipId) }
    }

    func discardRecording() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        selectedBlipIds = []
        errorMessage = nil
    }

    /// Fan-out send. Picks the first selected blip as the Storage
    /// owner) and writes one clip doc into every selected blip. Mirrors the
    /// per-blip ReviewViewModel.post path so deterministic clipIds (`{uid}_{hour}`)
    /// dedupe re-posts within the same local hour.
    func send(uid: String, blips: [Blip]) async -> Bool {
        guard let url = recordingURL else { return false }
        guard !selectedBlipIds.isEmpty else { return false }

        errorMessage = nil
        isSending = true
        defer { isSending = false }

        let destinations = blips.filter { selectedBlipIds.contains($0.id) }
        guard destinations.count == selectedBlipIds.count,
              let primary = destinations.first else {
            errorMessage = "one of those blips is no longer available."
            return false
        }

        do {
            try await uploader.upload(
                fileURL: url,
                uid: uid,
                primaryBlip: primary,
                destinations: destinations,
                caption: nil
            )
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
            selectedBlipIds = []
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
