// MARK: - FieldAdapter.swift

// SwiftUI view modifiers and common state types for form fields.

import Foundation
import OSLog
import SwiftUI

extension View {
    /// Limits text input to a maximum character count.
    ///
    /// Apply to TextField to enforce character limits (e.g., prompt length).
    /// - Parameters:
    ///   - text: Binding to the text value
    ///   - characterLimit: Maximum allowed characters
    func limitText(_ text: Binding<String>, to characterLimit: Int) -> some View {
        onChange(of: text.wrappedValue) {
            text.wrappedValue = String(text.wrappedValue.prefix(characterLimit))
        }
    }
}

/// Common error state for displaying errors in UI.
struct ErrorState {
    /// Error message to display
    var message: String
    /// Whether the error should be shown
    var isShowing: Bool
}
