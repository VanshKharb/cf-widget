import SwiftUI

// Small badges shared by the app and the widgets.

struct RankPill: View {
    let rank: String?

    var body: some View {
        let color = RankStyle.color(for: rank)
        Text(RankStyle.title(for: rank))
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }
}

struct DeltaBadge: View {
    let delta: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 8, weight: .bold))
            Text("\(delta >= 0 ? "+" : "")\(delta)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(delta >= 0 ? Color.green : Color.red)
    }
}

struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill").font(.system(size: 9))
            Text("\(days)d")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(days > 0 ? Color.orange : Color.secondary)
    }
}
