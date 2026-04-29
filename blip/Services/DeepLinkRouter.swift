import Foundation
import OSLog
import SwiftUI

private let log = Logger(subsystem: "app.blip.ios", category: "DeepLinkRouter")

/// `UserDefaults` key for the persisted referrer uid. Persisted (not just
/// in-memory) so the value survives the relaunch between "URL opened while
/// signed out" and "user finishes onboarding".
private let kPendingReferrerUidKey = "blip.pendingReferrerUid"

/// Centralized handler for incoming URLs (push payload, Universal Link, custom scheme).
///
/// Schemes we handle:
///   - `blip://capture`            → open the capture screen for the user's primary blip
///   - `blip://blip/{blipId}`      → navigate to the given blip's detail
///   - `blip://invite?ref={uid}`   → stash referrer uid until the user finishes signup
///
/// Views observe `pending` and consume by setting it back to `nil`.
@MainActor
final class DeepLinkRouter: ObservableObject {
    enum Action: Equatable {
        case openCapture
        case openBlip(id: String)
        case invite(referrerUid: String)
    }

    @Published var pending: Action?

    /// Read at first-sign-in so `ensureUserDoc(uid:referredByUid:)` can write
    /// the field on user-doc create. Persisted in `UserDefaults` so it
    /// survives the launch between "tapped invite link while signed out" and
    /// "completed phone-OTP onboarding". Mirrored as `@Published` so a logged-in
    /// listener can react if desired (currently only RootView consumes it).
    @Published private(set) var pendingReferrerUid: String?

    init() {
        pendingReferrerUid = UserDefaults.standard.string(forKey: kPendingReferrerUidKey)
    }

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
        case "invite":
            // ref uid arrives as a query param: blip://invite?ref=UID
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let ref = comps?.queryItems?.first(where: { $0.name == "ref" })?.value,
               !ref.isEmpty {
                stashReferrerUid(ref)
                pending = .invite(referrerUid: ref)
            }
        default:
            break
        }
    }

    func consume() {
        pending = nil
    }

    /// Read once at first-create-doc time and clear. Returns `nil` if no
    /// invite link was ever opened. Self-loop (`uid` == ref) is filtered at the
    /// caller (RootView) and at the server (rules + Cloud Function).
    func consumePendingReferrerUid() -> String? {
        let ref = pendingReferrerUid
        if ref != nil {
            UserDefaults.standard.removeObject(forKey: kPendingReferrerUidKey)
            pendingReferrerUid = nil
        }
        return ref
    }

    private func stashReferrerUid(_ ref: String) {
        UserDefaults.standard.set(ref, forKey: kPendingReferrerUidKey)
        pendingReferrerUid = ref
    }
}
