import AvgeekDesignSystem
import SwiftData
import SwiftUI

struct ProductGalleryImagePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager

    let onImageSelected: (PlatformImage) -> Void

    @Query(sort: \ProductGalleryItem.updatedAt, order: .reverse)
    private var allItems: [ProductGalleryItem]

    @State private var loadedImages: [UUID: PlatformImage] = [:]
    @State private var loadingIds: Set<UUID> = []
    @State private var searchText = ""

    private var items: [ProductGalleryItem] {
        let filtered = allItems.filter { $0.projectId == projectManager.currentProjectId }
        if searchText.isEmpty { return filtered }
        return filtered.filter {
            $0.productName.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    private var columns: [GridItem] {
        #if os(macOS)
        [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)]
        #else
        [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 12)]
        #endif
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyStateView
                } else {
                    imageGridView
                }
            }
            .navigationTitle("Product Gallery")
            #if os(macOS)
            .frame(minWidth: 640, minHeight: 400, maxHeight: 640)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search products...", text: $searchText)
                            .textFieldStyle(.plain)
                            .frame(width: 160)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private var emptyStateView: some View {
        AvgeekEmptyStateView(
            icon: "lamp.floor",
            title: "No products yet",
            message: "Add products to your Product Gallery first, then select them here."
        )
    }

    private var imageGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    ProductPickerCard(
                        item: item,
                        image: loadedImages[item.id],
                        isLoading: loadingIds.contains(item.id),
                        onSelect: {
                            selectFullImage(for: item)
                        }
                    )
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
        guard loadedImages[item.id] == nil, !loadingIds.contains(item.id) else { return }

        if let cached = ImageCache.shared.get(forKey: thumbName) {
            loadedImages[item.id] = cached
            return
        }

        loadingIds.insert(item.id)

        DispatchQueue.global(qos: .userInitiated).async {
            let image = loadImageFromiCloud(thumbName)
            DispatchQueue.main.async {
                if let image {
                    ImageCache.shared.set(image, forKey: thumbName)
                    loadedImages[item.id] = image
                }
                loadingIds.remove(item.id)
            }
        }
    }

    private func selectFullImage(for item: ProductGalleryItem) {
        guard let fileName = item.imageFileName else { return }

        if let cached = ImageCache.shared.get(forKey: fileName) {
            onImageSelected(cached)
            dismiss()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            if let image = loadImageFromiCloud(fileName) {
                ImageCache.shared.set(image, forKey: fileName)
                DispatchQueue.main.async {
                    onImageSelected(image)
                    dismiss()
                }
            }
        }
    }
}

private struct ProductPickerCard: View {
    let item: ProductGalleryItem
    let image: PlatformImage?
    let isLoading: Bool
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
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
                            .font(.title2)
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
                    .font(.caption)
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
