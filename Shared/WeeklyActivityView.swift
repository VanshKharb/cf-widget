import SwiftUI

/// Submissions per week as a bar chart.
///
/// A heatmap is seven rows tall, so a large widget has vertical space it can
/// never fill with one. This reuses the same weekly totals and fills it with
/// information instead of whitespace.
struct WeeklyActivityView: View {
    let grid: HeatmapGrid
    var accent: Color = .green

    private var totals: [Int] {
        grid.weeks.map { $0.reduce(0) { $0 + $1.count } }
    }

    var body: some View {
        GeometryReader { proxy in
            let values = totals
            let peak = max(values.max() ?? 0, 1)
            let barSpacing: CGFloat = 2
            let barWidth = (proxy.size.width - barSpacing * CGFloat(max(values.count - 1, 0))) / CGFloat(max(values.count, 1))

            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    let ratio = CGFloat(value) / CGFloat(peak)
                    // Empty weeks still get a hairline so the axis reads as a timeline.
                    let height = value > 0
                        ? max(ratio * proxy.size.height, 2)
                        : 1.5

                    RoundedRectangle(cornerRadius: barWidth / 4, style: .continuous)
                        .fill(value > 0 ? accent.opacity(0.35 + 0.55 * ratio) : HeatmapPalette.empty)
                        .frame(width: max(barWidth, 1), height: height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}
