// MARK: - FadeInHelper.swift

// Reusable fade-in animation modifier for async-loaded content.
//
// Provides a consistent fade-in animation for content that loads asynchronously,
// such as images from iCloud, network, or disk.
//
// ## Usage
// Apply `.fadeInOnLoad()` to content that should animate when it appears:
//
// ```swift
// Image(nsImage: loadedImage)
//     .fadeInOnLoad()
// ```
//
// ## Configuration
// - Default duration: 0.2 seconds
// - Default curve: easeIn
// - Can customize with parameters

import SwiftUI

// MARK: - Fade-In View Modifier

/// A view modifier that animates content with a fade-in effect.
struct FadeInModifier: ViewModifier {
    let duration: Double

    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: duration)) {
                    opacity = 1
                }
            }
    }
}

extension View {
    /// Applies a fade-in animation when the view appears.
    ///
    /// Use this for async-loaded content like images to create a smooth transition
    /// from loading state to visible content.
    ///
    /// - Parameter duration: Animation duration in seconds. Default is 0.2s.
    /// - Returns: A view with fade-in animation applied.
    func fadeInOnLoad(duration: Double = 0.2) -> some View {
        modifier(FadeInModifier(duration: duration))
    }
}

// MARK: - Animated State Change Helper

extension View {
    /// Wraps a state change in a fade animation.
    ///
    /// Use this when you need to animate the appearance of content
    /// that depends on a state change from an async operation.
    ///
    /// Example:
    /// ```swift
    /// .task {
    ///     let image = await loadImage()
    ///     animateFadeIn { self.loadedImage = image }
    /// }
    /// ```
    @MainActor
    static func animateFadeIn(duration: Double = 0.2, _ action: @escaping () -> Void) {
        withAnimation(.easeIn(duration: duration)) {
            action()
        }
    }
}
