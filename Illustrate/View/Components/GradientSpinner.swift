import SwiftUI

struct GradientSpinner: View {
    var color: Color = .accentColor
    var lineWidth: CGFloat = 1.2
    #if os(iOS)
    var size: CGFloat = 14
    #else
    var size: CGFloat = 12
    #endif
    var duration = 0.6

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .stroke(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: color.opacity(0), location: 0),
                        .init(color: color.opacity(1), location: 1),
                    ]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                .linear(duration: duration).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .frame(width: size, height: size)
            .onAppear { isAnimating = true }
            .accessibilityLabel("Loading")
            .accessibilityAddTraits(.updatesFrequently)
    }
}
