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

    /// Hand a local video file to Instagram Stories. Throws `notInstalled` if
    /// IG isn't on the device, or `readFailed` if we can't load the file.
    static func share(videoFileURL: URL) throws {
        guard isAvailable else { throw ShareError.notInstalled }

        let data: Data
        do {
            data = try Data(contentsOf: videoFileURL)
        } catch {
            throw ShareError.readFailed(error)
        }

        // Pasteboard handoff — IG reads these keys and ignores the rest. Setting
        // an expiration means a stale paste from a previous share won't leak.
        let item: [String: Any] = [
            "com.instagram.sharedSticker.backgroundVideo": data,
        ]
        UIPasteboard.general.setItems(
            [item],
            options: [.expirationDate: Date().addingTimeInterval(5 * 60)]
        )

        let url = URL(string: "instagram-stories://share")!
        UIApplication.shared.open(url, options: [:])
    }
}