import Foundation

/// Blip-local hour/dateKey utilities. The blipchat — not the user's device — is
/// the source of truth for hour buckets and its configured daily window. Both
/// the in-app preview grid and any deterministic per-(blip, hour) doc id (e.g.
/// nudges, future per-hour aggregates) must compute these from the blip's TZ.
enum BlipHour {
    static func currentHour(in tzIdentifier: String) -> Int {
        currentHour(in: TimeZone(identifier: tzIdentifier) ?? .current)
    }

    static func currentHour(in tz: TimeZone) -> Int {
        hour(for: Date(), in: tz)
    }

    static func hour(for date: Date, in tz: TimeZone) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.component(.hour, from: date)
    }

    static func currentDateKey(in tzIdentifier: String, startHour: Int = 4) -> String {
        dateKey(
            for: Date(),
            in: TimeZone(identifier: tzIdentifier) ?? .current,
            startHour: startHour
        )
    }

    /// The date key is anchored to the group's start hour. For an 8AM start,
    /// a clip at 7AM still belongs to the preceding group day.
    static func dateKey(for date: Date, in tz: TimeZone, startHour: Int = 4) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let localHour = calendar.component(.hour, from: date)
        var anchor = calendar.startOfDay(for: date)
        if localHour < startHour {
            anchor = calendar.date(byAdding: .day, value: -1, to: anchor) ?? anchor
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = tz
        return formatter.string(from: anchor)
    }

    static func isActive(
        at date: Date = Date(),
        timezoneIdentifier: String,
        startHour: Int,
        endHour: Int
    ) -> Bool {
        let hour = currentHour(at: date, in: timezoneIdentifier)
        return isActive(hour: hour, startHour: startHour, endHour: endHour)
    }

    static func isActive(hour: Int, startHour: Int, endHour: Int) -> Bool {
        if startHour == endHour { return true }
        if startHour < endHour { return hour >= startHour && hour < endHour }
        return hour >= startHour || hour < endHour
    }

    static func orderedHours(startHour: Int, endHour: Int) -> [Int] {
        let count = startHour == endHour
            ? 24
            : (endHour - startHour + 24) % 24
        return (0..<count).map { (startHour + $0) % 24 }
    }

    static func sortIndex(for hour: Int, startHour: Int) -> Int {
        (hour - startHour + 24) % 24
    }

    static func hourLabel(_ hour: Int) -> String {
        let normalized = ((hour % 24) + 24) % 24
        if normalized == 0 { return "12 AM" }
        if normalized < 12 { return "\(normalized) AM" }
        if normalized == 12 { return "12 PM" }
        return "\(normalized - 12) PM"
    }

    private static func currentHour(at date: Date, in tzIdentifier: String) -> Int {
        hour(for: date, in: TimeZone(identifier: tzIdentifier) ?? .current)
    }
}
