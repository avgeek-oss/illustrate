// MARK: - ImageSourcePicker.swift

// Simple button that triggers image selection.
//
// Wraps the imageSelection modifier to provide a clean API
// for selecting images from the photo library.

import SwiftUI

/// Button that opens image picker when tapped.
struct ImageSourcePicker: View {
    let buttonLabel: String
    var showPicker: Binding<Bool>?
    let onImageSelected: (PlatformImage) -> Void

    @State private var internalPickerState = false

    private var isPickerOpen: Binding<Bool> {
        showPicker ?? $internalPickerState
    }

    var body: some View {
        Button(buttonLabel) {
            isPickerOpen.wrappedValue = true
        }
        .buttonStyle(.bordered)
        .imageSelection(
            id: "imageSourcePicker",
            isPickerOpen: isPickerOpen,
            onImageSelected: onImageSelected
        )
    }
}
