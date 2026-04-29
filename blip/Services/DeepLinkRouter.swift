import Foundation
import OSLog
import SwiftUI

private let log = Logger(subsystem: "app.blip.ios", category: "DeepLinkRouter")

/// Centralized handler for incoming URLs (push payload, Universal Link, custom scheme).
///
/// Schemes we handle:
///   - `blip://capture`            → open the capture screen for the user's primary blip
///   - `blip://blip/{blipId}`      → navigate to the given blip's detail
///
/// Views observe `pending` and consume by setting it back to `nil`.
@MainActor
final class DeepLinkRouter: ObservableObject {
    enum Action: Equatable {
        case openCapture
        case openBlip(id: String)
    }

    @Published var pending: Action?

    func handle(url: URL) {
        log.info("deeplink: \(url.absoluteString, privacy: .public)")
        guard url.scheme == "blip" else { return }

        let host = url.host
        let pathParts = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "capture":
            pending = .openCapture
        case "blip":
            if let id = pathParts.first {
                pending = .openBlip(id: id)
            }
        default:
            break
        }
    }

    func consume() {
        pending = nil
    }
}
