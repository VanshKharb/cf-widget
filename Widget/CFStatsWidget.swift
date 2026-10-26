import SwiftUI
import WidgetKit

struct CFStatsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.stats, intent: HandleIntent.self, provider: CFProvider()) { entry in
            CFStatsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    CFWidgetBackground(accent: RankStyle.color(for: entry.snapshot?.rank))
                }
        }
        .configurationDisplayName("Codeforces Stats")
        .description("Rating, rank, solved count and your latest contest result.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct CFStatsWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CFEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                if let snapshot = entry.snapshot {
                    StatsAccessoryCircular(snapshot: snapshot)
                } else {
                    AccessoryUnavailable()
                }

            case .accessoryRectangular:
                if let snapshot = entry.snapshot {
                    StatsAccessoryRectangular(snapshot: snapshot)
                } else {
                    AccessoryUnavailable(circular: false)
                }

            case .accessoryInline:
                Text(entry.snapshot.map(inlineSummary) ?? "Codeforces unavailable")

            case .systemMedium:
                if let snapshot = entry.snapshot {
                    StatsMediumView(snapshot: snapshot, handle: entry.handle, isStale: entry.isStale)
                } else {
                    unavailable
                }

            default:
                if let snapshot = entry.snapshot {
                    StatsSmallView(snapshot: snapshot, handle: entry.handle, isStale: entry.isStale)
                } else {
                    unavailable
                }
            }
        }
    }

    private var unavailable: some View {
        WidgetMessageView(
            title: "No stats yet",
            message: entry.errorMessage ?? "Open the app and save a handle.",
            systemImage: "person.crop.circle.badge.questionmark"
        )
    }

    private func inlineSummary(_ snapshot: StatsSnapshot) -> String {
        let rating = snapshot.rating.map { "\($0) \(RankStyle.title(for: snapshot.rank))" } ?? "Unrated"
        return "CF \(snapshot.handle) · \(rating) · \(snapshot.solvedCount) solved"
    }
}

// MARK: - Small

struct StatsSmallView: View {
    let snapshot: StatsSnapshot
    let handle: String
    var isStale: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                // The handle matters more here than a cryptic rank initial.
                Text(snapshot.handle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                if isStale { WidgetStaleBadge() }
                Spacer(minLength: 0)
                WidgetRefreshButton(handle: handle)
            }

            Spacer(minLength: 4)

            Text(snapshot.rating.map(String.init) ?? "–")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(RankStyle.color(for: snapshot.rank))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(RankStyle.title(for: snapshot.rank))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let last = snapshot.lastContest {
                DeltaBadge(delta: last.delta)
                    .padding(.top, 1)
            }

            Spacer(minLength: 6)

            Divider().opacity(0.5)

            HStack(spacing: 6) {
                Text("\(Fmt.compact(snapshot.solvedCount)) solved")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                StreakBadge(days: snapshot.currentStreak())
            }
        }
    }
}

// MARK: - Medium

struct StatsMediumView: View {
    let snapshot: StatsSnapshot
    let handle: String
    var isStale: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(snapshot.handle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                RankPill(rank: snapshot.rank)
                if isStale { WidgetStaleBadge() }
                Spacer(minLength: 0)
                if let last = snapshot.lastContest {
                    DeltaBadge(delta: last.delta)
                }
                WidgetRefreshButton(handle: handle)
            }

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(snapshot.rating.map(String.init) ?? "–")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(RankStyle.color(for: snapshot.rank))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text("max \(snapshot.maxRating.map(String.init) ?? "–") · \(snapshot.ratedContestCount) contests")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                RatingSparklineView(points: snapshot.ratingHistory, accent: RankStyle.color(for: snapshot.rank))
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
            }

            Divider().opacity(0.5)

            HStack(spacing: 4) {
                WidgetMetric(value: Fmt.compact(snapshot.solvedCount), label: "solved")
                Spacer(minLength: 4)
                WidgetMetric(
                    value: Fmt.compact(snapshot.scannedSubmissions),
                    label: snapshot.isPartialScan ? "recent subs" : "submissions"
                )
                Spacer(minLength: 4)
                WidgetMetric(value: "\(snapshot.currentStreak())d", label: "streak", tint: .orange)
            }
        }
    }
}

// MARK: - Lock screen

struct StatsAccessoryCircular: View {
    let snapshot: StatsSnapshot

    var body: some View {
        Gauge(value: RankStyle.progress(for: snapshot.rating) ?? 1) {
            Text("CF")
        } currentValueLabel: {
            Text(snapshot.rating.map(String.init) ?? "–")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(RankStyle.color(for: snapshot.rank))
    }
}

struct StatsAccessoryRectangular: View {
    let snapshot: StatsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                Text(snapshot.handle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }

            Text("\(snapshot.rating.map(String.init) ?? "unrated") · \(RankStyle.title(for: snapshot.rank))")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Text("\(Fmt.compact(snapshot.solvedCount)) solved · \(snapshot.currentStreak())d streak")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AccessoryUnavailable: View {
    var circular: Bool = true

    var body: some View {
        if circular {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
        } else {
            Text("Codeforces unavailable")
        }
    }
}
