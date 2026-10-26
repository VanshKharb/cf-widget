import Foundation

// MARK: - Rating history

struct RatingPoint: Codable, Sendable, Identifiable, Equatable {
    var id: Int { contestId }
    let contestId: Int
    let date: Date
    let rating: Int
    let contestName: String
    let rank: Int
}

// MARK: - Last contest

struct ContestResult: Codable, Sendable, Equatable {
    let contestId: Int
    let name: String
    let date: Date
    let rank: Int
    let oldRating: Int
    let newRating: Int

    var delta: Int { newRating - oldRating }

    var isGain: Bool { delta >= 0 }

    var rankDisplay: String { "#\(rank)" }
}

// MARK: - Upcoming contest

struct UpcomingContest: Codable, Sendable, Identifiable {
    let id: Int
    let name: String
    let start: Date
    let durationSeconds: Int
}

// MARK: - Snapshot

/// Everything a widget or the app needs, computed once and cached. Building this
/// is the expensive part (up to 10 000 submissions); rendering it is cheap, which
/// is exactly what a widget timeline needs.
struct StatsSnapshot: Codable, Sendable {
    let handle: String
    let displayName: String
    let avatarURL: String?
    let country: String?
    let organization: String?

    let rating: Int?
    let maxRating: Int?
    let rank: String?
    let maxRank: String?
    let contribution: Int?
    let friendOfCount: Int?

    let solvedCount: Int
    let acceptedSubmissions: Int
    /// How many submissions were actually inspected.
    let scannedSubmissions: Int
    let ratedContestCount: Int
    /// `true` when the scan hit the request cap, so `solvedCount` is a floor
    /// rather than an exact answer.
    let isPartialScan: Bool

    /// UTC day key -> submissions that day, limited to the heatmap window.
    let heatmapCounts: [String: Int]
    /// The oldest submission seen, whether or not it falls inside the window.
    let earliestScannedSubmission: Date?
    let heatmapWeeks: Int

    let ratingHistory: [RatingPoint]
    let lastContest: ContestResult?
    let upcoming: [UpcomingContest]
    let generatedAt: Date

    // MARK: Derived

    var hasRating: Bool { (rating ?? 0) > 0 }

    /// Share of inspected submissions that were accepted.
    var acceptanceRate: Double? {
        guard scannedSubmissions > 0 else { return nil }
        return Double(acceptedSubmissions) / Double(scannedSubmissions)
    }

    var nextContest: UpcomingContest? { upcoming.first }

    /// Rating at the start of the cached history.
    var ratingChangeOverHistory: Int? {
        guard let first = ratingHistory.first, let last = ratingHistory.last, ratingHistory.count >= 2 else { return nil }
        return last.rating - first.rating
    }

    /// Builds the grid for a given widget size. The stored counts cover a wide
    /// window, so each widget can ask for exactly as many weeks as it can show.
    func heatmap(weeks: Int, now: Date = Date()) -> HeatmapGrid {
        HeatmapGrid.build(
            counts: heatmapCounts,
            earliestSubmission: earliestScannedSubmission,
            now: now,
            weekCount: weeks
        )
    }

    /// For views that want a streak without laying out a grid. Exact within the
    /// `heatmapWeeks` window the counts were stored for.
    func currentStreak(now: Date = Date()) -> Int {
        heatmap(weeks: heatmapWeeks, now: now).currentStreak
    }

    func longestStreak(now: Date = Date()) -> Int {
        heatmap(weeks: heatmapWeeks, now: now).longestStreak
    }
}

// MARK: - Merging

extension StatsSnapshot {
    /// Combines this (older) snapshot with a freshly fetched one.
    ///
    /// The app scans up to 10 000 submissions for an exact solved count, while a
    /// widget refresh scans only 1 200 to stay inside its memory budget. Without
    /// this merge a background widget refresh would visibly drop the solved
    /// count from its true value down to whatever fits in the smaller scan.
    func merging(newer: StatsSnapshot) -> StatsSnapshot {
        guard newer.handle == handle else { return newer }

        let fuller = newer.scannedSubmissions >= scannedSubmissions ? newer : self

        return StatsSnapshot(
            handle: newer.handle,
            displayName: newer.displayName,
            avatarURL: newer.avatarURL ?? avatarURL,
            country: newer.country ?? country,
            organization: newer.organization ?? organization,
            rating: newer.rating ?? rating,
            maxRating: Self.highest(newer.maxRating, maxRating),
            rank: newer.rank ?? rank,
            maxRank: newer.maxRank ?? maxRank,
            contribution: newer.contribution ?? contribution,
            friendOfCount: newer.friendOfCount ?? friendOfCount,
            solvedCount: fuller.solvedCount,
            acceptedSubmissions: fuller.acceptedSubmissions,
            scannedSubmissions: fuller.scannedSubmissions,
            ratedContestCount: max(newer.ratedContestCount, ratedContestCount),
            isPartialScan: fuller.isPartialScan,
            heatmapCounts: Self.combineCounts(heatmapCounts, newer.heatmapCounts),
            earliestScannedSubmission: Self.earliest(earliestScannedSubmission, newer.earliestScannedSubmission),
            heatmapWeeks: max(newer.heatmapWeeks, heatmapWeeks),
            ratingHistory: newer.ratingHistory.isEmpty ? ratingHistory : newer.ratingHistory,
            lastContest: newer.lastContest ?? lastContest,
            upcoming: newer.upcoming.isEmpty ? upcoming : newer.upcoming,
            generatedAt: newer.generatedAt
        )
    }

    /// Per day, the larger of the two counts: a newer scan knows the most recent
    /// days best, an older fuller scan saw days the newer one never reached.
    private static func combineCounts(_ lhs: [String: Int], _ rhs: [String: Int]) -> [String: Int] {
        var result = lhs
        for (key, value) in rhs {
            result[key] = Swift.max(result[key] ?? 0, value)
        }
        return result
    }

    private static func highest(_ lhs: Int?, _ rhs: Int?) -> Int? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): return Swift.max(lhs, rhs)
        case let (lhs?, nil): return lhs
        case let (nil, rhs?): return rhs
        default: return nil
        }
    }

    private static func earliest(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): return Swift.min(lhs, rhs)
        case let (lhs?, nil): return lhs
        case let (nil, rhs?): return rhs
        default: return nil
        }
    }
}

// MARK: - Building

extension StatsSnapshot {
    static func build(
        handle: String,
        user: CFUser,
        ratingHistory: [CFRatingChange],
        submissions: [CFSubmission],
        contests: [CFContest],
        now: Date = Date(),
        heatmapWeeks: Int = 26,
        historyLimit: Int = 60,
        scannedLimit: Int
    ) -> StatsSnapshot {

        let weeks = max(1, min(heatmapWeeks, 53))
        let windowStartKey = DayKey.string(from: HeatmapGrid.window(now: now, weekCount: weeks).start)

        var counts: [String: Int] = [:]
        counts.reserveCapacity(256)

        var solvedProblems = Set<String>()
        var acceptedCount = 0
        var earliest: Date?

        for submission in submissions {
            let date = Date(timeIntervalSince1970: TimeInterval(submission.creationTimeSeconds))
            if earliest == nil || date < earliest! { earliest = date }

            if submission.isAccepted {
                acceptedCount += 1
                if let key = submission.problemKey { solvedProblems.insert(key) }
            }

            // Day keys are "yyyy-MM-dd", so string comparison is chronological.
            let key = DayKey.string(from: date)
            if key >= windowStartKey {
                counts[key, default: 0] += 1
            }
        }

        let points = ratingHistory.map { change in
            RatingPoint(
                contestId: change.contestId,
                date: Date(timeIntervalSince1970: TimeInterval(change.ratingUpdateTimeSeconds)),
                rating: change.newRating,
                contestName: change.contestName,
                rank: change.rank
            )
        }

        let lastContest = ratingHistory.last.map { change in
            ContestResult(
                contestId: change.contestId,
                name: change.contestName,
                date: Date(timeIntervalSince1970: TimeInterval(change.ratingUpdateTimeSeconds)),
                rank: change.rank,
                oldRating: change.oldRating,
                newRating: change.newRating
            )
        }

        let upcoming = contests
            .filter { $0.isUpcoming && $0.startTimeSeconds != nil }
            .compactMap { contest -> UpcomingContest? in
                guard let start = contest.startTimeSeconds else { return nil }
                return UpcomingContest(
                    id: contest.id,
                    name: contest.name,
                    start: Date(timeIntervalSince1970: TimeInterval(start)),
                    durationSeconds: contest.durationSeconds
                )
            }
            .sorted { $0.start < $1.start }
            .prefix(4)

        return StatsSnapshot(
            handle: handle,
            displayName: user.displayName,
            avatarURL: user.avatar ?? user.titlePhoto,
            country: user.country,
            organization: user.organization,
            rating: user.rating,
            maxRating: user.maxRating,
            rank: user.rank,
            maxRank: user.maxRank,
            contribution: user.contribution,
            friendOfCount: user.friendOfCount,
            solvedCount: solvedProblems.count,
            acceptedSubmissions: acceptedCount,
            scannedSubmissions: submissions.count,
            ratedContestCount: ratingHistory.count,
            isPartialScan: !submissions.isEmpty && submissions.count >= scannedLimit,
            heatmapCounts: counts,
            earliestScannedSubmission: earliest,
            heatmapWeeks: weeks,
            ratingHistory: Array(points.suffix(max(historyLimit, 2))),
            lastContest: lastContest,
            upcoming: Array(upcoming),
            generatedAt: now
        )
    }
}
