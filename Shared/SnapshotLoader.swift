import Foundation

/// Fetches everything needed for a snapshot and folds it into one value.
///
/// The app calls this with `.full` (up to 10 000 submissions, ~3.5 MB) so the
/// solved count is exact. Widgets call it with `.light` and only when the cache
/// has gone stale, so a background timeline refresh never pulls megabytes.
enum SnapshotLoader {
    struct Options: Sendable {
        var scannedSubmissions: Int
        var heatmapWeeks: Int
        var includeContests: Bool
        var historyLimit: Int

        static let full = Options(
            scannedSubmissions: 10_000,
            heatmapWeeks: 26,
            includeContests: true,
            historyLimit: 60
        )

        static let light = Options(
            scannedSubmissions: 1_200,
            heatmapWeeks: 26,
            includeContests: true,
            historyLimit: 60
        )
    }

    static func load(
        handle rawHandle: String,
        options: Options,
        now: Date = Date(),
        api: CodeforcesAPI = .shared
    ) async throws -> StatsSnapshot {
        let handle = Handle.normalize(rawHandle)
        guard !handle.isEmpty else { throw CodeforcesError.emptyHandle }

        async let userTask = api.userInfo(handle: handle)
        async let historyTask = api.ratingHistory(handle: handle)
        async let submissionsTask = api.submissions(handle: handle, count: options.scannedSubmissions)
        async let contestsTask = contests(options: options, api: api)

        // `user.info` is the request that legitimately fails for a bad handle, so
        // it is awaited first and its error is the one that surfaces.
        let user = try await userTask
        let history = try await historyTask
        let submissions = try await submissionsTask
        let contestList = await contestsTask

        return StatsSnapshot.build(
            handle: handle,
            user: user,
            ratingHistory: history,
            submissions: submissions,
            contests: contestList,
            now: now,
            heatmapWeeks: options.heatmapWeeks,
            historyLimit: options.historyLimit,
            scannedLimit: options.scannedSubmissions
        )
    }

    /// The contest list is a nice-to-have: if it fails, the rest of the snapshot
    /// is still worth showing, so the error is swallowed.
    private static func contests(options: Options, api: CodeforcesAPI) async -> [CFContest] {
        guard options.includeContests else { return [] }
        return (try? await api.contests()) ?? []
    }
}
