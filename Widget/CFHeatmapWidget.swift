import SwiftUI
import WidgetKit

struct CFHeatmapWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.heatmap, intent: HandleIntent.self, provider: CFProvider()) { entry in
            CFHeatmapWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    CFWidgetBackground(accent: .green)
                }
        }
        .configurationDisplayName("Submission Heatmap")
        .description("Your Codeforces submission activity, GitHub style.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct CFHeatmapWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CFEntry

    /// A medium widget has room for about 18 weeks; a large one for 26.
    private var weeks: Int { family == .systemLarge ? 26 : 18 }

    private var spacing: CGFloat { family == .systemLarge ? 2.5 : 2 }

    var body: some View {
        if let snapshot = entry.snapshot {
            let grid = snapshot.heatmap(weeks: weeks)

            VStack(alignment: .leading, spacing: 6) {
                header(snapshot: snapshot, grid: grid)

                HeatmapGridView(
                    grid: grid,
                    spacing: spacing,
                    cornerRadius: family == .systemLarge ? 2 : 1.5,
                    // Dropping labels at medium size buys ~15pt of height, which
                    // is exactly what the grid is short of there.
                    showsMonthLabels: family == .systemLarge
                )
                .frame(maxHeight: .infinity)

                // Seven rows can never fill a 382pt-tall widget, so the large
                // size gets a weekly bar chart instead of a band of dead space.
                if family == .systemLarge {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SUBMISSIONS PER WEEK")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .kerning(0.4)
                        WeeklyActivityView(grid: grid)
                            .frame(height: 52)
                    }
                    metricsRow(snapshot: snapshot, grid: grid)
                }

                footer(grid: grid, snapshot: snapshot)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            WidgetMessageView(
                title: "No activity yet",
                message: entry.errorMessage ?? "Open the app and save a handle.",
                systemImage: "square.grid.3x3"
            )
        }
    }

    private func metricsRow(snapshot: StatsSnapshot, grid: HeatmapGrid) -> some View {
        HStack(spacing: 4) {
            WidgetMetric(value: Fmt.compact(snapshot.solvedCount), label: "solved")
            Spacer(minLength: 4)
            WidgetMetric(value: Fmt.compact(grid.totalSubmissions), label: "submissions")
            Spacer(minLength: 4)
            WidgetMetric(value: "\(grid.activeDays)", label: "active days")
            Spacer(minLength: 4)
            WidgetMetric(value: "\(grid.longestStreak)d", label: "best streak", tint: .orange)
        }
    }

    private func header(snapshot: StatsSnapshot, grid: HeatmapGrid) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text(snapshot.handle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text("\(Fmt.compact(snapshot.solvedCount)) solved\(snapshot.isPartialScan ? " (partial)" : "")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if entry.isStale { WidgetStaleBadge() }

            StreakBadge(days: grid.currentStreak)

            WidgetRefreshButton(handle: entry.handle)
        }
    }

    private func footer(grid: HeatmapGrid, snapshot: StatsSnapshot) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Text("\(Fmt.compact(grid.totalSubmissions)) submissions in \(weeks)w")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if grid.isTruncated {
                Text("· partial")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if family == .systemLarge {
                HeatmapLegend()
            } else {
                Text("\(grid.activeDays) active days")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
