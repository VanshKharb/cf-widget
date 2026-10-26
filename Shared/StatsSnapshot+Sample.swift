import Foundation

extension StatsSnapshot {
    /// Deterministic fake data for widget placeholders and previews.
    ///
    /// Everything here is internally consistent on purpose: the rating, the peak
    /// and the rank title all sit inside the same Codeforces band, so a real
    /// competitor looking at a screenshot won't spot that it's sample data.
    static var sample: StatsSnapshot {
        let now = Date()
        let calendar = Calendar.codeforcesUTC

        // A small LCG, so the preview picture never changes between builds.
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func next(_ bound: Int) -> Int {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((seed >> 33) % UInt64(bound))
        }

        var counts: [String: Int] = [:]
        for offset in 0..<190 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            let weekend = weekday == 1 || weekday == 7
            let roll = next(10)
            let value = roll > (weekend ? 4 : 6) ? next(8) + 1 : 0
            if value > 0 { counts[DayKey.string(from: date)] = value }
        }

        // A believable climb ending at 1804, peaking at 1868. Both are inside the
        // Expert band (1600–1899), which is what `rank` and `maxRank` say.
        let ratings = [
            1441, 1478, 1452, 1509, 1562, 1540, 1597, 1643, 1618, 1672,
            1711, 1689, 1738, 1776, 1754, 1801, 1846, 1822, 1868, 1841,
            1793, 1834, 1779, 1804,
        ]

        var history: [RatingPoint] = []
        for (index, rating) in ratings.enumerated() {
            guard let date = calendar.date(byAdding: .day, value: -((ratings.count - index) * 19), to: now) else { continue }
            history.append(
                RatingPoint(
                    contestId: 2_200 + index,
                    date: date,
                    rating: rating,
                    contestName: "Codeforces Round \(1_100 + index) (Div. 2)",
                    rank: 1_412 - index * 14
                )
            )
        }

        let last = history.last!

        return StatsSnapshot(
            handle: "daily_cp",
            displayName: "Daily CP",
            avatarURL: nil,
            country: "India",
            organization: nil,
            rating: last.rating,
            maxRating: ratings.max(),
            rank: "expert",
            maxRank: "expert",
            contribution: 12,
            friendOfCount: 34,
            solvedCount: 438,
            acceptedSubmissions: 612,
            scannedSubmissions: 1_204,
            ratedContestCount: ratings.count,
            isPartialScan: false,
            heatmapCounts: counts,
            earliestScannedSubmission: calendar.date(byAdding: .day, value: -700, to: now),
            heatmapWeeks: 26,
            ratingHistory: history,
            lastContest: ContestResult(
                contestId: last.contestId,
                name: last.contestName,
                date: last.date,
                rank: 1_287,
                oldRating: 1_779,
                newRating: 1_804
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
