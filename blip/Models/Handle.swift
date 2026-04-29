import Foundation

/// Snapchat-style username validator. Rules:
/// - 3 to 15 characters
/// - lowercase letters, digits, period, underscore
/// - must start with a letter
/// - must not end with a separator (period or underscore)
/// - no two adjacent separators (no "..", "__", "._", "_.")
///
/// All validation runs against the *normalized* form — trim whitespace and
/// lowercase before validating. The /usernames/{handle} doc id is the
/// normalized form, so equality and uniqueness are case-insensitive.
enum Handle {
    static let minLength = 3
    static let maxLength = 15

    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isValid(_ normalized: String) -> Bool {
        guard normalized.count >= minLength, normalized.count <= maxLength else { return false }

        guard let first = normalized.first, Self.lowercaseLetters.contains(first) else { return false }
        guard let last = normalized.last, !Self.separators.contains(last) else { return false }

        let allowed = Self.lowercaseLetters
            .union(Self.digits)
            .union(Self.separators)
        guard normalized.allSatisfy({ allowed.contains($0) }) else { return false }

        var prev: Character?
        for c in normalized {
            if let p = prev, Self.separators.contains(p), Self.separators.contains(c) {
                return false
            }
            prev = c
        }
        return true
    }

    private static let lowercaseLetters: Set<Character> = Set("abcdefghijklmnopqrstuvwxyz")
    private static let digits: Set<Character> = Set("0123456789")
    private static let separators: Set<Character> = [".", "_"]
}

enum HandleError: LocalizedError {
    case invalidFormat
    case alreadyTaken
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "handles are 3–15 chars, start with a letter, and use only a–z, 0–9, . or _."
        case .alreadyTaken:
            return "that handle is taken."
        case .notSignedIn:
            return "you need to be signed in to claim a handle."
        }
    }
}
