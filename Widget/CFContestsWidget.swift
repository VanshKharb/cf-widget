import SwiftUI
import WidgetKit

struct CFContestsWidget: Widget {
    /// Codeforces' own blue.
    private static let accent = Color.adaptive(light: 0x1F5FE0, dark: 0x6E9BFF)

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.contests, intent: HandleIntent.self, provider: CFProvider()) { entry in
            CFContestsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground(accent: Self.accent)
                }
        }
        .configurationDisplayName("Contests")
        .description("The next Codeforces rounds with a live countdown.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CFContestsWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CFEntry

    private var accent: Color { Color.adaptive(light: 0x1F5FE0, dark: 0x6E9BFF) }

    var body: some View {
        if let next = entry.snapshot?.nextContest {
            if family == .systemMedium {
                ContestsMediumView(next: next, following: Array(entry.snapshot?.upcoming.dropFirst().prefix(2) ?? []), accent: accent)
            } else {
                ContestsSmallView(next: next, accent: accent)
            }
        } else if entry.snapshot != nil {
            WidgetMessageView(
                title: "No rounds scheduled",
                message: "Codeforces has not announced its next contest yet.",
                systemImage: "calendar.badge.checkmark"
            )
        } else {
            WidgetMessageView(
                title: "Codeforces unavailable",
                message: entry.errorMessage ?? "Open the app and save a handle.",
                systemImage: "calendar.badge.exclamationmark"
            )
        }
    }
}

struct ContestsSmallView: View {
    let next: UpcomingContest
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                Text("NEXT ROUND")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .kerning(0.4)
            }

            Text(next.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(4)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 2)

            // Relative text keeps ticking without needing a new timeline entry.
            Text(next.start, style: .relative)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(Fmt.shortDateTime(next.start))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct ContestsMediumView: View {
    let next: UpcomingContest
    let following: [UpcomingContest]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                Text("NEXT ROUND")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .kerning(0.4)
                Spacer(minLength: 0)
                Text(Fmt.duration(next.durationSeconds))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 10) {
                Text(next.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(next.start, style: .relative)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(Fmt.shortDateTime(next.start))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .layoutPriority(1)
            }

            if !following.isEmpty {
                Divider().opacity(0.5)

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(following) { contest in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(accent.opacity(0.6))
                                .frame(width: 4, height: 4)
                            Text(contest.name)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(contest.start, style: .relative)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
