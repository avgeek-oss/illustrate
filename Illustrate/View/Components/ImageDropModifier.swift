// MARK: - ImageDropModifier.swift

// Drag and drop support for image input fields.
//
// Provides a reusable modifier that enables image drop functionality:
// - Accepts dropped images from Finder, Photos, or other apps
// - Provides visual feedback via isTargeted binding
// - Converts dropped data to PlatformImage
// - Supports single and multi-image drops
//
// ## Supported Types
// - PNG, JPEG, TIFF, GIF, HEIC images
// - File URLs pointing to images
//
// ## Usage
// ```swift
// // Single drop only
// .imageDropTarget(isTargeted: $isDropTargeted) { image in
//     selectedImage = image
// }
//
// // With multi-drop support
// .imageDropTarget(isTargeted: $isDropTargeted) { image in
//     selectedImage = image
// } onMultipleImagesDropped: { images in
//     attachedImages.append(contentsOf: images)
// }
// ```

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Image Drop Modifier

/// A ViewModifier that enables drag and drop of images onto a view.
struct ImageDropModifier: ViewModifier {
    /// Binding that indicates when a valid drop is hovering over the view
    @Binding var isTargeted: Bool
    /// Callback invoked when a single image is dropped
    let onImageDropped: (PlatformImage) -> Void
    /// Callback invoked when multiple images are dropped at once
    let onMultipleImagesDropped: (([PlatformImage]) -> Void)?

    func body(content: Content) -> some View {
        content
            .dropDestination(for: Data.self) { items, _ in
                handleDrop(items: items)
            } isTargeted: { targeted in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isTargeted = targeted
                }
            }
    }

    private func handleDrop(items: [Data]) -> Bool {
        let images = items.compactMap { platformImage(from: $0) }
        guard !images.isEmpty else { return false }

        if images.count > 1, let multiCallback = onMultipleImagesDropped {
            multiCallback(images)
        } else if let firstImage = images.first {
            onImageDropped(firstImage)
        }

        return true
    }

    private func platformImage(from data: Data) -> PlatformImage? {
        #if os(macOS)
        return NSImage(data: data)
        #else
        return UIImage(data: data)
        #endif
    }
}

// MARK: - URL Drop Modifier

/// A ViewModifier that enables drag and drop of image files (URLs) onto a view.
struct ImageURLDropModifier: ViewModifier {
    @Binding var isTargeted: Bool
    let onImageDropped: (PlatformImage) -> Void
    let onMultipleImagesDropped: (([PlatformImage]) -> Void)?

    func body(content: Content) -> some View {
        content
            .dropDestination(for: URL.self) { urls, _ in
                handleURLDrop(urls: urls)
            } isTargeted: { targeted in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isTargeted = targeted
                }
            }
    }

    private func handleURLDrop(urls: [URL]) -> Bool {
        var images: [PlatformImage] = []

        for url in urls {
            // Check if URL points to an image file
            guard let typeIdentifier = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
                  let utType = UTType(typeIdentifier),
                  utType.conforms(to: .image)
            else {
                continue
            }

            // Try to load the image
            let gotAccess = url.startAccessingSecurityScopedResource()
            defer {
                if gotAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            if let data = try? Data(contentsOf: url),
               let image = platformImage(from: data)
            {
                images.append(image)
            }
        }

        guard !images.isEmpty else { return false }

        if images.count > 1, let multiCallback = onMultipleImagesDropped {
            multiCallback(images)
        } else if let firstImage = images.first {
            onImageDropped(firstImage)
        }

        return true
    }

    private func platformImage(from data: Data) -> PlatformImage? {
        #if os(macOS)
        return NSImage(data: data)
        #else
        return UIImage(data: data)
        #endif
    }
}

// MARK: - Combined Image Drop Modifier

/// A ViewModifier that accepts both image data and image file URLs.
struct CombinedImageDropModifier: ViewModifier {
    @Binding var isTargeted: Bool
    let onImageDropped: (PlatformImage) -> Void
    let onMultipleImagesDropped: (([PlatformImage]) -> Void)?

    @State private var isDataTargeted = false
    @State private var isURLTargeted = false

    func body(content: Content) -> some View {
        content
            .modifier(ImageDropModifier(
                isTargeted: $isDataTargeted,
                onImageDropped: onImageDropped,
                onMultipleImagesDropped: onMultipleImagesDropped
            ))
            .modifier(ImageURLDropModifier(
                isTargeted: $isURLTargeted,
                onImageDropped: onImageDropped,
                onMultipleImagesDropped: onMultipleImagesDropped
            ))
            .onChange(of: isDataTargeted) { _, newValue in
                updateTargeted(newValue || isURLTargeted)
            }
            .onChange(of: isURLTargeted) { _, newValue in
                updateTargeted(newValue || isDataTargeted)
            }
    }

    private func updateTargeted(_ value: Bool) {
        if isTargeted != value {
            isTargeted = value
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds image drop functionality to a view.
    ///
    /// When an image is dragged over the view, `isTargeted` becomes true,
    /// allowing the view to show visual feedback. When dropped, the
    /// appropriate callback is invoked.
    ///
    /// Supports:
    /// - Direct image data (PNG, JPEG, etc.)
    /// - Image file URLs from Finder or other apps
    /// - Single and multiple image drops
    ///
    /// - Parameters:
    ///   - isTargeted: Binding that indicates when a valid drop is hovering
    ///   - onImageDropped: Callback with a single dropped PlatformImage
    ///   - onMultipleImagesDropped: Optional callback when multiple images are dropped at once.
    ///     If not provided and multiple images are dropped, only the first image triggers `onImageDropped`.
    /// - Returns: Modified view with drop support
    func imageDropTarget(
        isTargeted: Binding<Bool>,
        onImageDropped: @escaping (PlatformImage) -> Void,
        onMultipleImagesDropped: (([PlatformImage]) -> Void)? = nil
    ) -> some View {
        modifier(CombinedImageDropModifier(
            isTargeted: isTargeted,
            onImageDropped: onImageDropped,
            onMultipleImagesDropped: onMultipleImagesDropped
        ))
    }
}
