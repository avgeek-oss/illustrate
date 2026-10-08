// MARK: - ImageSelectionModifier.swift

// Unified image selection system with multiple source options.
//
// Provides a consistent interface for selecting images from:
// - Photo Library (PhotosPicker)
// - File System (fileImporter)
// - Brand Kit images
// - Recent generations
//
// ## Optional Crop
// When enableCrop is true, presents ImageCropAdapter after selection
// to crop the image to target dimensions.
//
// ## Image Processing
// After selection (and optional crop):
// - Resize to maxImagePixels if exceeded
// - Compress to maxImageSizeBytes if exceeded
//
// ## Usage
// ```swift
// .imageSelection(
//     isPickerOpen: $showPicker,
//     enableCrop: true,
//     cropDimensions: "1024x1024",
//     onImageSelected: { image in ... }
// )
// ```

import OSLog
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

// MARK: - Image Transferable

/// A Transferable type for loading images from PhotosPicker.
/// Uses explicit type representations for JPEG, PNG, HEIC to ensure proper loading.
struct ImageTransferable: Transferable {
    let image: PlatformImage

    static var transferRepresentation: some TransferRepresentation {
        // Explicit representations for common image types
        DataRepresentation(importedContentType: .jpeg) { data in
            guard let image = platformImage(from: data) else {
                throw TransferError.importFailed
            }
            return ImageTransferable(image: image)
        }
        DataRepresentation(importedContentType: .png) { data in
            guard let image = platformImage(from: data) else {
                throw TransferError.importFailed
            }
            return ImageTransferable(image: image)
        }
        DataRepresentation(importedContentType: .heic) { data in
            guard let image = platformImage(from: data) else {
                throw TransferError.importFailed
            }
            return ImageTransferable(image: image)
        }
        DataRepresentation(importedContentType: .heif) { data in
            guard let image = platformImage(from: data) else {
                throw TransferError.importFailed
            }
            return ImageTransferable(image: image)
        }
        DataRepresentation(importedContentType: .gif) { data in
            guard let image = platformImage(from: data) else {
                throw TransferError.importFailed
            }
            return ImageTransferable(image: image)
        }
        DataRepresentation(importedContentType: .tiff) { data in
            guard let image = platformImage(from: data) else {
                throw TransferError.importFailed
            }
            return ImageTransferable(image: image)
        }
        DataRepresentation(importedContentType: .webP) { data in
            guard let image = platformImage(from: data) else {
                throw TransferError.importFailed
            }
            return ImageTransferable(image: image)
        }
        DataRepresentation(importedContentType: .bmp) { data in
            guard let image = platformImage(from: data) else {
                throw TransferError.importFailed
            }
            return ImageTransferable(image: image)
        }
    }

    enum TransferError: Error {
        case importFailed
    }

    private static func platformImage(from data: Data) -> PlatformImage? {
        #if os(macOS)
        return NSImage(data: data)
        #else
        return UIImage(data: data)
        #endif
    }
}

// MARK: - Image Source Options

struct ImageSourceOptions: OptionSet {
    let rawValue: UInt
    static let photoLibrary = ImageSourceOptions(rawValue: 1 << 0)
    static let chooseFile = ImageSourceOptions(rawValue: 1 << 1)
    static let brandKit = ImageSourceOptions(rawValue: 1 << 2)
    static let productGallery = ImageSourceOptions(rawValue: 1 << 3)
    static let recentGenerations = ImageSourceOptions(rawValue: 1 << 4)

    static let all: ImageSourceOptions = [.photoLibrary, .chooseFile, .brandKit, .productGallery, .recentGenerations]
    static let uploadsOnly: ImageSourceOptions = [.photoLibrary, .chooseFile]
}

// MARK: - Image Selection Modifier

/// A unified ViewModifier that handles image source selection with optional crop sheet.
struct ImageSelectionModifier: ViewModifier {
    let id: String
    @Binding var isPickerOpen: Bool
    let sources: ImageSourceOptions
    let onImageSelected: (PlatformImage) -> Void

    // Crop configuration
    let enableCrop: Bool
    let cropDimensions: String?
    let maxImagePixels: Int?
    let maxImageSizeBytes: Int?
    let onCropConfirm: ((PlatformImage) -> Void)?
    let onCropCancel: (() -> Void)?

    /// Optional external image input (e.g., from drag & drop)
    @Binding var droppedImage: PlatformImage?

    @State private var showingSourceOptions = false
    @State private var showingPhotosPicker = false
    @State private var showingFileImporter = false
    @State private var showingBrandKitPicker = false
    @State private var showingGenerationsPicker = false
    @State private var showingProductGalleryPicker = false
    @State private var pickerItem: PhotosPickerItem?

    @State private var pendingImage: IdentifiableImage?
    @State private var cropSessionId = UUID()

    func body(content: Content) -> some View {
        content
            .onChange(of: isPickerOpen) { _, newValue in
                if newValue {
                    showingSourceOptions = true
                    isPickerOpen = false
                }
            }
            .onChange(of: droppedImage) { _, newImage in
                if let image = newImage {
                    droppedImage = nil
                    processImage(image)
                }
            }
            .sheet(isPresented: $showingSourceOptions) {
                ImageSourceOptionsSheet(
                    sources: sources,
                    onPhotoLibrary: {
                        showingSourceOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingPhotosPicker = true
                        }
                    },
                    onChooseFile: {
                        showingSourceOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            #if os(macOS)
                            showMacOpenPanel()
                            #else
                            showingFileImporter = true
                            #endif
                        }
                    },
                    onRecentGenerations: {
                        showingSourceOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingGenerationsPicker = true
                        }
                    },
                    onBrandKit: {
                        showingSourceOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingBrandKitPicker = true
                        }
                    },
                    onProductGallery: {
                        showingSourceOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingProductGalleryPicker = true
                        }
                    }
                )
            }
            .photosPicker(
                isPresented: $showingPhotosPicker,
                selection: $pickerItem,
                matching: .images
            )
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    guard let url = urls.first else { return }
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }

                    if let data = try? Data(contentsOf: url),
                       let image = platformImage(from: data)
                    {
                        processImage(image)
                    }
                case let .failure(error):
                    AppLogger.ui.error("File import error: \(error.localizedDescription, privacy: .public)")
                }
            }
            .sheet(isPresented: $showingBrandKitPicker) {
                BrandKitImagePicker(onImageSelected: processImage)
            }
            .sheet(isPresented: $showingGenerationsPicker) {
                GenerationsImagePicker(onImageSelected: processImage)
            }
            .sheet(isPresented: $showingProductGalleryPicker) {
                ProductGalleryImagePicker(onImageSelected: processImage)
            }
            .onChange(of: pickerItem) {
                guard let item = pickerItem else { return }
                Task {
                    // Try loading the image using multiple strategies
                    var loadedImage: PlatformImage?

                    // Strategy 1: Try ImageTransferable (works for most cases)
                    if loadedImage == nil {
                        do {
                            if let transferable = try await item.loadTransferable(type: ImageTransferable.self) {
                                loadedImage = transferable.image
                            }
                        } catch {
                            AppLogger.ui
                                .debug(
                                    "PhotosPicker: ImageTransferable failed - \(error.localizedDescription, privacy: .public)"
                                )
                        }
                    }

                    // Strategy 2: Try loading as Data directly (fallback for problematic cases)
                    if loadedImage == nil {
                        do {
                            if let data = try await item.loadTransferable(type: Data.self) {
                                #if os(macOS)
                                loadedImage = NSImage(data: data)
                                #else
                                loadedImage = UIImage(data: data)
                                #endif
                            }
                        } catch {
                            AppLogger.ui
                                .debug(
                                    "PhotosPicker: Data fallback failed - \(error.localizedDescription, privacy: .public)"
                                )
                        }
                    }

                    if let image = loadedImage {
                        await MainActor.run {
                            processImage(image)
                        }
                    } else {
                        AppLogger.ui.error("PhotosPicker: All image loading strategies failed")
                    }

                    await MainActor.run {
                        pickerItem = nil
                    }
                }
            }
            .sheet(item: $pendingImage) { item in
                if enableCrop {
                    let effectiveDimensions = (cropDimensions?.isEmpty == false) ? cropDimensions! : "1024x1024"
                    ImageCropAdapter(
                        image: item.image,
                        cropDimensions: effectiveDimensions,
                        sessionId: cropSessionId,
                        onCropConfirm: { croppedImage in
                            var finalImage = croppedImage
                            if let maxPx = maxImagePixels, croppedImage.pixelCount > maxPx {
                                finalImage = croppedImage.resizedToFit(maxPixels: maxPx)
                            }
                            if let maxSize = maxImageSizeBytes, finalImage.estimatedDataSize() > maxSize {
                                finalImage = finalImage.compressedToFit(maxSizeBytes: maxSize)
                            }
                            pendingImage = nil
                            onImageSelected(finalImage)
                            onCropConfirm?(finalImage)
                        },
                        onCropCancel: {
                            pendingImage = nil
                            onCropCancel?()
                        }
                    )
                }
            }
    }

    private func platformImage(from data: Data) -> PlatformImage? {
        #if os(macOS)
        return NSImage(data: data)
        #else
        return UIImage(data: data)
        #endif
    }

    #if os(macOS)
    private func showMacOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Choose an Image"

        // Use begin() instead of runModal() to avoid conflicts with SwiftUI's modal state
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let data = try? Data(contentsOf: url),
                   let image = platformImage(from: data)
                {
                    DispatchQueue.main.async {
                        processImage(image)
                    }
                }
            }
        }
    }
    #endif

    private func processImage(_ image: PlatformImage) {
        if enableCrop {
            pendingImage = IdentifiableImage(image: image)
            cropSessionId = UUID()
        } else {
            onImageSelected(image)
        }
    }
}

// MARK: - Image Source Options Sheet

private struct ImageSourceOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let sources: ImageSourceOptions
    let onPhotoLibrary: () -> Void
    let onChooseFile: () -> Void
    let onRecentGenerations: () -> Void
    let onBrandKit: () -> Void
    let onProductGallery: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if sources.contains(.photoLibrary) {
                    ImageSourceButton(
                        title: "Photo Library",
                        icon: "photo.on.rectangle",
                        action: onPhotoLibrary
                    )
                }
                if sources.contains(.chooseFile) {
                    ImageSourceButton(
                        title: "Choose File",
                        icon: "folder",
                        action: onChooseFile
                    )
                }
                if sources.contains(.brandKit) {
                    ImageSourceButton(
                        title: "Brand Kit",
                        icon: "briefcase",
                        action: onBrandKit
                    )
                }
                if sources.contains(.productGallery) {
                    ImageSourceButton(
                        title: "Product Gallery",
                        icon: "lamp.floor",
                        action: onProductGallery
                    )
                }
                if sources.contains(.recentGenerations) {
                    ImageSourceButton(
                        title: "Recent Generations",
                        icon: "sparkles.rectangle.stack",
                        action: onRecentGenerations
                    )
                }
            }
            .listStyle(.inset)
            .navigationTitle("Choose Image Source")
            #if os(macOS)
            .frame(minWidth: 240, minHeight: 160)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ImageSourceButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Extension

extension View {
    /// Adds image source selection with optional crop sheet.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for this picker instance (required when using multiple pickers)
    ///   - isPickerOpen: Binding to trigger the picker
    ///   - enableCrop: Whether to show crop sheet after selection (default: false)
    ///   - cropDimensions: Target dimensions for cropping (e.g., "1024x1024")
    ///   - maxImagePixels: Optional max pixels to resize image after crop
    ///   - maxImageSizeBytes: Optional max file size in bytes to compress image after crop
    ///   - droppedImage: Optional binding for external image input (e.g., from drag & drop).
    ///   - onCropConfirm: Optional callback when crop is confirmed
    ///   - onCropCancel: Optional callback when crop is cancelled
    ///   - onImageSelected: Callback with the selected (and optionally cropped) image
    func imageSelection(
        id: String = "default",
        isPickerOpen: Binding<Bool>,
        sources: ImageSourceOptions = .all,
        enableCrop: Bool = false,
        cropDimensions: String? = nil,
        maxImagePixels: Int? = nil,
        maxImageSizeBytes: Int? = nil,
        droppedImage: Binding<PlatformImage?> = .constant(nil),
        onCropConfirm: ((PlatformImage) -> Void)? = nil,
        onCropCancel: (() -> Void)? = nil,
        onImageSelected: @escaping (PlatformImage) -> Void
    ) -> some View {
        modifier(ImageSelectionModifier(
            id: id,
            isPickerOpen: isPickerOpen,
            sources: sources,
            onImageSelected: onImageSelected,
            enableCrop: enableCrop,
            cropDimensions: cropDimensions,
            maxImagePixels: maxImagePixels,
            maxImageSizeBytes: maxImageSizeBytes,
            onCropConfirm: onCropConfirm,
            onCropCancel: onCropCancel,
            droppedImage: droppedImage
        ))
    }
}

// MARK: - Generation Navigation Modifiers

/// View modifier for image generation navigation destination
struct ImageGenerationNavigationModifier: ViewModifier {
    @Binding var isNavigationActive: Bool
    @Binding var selectedSetId: UUID?
    var onDisappear: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .navigationDestination(isPresented: $isNavigationActive) {
                if let setId = selectedSetId {
                    GenerationImageView(setId: setId)
                        .onDisappear {
                            DispatchQueue.main.async {
                                isNavigationActive = false
                                selectedSetId = nil
                                onDisappear?()
                            }
                        }
                }
            }
    }
}

/// View modifier for video generation navigation destination
struct VideoGenerationNavigationModifier: ViewModifier {
    @Binding var isNavigationActive: Bool
    @Binding var selectedSetId: UUID?
    var onDisappear: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .navigationDestination(isPresented: $isNavigationActive) {
                if let setId = selectedSetId {
                    GenerationVideoView(setId: setId)
                        .onDisappear {
                            DispatchQueue.main.async {
                                isNavigationActive = false
                                selectedSetId = nil
                                onDisappear?()
                            }
                        }
                }
            }
    }
}

extension View {
    /// Adds navigation destination for image generation results.
    func imageGenerationNavigation(
        isPresented: Binding<Bool>,
        setId: Binding<UUID?>,
        onDisappear: (() -> Void)? = nil
    ) -> some View {
        modifier(ImageGenerationNavigationModifier(
            isNavigationActive: isPresented,
            selectedSetId: setId,
            onDisappear: onDisappear
        ))
    }

    /// Adds navigation destination for video generation results.
    func videoGenerationNavigation(
        isPresented: Binding<Bool>,
        setId: Binding<UUID?>,
        onDisappear: (() -> Void)? = nil
    ) -> some View {
        modifier(VideoGenerationNavigationModifier(
            isNavigationActive: isPresented,
            selectedSetId: setId,
            onDisappear: onDisappear
        ))
    }
}
