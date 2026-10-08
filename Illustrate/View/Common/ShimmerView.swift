// MARK: - ShimmerView.swift

// A reusable shimmer placeholder view for loading states.
//
// Features:
// - Subtle pulsing background
// - Top-to-bottom scanning gradient effect
// - Staggered delay support for multiple items
//
// ## Usage
// ```swift
// ShimmerView()
//     .aspectRatio(16/9, contentMode: .fit)
//
// // With staggered delay for lists
// ForEach(0..<3, id: \.self) { index in
//     ShimmerView(delay: Double(index) * 0.1)
// }
// ```

import SwiftUI

/// A subtle pulsing placeholder view with top-to-bottom scanning effect.
struct ShimmerView: View {
    let delay: Double
    var cornerRadius: CGFloat

    @State private var isAnimating = false
    @State private var scanPosition: CGFloat = 0

    init(delay: Double = 0, cornerRadius: CGFloat = 8) {
        self.delay = delay
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.secondary.opacity(isAnimating ? 0.1 : 0.05))
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.secondary.opacity(0.08), location: 0.2),
                            .init(color: Color.secondary.opacity(0.16), location: 0.5),
                            .init(color: Color.secondary.opacity(0.08), location: 0.8),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.9)
                    .offset(y: -geometry.size.height * 0.4 + scanPosition * geometry.size.height * 1.8)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
            .animation(
                .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
                withAnimation(
                    .timingCurve(0.6, 0, 0.4, 1, duration: 1.4)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                ) {
                    scanPosition = 1
                }
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        ShimmerView()
            .frame(width: 200, height: 120)

        HStack(spacing: 12) {
            ForEach(0 ..< 3, id: \.self) { index in
                ShimmerView(delay: Double(index) * 0.1)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .frame(width: 300)
    }
    .padding()
}
