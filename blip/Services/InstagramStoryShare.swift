import UIKit

/// Direct hand-off to Instagram Stories' "share to story" flow.
///
/// Per Meta's docs (https://developers.facebook.com/docs/instagram-platform/sharing-to-stories),
/// the host app drops the video on `UIPasteboard.general` keyed by
/// `com.instagram.sharedSticker.backgroundVideo`, sets a 5-minute expiration,
/// then opens `instagram-stories://share`. Instagram reads the pasteboard and
/// drops the user into story-creation with the video pre-loaded.
///
/// Falls back to the system share sheet if Instagram isn't installed (caller
/// checks `isAvailable` first).
enum InstagramStoryShare {
    /// True if Instagram is installed and registered for the `instagram-stories` scheme.
    static var isAvailable: Bool {
        guard let url = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    enum ShareError: Error {
        case notInstalled
        case readFailed(Error)
    }

    /// Hand a local video file to Instagram Stories.
    /// File reading is dispatched to a background thread to avoid freezing the UI.
    @MainActor
    static func share(videoFileURL: URL) async throws {
        guard isAvailable else { throw ShareError.notInstalled }

        // Read the (potentially large) video file off the main thread.
        let data = try await Task.detached(priority: .userInitiated) {
            do {
                return try Data(contentsOf: videoFileURL)
            } catch {
                throw ShareError.readFailed(error)
            }
        }.value

        // Pasteboard handoff must happen on the main thread.
        let item: [String: Any] = [
            "com.instagram.sharedSticker.backgroundVideo": data,
        ]
        UIPasteboard.general.setItems(
            [item],
            options: [.expirationDate: Date().addingTimeInterval(5 * 60)]
        )

        // URL is a known-good hardcoded string — canOpenURL already passed.
        // Use the completion-handler overload explicitly so the compiler doesn't
        // pick up the async overload added in iOS 18 and require 'await'.
        if let url = URL(string: "instagram-stories://share") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}