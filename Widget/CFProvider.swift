import WidgetKit

/// What a widget renders for one point in time.
struct CFEntry: TimelineEntry {
    let date: Date
    let handle: String
    let snapshot: StatsSnapshot?
    let errorMessage: String?
    /// Cached data is being shown because the refresh failed.
    let isStale: Bool
}

/// One provider behind all three widgets. It prefers the snapshot the app left
/// in the shared container and only fetches for itself when that cache has gone
/// stale, which keeps background refreshes cheap and inside the widget's memory
/// budget.
struct CFProvider: AppIntentTimelineProvider {
    /// How long a cached snapshot is considered fresh.
    private let cacheLifetime: TimeInterval = 20 * 60

    /// Widgets are budgeted by the system; this is a request, not a guarantee.
    private let refreshInterval: TimeInterval = 30 * 60

    func placeholder(in context: Context) -> CFEntry {
        CFEntry(date: Date(), handle: StatsSnapshot.sample.handle, snapshot: .sample, errorMessage: nil, isStale: false)
    }

    func snapshot(for configuration: HandleIntent, in context: Context) async -> CFEntry {
        // The gallery renders instantly from canned data.
        guard !context.isPreview else { return placeholder(in: context) }
        return await entry(for: configuration)
    }

    func timeline(for configuration: HandleIntent, in context: Context) async -> Timeline<CFEntry> {
        Timeline(
            entries: [await entry(for: configuration)],
            policy: .after(Date().addingTimeInterval(refreshInterval))
        )
    }

    // MARK: - Loading

    private func entry(for configuration: HandleIntent) async -> CFEntry {
        let handle = resolvedHandle(configuration)
        let cached = SharedStore.snapshot(for: handle)

        if let cached, Date().timeIntervalSince(cached.generatedAt) < cacheLifetime {
            return CFEntry(date: Date(), handle: handle, snapshot: cached, errorMessage: nil, isStale: false)
        }

        do {
            let fresh = try await SnapshotLoader.load(handle: handle, options: .light)
            SharedStore.save(fresh)
            return CFEntry(date: Date(), handle: handle, snapshot: fresh, errorMessage: nil, isStale: false)
        } catch {
            // Stale data beats an error card, as long as we admit it is stale.
            return CFEntry(
                date: Date(),
                handle: handle,
                snapshot: cached,
                errorMessage: cached == nil ? error.localizedDescription : nil,
                isStale: cached != nil
            )
        }
    }

    /// An explicit handle in the widget's configuration wins; otherwise fall back
    /// to whatever the app last saved.
    private func resolvedHandle(_ configuration: HandleIntent) -> String {
        if let raw = configuration.handle {
            let normalized = Handle.normalize(raw)
            if !normalized.isEmpty { return normalized }
        }
        return SharedStore.primaryHandle
    }
}
