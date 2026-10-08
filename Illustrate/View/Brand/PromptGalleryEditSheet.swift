import SwiftUI

enum PromptGalleryEditMode {
    case create
    case edit(PromptGalleryItem)
}

struct PromptGalleryEditSheet: View {
    let mode: PromptGalleryEditMode
    let onSave: (String, String, [String]) -> Void
    var onDelete: (() -> Void)?
    var prefillPrompt: String?
    var prefillTags: [String]?

    @Environment(\.dismiss) private var dismiss: DismissAction

    @State private var title = ""
    @State private var prompt = ""
    @State private var tagInput = ""
    @State private var tags: [String] = []

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Prompt", text: $prompt, axis: .vertical)
                        .lineLimit(3 ... 10)
                }

                Section {
                    HStack {
                        TextField("Add tag", text: $tagInput)
                            .onSubmit(addTag)
                        Button("Add", action: addTag)
                            .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    if !tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                TagChip(tag: tag) {
                                    tags.removeAll { $0 == tag }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Tags")
                }

                if isEditing, let onDelete: () -> Void {
                    Section {
                        Button("Delete Prompt", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Prompt" : "Add Prompt")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            title.trimmingCharacters(in: .whitespaces),
                            prompt.trimmingCharacters(in: .whitespaces),
                            tags
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 450, minHeight: 350)
        #endif
        .onAppear {
            if case let .edit(item) = mode {
                title = item.title
                prompt = item.prompt
                tags = item.tags
            } else {
                if let prefillPrompt: String {
                    prompt = prefillPrompt
                }
                if let prefillTags: [String] {
                    tags = prefillTags
                }
            }
        }
    }

    private func addTag() {
        let trimmed: String = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tagInput = ""
    }
}

private struct TagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.1))
        .foregroundColor(.accentColor)
        .cornerRadius(4)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result: FlowLayout.ArrangeResult = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result: FlowLayout.ArrangeResult = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth: CGFloat = proposal.width ?? .infinity
        var result: FlowLayout.ArrangeResult = ArrangeResult()
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview: LayoutSubviews.Element in subviews {
            let size: CGSize = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            result.positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        result.size = CGSize(width: maxWidth, height: y + rowHeight)
        return result
    }
}
