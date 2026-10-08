// MARK: - BrushSettingsPopover.swift

// Popover content for brush tool settings.

import SwiftUI

/// Popover content for brush color and size settings.
struct BrushSettingsPopover: View {
    @Binding var brushColor: Color
    @Binding var brushSize: Double

    private let minBrushSize: Double = 16
    private let maxBrushSize: Double = 48

    var body: some View {
        HStack(spacing: 12) {
            ColorPicker("", selection: $brushColor, supportsOpacity: false)
                .labelsHidden()

            Slider(value: $brushSize, in: minBrushSize ... maxBrushSize, step: 1)
                .frame(width: 120)

            Circle()
                .fill(brushColor)
                .frame(width: brushSize, height: brushSize)
                .frame(width: maxBrushSize, height: maxBrushSize)
        }
        .padding(12)
    }
}

// MARK: - Preview

#Preview {
    BrushSettingsPopover(
        brushColor: .constant(.red),
        brushSize: .constant(24)
    )
}
