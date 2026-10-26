import AppIntents
import SwiftUI

/// "value over caption" pair used across the widgets.
struct WidgetMetric: View {
    let value: String
    let label: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// Shown when there is nothing to draw.
struct WidgetMessageView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Wired to `RefreshIntent`, which refetches and reloads this timeline.
struct WidgetRefreshButton: View {
    let handle: String

    var body: some View {
        Button(intent: RefreshIntent(handle: handle)) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

struct WidgetStaleBadge: View {
    var body: some View {
        Image(systemName: "wifi.slash")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}
