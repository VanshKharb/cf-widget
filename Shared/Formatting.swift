import Foundation

// MARK: - Calendar

extension Calendar {
    /// Codeforces timestamps are bucketed in UTC so the heatmap looks identical
    /// no matter which time zone the device is in. Weeks start on Sunday, which
    /// is what every contribution graph on the internet does.
    static let codeforcesUTC: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()
}

// MARK: - Day keys

/// `"yyyy-MM-dd"` in UTC. These sort lexicographically in the same order they
/// sort chronologically, which makes window comparisons trivial.
enum DayKey {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)!
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func string(from date: Date) -> String { formatter.string(from: date) }

    static func date(from key: String) -> Date? { formatter.date(from: key) }
}

// MARK: - Handles

enum Handle {
    /// Codeforces handles are case-insensitive; normalising to lowercase keeps
    /// the snapshot cache from storing the same account twice.
    static func normalize(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()
    }
}

// MARK: - Number / date formatting

enum Fmt {
    /// `1_234` -> `"1.2k"`, `2_500_000` -> `"2.5M"`.
    static func compact(_ value: Int) -> String {
        let magnitude = abs(value)
        if magnitude >= 1_000_000 { return trimmed(Double(value) / 1_000_000) + "M" }
        if magnitude >= 1_000 { return trimmed(Double(value) / 1_000) + "k" }
        return "\(value)"
    }

    private static func trimmed(_ value: Double) -> String {
        let text = String(format: "%.1f", value)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    /// `"in 3d 4h"` / `"in 12m"`.
    static func countdown(to date: Date, now: Date = Date()) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        guard seconds > 0 else { return "starting now" }

        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 { return "in \(days)d \(hours)h" }
        if hours > 0 { return "in \(hours)h \(minutes)m" }
        return "in \(max(minutes, 1))m"
    }

    /// `"2d ago"` / `"just now"`.
    static func relativePast(_ date: Date, now: Date = Date()) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3_600 { return "\(seconds / 60)m ago" }
        if seconds < 86_400 { return "\(seconds / 3_600)h ago" }
        if seconds < 86_400 * 30 { return "\(seconds / 86_400)d ago" }
        if seconds < 86_400 * 365 { return "\(seconds / (86_400 * 30))mo ago" }
        return "\(seconds / (86_400 * 365))y ago"
    }

    /// Contest length: `8_100` -> `"2h 15m"`.
    static func duration(_ seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }

    /// `"Nov 2"`, localised to the device's locale and time zone, because this
    /// one describes an event the user will attend in their own time.
    static func shortDateTime(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}
