import Foundation

/// Single source of truth for invite-share copy. Every place we hand a string
/// to a `ShareSheet` for invites should route through here so:
///   1. The blip-join code stays attached to the message (legacy mechanic).
///   2. The `blip://invite?ref={uid}` deep link is appended whenever we know
///      the inviter's uid — that's what credits the referrer's `referralsCount`
///      via the `onUserCreated` Cloud Function trigger after the recipient
///      finishes signup on a device that already has the app installed.
///
/// Universal Links + a hosted `apple-app-site-association` file are the real
/// fix for SMS/iMessage-shared installs; the custom scheme is v0 only.
enum InviteShare {
    /// Builds the shared text body. Always includes the blip's joinCode so
    /// existing flows still work; appends a deep link only when `referrerUid`
    /// is non-nil (e.g. user is signed in at share time).
    /// Drops "my" — group-first voice. Code line stays tight; URL gets its own
    /// line so iMessage/SMS treats it as a tappable link.
    static func text(blipName: String, joinCode: String, referrerUid: String?) -> String {
        let header = "join \"\(blipName)\" on blip — code: \(joinCode)"
        guard let url = inviteURL(referrerUid: referrerUid) else { return header }
        return "\(header)\n\(url.absoluteString)"
    }

    /// Personal referral URL for the given uid. Returns `nil` when uid is
    /// missing — callers fall back to plain join-code copy.
    static func inviteURL(referrerUid: String?) -> URL? {
        guard let uid = referrerUid, !uid.isEmpty else { return nil }
        var comps = URLComponents()
        comps.scheme = "blip"
        comps.host = "invite"
        comps.queryItems = [URLQueryItem(name: "ref", value: uid)]
        return comps.url
    }
}
