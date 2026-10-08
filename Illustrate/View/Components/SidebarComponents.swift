// MARK: - SidebarComponents.swift

// Reusable UI components for sidebar-based views (Agents, Flow Canvas, ChatThreads).
//
// These components reduce code duplication across views that display lists of
// pinnable items with consistent create/rename/delete functionality.
//
// ## Components Included
// - NameInputSheet: Create/Rename dialog with text input
// - PinnableRowView: Row view with pin indicator and context menu
//
// ## See Also
// - GuidePopover.swift: Help guide button with popover content

import AvgeekDesignSystem
import AvgeekLocalizationCore
import AvgeekLocalizationUI
import SwiftUI

// MARK: - Name Input Sheet

/// A reusable sheet for creating or renaming items.
///
/// Used for creating new Agents, Flow Canvas, and ChatThreads,
/// as well as renaming existing ones.
struct NameInputSheet: View {
    let title: String
    let placeholder: String
    let actionTitle: String
    @Binding var name: String
    @Binding var isPresented: Bool
    let onAction: () -> Void
    var onCancel: (() -> Void)?
    var usesRoundedBorder = true

    @AppLocalized private var localize

    var body: some View {
        NavigationStack {
            Form {
                if usesRoundedBorder {
                    TextField(localize(placeholder), text: $name)
                        .textFieldStyle(.roundedBorder)
                } else {
                    TextField(localize(placeholder), text: $name)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(localize(title))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localize("Cancel")) {
                        isPresented = false
                        onCancel?()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localize(actionTitle)) {
                        isPresented = false
                        onAction()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 340)
        #endif
    }
}

// MARK: - Pinnable Row View

/// A reusable row view for displaying pinnable items in a sidebar list.
///
/// Shows a pin indicator when pinned, the item name, and provides
/// a context menu with Pin/Unpin, Rename, Duplicate (optional), and Delete actions.
struct PinnableRowView<Item: Pinnable>: View {
    let item: Item
    let onRename: () -> Void
    let onTogglePin: () -> Void
    var onDuplicate: (() -> Void)?
    let onDelete: () -> Void

    var body: some View {
        HStack {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(item.name)
                .font(.body)
                .lineLimit(1)
            Spacer()
        }
        .contextMenu {
            Button {
                onTogglePin()
            } label: {
                Label(
                    item.isPinned ? "Unpin" : "Pin",
                    systemImage: item.isPinned ? "pin.slash" : "pin"
                )
            }
            Button {
                onRename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            if let onDuplicate {
                Button {
                    onDuplicate()
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
            }
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Expand Window View

/// A reusable view displayed when the window width is too narrow.
///
/// Prompts users to expand the window to continue using the feature.
struct ExpandWindowView: View {
    var body: some View {
        AvgeekEmptyStateView(
            icon: "arrow.left.and.right.square",
            title: "Window Too Narrow",
            message: "Please expand the window to access this feature."
        )
        .background(systemBackground)
    }
}

/// Minimum width required for canvas-based views.
let canvasMinWidth: CGFloat = 720
