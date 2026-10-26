import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var handle: String
    var snapshot: StatsSnapshot?
    var isLoading = false
    var errorMessage: String?

    init() {
        let stored = SharedStore.primaryHandle
        handle = stored
        snapshot = SharedStore.snapshot(for: stored)
    }

    /// Cached data older than an hour is worth re-fetching on launch.
    var isStale: Bool {
        guard let snapshot else { return true }
        return Date().timeIntervalSince(snapshot.generatedAt) > 60 * 60
    }

    /// `true` on a fresh install: the field shows the demo handle, but it is not
    /// the user's own, so we neither fetch it nor present it as their data.
    var showsPlaceholderHandle: Bool { !SharedStore.hasSavedHandle }

    /// The expensive scan: up to 10 000 submissions, which is what makes the
    /// solved count exact rather than an estimate.
    func refresh() async {
        let target = Handle.normalize(handle)
        guard !target.isEmpty else {
            errorMessage = CodeforcesError.emptyHandle.errorDescription
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let fresh = try await SnapshotLoader.load(handle: target, options: .full)

            SharedStore.primaryHandle = target
            SharedStore.save(fresh)

            handle = target
            snapshot = fresh

            // The Home Screen should not have to wait for its own refresh.
            WidgetReload.all()
        } catch {
            errorMessage = error.localizedDescription
            // Show whatever we have for this handle rather than nothing.
            snapshot = SharedStore.snapshot(for: target)
        }

        isLoading = false
    }

    func refreshIfStale() async {
        guard !showsPlaceholderHandle else { return }
        guard snapshot == nil || isStale else { return }
        await refresh()
    }
}
