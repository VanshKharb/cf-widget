import Foundation

extension StatsSnapshot {
    /// Deterministic fake data so widget previews, placeholders and Xcode
    /// previews look like a real, busy account.
    static var sample: StatsSnapshot {
        let now = Date()
        let calendar = Calendar.codeforcesUTC

        // A small LCG: same picture every time, no `random()` in previews.
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func next(_ bound: Int) -> Int {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((seed >> 33) % UInt64(bound))
        }

        var counts: [String: Int] = [:]
        for offset in 0..<200 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let roll = next(10)
            // Weekends are busier, mirroring how contests are scheduled.
            let weekday = calendar.component(.weekday, from: date)
            let busy = weekday == 1 || weekday == 7
            let value = roll > (busy ? 3 : 6) ? next(9) + 1 : 0
            if value > 0 { counts[DayKey.string(from: date)] = value }
        }

        var history: [RatingPoint] = []
        var rating = 1_180
        for index in 0..<24 {
            rating += next(90) - 35
            guard let date = calendar.date(byAdding: .day, value: -((24 - index) * 21), to: now) else { continue }
            history.append(
                RatingPoint(
                    contestId: 1_800 + index,
                    date: date,
                    rating: rating,
                    contestName: "Codeforces Round \(900 + index) (Div. 2)",
                    rank: next(4_000) + 200
                )
            )
        }

        let last = history.last!

        return StatsSnapshot(
            handle: "vansh",
            displayName: "Vansh Kharb",
            avatarURL: nil,
            country: "India",
            organization: "IIIT",
            rating: last.rating,
            maxRating: history.map(\.rating).max(),
            rank: "expert",
            maxRank: "candidate master",
            contribution: 12,
            friendOfCount: 34,
            solvedCount: 438,
            acceptedSubmissions: 612,
            scannedSubmissions: 1_204,
            ratedContestCount: 47,
            isPartialScan: false,
            heatmapCounts: counts,
            earliestScannedSubmission: calendar.date(byAdding: .day, value: -700, to: now),
            heatmapWeeks: 26,
            ratingHistory: history,
            lastContest: ContestResult(
                contestId: last.contestId,
                name: last.contestName,
                date: last.date,
                rank: last.rank,
                oldRating: last.rating - 42,
                newRating: last.rating
            ),
            upcoming: [
                UpcomingContest(
                    id: 2_261,
                    name: "WorldQuant Round 1 (Div. 1 + Div. 2)",
                    start: now.addingTimeInterval(3 * 86_400 + 4 * 3_600),
                    durationSeconds: 7_200
                ),
                UpcomingContest(
                    id: 2_277,
                    name: "Codeforces Round (Div. 2)",
                    start: now.addingTimeInterval(9 * 86_400 + 2 * 3_600),
                    durationSeconds: 7_200
                ),
            ],
            generatedAt: now
        )
    }
}
