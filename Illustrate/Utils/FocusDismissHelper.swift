// MARK: - FocusDismissHelper.swift

// Utility for dismissing keyboard/focus when tapping outside text fields.
//
// SwiftUI on macOS doesn't automatically dismiss focus from TextFields when
// clicking elsewhere. This helper provides both:
// 1. A window-level modifier that handles focus dismissal globally
// 2. A view-level modifier for specific areas
//
// ## Usage
// Apply `.installFocusDismissHandler()` once to your root view (e.g., MainView).
// This automatically dismisses focus when clicking outside text fields.
//
// For specific areas, use `` on container views.
//
// ## Platform Support
// - macOS: Uses NSEvent monitoring and `makeFirstResponder(nil)`
// - iOS: Uses `resignFirstResponder` action
//
// ## Implementation Notes
// The window-level handler monitors mouse clicks and checks if the click target
// is a text input. If not, it dismisses the first responder. This is more
// efficient than adding modifiers to every view individually.

import SwiftUI

// MARK: - Window-Level Focus Dismissal (macOS)

#if os(macOS)
import AppKit

/// Monitors mouse events and dismisses focus when clicking outside text fields.
private class FocusDismissMonitor {
    static let shared = FocusDismissMonitor()
    private var monitor: Any?

    private init() {}

    func start() {
        guard monitor == nil else { return }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            self.handleMouseDown(event)
            return event
        }
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let window = event.window,
              let firstResponder = window.firstResponder
        else { return }

        // Only act if current first responder is a text view (TextField's backing view)
        guard firstResponder is NSTextView || firstResponder is NSTextField else { return }

        // Get the view under the click
        let locationInWindow = event.locationInWindow
        guard let contentView = window.contentView,
              let hitView = contentView.hitTest(locationInWindow)
        else { return }

        // Check if the clicked view or its ancestors is a text input
        var view: NSView? = hitView
        while let currentView = view {
            if currentView is NSTextField || currentView is NSTextView {
                // Clicking on another text field - let it handle focus naturally
                return
            }
            view = currentView.superview
        }

        // Clicking outside text fields - dismiss focus
        window.makeFirstResponder(nil)
    }
}

extension View {
    /// Installs a window-level handler that dismisses focus when clicking outside text fields.
    ///
    /// Apply this modifier once to your root view (e.g., MainView). It will automatically
    /// handle focus dismissal for the entire window without needing to modify individual views.
    func installFocusDismissHandler() -> some View {
        onAppear {
            FocusDismissMonitor.shared.start()
        }
    }
}

#else
import UIKit

private final class KeyboardDismissTapInstaller: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissTapInstaller()

    private var installedWindows: Set<ObjectIdentifier> = []

    override private init() {}

    func install() {
        DispatchQueue.main.async {
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)

            for window in windows {
                let windowId = ObjectIdentifier(window)
                guard !self.installedWindows.contains(windowId) else { continue }

                let recognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
                recognizer.cancelsTouchesInView = false
                recognizer.delegate = self
                window.addGestureRecognizer(recognizer)
                self.installedWindows.insert(windowId)
            }
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let rootView = recognizer.view else { return }
        let location = recognizer.location(in: rootView)
        guard let tappedView = rootView.hitTest(location, with: nil) else {
            dismissKeyboard()
            return
        }

        guard !tappedView.isTextInputOrDescendant else {
            return
        }

        dismissKeyboard()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

private extension UIView {
    var isTextInputOrDescendant: Bool {
        var view: UIView? = self
        while let currentView = view {
            if currentView is UITextField || currentView is UITextView {
                return true
            }
            view = currentView.superview
        }
        return false
    }
}

extension View {
    /// Installs a window-level handler that dismisses keyboard focus when tapping outside text inputs.
    func installFocusDismissHandler() -> some View {
        onAppear {
            KeyboardDismissTapInstaller.shared.install()
        }
    }
}
#endif
