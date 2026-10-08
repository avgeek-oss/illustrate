import AvgeekDesignSystem
import SwiftData
import SwiftUI

struct PromptGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager

    @Query(sort: \PromptGalleryItem.updatedAt, order: .reverse)
    private var allItems: [PromptGalleryItem]

    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var activeSheet: PromptGallerySheet?
    @State private var selectedItems: Set<PromptGalleryItem.ID> = []

    private var items: [PromptGalleryItem] {
        let filtered = allItems.filter { $0.projectId == projectManager.currentProjectId }
        var result = filtered

        if let selectedTag {
            result = result.filter { $0.tags.contains(selectedTag) }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                    $0.prompt.localizedCaseInsensitiveContains(searchText) ||
                    $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }

        return result
    }

    private var allTags: [String] {
        let filtered = allItems.filter { $0.projectId == projectManager.currentProjectId }
        return Array(Set(filtered.flatMap(\.tags))).sorted()
    }

    var body: some View {
        Group {
            if items.isEmpty, allTags.isEmpty {
                emptyState
            } else {
                tableContent
            }
        }
        .navigationTitle("Prompt Gallery")
        .searchable(text: $searchText, prompt: "Search prompts")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if !allTags.isEmpty {
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

                Button {
                    activeSheet = .create
                } label: {
                    Label("Add Prompt", systemImage: "plus")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .create:
                PromptGalleryEditSheet(mode: .create, onSave: { title, prompt, tags in
                    addItem(title: title, prompt: prompt, tags: tags)
                })
            case let .edit(item):
                PromptGalleryEditSheet(
                    mode: .edit(item),
                    onSave: { title, prompt, tags in
                        updateItem(item, title: title, prompt: prompt, tags: tags)
                    },
                    onDelete: {
                        deleteItem(item)
                    }
                )
            }
        }
    }

    private var emptyState: some View {
        AvgeekEmptyStateView(
            icon: "text.book.closed",
            title: "No Saved Prompts",
            message: "Save your best prompts here so you can reuse them quickly.",
            buttonTitle: "Add Prompt",
            buttonIcon: "plus",
            onButtonTap: { activeSheet = .create }
        )
    }

    #if os(macOS)
    private var tableContent: some View {
        Table(of: PromptGalleryItem.self, selection: $selectedItems) {
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

            TableColumn("Updated") { item in
                Text(item.updatedAt, style: .date)
            }
            .width(min: 120, ideal: 140, max: 160)
        } rows: {
            ForEach(items) { item in
                TableRow(item)
                    .contextMenu {
                        Button {
                            activeSheet = .edit(item)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            deleteItem(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .onTapGesture(count: 2) {
            if let firstId = selectedItems.first,
               let item = items.first(where: { $0.id == firstId })
            {
                activeSheet = .edit(item)
            }
        }
    }
    #else
    private var tableContent: some View {
        List {
            ForEach(items) { item in
                Button {
                    activeSheet = .edit(item)
                } label: {
                    PromptGalleryMobileRow(item: item)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        activeSheet = .edit(item)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        deleteItem(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteItem(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.inset)
    }
    #endif

    private func addItem(title: String, prompt: String, tags: [String]) {
        let item = PromptGalleryItem(
            projectId: projectManager.currentProjectId,
            title: title,
            prompt: prompt,
            tags: tags
        )
        modelContext.insert(item)
    }

    private func updateItem(_ item: PromptGalleryItem, title: String, prompt: String, tags: [String]) {
        item.title = title
        item.prompt = prompt
        item.tags = tags
        item.updatedAt = Date()
    }

    private func deleteItem(_ item: PromptGalleryItem) {
        modelContext.delete(item)
    }
}

private enum PromptGallerySheet: Identifiable {
    case create
    case edit(PromptGalleryItem)

    var id: String {
        switch self {
        case .create:
            "create"
        case let .edit(item):
            item.id.uuidString
        }
    }
}

#if os(iOS)
private struct PromptGalleryMobileRow: View {
    let item: PromptGalleryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(item.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(item.prompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if !item.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
#endif
