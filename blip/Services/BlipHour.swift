import Foundation

/// Blip-local hour/dateKey utilities. The blipchat — not the user's device — is
/// the source of truth for hour buckets and the 4AM-anchored day window. Both
/// the in-app preview grid and any deterministic per-(blip, hour) doc id (e.g.
/// nudges, future per-hour aggregates) must compute these from the blip's TZ.
enum BlipHour {
    static func currentHour(in tzIdentifier: String) -> Int {
        currentHour(in: TimeZone(identifier: tzIdentifier) ?? .current)
    }

    static func currentHour(in tz: TimeZone) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.component(.hour, from: Date())
    }

    static func currentDateKey(in tzIdentifier: String) -> String {
        dateKey(for: Date(), in: TimeZone(identifier: tzIdentifier) ?? .current)
    }

    /// 4AM-to-4AM window: a clip at 3AM still belongs to "yesterday's" key.
    static func dateKey(for date: Date, in tz: TimeZone) -> String {
        let shifted = date.addingTimeInterval(-4 * 3600)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = tz
        return formatter.string(from: shifted)
    }
}
