// MARK: - ToolPalette.swift

// Vertical toolbar for selecting editing tools.
//
// Displays all available EditTool options in a vertical stack
// with visual indication of the currently selected tool.
//
// ## Design
// - Vertical layout positioned on the left edge of the canvas
// - Icon buttons with rounded backgrounds
// - Selected tool highlighted with accent color
// - Tooltips showing tool name on hover
// - Semi-transparent material background
//
// ## Interaction
// - Click a tool button to activate that tool
// - Click brush tool while selected to show settings popover
// - The selected tool determines the canvas interaction mode

import SwiftUI

/// Vertical toolbar for selecting canvas editing tools.
///
/// Displays all available tools with visual feedback for the
/// currently selected tool. The brush tool supports a two-click
/// pattern: first click selects, second click shows settings popover.
struct ToolPalette: View {
    @Binding var selectedTool: EditTool
    @Binding var brushColor: Color
    @Binding var brushSize: Double
    @Binding var shapeColor: Color
    @Binding var selectedShapeType: ShapeType

    /// Called when brush settings change (for layer finalization)
    var onBrushSettingsChanged: (() -> Void)?

    @State private var showBrushPopover = false
    @State private var showShapePopover = false

    var body: some View {
        VStack(spacing: 8) {
            ForEach(EditTool.allCases) { tool in
                if tool == .brush {
                    brushToolButton
                } else if tool == .shape {
                    shapeToolButton
                } else {
                    toolButton(for: tool)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    // MARK: - Standard Tool Button

    private func toolButton(for tool: EditTool) -> some View {
        Button {
            selectedTool = tool
        } label: {
            toolButtonLabel(for: tool, isSelected: selectedTool == tool)
        }
        .buttonStyle(.plain)
        .help(tool.label)
        .accessibilityLabel(tool.label)
        .accessibilityHint(selectedTool == tool ? "Currently selected" : "Double tap to select")
        .accessibilityAddTraits(selectedTool == tool ? [.isSelected] : [])
        .animation(.easeInOut(duration: 0.15), value: selectedTool)
    }

    // MARK: - Brush Tool Button

    private var brushToolButton: some View {
        Button {
            if selectedTool == .brush {
                // Already selected: toggle popover
                showBrushPopover.toggle()
            } else {
                // First click: select brush tool and show popover
                selectedTool = .brush
                showBrushPopover = true
            }
        } label: {
            toolButtonLabel(for: .brush, isSelected: selectedTool == .brush)
        }
        .buttonStyle(.plain)
        .help(selectedTool == .brush ? "Brush Settings" : EditTool.brush.label)
        .accessibilityLabel(selectedTool == .brush ? "Brush Settings" : EditTool.brush.label)
        .accessibilityHint(selectedTool == .brush ? "Double tap to open brush settings" :
            "Double tap to select brush tool")
        .accessibilityAddTraits(selectedTool == .brush ? [.isSelected] : [])
        .animation(.easeInOut(duration: 0.15), value: selectedTool)
        .popover(isPresented: $showBrushPopover, arrowEdge: .trailing) {
            BrushSettingsPopover(
                brushColor: $brushColor,
                brushSize: $brushSize
            )
            .onChange(of: brushColor) { _, _ in
                onBrushSettingsChanged?()
            }
            .onChange(of: brushSize) { _, _ in
                onBrushSettingsChanged?()
            }
        }
    }

    // MARK: - Shape Tool Button

    private var shapeToolButton: some View {
        Button {
            if selectedTool == .shape {
                // Already selected: toggle popover
                showShapePopover.toggle()
            } else {
                // First click: select shape tool and show popover
                selectedTool = .shape
                showShapePopover = true
            }
        } label: {
            toolButtonLabel(for: .shape, isSelected: selectedTool == .shape)
        }
        .buttonStyle(.plain)
        .help(selectedTool == .shape ? "Shape Settings" : EditTool.shape.label)
        .accessibilityLabel(selectedTool == .shape ? "Shape Settings" : EditTool.shape.label)
        .accessibilityHint(selectedTool == .shape ? "Double tap to open shape settings" :
            "Double tap to select shape tool")
        .accessibilityAddTraits(selectedTool == .shape ? [.isSelected] : [])
        .animation(.easeInOut(duration: 0.15), value: selectedTool)
        .popover(isPresented: $showShapePopover, arrowEdge: .trailing) {
            ShapeSettingsPopover(
                shapeColor: $shapeColor,
                selectedShapeType: $selectedShapeType
            )
        }
    }

    // MARK: - Tool Button Label

    private func toolButtonLabel(for tool: EditTool, isSelected: Bool) -> some View {
        Image(systemName: tool.icon)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        ToolPalette(
            selectedTool: .constant(.brush),
            brushColor: .constant(.red),
            brushSize: .constant(12),
            shapeColor: .constant(.blue),
            selectedShapeType: .constant(.square)
        )
    }
    .padding()
    .frame(width: 100, height: 400)
}
