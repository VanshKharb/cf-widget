import WidgetKit

/// Widget kinds. Shared so the app can reload exactly the timelines it changed.
enum WidgetKind {
    static let stats = "CFStatsWidget"
    static let heatmap = "CFHeatmapWidget"
    static let contests = "CFContestsWidget"

    static let all = [stats, heatmap, contests]
}

enum WidgetReload {
    /// Called by the app after a refresh so the Home Screen catches up straight away.
    static func all() {
        for kind in WidgetKind.all {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
