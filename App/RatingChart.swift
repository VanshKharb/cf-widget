import SwiftUI

/// Bigger version of the rating curve for the app: adds the value range on the
/// left, gridlines, and the date range underneath. The curve itself is the same
/// `RatingSparklineView` the widgets use, so the two never drift apart.
struct RatingChart: View {
    let points: [RatingPoint]
    var accent: Color = .blue

    private let plotHeight: CGFloat = 165

    var body: some View {
        if points.count < 2 {
            Text("Not enough rated contests yet.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 90)
        } else {
            let values = points.map(\.rating)
            let low = values.min() ?? 0
            let high = values.max() ?? 0

            VStack(spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(high)")
                        Spacer(minLength: 0)
                        Text("\(low)")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: plotHeight)

                    ZStack {
                        VStack(spacing: 0) {
                            Divider().opacity(0.35)
                            Spacer(minLength: 0)
                            Divider().opacity(0.35)
                            Spacer(minLength: 0)
                            Divider().opacity(0.35)
                        }

                        RatingSparklineView(
                            points: points,
                            accent: accent,
                            lineWidth: 2,
                            showsFill: true,
                            showsLastPoint: true
                        )
                    }
                    .frame(height: plotHeight)
                }

                HStack {
                    Text(points.first?.date.formatted(.dateTime.month(.abbreviated).year()) ?? "")
                    Spacer(minLength: 0)
                    Text(points.last?.date.formatted(.dateTime.month(.abbreviated).year()) ?? "")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 40)
            }
        }
    }
}
