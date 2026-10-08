// MARK: - BrandKitImagePicker.swift

// Picker for selecting images from the project's brand kit.
//
// Displays all uploaded brand kit images (logo, icon, etc.) in a
// grid for selection as reference images in generation.
//
// ## Image Loading
// Loads thumbnails first, then fetches full images when selected.
// Uses ImageCache for performance.

import AvgeekDesignSystem
import SwiftData
import SwiftUI

/// Represents a selectable brand image (either logo or model asset)
private enum BrandImageItem: Identifiable {
    case logo(BrandImageVariant)
    case modelAsset(ModelAsset)

    var id: String {
        switch self {
        case let .logo(variant):
            "logo_\(variant.rawValue)"
        case let .modelAsset(asset):
            "model_\(asset.id.uuidString)"
        }
    }

    var displayName: String {
        switch self {
        case let .logo(variant):
            variant.displayName
        case .modelAsset:
            "Model Asset"
        }
    }
}

/// Grid picker for selecting brand kit images.
struct BrandKitImagePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var brandKitManager = BrandKitManager.shared
    @StateObject private var projectManager = ProjectManager.shared

    let onImageSelected: (PlatformImage) -> Void

    @State private var logoImages: [BrandImageVariant: PlatformImage] = [:]
    @State private var modelAssetImages: [UUID: PlatformImage] = [:]
    @State private var loadingItems: Set<String> = []

    private var availableItems: [(item: BrandImageItem, image: PlatformImage)] {
        var items: [(BrandImageItem, PlatformImage)] = []

        // Add logos
        for variant in BrandImageVariant.allCases {
            if let image = logoImages[variant] {
                items.append((.logo(variant), image))
            }
        }

        // Add model assets
        if let kit = brandKitManager.currentBrandKit {
            for asset in kit.modelAssets {
                if let image = modelAssetImages[asset.id] {
                    items.append((.modelAsset(asset), image))
                }
            }
        }

        return items
    }

    var body: some View {
        NavigationStack {
            Group {
                if !loadingItems.isEmpty, availableItems.isEmpty {
                    ProgressView("Loading brand images...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if availableItems.isEmpty {
                    AvgeekEmptyStateView(
                        icon: "photo.on.rectangle.angled",
                        title: "No brand images available",
                        message: "Add images to your brand kit to use them here."
                    )
                } else {
                    imageGridView
                }
            }
            .navigationTitle("Brand Kit Images")
            #if os(macOS)
            .frame(minWidth: 640, minHeight: 400, maxHeight: 640)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            brandKitManager.ensureBrandKitExists(modelContext: modelContext, projectId: projectManager.currentProjectId)
            loadBrandImagesAsync()
        }
    }

    private var imageGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16),
            ], spacing: 16) {
                ForEach(availableItems, id: \.item.id) { item in
                    BrandImageCard(
                        displayName: item.item.displayName,
                        image: item.image,
                        onSelect: {
                            selectFullImage(for: item.item)
                        }
                    )
                }
            }
            .padding()
        }
    }

    private func selectFullImage(for item: BrandImageItem) {
        guard let kit = brandKitManager.currentBrandKit else { return }

        let fileName: String? = switch item {
        case let .logo(variant):
            kit.imageFileName(for: variant)
        case let .modelAsset(asset):
            asset.fileName
        }

        guard let fileName else { return }

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

    private func loadBrandImagesAsync() {
        guard let kit = brandKitManager.currentBrandKit else {
            logoImages = [:]
            modelAssetImages = [:]
            return
        }

        // Load logos
        for variant in BrandImageVariant.allCases {
            let largeThumbFileName = kit.largeThumbFileName(for: variant)
            let smallThumbFileName = kit.thumbFileName(for: variant)
            let fullFileName = kit.imageFileName(for: variant)

            guard let fileName = largeThumbFileName ?? smallThumbFileName ?? fullFileName else {
                logoImages[variant] = nil
                continue
            }

            let itemId = "logo_\(variant.rawValue)"

            if let cached = ImageCache.shared.get(forKey: fileName) {
                logoImages[variant] = cached
            } else {
                loadingItems.insert(itemId)
                DispatchQueue.global(qos: .userInitiated).async {
                    let image = loadImageFromiCloud(fileName)
                    DispatchQueue.main.async {
                        if let image {
                            ImageCache.shared.set(image, forKey: fileName)
                        }
                        logoImages[variant] = image
                        loadingItems.remove(itemId)
                    }
                }
            }
        }

        // Load model assets
        for asset in kit.modelAssets {
            let fileName = asset.largeThumbFileName

            let itemId = "model_\(asset.id.uuidString)"

            if let cached = ImageCache.shared.get(forKey: fileName) {
                modelAssetImages[asset.id] = cached
            } else {
                loadingItems.insert(itemId)
                DispatchQueue.global(qos: .userInitiated).async {
                    let image = loadImageFromiCloud(fileName)
                    DispatchQueue.main.async {
                        if let image {
                            ImageCache.shared.set(image, forKey: fileName)
                        }
                        modelAssetImages[asset.id] = image
                        loadingItems.remove(itemId)
                    }
                }
            }
        }
    }
}

// MARK: - Brand Image Card

private struct BrandImageCard: View {
    let displayName: String
    let image: PlatformImage
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .aspectRatio(1, contentMode: .fit)

                    #if os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(12)
                    #else
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(12)
                    #endif
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isHovering ? Color.accentColor : Color.secondary,
                            lineWidth: isHovering ? 2 : 1
                        )
                )
                .shadow(color: isHovering ? Color.accentColor.opacity(0.3) : Color.clear, radius: 8)

                Text(displayName)
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
