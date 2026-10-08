// MARK: - ToastManager.swift

// Global toast notification system for user feedback.
//
// Provides a simple API for showing toast notifications anywhere
// in the app. Uses AlertToast library for the visual presentation.
//
// ## Toast Types
// - success: Green checkmark with message
// - error: Red warning with message and optional subtitle
// - info: Blue info icon with message
//
// ## Usage
// ```swift
// showToast(.success("Image copied to clipboard"))
// showToast(.error("Generation failed", subtitle: "Check your API key"))
// ```
//
// ## Integration
// Add `.withGlobalToast()` modifier to root view to enable toasts.

import AlertToast
import AvgeekDesignSystem
import SwiftUI

// MARK: - Toast Types

enum ToastType {
    case success(String)
    case error(String, subtitle: String? = nil)
    case info(String)
    case successCenter(String)

    var alertToast: AlertToast {
        switch self {
        case let .success(message):
            AlertToast(
                displayMode: .hud,
                type: .systemImage("checkmark.circle", Color.green),
                title: message
            )
        case let .error(message, subtitle):
            AlertToast(
                displayMode: .hud,
                type: .systemImage("exclamationmark.triangle", Color.red),
                title: message,
                subTitle: subtitle ?? "Tap to dismiss"
            )
        case let .info(message):
            AlertToast(
                displayMode: .hud,
                type: .systemImage("info.circle", Color.blue),
                title: message
            )
        case let .successCenter(message):
            #if os(iOS)
            AlertToast(
                displayMode: .alert,
                type: .complete(.green),
                title: message
            )
            #else
            AlertToast(
                displayMode: .hud,
                type: .systemImage("checkmark.circle", Color.green),
                title: message
            )
            #endif
        }
    }

    var duration: Double {
        switch self {
        case .error:
            12
        case .successCenter:
            2
        default:
            3
        }
    }
}

// MARK: - Toast Manager

@Observable
final class ToastManager {
    static let shared = ToastManager()

    var isShowing = false
    var currentToast: ToastType = .info("")

    private init() {}

    func show(_ type: ToastType) {
        currentToast = type
        isShowing = true
    }
}

// MARK: - View Modifier

struct GlobalToastModifier: ViewModifier {
    @Bindable private var manager = ToastManager.shared

    func body(content: Content) -> some View {
        content
            .toast(isPresenting: $manager.isShowing, duration: manager.currentToast.duration, offsetY: 16) {
                manager.currentToast.alertToast
            }
    }
}

extension View {
    func withGlobalToast() -> some View {
        modifier(GlobalToastModifier())
    }
}

// MARK: - Convenience Functions

func showToast(_ type: ToastType) {
    switch type {
    case .success, .successCenter:
        AvgeekFeedback.success()
    case .error:
        AvgeekFeedback.error()
    case .info:
        AvgeekFeedback.selection()
    }
    ToastManager.shared.show(type)
}
