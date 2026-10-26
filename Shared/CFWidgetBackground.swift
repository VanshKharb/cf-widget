import SwiftUI

/// Shared widget backdrop: the system background with a soft rank-coloured glow
/// in the corner, so all three widgets look like one product.
struct CFWidgetBackground: View {
    var accent: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)

            RadialGradient(
                colors: [accent.opacity(colorScheme == .dark ? 0.34 : 0.16), accent.opacity(0)],
                center: .topLeading,
                startRadius: 1,
                endRadius: 210
            )

            RadialGradient(
                colors: [accent.opacity(colorScheme == .dark ? 0.16 : 0.07), accent.opacity(0)],
                center: .bottomTrailing,
                startRadius: 1,
                endRadius: 160
            )
        }
    }
}
