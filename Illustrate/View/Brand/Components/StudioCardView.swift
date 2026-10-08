// MARK: - StudioCardView.swift

// Card rendering for creative studio items in a grid.
//
// Displays a generated brand asset with:
// - Thumbnail/preview loading
// - Asset type badge
// - Context menu actions (Edit, Delete)
// - Expand view support
//
// ## Media Loading
// Uses ICloudImageLoader for async loading from iCloud.
// Shows loading indicator while fetching.
//
// ## Context Actions
// - Edit: Opens edit sheet for iteration with source image
// - Remove from studio: Remove item from the studio

import SwiftData
import SwiftUI

#if !os(macOS)
import Photos
import UIKit
#endif

/// Card component for creative studio items in grid.
struct StudioCardView: View {
    let item: CreativeStudioItem
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var loadedImage: PlatformImage?
    @State private var isLoadingImage = false
    @State private var showExpandedImage = false
    @State private var imageSize: CGSize = .zero

    private let cardWidth: CGFloat = 280

    var body: some View {
        cardContent
            .onAppear {
                loadImageIfNeeded()
            }
            .onChange(of: item.generationId) { _, _ in
                loadImageIfNeeded()
            }
            #if os(macOS)
            .sheet(isPresented: $showExpandedImage) {
                if let genId = item.generationId {
                    ExpandedImageView(
                        imageName: genId.uuidString,
                        isPresented: $showExpandedImage
                    )
                }
            }
            #else
            .fullScreenCover(isPresented: $showExpandedImage) {
                if let genId = item.generationId {
                    ExpandedImageView(
                        imageName: genId.uuidString,
                        isPresented: $showExpandedImage
                    )
                }
            }
            #endif
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        if item.status == .GENERATED, loadedImage != nil {
            generatedCard
                .contextMenu {
                    contextMenuContent
                }
        } else if item.status == .PROCESSING {
            processingCard
        } else {
            failedCard
                .contextMenu {
                    contextMenuContent
                }
        }
    }

    // MARK: - Generated Card

    private var generatedCard: some View {
        VStack(spacing: 0) {
            // Header with asset type
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: item.assetTypeEnum.icon)
                    .foregroundStyle(label)
                    .frame(width: 16, height: 16)

                Text(item.assetTypeEnum.displayName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .frame(width: 16, height: 16)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Image content
            if let image = loadedImage {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: calculatedCardWidth, height: calculatedImageHeight)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        expandButton
                    }
                #else
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: calculatedCardWidth, height: calculatedImageHeight)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        expandButton
                    }
                #endif
            }

            Divider()

            // Footer with prompt preview
            VStack(alignment: .leading, spacing: 4) {
                Text(item.userPrompt)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formatDate(item.createdAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: calculatedCardWidth)
        .background(systemBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(secondaryLabel.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Processing Card

    private var processingCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: item.assetTypeEnum.icon)
                    .foregroundStyle(label)
                    .frame(width: 16, height: 16)

                Text(item.assetTypeEnum.displayName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                GradientSpinner()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Shimmer placeholder
            Rectangle()
                .fill(secondarySystemFill)
                .frame(width: cardWidth, height: 200)
                .shimmer(isAnimating: true)

            Divider()

            // Footer
            VStack(alignment: .leading, spacing: 4) {
                Text(item.userPrompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    Text("Generating...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: cardWidth)
        .background(systemBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
    }

    // MARK: - Failed Card

    private var failedCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: item.assetTypeEnum.icon)
                    .foregroundStyle(label)
                    .font(.system(size: 13, weight: .semibold))

                Text(item.assetTypeEnum.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Error content
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(.red)

                Text("Generation Failed")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if let error = item.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 12)
                }
            }
            .frame(width: cardWidth, height: 200)

            Divider()

            // Footer
            VStack(alignment: .leading, spacing: 4) {
                Text(item.userPrompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formatDate(item.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: cardWidth)
        .background(systemBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
    }

    // MARK: - Expand Button

    private var expandButton: some View {
        Button {
            showExpandedImage = true
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(8)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(8)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        if item.status == .GENERATED {
            Button {
                onEdit?()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Divider()

            Button {
                if let genId = item.generationId, let image = loadImageFromiCloud(genId.uuidString) {
                    #if os(macOS)
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([image])
                    #else
                    UIPasteboard.general.image = image
                    #endif
                    showToast(.success("Copied to clipboard"))
                }
            } label: {
                Label("Copy image", systemImage: "doc.on.doc")
            }
            .disabled(item.generationId == nil)

            Button {
                if let genId = item.generationId, let image = loadImageFromiCloud(genId.uuidString) {
                    #if os(macOS)
                    image.saveImageToDownloads(fileName: genId.uuidString)
                    #else
                    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                        DispatchQueue.main.async {
                            if status == .authorized || status == .limited {
                                PHPhotoLibrary.shared().performChanges {
                                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                                }
                            }
                        }
                    }
                    #endif
                }
            } label: {
                Label("Download image", systemImage: "arrow.down")
            }
            .disabled(item.generationId == nil)

            Button {
                if let genId = item.generationId, let image = loadImageFromiCloud(genId.uuidString) {
                    #if os(macOS)
                    image.shareImage()
                    #else
                    UIPasteboard.general.image = image
                    showToast(.success("Copied to clipboard for sharing"))
                    #endif
                }
            } label: {
                Label("Share image", systemImage: "square.and.arrow.up")
            }
            .disabled(item.generationId == nil)

            Divider()
        }

        Button(role: .destructive) {
            onDelete?()
        } label: {
            Label("Remove from studio", systemImage: "trash")
        }
    }

    // MARK: - Image Size Calculations

    private var calculatedCardWidth: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return cardWidth
        }

        let aspectRatio = imageSize.width / imageSize.height

        if aspectRatio >= 1.5 {
            return 320
        } else if aspectRatio >= 1.2 {
            return 300
        } else if aspectRatio >= 0.9 {
            return 280
        } else if aspectRatio >= 0.7 {
            return 260
        } else {
            return 240
        }
    }

    private var calculatedImageHeight: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return 200
        }

        let aspectRatio = imageSize.width / imageSize.height
        let height = calculatedCardWidth / aspectRatio

        return min(max(height, 150), 400)
    }

    // MARK: - Image Loading

    private func loadImageIfNeeded() {
        guard let generationId = item.generationId else {
            loadedImage = nil
            return
        }

        let fileName = generationId.uuidString

        // Check cache first
        if let cached = ImageCache.shared.get(forKey: fileName) {
            loadedImage = cached
            imageSize = cached.size
            return
        }

        // Load from iCloud
        isLoadingImage = true
        DispatchQueue.global(qos: .userInitiated).async {
            let image = loadImageFromiCloud(fileName)
            DispatchQueue.main.async {
                if let img = image {
                    ImageCache.shared.set(img, forKey: fileName)
                    loadedImage = img
                    imageSize = img.size
                }
                isLoadingImage = false
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Shimmer Modifier

extension View {
    @ViewBuilder
    func shimmer(isAnimating: Bool) -> some View {
        if isAnimating {
            modifier(ShimmerModifier())
        } else {
            self
        }
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.1),
                            Color.clear,
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}
