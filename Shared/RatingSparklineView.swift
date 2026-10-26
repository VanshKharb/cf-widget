import SwiftUI

/// Compact rating curve for widgets: no axes, just the shape of the climb.
struct RatingSparklineView: View {
    let points: [RatingPoint]
    var accent: Color = .green
    var lineWidth: CGFloat = 1.8
    var showsFill: Bool = true
    var showsLastPoint: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let values = points.map { Double($0.rating) }

            if values.count >= 2, let low = values.min(), let high = values.max() {
                let inset = lineWidth / 2 + 0.5
                let width = max(proxy.size.width - inset * 2, 1)
                let height = max(proxy.size.height - inset * 2, 1)
                let span = max(high - low, 1)
                let step = width / CGFloat(values.count - 1)

                let line = Path { path in
                    for (index, value) in values.enumerated() {
                        let point = CGPoint(
                            x: inset + CGFloat(index) * step,
                            y: inset + height - CGFloat((value - low) / span) * height
                        )
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                }

                ZStack {
                    if showsFill {
                        line
                            .closedToBottom(inset: inset, height: height)
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.35), accent.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                    line.stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                    if showsLastPoint, let last = values.last {
                        Circle()
                            .fill(accent)
                            .frame(width: lineWidth * 2.2, height: lineWidth * 2.2)
                            .position(
                                x: inset + width,
                                y: inset + height - CGFloat((last - low) / span) * height
                            )
                    }
                }
            } else {
                // One contest (or none) is not a curve; a dashed baseline reads
                // better than an empty box.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                }
                .stroke(accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
    }
}

private extension Path {
    /// Closes the curve down to the baseline so it can be filled as an area.
    func closedToBottom(inset: CGFloat, height: CGFloat) -> Path {
        var copy = self
        let lastX = copy.currentPoint?.x ?? inset
        copy.addLine(to: CGPoint(x: lastX, y: inset + height))
        copy.addLine(to: CGPoint(x: inset, y: inset + height))
        copy.closeSubpath()
        return copy
    }
}
