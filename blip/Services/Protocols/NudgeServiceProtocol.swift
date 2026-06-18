import Foundation

/// Thin write-only protocol for sending a peer nudge. Per CLAUDE.md Interface
/// Segregation: callers (a view's `Task { ... }` confirm action) need to push
/// a single nudge — they do not need any reactive state from a NudgeService,
/// so this protocol intentionally does not inherit `ObservableObject`.
protocol NudgeServicing {
    /// Best-effort. Throws if the underlying Firestore write fails for a reason
    /// other than the deterministic-id throttle (already-nudged-this-hour, which
    /// surfaces as a permission-denied error and should be treated as success).
    func sendNudge(
        blipId: String,
        blipTimezone: String,
        activeStartHour: Int,
        activeEndHour: Int,
        senderUid: String,
        nudgeeUid: String
    ) async throws
}
