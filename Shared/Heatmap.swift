import Foundation

/// One square in the contribution graph.
struct HeatmapCell: Identifiable, Sendable {
    /// UTC day key, also the cell's stable identity.
    let id: String
    let date: Date
    let count: Int
    /// Days after today in the current week are rendered as empty placeholders
    /// so the grid stays rectangular.
    let isFuture: Bool
}

/// A GitHub-style contribution grid, laid out as one array of 7 cells per week.
struct HeatmapGrid: Sendable {
    let weeks: [[HeatmapCell]]
    let maxCount: Int
    let activeDays: Int
    let totalSubmissions: Int
    let currentStreak: Int
    let longestStreak: Int
    let firstDate: Date
    let today: Date
    /// `true` when the oldest submission we scanned is newer than the start of
    /// the window, i.e. the left edge of the graph is incomplete.
    let isTruncated: Bool

    static let empty = HeatmapGrid(
        weeks: [],
        maxCount: 0,
        activeDays: 0,
        totalSubmissions: 0,
        currentStreak: 0,
        longestStreak: 0,
        firstDate: Date(),
        today: Date(),
        isTruncated: false
    )

    /// The window a grid of `weekCount` weeks covers, aligned so that the last
    /// column always contains today.
    static func window(now: Date, weekCount: Int) -> (start: Date, today: Date, endOfWeek: Date) {
        let calendar = Calendar.codeforcesUTC
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today) // 1 = Sunday
        let endOfWeek = calendar.date(byAdding: .day, value: 7 - weekday, to: today) ?? today
        let start = calendar.date(byAdding: .day, value: -((weekCount * 7) - 1), to: endOfWeek) ?? today
        return (start, today, endOfWeek)
    }

    /// - Parameters:
    ///   - counts: UTC day key -> number of submissions that day.
    ///   - earliestSubmission: the oldest submission actually seen, used to flag
    ///     a partially filled window.
    static func build(
        counts: [String: Int],
        earliestSubmission: Date?,
        now: Date = Date(),
        weekCount: Int = 26
    ) -> HeatmapGrid {
        let weekCount = max(1, min(weekCount, 53))
        let calendar = Calendar.codeforcesUTC
        let bounds = window(now: now, weekCount: weekCount)

        var weeks: [[HeatmapCell]] = []
        weeks.reserveCapacity(weekCount)

        var maxCount = 0
        var activeDays = 0
        var total = 0

        for week in 0..<weekCount {
            var column: [HeatmapCell] = []
            column.reserveCapacity(7)

            for day in 0..<7 {
                let date = calendar.date(byAdding: .day, value: week * 7 + day, to: bounds.start) ?? bounds.start
                let key = DayKey.string(from: date)
                let isFuture = date > bounds.today
                let count = isFuture ? 0 : (counts[key] ?? 0)

                if count > 0 {
                    activeDays += 1
                    total += count
                    maxCount = max(maxCount, count)
                }

                column.append(HeatmapCell(id: key, date: date, count: count, isFuture: isFuture))
            }

            weeks.append(column)
        }

        let streaks = streaks(counts: counts, in: weeks)

        return HeatmapGrid(
            weeks: weeks,
            maxCount: maxCount,
            activeDays: activeDays,
            totalSubmissions: total,
            currentStreak: streaks.current,
            longestStreak: streaks.longest,
            firstDate: bounds.start,
            today: bounds.today,
            isTruncated: earliestSubmission.map { $0 > bounds.start } ?? false
        )
    }

    /// Longest run of consecutive active days in the window, plus the streak
    /// running into today. A day with no submissions today does not break the
    /// current streak until tomorrow — same forgiving rule GitHub uses.
    private static func streaks(counts: [String: Int], in weeks: [[HeatmapCell]]) -> (current: Int, longest: Int) {
        let days = weeks.flatMap { $0 }.filter { !$0.isFuture }
        var longest = 0
        var run = 0

        for day in days {
            if (counts[day.id] ?? 0) > 0 {
                run += 1
                longest = max(longest, run)
            } else {
                run = 0
            }
        }

        var index = days.count - 1
        if index >= 0 && (counts[days[index].id] ?? 0) == 0 { index -= 1 }

        var current = 0
        while index >= 0 && (counts[days[index].id] ?? 0) > 0 {
            current += 1
            index -= 1
        }

        return (current, longest)
    }
}
