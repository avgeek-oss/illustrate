// MARK: - ScrollWheelComponents.swift

// macOS scroll wheel and trackpad gesture handling.
//
// Captures native macOS scroll/pinch events for canvas zoom:
// - Scroll wheel: Pan the canvas
// - Pinch gesture: Zoom centered on cursor
// - Ctrl+scroll: Zoom (mouse wheel zoom)
//
// ## Mouse-Centered Zoom
// Zooming centers on the mouse position, not screen center.
// This provides a more natural zoom experience.
//
// ## Platform
// macOS only - iOS uses native SwiftUI gestures.

import SwiftUI

#if os(macOS)
import AppKit

/// NSView wrapper to capture scroll wheel and magnify gestures.
struct ScrollWheelCaptureView: NSViewRepresentable {
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGPoint
    @Binding var lastOffset: CGPoint
    let minScale: CGFloat
    let maxScale: CGFloat
    let viewSize: CGSize

    func makeNSView(context: Context) -> GestureNSView {
        let view = GestureNSView()
        view.onScroll = { [self] deltaX, deltaY, mouseLocation, modifiers in
            handleScroll(deltaX: deltaX, deltaY: deltaY, mouseLocation: mouseLocation, modifiers: modifiers)
        }
        view.onMagnify = { [self] magnification, mouseLocation in
            handleMagnify(magnification: magnification, mouseLocation: mouseLocation)
        }
        return view
    }

    func updateNSView(_ nsView: GestureNSView, context: Context) {
        nsView.onScroll = { [self] deltaX, deltaY, mouseLocation, modifiers in
            handleScroll(deltaX: deltaX, deltaY: deltaY, mouseLocation: mouseLocation, modifiers: modifiers)
        }
        nsView.onMagnify = { [self] magnification, mouseLocation in
            handleMagnify(magnification: magnification, mouseLocation: mouseLocation)
        }
    }

    private func handleScroll(
        deltaX: CGFloat,
        deltaY: CGFloat,
        mouseLocation: CGPoint,
        modifiers: NSEvent.ModifierFlags
    ) {
        if modifiers.contains(.command) || modifiers.contains(.option) {
            let zoomDelta = deltaY * 0.008

            guard abs(zoomDelta) > 0.001 else { return }

            let oldScale = scale
            let newScale = min(max(scale * (1 + zoomDelta), minScale), maxScale)

            if abs(newScale - oldScale) > 0.001 {
                let scaleRatio = newScale / oldScale

                let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
                let mouseRelativeToCenter = CGPoint(
                    x: mouseLocation.x - center.x,
                    y: mouseLocation.y - center.y
                )

                offset = CGPoint(
                    x: mouseRelativeToCenter.x * (1 - scaleRatio) + offset.x * scaleRatio,
                    y: mouseRelativeToCenter.y * (1 - scaleRatio) + offset.y * scaleRatio
                )
                lastOffset = offset
                scale = newScale
                lastScale = scale
            }
        }
    }

    private func handleMagnify(magnification: CGFloat, mouseLocation: CGPoint) {
        let oldScale = scale
        let newScale = min(max(scale * (1 + magnification), minScale), maxScale)

        guard abs(newScale - oldScale) > 0.001 else { return }

        let scaleRatio = newScale / oldScale

        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let mouseRelativeToCenter = CGPoint(
            x: mouseLocation.x - center.x,
            y: mouseLocation.y - center.y
        )

        offset = CGPoint(
            x: mouseRelativeToCenter.x * (1 - scaleRatio) + offset.x * scaleRatio,
            y: mouseRelativeToCenter.y * (1 - scaleRatio) + offset.y * scaleRatio
        )
        lastOffset = offset
        scale = newScale
        lastScale = scale
    }
}

class GestureNSView: NSView {
    var onScroll: ((CGFloat, CGFloat, CGPoint, NSEvent.ModifierFlags) -> Void)?
    var onMagnify: ((CGFloat, CGPoint) -> Void)?
    private var scrollMonitor: Any?
    private var magnifyMonitor: Any?

    override var acceptsFirstResponder: Bool {
        false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }

        if let monitor = magnifyMonitor {
            NSEvent.removeMonitor(monitor)
            magnifyMonitor = nil
        }

        if window != nil {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self else { return event }

                let locationInWindow = event.locationInWindow
                let locationInView = convert(locationInWindow, from: nil)

                if bounds.contains(locationInView) {
                    let flippedLocation = CGPoint(x: locationInView.x, y: bounds.height - locationInView.y)
                    onScroll?(event.scrollingDeltaX, event.scrollingDeltaY, flippedLocation, event.modifierFlags)
                }

                return event
            }

            magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
                guard let self else { return event }

                let locationInWindow = event.locationInWindow
                let locationInView = convert(locationInWindow, from: nil)

                if bounds.contains(locationInView) {
                    let flippedLocation = CGPoint(x: locationInView.x, y: bounds.height - locationInView.y)
                    onMagnify?(event.magnification, flippedLocation)
                }

                return event
            }
        }
    }

    override func removeFromSuperview() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        if let monitor = magnifyMonitor {
            NSEvent.removeMonitor(monitor)
            magnifyMonitor = nil
        }
        super.removeFromSuperview()
    }

    deinit {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = magnifyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
#endif
