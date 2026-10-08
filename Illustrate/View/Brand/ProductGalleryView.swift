import AvgeekDesignSystem
import SwiftData
import SwiftUI

struct ProductGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager

    @Query(sort: \ProductGalleryItem.updatedAt, order: .reverse)
    private var allItems: [ProductGalleryItem]

    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var showAddSheet = false
    @State private var editingItem: ProductGalleryItem?
    @State private var loadedThumbnails: [UUID: PlatformImage] = [:]
    @State private var loadingIds: Set<UUID> = []

    private var items: [ProductGalleryItem] {
        let filtered = allItems.filter { $0.projectId == projectManager.currentProjectId }
        var result = filtered

        if let selectedTag {
            result = result.filter { $0.tags.contains(selectedTag) }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.productName.localizedCaseInsensitiveContains(searchText) ||
                    $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }

        return result
    }

    private var allTags: [String] {
        let filtered = allItems.filter { $0.projectId == projectManager.currentProjectId }
        return Array(Set(filtered.flatMap(\.tags))).sorted()
    }

    private var columns: [GridItem] {
        #if os(macOS)
        [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)]
        #else
        [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)]
        #endif
    }

    var body: some View {
        Group {
            if items.isEmpty, allTags.isEmpty {
                emptyState
            } else {
                gridContent
            }
        }
        .navigationTitle("Product Gallery")
        .searchable(text: $searchText, prompt: "Search products")
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
                    showAddSheet = true
                } label: {
                    Label("Add Product", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            ProductGalleryEditSheet(mode: .create, modelContext: modelContext) { _, _ in
                refreshThumbnails()
            }
        }
        .sheet(item: $editingItem) { item in
            ProductGalleryEditSheet(
                mode: .edit(item),
                modelContext: modelContext,
                onSave: { _, _ in
                    refreshThumbnails()
                },
                onDelete: {
                    deleteItem(item)
                }
            )
        }
    }

    private var emptyState: some View {
        AvgeekEmptyStateView(
            icon: "lamp.floor",
            title: "No Products",
            message: "Add your products here to quickly use them in product photoshoots.",
            buttonTitle: "Add Product",
            buttonIcon: "plus",
            onButtonTap: { showAddSheet = true }
        )
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    ProductCard(
                        item: item,
                        image: loadedThumbnails[item.id],
                        isLoading: loadingIds.contains(item.id),
                        onTap: { editingItem = item }
                    )
                    .contextMenu {
                        Button {
                            editingItem = item
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
                    .onAppear {
                        loadThumbnail(for: item)
                    }
                }
            }
            .padding()
        }
    }

    private func loadThumbnail(for item: ProductGalleryItem) {
        guard let thumbName = item.largeThumbFileName ?? item.thumbFileName ?? item.imageFileName else { return }
        guard loadedThumbnails[item.id] == nil, !loadingIds.contains(item.id) else { return }

        if let cached = ImageCache.shared.get(forKey: thumbName) {
            loadedThumbnails[item.id] = cached
            return
        }

        loadingIds.insert(item.id)

        DispatchQueue.global(qos: .userInitiated).async {
            let image = loadImageFromiCloud(thumbName)
            DispatchQueue.main.async {
                if let image {
                    ImageCache.shared.set(image, forKey: thumbName)
                    loadedThumbnails[item.id] = image
                }
                loadingIds.remove(item.id)
            }
        }
    }

    private func refreshThumbnails() {
        loadedThumbnails.removeAll()
        loadingIds.removeAll()
    }

    private func deleteItem(_ item: ProductGalleryItem) {
        if let fileName = item.imageFileName {
            deleteImageFromiCloud(fileName: fileName)
        }
        if let thumbName = item.thumbFileName {
            deleteImageFromiCloud(fileName: thumbName)
        }
        if let largeThumbName = item.largeThumbFileName {
            deleteImageFromiCloud(fileName: largeThumbName)
        }
        loadedThumbnails.removeValue(forKey: item.id)
        modelContext.delete(item)
    }

    private func deleteImageFromiCloud(fileName: String) {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
        else { return }

        let fileURL = containerURL.appendingPathComponent("\(fileName).png")
        try? FileManager.default.removeItem(at: fileURL)
    }
}

private struct ProductCard: View {
    let item: ProductGalleryItem
    let image: PlatformImage?
    let isLoading: Bool
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .aspectRatio(1, contentMode: .fit)

                    if isLoading {
                        ProgressView()
                    } else if let image {
                        #if os(macOS)
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(8)
                        #else
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(8)
                        #endif
                    } else {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.tertiary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isHovering ? Color.accentColor : Color.secondary.opacity(0.2),
                            lineWidth: isHovering ? 2 : 1
                        )
                )
                .shadow(color: isHovering ? Color.accentColor.opacity(0.3) : Color.clear, radius: 8)

                Text(item.productName)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
