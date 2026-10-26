import SwiftUI
import WidgetKit

@main
struct CFWidgetBundle: WidgetBundle {
    var body: some Widget {
        CFStatsWidget()
        CFHeatmapWidget()
        CFContestsWidget()
    }
}
