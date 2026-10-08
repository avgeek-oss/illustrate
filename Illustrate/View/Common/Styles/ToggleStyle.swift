// MARK: - ToggleStyle.swift

// Platform-adaptive toggle style.
//
// Uses checkbox style on macOS, default switch on iOS
// for native look and feel.

import Foundation
import SwiftUI

/// Platform-adaptive toggle style (checkbox on macOS).
struct IllustrateToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        #if os(macOS)
        CheckboxToggleStyle().makeBody(configuration: configuration)
        #else
        DefaultToggleStyle().makeBody(configuration: configuration)
        #endif
    }
}
