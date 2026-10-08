// MARK: - CanvasLockButton.swift

// Lock/unlock toggle button for canvas editing.
//
// When locked, cards cannot be moved or edited.
// Useful for reviewing workflows without accidental changes.

import SwiftUI

// MARK: - Canvas Lock Button

/// Toggle button to lock/unlock canvas editing.
struct CanvasLockButton: View {
    let isLocked: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            Image(systemName: isLocked ? "lock.fill" : "lock.open")
                .font(.system(.caption))
                .foregroundStyle(isLocked ? Color.accentColor : .secondary)
                .frame(
                    minWidth: CanvasConstants.zoomWidgetButtonHeight,
                    minHeight: CanvasConstants.zoomWidgetButtonHeight
                )
                .background(isLocked ? Color.accentColor.opacity(0.15) : secondarySystemFill)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isLocked ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.2),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help(isLocked ? "Unlock canvas" : "Lock canvas")
    }
}

// MARK: - Canvas Action Button

/// Reusable action button for canvas controls
struct CanvasActionButton: View {
    let icon: String
    let helpText: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(.caption))
                .foregroundStyle(.secondary)
                .frame(
                    minWidth: CanvasConstants.zoomWidgetButtonHeight,
                    minHeight: CanvasConstants.zoomWidgetButtonHeight
                )
                .background(secondarySystemFill)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}
