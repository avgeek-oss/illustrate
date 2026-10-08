import SwiftData
import SwiftUI

enum ProductGalleryEditMode {
    case create
    case edit(ProductGalleryItem)
}

struct ProductGalleryEditSheet: View {
    let mode: ProductGalleryEditMode
    let modelContext: ModelContext
    var onSave: ((String, [String]) -> Void)?
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss: DismissAction
    @EnvironmentObject private var projectManager: ProjectManager

    @State private var productName = ""
    @State private var tagInput = ""
    @State private var tags: [String] = []
    @State private var selectedImage: PlatformImage?
    @State private var isImagePickerOpen = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Product Name", text: $productName)
                    imageUploadField
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
                                ProductTagChip(tag: tag) {
                                    tags.removeAll { $0 == tag }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Tags")
                }

                if isEditing {
                    Section {
                        Button("Delete Product", role: .destructive) {
                            if let onDelete: () -> Void { onDelete() }
                            dismiss()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Product" : "Add Product")
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
                        saveProduct()
                        dismiss()
                    }
                    .disabled(productName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 450, minHeight: 400)
        #endif
        .onAppear {
            if case let .edit(item) = mode {
                productName = item.productName
                tags = item.tags
                if let thumbName: String = item.largeThumbFileName ?? item.thumbFileName ?? item.imageFileName {
                    selectedImage = ImageCache.shared.get(forKey: thumbName) ?? loadImageFromiCloud(thumbName)
                }
            }
        }
    }

    private var imageUploadField: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 100, height: 100)

                if let selectedImage: PlatformImage {
                    #if os(macOS)
                    Image(nsImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(width: 100, height: 100)
                    #else
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(width: 100, height: 100)
                    #endif
                } else {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
            .onTapGesture {
                isImagePickerOpen = true
            }

            if selectedImage != nil {
                Button("Remove") {
                    selectedImage = nil
                }
                .foregroundStyle(.red)
            }

            Spacer()
        }
        .imageSelection(
            id: "productGalleryImagePicker",
            isPickerOpen: $isImagePickerOpen,
            sources: .uploadsOnly,
            onImageSelected: { image in
                selectedImage = image
            }
        )
    }

    private func saveProduct() {
        let trimmedName: String = productName.trimmingCharacters(in: .whitespaces)

        switch mode {
        case .create:
            var imageFileName: String?
            var thumbFileName: String?
            var largeThumbFileName: String?

            if let image: PlatformImage = selectedImage {
                let itemId = UUID()
                let baseName = "product_gallery_\(itemId.uuidString)"

                imageFileName = baseName
                image.saveToiCloud(fileName: baseName)

                let imageSize: CGSize = image.size
                let aspectRatio: CGFloat = imageSize.width / imageSize.height

                let smallMaxDimension: CGFloat = 96
                let smallThumbnailSize = if aspectRatio > 1 {
                    CGSize(width: smallMaxDimension, height: smallMaxDimension / aspectRatio)
                } else {
                    CGSize(width: smallMaxDimension * aspectRatio, height: smallMaxDimension)
                }
                if let smallThumbnail: PlatformImage = image.resizeImage(targetSize: smallThumbnailSize) {
                    thumbFileName = baseName + "_thumb"
                    smallThumbnail.saveToiCloud(fileName: thumbFileName!)
                }

                let largeMaxDimension: CGFloat = 320
                let largeThumbnailSize = if aspectRatio > 1 {
                    CGSize(width: largeMaxDimension, height: largeMaxDimension / aspectRatio)
                } else {
                    CGSize(width: largeMaxDimension * aspectRatio, height: largeMaxDimension)
                }
                if let largeThumbnail: PlatformImage = image.resizeImage(targetSize: largeThumbnailSize) {
                    largeThumbFileName = baseName + "_thumb_large"
                    largeThumbnail.saveToiCloud(fileName: largeThumbFileName!)
                }
            }

            let item = ProductGalleryItem(
                projectId: projectManager.currentProjectId,
                productName: trimmedName,
                tags: tags,
                imageFileName: imageFileName,
                thumbFileName: thumbFileName,
                largeThumbFileName: largeThumbFileName
            )
            modelContext.insert(item)

        case let .edit(existingItem):
            existingItem.productName = trimmedName
            existingItem.tags = tags
            existingItem.updatedAt = Date()

            if let image: PlatformImage = selectedImage {
                if let oldFileName: String = existingItem.imageFileName {
                    deleteImageFromiCloud(fileName: oldFileName)
                }
                if let oldThumb: String = existingItem.thumbFileName {
                    deleteImageFromiCloud(fileName: oldThumb)
                }
                if let oldLargeThumb: String = existingItem.largeThumbFileName {
                    deleteImageFromiCloud(fileName: oldLargeThumb)
                }

                let baseName = "product_gallery_\(existingItem.id.uuidString)"
                existingItem.imageFileName = baseName
                image.saveToiCloud(fileName: baseName)

                let imageSize: CGSize = image.size
                let aspectRatio: CGFloat = imageSize.width / imageSize.height

                let smallMaxDimension: CGFloat = 96
                let smallThumbnailSize = if aspectRatio > 1 {
                    CGSize(width: smallMaxDimension, height: smallMaxDimension / aspectRatio)
                } else {
                    CGSize(width: smallMaxDimension * aspectRatio, height: smallMaxDimension)
                }
                if let smallThumbnail: PlatformImage = image.resizeImage(targetSize: smallThumbnailSize) {
                    existingItem.thumbFileName = baseName + "_thumb"
                    smallThumbnail.saveToiCloud(fileName: existingItem.thumbFileName!)
                }

                let largeMaxDimension: CGFloat = 320
                let largeThumbnailSize = if aspectRatio > 1 {
                    CGSize(width: largeMaxDimension, height: largeMaxDimension / aspectRatio)
                } else {
                    CGSize(width: largeMaxDimension * aspectRatio, height: largeMaxDimension)
                }
                if let largeThumbnail: PlatformImage = image.resizeImage(targetSize: largeThumbnailSize) {
                    existingItem.largeThumbFileName = baseName + "_thumb_large"
                    largeThumbnail.saveToiCloud(fileName: existingItem.largeThumbFileName!)
                }
            }
        }

        onSave?(trimmedName, tags)
    }

    private func addTag() {
        let trimmed: String = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tagInput = ""
    }

    private func deleteImageFromiCloud(fileName: String) {
        guard let containerURL: URL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
        else { return }

        let fileURL: URL = containerURL.appendingPathComponent("\(fileName).png")
        try? FileManager.default.removeItem(at: fileURL)
    }
}

private struct ProductTagChip: View {
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
