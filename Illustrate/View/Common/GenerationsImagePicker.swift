// MARK: - GenerationsImagePicker.swift

// Picker for selecting from existing generated images.
//
// Displays a searchable grid of previously generated images,
// allowing users to select one as a source for new generations.
//
// ## Features
// - Grid view of all project generations
// - Search by prompt text
// - Async thumbnail loading
// - Selection with preview
//
// ## Use Cases
// - Image-to-image generation source
// - Reference image selection
// - Video source frame selection

import AvgeekDesignSystem
import SwiftData
import SwiftUI

/// Grid picker for selecting from existing generated images.
struct GenerationsImagePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager
    @ObservedObject private var cache = GalleryCache.shared

    let onImageSelected: (PlatformImage) -> Void

    private var generations: [Generation] {
        let filtered = cache.imageGenerations
        if searchText.isEmpty {
            return filtered
        }
        return filtered.filter { $0.prompt.localizedCaseInsensitiveContains(searchText) }
    }

    @State private var loadedImages: [UUID: PlatformImage] = [:]
    @State private var loadingIds: Set<UUID> = []
    @State private var selectedGeneration: Generation?
    @State private var searchText = ""

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
                if generations.isEmpty {
                    emptyStateView
                } else {
                    imageGridView
                }
            }
            .navigationTitle("Recent Generations")
            #if os(macOS)
            .frame(minWidth: 640, minHeight: 400, maxHeight: 640)
            #endif
            .onAppear {
                cache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            }
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
                        TextField("Search prompts...", text: $searchText)
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

    private var hasAnyGenerations: Bool {
        !cache.imageGenerations.isEmpty
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if !searchText.isEmpty, hasAnyGenerations {
            AvgeekEmptyStateView(
                icon: "magnifyingglass",
                title: "No results found",
                message: "No generations match \"\(searchText)\""
            )
        } else {
            AvgeekEmptyStateView(
                icon: "photo",
                title: "No generations yet",
                message: "Generate some images first to use them as source images."
            )
        }
    }

    private var imageGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(generations, id: \.id) { generation in
                    GenerationImageCard(
                        generation: generation,
                        image: loadedImages[generation.id],
                        isLoading: loadingIds.contains(generation.id),
                        onSelect: {
                            selectFullImage(for: generation)
                        }
                    )
                    .onAppear {
                        loadThumbnail(for: generation)
                    }
                }
            }
            .padding()
        }
    }

    private func loadThumbnail(for generation: Generation) {
        let thumbName = ".\(generation.id.uuidString)_o50"

        if loadedImages[generation.id] != nil || loadingIds.contains(generation.id) {
            return
        }

        if let cached = ImageCache.shared.get(forKey: thumbName) {
            loadedImages[generation.id] = cached
            return
        }

        loadingIds.insert(generation.id)

        DispatchQueue.global(qos: .userInitiated).async {
            let image = loadImageFromiCloud(thumbName)
            DispatchQueue.main.async {
                if let image {
                    ImageCache.shared.set(image, forKey: thumbName)
                    loadedImages[generation.id] = image
                }
                loadingIds.remove(generation.id)
            }
        }
    }

    private func selectFullImage(for generation: Generation) {
        let fullImageName = generation.id.uuidString

        if let cached = ImageCache.shared.get(forKey: fullImageName) {
            onImageSelected(cached)
            dismiss()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            if let image = loadImageFromiCloud(fullImageName) {
                ImageCache.shared.set(image, forKey: fullImageName)
                DispatchQueue.main.async {
                    onImageSelected(image)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Generation Image Card

private struct GenerationImageCard: View {
    let generation: Generation
    let image: PlatformImage?
    let isLoading: Bool
    let onSelect: () -> Void

    @State private var isHovering = false

    private var aspectRatio: CGFloat {
        let dims = generation.dimensions

        if dims.contains(":") {
            let parts = dims.split(separator: ":")
            guard parts.count == 2,
                  let width = Double(parts[0]),
                  let height = Double(parts[1]),
                  height > 0
            else {
                return 1.0
            }
            return CGFloat(width / height)
        }

        let parts = dims.split(separator: "x")
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1]),
              height > 0
        else {
            return 1.0
        }
        return CGFloat(width / height)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .aspectRatio(aspectRatio, contentMode: .fit)

                    if isLoading {
                        GradientSpinner()
                    } else if let image {
                        #if os(macOS)
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        #else
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        #endif
                    } else {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isHovering ? Color.accentColor : Color.secondary,
                            lineWidth: isHovering ? 2 : 1
                        )
                )
                .shadow(color: isHovering ? Color.accentColor.opacity(0.3) : Color.clear, radius: 8)

                Text(generation.prompt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
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
