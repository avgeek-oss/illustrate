// MARK: - ShapeSettingsPopover.swift

// Popover content for shape tool settings.

import SwiftUI

/// Popover content for shape color and type settings.
struct ShapeSettingsPopover: View {
    @Binding var shapeColor: Color
    @Binding var selectedShapeType: ShapeType

    var body: some View {
        HStack(spacing: 12) {
            ColorPicker("", selection: $shapeColor, supportsOpacity: false)
                .labelsHidden()

            Divider()
                .frame(height: 32)

            ForEach(ShapeType.allCases) { shape in
                shapeButton(for: shape)
            }
        }
        .padding(12)
    }

    // MARK: - Shape Button

    private func shapeButton(for shape: ShapeType) -> some View {
        Button {
            selectedShapeType = shape
        } label: {
            Image(systemName: shape.filledIcon)
                .font(.system(size: 20))
                .foregroundStyle(selectedShapeType == shape ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedShapeType == shape ? Color.accentColor : Color.secondary.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .help(shape.displayName)
    }
}

// MARK: - Preview

#Preview {
    ShapeSettingsPopover(
        shapeColor: .constant(.blue),
        selectedShapeType: .constant(.square)
    )
}
