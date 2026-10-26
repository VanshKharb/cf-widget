import Foundation

/// Standalone harness for the Foundation-only core (`Shared/` minus the SwiftUI
/// files). It hits the real Codeforces API and asserts the derived values are
/// self-consistent. Run it with `Tools/verify.sh`.
///
///     ./Tools/verify.sh
@main
struct Verify {
    final class Report {
        private(set) var failures = 0
        private(set) var checks = 0

        func check(_ condition: Bool, _ label: String, detail: @autoclosure () -> String = "") {
            checks += 1
            if condition {
                print("  ok   \(label)")
            } else {
                failures += 1
                let extra = detail()
                print("  FAIL \(label)\(extra.isEmpty ? "" : " — \(extra)")")
            }
        }

        func section(_ title: String) { print("\n\(title)") }
    }

    static func main() async {
        let report = Report()

        testFormatting(report)
        testHeatmapGeometry(report)
        testStreaks(report)
        testMerging(report)
        testStore(report)
        await testLiveAPI(report)

        print("\n\(report.checks - report.failures)/\(report.checks) checks passed")
        if report.failures > 0 {
            print("\(report.failures) FAILED")
            exit(1)
        }
    }

    // MARK: Pure helpers

    static func testFormatting(_ report: Report) {
        report.section("Formatting")

        report.check(Handle.normalize("  @Tourist \n") == "tourist", "handle normalisation strips @ and whitespace")
        report.check(Handle.normalize("") == "", "empty handle stays empty")

        report.check(Fmt.compact(438) == "438", "compact small number", detail: Fmt.compact(438))
        report.check(Fmt.compact(1_204) == "1.2k", "compact thousands", detail: Fmt.compact(1_204))
        report.check(Fmt.compact(1_000) == "1k", "compact exact thousand", detail: Fmt.compact(1_000))
        report.check(Fmt.compact(2_500_000) == "2.5M", "compact millions", detail: Fmt.compact(2_500_000))

        let now = Date()
        report.check(Fmt.countdown(to: now.addingTimeInterval(90), now: now) == "in 1m", "countdown minutes")
        report.check(Fmt.countdown(to: now.addingTimeInterval(3 * 86_400 + 4 * 3_600), now: now) == "in 3d 4h", "countdown days")
        report.check(Fmt.countdown(to: now.addingTimeInterval(-10), now: now) == "starting now", "countdown past")

        report.check(DayKey.date(from: DayKey.string(from: now)) != nil, "day key round-trips")
        report.check(DayKey.string(from: Date(timeIntervalSince1970: 0)) == "1970-01-01", "day key is UTC", detail: DayKey.string(from: Date(timeIntervalSince1970: 0)))
    }

    // MARK: Grid geometry

    static func testHeatmapGeometry(_ report: Report) {
        report.section("Heatmap geometry")

        let now = Date()
        for weekCount in [1, 18, 26, 53] {
            let grid = HeatmapGrid.build(counts: [:], earliestSubmission: nil, now: now, weekCount: weekCount)
            report.check(grid.weeks.count == weekCount, "\(weekCount) weeks produces \(weekCount) columns", detail: "got \(grid.weeks.count)")
            report.check(grid.weeks.allSatisfy { $0.count == 7 }, "\(weekCount) weeks: every column has 7 days")
        }

        let grid = HeatmapGrid.build(counts: [:], earliestSubmission: nil, now: now, weekCount: 26)
        let calendar = Calendar.codeforcesUTC
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today) // 1 = Sunday

        // Today must sit in the final column, at its real weekday slot.
        let lastColumn = grid.weeks[25]
        report.check(lastColumn[weekday - 1].date == today, "today is in the last column at the right weekday")
        report.check(!lastColumn[weekday - 1].isFuture, "today is not marked future")

        // Everything after today in that column is a placeholder.
        let afterToday = lastColumn.filter { $0.date > today }
        report.check(afterToday.allSatisfy { $0.isFuture }, "days after today are future")
        report.check(afterToday.allSatisfy { $0.count == 0 }, "future days never carry a count")

        // Purely future days must never register as activity.
        let futureOnly = HeatmapGrid.build(
            counts: [DayKey.string(from: calendar.date(byAdding: .day, value: 2, to: today)!) : 5],
            earliestSubmission: nil,
            now: now,
            weekCount: 4
        )
        report.check(futureOnly.totalSubmissions == 0, "future day counts are ignored")
    }

    // MARK: Streaks

    static func testStreaks(_ report: Report) {
        report.section("Streaks")

        let now = Date()
        let calendar = Calendar.codeforcesUTC
        let today = calendar.startOfDay(for: now)
        func key(_ daysAgo: Int) -> String {
            DayKey.string(from: calendar.date(byAdding: .day, value: -daysAgo, to: today)!)
        }

        let active = HeatmapGrid.build(
            counts: [key(0): 3, key(1): 1, key(2): 4, key(10): 1, key(11): 1, key(12): 1, key(13): 1, key(14): 1],
            earliestSubmission: nil,
            now: now,
            weekCount: 8
        )
        report.check(active.currentStreak == 3, "current streak counts back from today", detail: "got \(active.currentStreak)")
        report.check(active.longestStreak == 5, "longest streak finds the longer run", detail: "got \(active.longestStreak)")
        report.check(active.activeDays == 8, "active days counted", detail: "got \(active.activeDays)")
        report.check(active.totalSubmissions == 13, "submission total summed", detail: "got \(active.totalSubmissions)")
        report.check(active.maxCount == 4, "max per day found", detail: "got \(active.maxCount)")

        // A quiet today should not wipe out the streak until tomorrow.
        let quietToday = HeatmapGrid.build(
            counts: [key(1): 2, key(2): 2],
            earliestSubmission: nil,
            now: now,
            weekCount: 8
        )
        report.check(quietToday.currentStreak == 2, "inactive today keeps yesterday's streak", detail: "got \(quietToday.currentStreak)")

        let dormant = HeatmapGrid.build(counts: [:], earliestSubmission: nil, now: now, weekCount: 8)
        report.check(dormant.currentStreak == 0, "no activity means no streak")
        report.check(dormant.longestStreak == 0, "no activity means no longest streak")
    }

    // MARK: Merging

    static func testMerging(_ report: Report) {
        report.section("Snapshot merging")

        let now = Date()
        let calendar = Calendar.codeforcesUTC
        func key(_ daysAgo: Int) -> String {
            DayKey.string(from: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        }

        func make(
            rating: Int,
            maxRating: Int,
            solved: Int,
            scanned: Int,
            partial: Bool,
            counts: [String: Int],
            earliestDaysAgo: Int,
            generatedAt: Date
        ) -> StatsSnapshot {
            StatsSnapshot(
                handle: "vansh", displayName: "Vansh", avatarURL: nil, country: nil, organization: nil,
                rating: rating, maxRating: maxRating, rank: "specialist", maxRank: "candidate master",
                contribution: 5, friendOfCount: 1,
                solvedCount: solved, acceptedSubmissions: solved + 174, scannedSubmissions: scanned,
                ratedContestCount: 47, isPartialScan: partial,
                heatmapCounts: counts,
                earliestScannedSubmission: calendar.date(byAdding: .day, value: -earliestDaysAgo, to: now),
                heatmapWeeks: 26,
                ratingHistory: [], lastContest: nil, upcoming: [],
                generatedAt: generatedAt
            )
        }

        // The app's accurate, slightly stale scan.
        let full = make(
            rating: 1500, maxRating: 2412, solved: 438, scanned: 5499, partial: false,
            counts: [key(30): 3, key(31): 1], earliestDaysAgo: 400,
            generatedAt: now.addingTimeInterval(-3_600)
        )

        // A widget's fresh but shallow refresh.
        let light = make(
            rating: 1560, maxRating: 2412, solved: 120, scanned: 1_200, partial: true,
            counts: [key(0): 4, key(30): 5], earliestDaysAgo: 20,
            generatedAt: now
        )

        let merged = full.merging(newer: light)
        report.check(merged.solvedCount == 438, "merge keeps the full scan's solved count", detail: "got \(merged.solvedCount)")
        report.check(!merged.isPartialScan, "merge keeps the complete-scan flag", detail: "partial=\(merged.isPartialScan)")
        report.check(merged.scannedSubmissions == 5499, "merge keeps the wider scan's coverage")
        report.check(merged.rating == 1560, "merge takes the newer rating")
        report.check(merged.maxRating == 2412, "merge keeps the highest max rating")
        report.check(merged.heatmapCounts[key(0)] == 4, "merge picks up new days from the newer scan")
        report.check(merged.heatmapCounts[key(31)] == 1, "merge retains old days the newer scan never saw")
        report.check(merged.heatmapCounts[key(30)] == 5, "merge keeps the larger count for a shared day")
        report.check(merged.generatedAt == now, "merge takes the newer timestamp")
        report.check(merged.earliestScannedSubmission == full.earliestScannedSubmission, "merge keeps the earliest submission")

        let reversed = light.merging(newer: full)
        report.check(reversed.solvedCount == 438, "merging a fuller scan in still picks the fuller count", detail: "got \(reversed.solvedCount)")

        let other = make(rating: 900, maxRating: 900, solved: 5, scanned: 5, partial: false, counts: [:], earliestDaysAgo: 5, generatedAt: now)
        report.check(full.merging(newer: other).handle == "vansh", "merging a different handle is rejected")

        // Store level: saving a light scan must not shrink the cached count.
        SharedStore.removeAll()
        SharedStore.save(full)
        SharedStore.save(light)
        let cached = SharedStore.snapshot(for: "vansh")?.solvedCount
        report.check(cached == 438, "saving a light scan through the store preserves the full count", detail: "got \(String(describing: cached))")
        SharedStore.removeAll()
    }

    // MARK: Cache round trip

    static func testStore(_ report: Report) {
        report.section("Snapshot cache")

        let sample = StatsSnapshot.sample
        SharedStore.save(sample)

        guard let loaded = SharedStore.snapshot(for: sample.handle) else {
            report.check(false, "snapshot survives a save/load round trip")
            return
        }

        report.check(true, "snapshot survives a save/load round trip")
        report.check(loaded.handle == sample.handle, "handle preserved")
        report.check(loaded.solvedCount == sample.solvedCount, "solved count preserved")
        report.check(loaded.ratingHistory.count == sample.ratingHistory.count, "rating history preserved")
        report.check(loaded.heatmapCounts == sample.heatmapCounts, "heatmap counts preserved")

        // Dates go through ISO8601, so allow sub-second drift.
        let drift = abs(loaded.generatedAt.timeIntervalSince(sample.generatedAt))
        report.check(drift < 1, "generatedAt survives encoding", detail: "drift \(drift)s")

        report.check(SharedStore.snapshot(for: "  \(sample.handle.uppercased()) ") != nil, "cache lookup normalises the handle")

        // Cache must stay bounded.
        for index in 0..<10 {
            let extra = StatsSnapshot(
                handle: "user\(index)", displayName: "User \(index)", avatarURL: nil, country: nil, organization: nil,
                rating: 1_200, maxRating: 1_200, rank: "pupil", maxRank: "pupil", contribution: 0, friendOfCount: 0,
                solvedCount: 1, acceptedSubmissions: 1, scannedSubmissions: 1, ratedContestCount: 1, isPartialScan: false,
                heatmapCounts: [:], earliestScannedSubmission: nil, heatmapWeeks: 26, ratingHistory: [],
                lastContest: nil, upcoming: [], generatedAt: Date()
            )
            SharedStore.save(extra)
        }
        report.check(SharedStore.cachedHandles().count <= 4, "cache is capped at 4 handles", detail: "got \(SharedStore.cachedHandles().count)")

        SharedStore.removeAll()
        report.check(SharedStore.cachedHandles().isEmpty, "cache can be cleared")
    }

    // MARK: Live API

    static func testLiveAPI(_ report: Report) async {
        report.section("Live Codeforces API")

        do {
            let snapshot = try await SnapshotLoader.load(
                handle: "tourist",
                options: .init(scannedSubmissions: 10_000, heatmapWeeks: 26, includeContests: true, historyLimit: 60)
            )

            report.check(snapshot.handle == "tourist", "handle echoed back")
            report.check(snapshot.hasRating, "rating decoded", detail: "rating=\(String(describing: snapshot.rating))")
            report.check((snapshot.maxRating ?? 0) >= (snapshot.rating ?? 0), "max rating is at least current rating")
            report.check(snapshot.rank == "legendary grandmaster", "rank decoded", detail: String(describing: snapshot.rank))
            report.check(snapshot.ratedContestCount > 100, "contest history loaded", detail: "got \(snapshot.ratedContestCount)")
            report.check(snapshot.ratingHistory.count <= 60, "history respects the limit", detail: "got \(snapshot.ratingHistory.count)")
            report.check(snapshot.lastContest != nil, "last contest present")
            report.check(snapshot.nextContest != nil, "an upcoming contest was found", detail: "got \(snapshot.upcoming.count)")
            report.check(snapshot.upcoming.count <= 4, "upcoming contests are capped")

            if let last = snapshot.lastContest {
                report.check(last.newRating - last.oldRating == last.delta, "delta matches old/new rating")
                // The newest rating change must be the most recent contest.
                report.check(snapshot.ratingHistory.last?.contestId == last.contestId, "last contest is the newest rating change")
                report.check(snapshot.rating == last.newRating, "rating equals the latest rating change")
            }

            if let next = snapshot.nextContest {
                report.check(next.start > Date(), "next contest starts in the future")
            }

            report.check(snapshot.ratingHistory == snapshot.ratingHistory.sorted { $0.date < $1.date }, "history is chronological")

            // Independent re-derivation of the solved count from the raw payload.
            let api = CodeforcesAPI.shared
            let raw = try await api.submissions(handle: "tourist", count: 10_000)
            var independent = Set<String>()
            for submission in raw where submission.isAccepted {
                if let key = submission.problemKey { independent.insert(key) }
            }
            report.check(snapshot.solvedCount == independent.count, "solved count is independently reproducible", detail: "snapshot=\(snapshot.solvedCount) recomputed=\(independent.count)")
            report.check(snapshot.scannedSubmissions == raw.count, "scanned count matches the payload", detail: "snapshot=\(snapshot.scannedSubmissions) raw=\(raw.count)")
            // tourist has fewer than 10 000 submissions, so this scan saw everything.
            report.check(!snapshot.isPartialScan, "a scan that saw every submission is not partial", detail: "scanned=\(snapshot.scannedSubmissions)")
            report.check(!snapshot.heatmapCounts.isEmpty, "heatmap counts were produced")

            // Heatmap totals must equal the submissions that fall inside the window.
            let grid = snapshot.heatmap(weeks: 26)
            report.check(grid.totalSubmissions == snapshot.heatmapCounts.values.reduce(0, +), "heatmap total equals stored counts", detail: "grid=\(grid.totalSubmissions) stored=\(snapshot.heatmapCounts.values.reduce(0, +))")
            report.check(grid.weeks.count == 26, "heatmap has 26 columns")
            report.check(grid.weeks.flatMap { $0 }.count == 182, "heatmap has 182 cells")
            report.check(!grid.isTruncated, "a full scan is not truncated")

            print("\n  tourist: rating \(snapshot.rating.map(String.init) ?? "–") · solved \(snapshot.solvedCount) · scanned \(snapshot.scannedSubmissions) · contests \(snapshot.ratedContestCount)")
            print("  heatmap \(grid.totalSubmissions) submissions, streak \(grid.currentStreak)d (longest \(grid.longestStreak)d), \(grid.activeDays) active days")
            if let last = snapshot.lastContest {
                print("  last: \(last.name.prefix(46)) → \(last.delta >= 0 ? "+" : "")\(last.delta)")
            }
            if let next = snapshot.nextContest {
                print("  next: \(next.name.prefix(46)) \(Fmt.countdown(to: next.start))")
            }
        } catch {
            report.check(false, "full snapshot load", detail: "\(error)")
        }

        // A light scan should still produce a usable snapshot for the widget.
        do {
            let light = try await SnapshotLoader.load(handle: "tourist", options: .light)
            report.check(light.solvedCount > 0, "light scan yields a solved count", detail: "got \(light.solvedCount)")
            report.check(light.isPartialScan, "light scan is flagged partial")
            print("  light scan: solved \(light.solvedCount) from \(light.scannedSubmissions) submissions (partial: \(light.isPartialScan))")
        } catch {
            report.check(false, "light snapshot load", detail: "\(error)")
        }

        // Error mapping.
        do {
            _ = try await SnapshotLoader.load(handle: "zzz_no_such_handle_9999", options: .light)
            report.check(false, "unknown handle should throw")
        } catch let error as CodeforcesError {
            report.check(error == .handleNotFound("zzz_no_such_handle_9999"), "unknown handle maps to handleNotFound", detail: "\(error)")
            report.check(error.errorDescription?.isEmpty == false, "error has a user-facing message")
        } catch {
            report.check(false, "unknown handle threw the wrong error type", detail: "\(error)")
        }

        do {
            _ = try await SnapshotLoader.load(handle: "   ", options: .light)
            report.check(false, "empty handle should throw")
        } catch let error as CodeforcesError {
            report.check(error == .emptyHandle, "empty handle maps to emptyHandle", detail: "\(error)")
        } catch {
            report.check(false, "empty handle threw the wrong error type", detail: "\(error)")
        }

        // Handles are case-insensitive upstream and normalised locally.
        do {
            let upper = try await SnapshotLoader.load(handle: "TOURIST", options: .light)
            report.check(upper.handle == "tourist", "uppercase handle is normalised", detail: upper.handle)
        } catch {
            report.check(false, "uppercase handle load", detail: "\(error)")
        }
    }
}
