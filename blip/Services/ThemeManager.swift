import SwiftUI

private let kThemeKey = "blip.theme.preference"

/// Single-responsibility service: stores and publishes the user's theme preference.
/// Persists to `UserDefaults` so the setting survives cold launches.
@MainActor
final class ThemeManager: ObservableObject, ThemeManagerProtocol {
    @Published var preference: ThemePreference {
        didSet { UserDefaults.standard.set(preference.rawValue, forKey: kThemeKey) }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: kThemeKey) ?? ""
        preference = ThemePreference(rawValue: saved) ?? .system
    }
}
