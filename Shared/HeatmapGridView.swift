import SwiftUI

/// The contribution grid itself, shared by the widget and the app.
///
/// Cell size is derived from the space offered by the parent rather than being
/// hard-coded, because a widget's canvas differs per family and device.
struct HeatmapGridView: View {
    let grid: HeatmapGrid
    var spacing: CGFloat = 2
    var cornerRadius: CGFloat = 1.5
    var showsMonthLabels: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let columns = max(grid.weeks.count, 1)
            let labelHeight: CGFloat = showsMonthLabels ? 12 : 0
            let labelSpacing: CGFloat = showsMonthLabels ? 3 : 0

            let availableHeight = max(proxy.size.height - labelHeight - labelSpacing, 1)
            let availableWidth = max(proxy.size.width, 1)

            let widthPerCell = (availableWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let heightPerCell = (availableHeight - spacing * 6) / 7
            let cellSize = max(min(widthPerCell, heightPerCell), 1.5)
            let gridWidth = cellSize * CGFloat(columns) + spacing * CGFloat(columns - 1)

            VStack(alignment: .leading, spacing: labelSpacing) {
                if showsMonthLabels {
                    monthLabels(columnWidth: cellSize + spacing, columns: columns)
                }
                columnsView(cellSize: cellSize)
            }
            .frame(width: gridWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func columnsView(cellSize: CGFloat) -> some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, column in
                VStack(spacing: spacing) {
                    ForEach(column) { cell in
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(HeatmapPalette.color(count: cell.count, maxCount: grid.maxCount, isFuture: cell.isFuture))
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
    }

    /// A label above each column where the month changes.
    private func monthLabels(columnWidth: CGFloat, columns: Int) -> some View {
        let calendar = Calendar.codeforcesUTC
        var labels: [(index: Int, text: String)] = []
        var lastMonth = -1
        var lastPlaced = -99

        for (index, column) in grid.weeks.enumerated() {
            guard let first = column.first else { continue }
            let month = calendar.component(.month, from: first.date)
            guard month != lastMonth else { continue }
            lastMonth = month

            // Labels near the right edge would overflow, and labels closer than
            // three columns to the previous one overlap each other ("JulJul").
            if index <= columns - 3, index - lastPlaced >= 3 {
                labels.append((index, first.date.formatted(.dateTime.month(.abbreviated))))
                lastPlaced = index
            }
        }

        return ZStack(alignment: .topLeading) {
            Color.clear.frame(height: 12)
            ForEach(labels, id: \.index) { label in
                Text(label.text)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .offset(x: CGFloat(label.index) * columnWidth)
            }
        }
    }
}

/// "less ▢▢▢▢ more" legend.
struct HeatmapLegend: View {
    var body: some View {
        HStack(spacing: 3) {
            Text("less")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(HeatmapPalette.empty)
                .frame(width: 8, height: 8)

            ForEach(Array(HeatmapPalette.levels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(level)
                    .frame(width: 8, height: 8)
            }

            Text("more")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
