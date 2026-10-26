import SwiftUI
import WidgetKit

@main
struct HomejudgeBundle: WidgetBundle {
    var body: some Widget {
        CFStatsWidget()
        CFHeatmapWidget()
        CFContestsWidget()
    }
}
