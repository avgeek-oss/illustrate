// MARK: - HoverTrackingView.swift

// Custom hover tracking for macOS that works reliably inside ScrollViews.
//
// The standard SwiftUI `.onHover` modifier can fail to trigger inside ScrollViews
// on macOS. This component uses NSTrackingArea directly for reliable hover detection.
//
// ## Usage
// ```swift
// @State private var isHovered = false
//
// SomeView()
//     .hoverTracking(isHovered: $isHovered)
// ```

import SwiftUI

#if os(macOS)
import AppKit

/// A transparent NSView that tracks mouse hover events.
class HoverTrackingNSView: NSView {
    var onHoverChanged: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrackingArea()
    }

    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }
}

/// NSViewRepresentable wrapper for HoverTrackingNSView.
struct HoverTrackingRepresentable: NSViewRepresentable {
    @Binding var isHovered: Bool

    func makeNSView(context: Context) -> HoverTrackingNSView {
        let view = HoverTrackingNSView()
        view.onHoverChanged = { hovering in
            DispatchQueue.main.async {
                isHovered = hovering
            }
        }
        return view
    }

    func updateNSView(_ nsView: HoverTrackingNSView, context: Context) {
        nsView.onHoverChanged = { hovering in
            DispatchQueue.main.async {
                isHovered = hovering
            }
        }
    }
}

/// A ViewModifier that adds reliable hover tracking on macOS.
struct HoverTrackingModifier: ViewModifier {
    @Binding var isHovered: Bool

    func body(content: Content) -> some View {
        content
            .background(
                HoverTrackingRepresentable(isHovered: $isHovered)
            )
    }
}

extension View {
    /// Adds reliable hover tracking that works inside ScrollViews on macOS.
    func hoverTracking(isHovered: Binding<Bool>) -> some View {
        modifier(HoverTrackingModifier(isHovered: isHovered))
    }
}

#else
/// iOS fallback - just use standard onHover (which does nothing on iOS anyway)
extension View {
    func hoverTracking(isHovered: Binding<Bool>) -> some View {
        onHover { hovering in
            isHovered.wrappedValue = hovering
        }
    }
}
#endif
