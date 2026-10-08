import AvgeekDesignSystem
import SwiftData
import SwiftUI

struct PromptGalleryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager

    let onSelect: (String) -> Void

    @Query(sort: \PromptGalleryItem.updatedAt, order: .reverse)
    private var allItems: [PromptGalleryItem]

    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var selectedItem: PromptGalleryItem.ID?

    private var items: [PromptGalleryItem] {
        let filtered = allItems.filter { $0.projectId == projectManager.currentProjectId }
        var result = filtered

        if let selectedTag {
            result = result.filter { $0.tags.contains(selectedTag) }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                    $0.prompt.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private var allTags: [String] {
        let filtered: [PromptGalleryItem] = allItems.filter { $0.projectId == projectManager.currentProjectId }
        return Array(Set(filtered.flatMap(\.tags))).sorted()
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty, allTags.isEmpty {
                    emptyState
                } else {
                    tableContent
                }
            }
            .navigationTitle("Pick a Prompt")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search prompts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if !allTags.isEmpty {
                    ToolbarItemGroup(placement: .automatic) {
                        Menu {
                            Button {
                                selectedTag = nil
                            } label: {
                                if selectedTag == nil {
                                    Label("All", systemImage: "checkmark")
                                } else {
                                    Text("All")
                                }
                            }

                            Divider()

                            ForEach(allTags, id: \.self) { tag in
                                Button {
                                    selectedTag = selectedTag == tag ? nil : tag
                                } label: {
                                    if selectedTag == tag {
                                        Label(tag, systemImage: "checkmark")
                                    } else {
                                        Text(tag)
                                    }
                                }
                            }
                        } label: {
                            Label("Filter by Tag", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                }

                #if os(macOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        if let id = selectedItem,
                           let item = items.first(where: { $0.id == id })
                        {
                            onSelect(item.prompt)
                            dismiss()
                        }
                    }
                    .disabled(selectedItem == nil)
                }
                #endif
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #endif
    }

    private var emptyState: some View {
        AvgeekEmptyStateView(
            icon: "text.book.closed",
            title: "No Saved Prompts",
            message: "Save prompts to your Prompt Gallery first, then pick them here."
        )
    }

    #if os(macOS)
    private var tableContent: some View {
        Table(of: PromptGalleryItem.self, selection: $selectedItem) {
            TableColumn("Title") { item in
                Text(item.title)
                    .lineLimit(1)
            }
            .width(min: 150, ideal: 200)

            TableColumn("Prompt") { item in
                Text(item.prompt)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
            .width(min: 300, ideal: 400)
        } rows: {
            ForEach(items) { item in
                TableRow(item)
                    .contextMenu {
                        Button {
                            onSelect(item.prompt)
                            dismiss()
                        } label: {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                    }
            }
        }
        .onTapGesture(count: 2) {
            if let id = selectedItem,
               let item = items.first(where: { $0.id == id })
            {
                onSelect(item.prompt)
                dismiss()
            }
        }
    }
    #else
    private var tableContent: some View {
        List {
            ForEach(items) { item in
                Button {
                    onSelect(item.prompt)
                    dismiss()
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                                .lineLimit(1)

                            Text(item.prompt)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.forward")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }
        }
        .listStyle(.inset)
    }
    #endif
}
