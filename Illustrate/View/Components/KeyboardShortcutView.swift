// MARK: - KeyboardShortcutView.swift

// Keyboard shortcut hint display with activation.
//
// Shows keyboard shortcut keys in styled badges with description.
// Also registers the actual keyboard shortcut handler.
//
// ## Platform
// macOS only - iOS doesn't have keyboard shortcuts.

import SwiftUI

#if os(macOS)
/// Keyboard shortcut display with badge styling.
struct KeyboardShortcutView: View {
    let keys: [String]
    let description: String
    let keyEquivalent: KeyEquivalent
    let modifiers: EventModifiers
    var onEngaged: (() -> Void)?

    init(
        keys: [String],
        description: String,
        keyEquivalent: KeyEquivalent,
        modifiers: EventModifiers = .command,
        onEngaged: (() -> Void)? = nil
    ) {
        self.keys = keys
        self.description = description
        self.keyEquivalent = keyEquivalent
        self.modifiers = modifiers
        self.onEngaged = onEngaged
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.2))
                            .shadow(color: .secondary.opacity(0.1), radius: 1, y: 1)
                    )
                    .foregroundStyle(.secondary)
            }
            Text("to \(description)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .background {
            Button("") {
                onEngaged?()
            }
            .keyboardShortcut(keyEquivalent, modifiers: modifiers)
            .opacity(0)
        }
    }
}
#endif
