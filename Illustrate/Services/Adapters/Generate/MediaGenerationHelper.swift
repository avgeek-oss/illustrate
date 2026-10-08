// MARK: - MediaGenerationHelper.swift

// Helper utilities for post-processing generated media files.
//
// This file provides:
// 1. Error codes for generation failures
// 2. Optimized image scale definitions
// 3. MediaGenerationHelper for saving media assets
//
// ## Optimized Images
// When an image is generated, multiple scaled versions are saved:
// - o50: 50% scale (gallery grid)
// - o20: 20% scale (thumbnails)
// - o10: 10% scale (small thumbnails)
// - o04: 4% scale (tiny previews)
//
// Files are prefixed with "." to hide from casual browsing.
//
// ## Client Assets
// Input images used for generation are saved alongside results:
// - _client: Source image for img2img
// - _mask: Mask for inpainting
// - _lastframe: Last frame for video extension
// - _ref0, _ref1...: Reference images
// - _refvideo: Source video for video extension

import Foundation
import IllustrateProviders
import OSLog

// MARK: - Optimized Image Scales

/// Standard scales for generating optimized image variants
let optimizedImageScales: [(scale: Double, suffix: String)] = [
    (0.50, "o50"),
    (0.20, "o20"),
    (0.10, "o10"),
    (0.04, "o04"),
]

// MARK: - Media Processing Helper

enum MediaGenerationHelper {
    /// Saves optimized versions of an image at standard scales
    /// - Parameters:
    ///   - image: The source image to optimize
    ///   - uuid: The UUID for the file names
    static func saveOptimizedImageVersions(image: PlatformImage, uuid: UUID) async {
        await withTaskGroup(of: Void.self) { group in
            for (scale, suffix) in optimizedImageScales {
                group.addTask {
                    guard let resized = image.resizeImage(scale: scale),
                          let pngData = resized.toPNGData()
                    else { return }
                    _ = saveImageToDocumentsDirectory(
                        imageData: pngData,
                        withName: ".\(uuid)_\(suffix)"
                    )
                    resized.saveToiCloud(fileName: ".\(uuid)_\(suffix)")
                }
            }
        }
    }

    /// Saves client image if provided
    /// - Parameters:
    ///   - clientImage: Base64 encoded client image
    ///   - uuid: The UUID for the file name
    static func saveClientImage(clientImage: String?, uuid: UUID) {
        guard let clientImage,
              let clientImageData = Data(base64Encoded: clientImage, options: .ignoreUnknownCharacters)
        else { return }

        _ = saveImageToDocumentsDirectory(
            imageData: clientImageData,
            withName: ".\(uuid)_client"
        )
        if let image = toPlatformImage(from: clientImageData) {
            image.saveToiCloud(fileName: ".\(uuid)_client")
        }
    }

    /// Saves client mask if provided
    /// - Parameters:
    ///   - clientMask: Base64 encoded client mask
    ///   - uuid: The UUID for the file name
    static func saveClientMask(clientMask: String?, uuid: UUID) {
        guard let clientMask,
              let clientMaskData = Data(base64Encoded: clientMask, options: .ignoreUnknownCharacters)
        else { return }

        _ = saveImageToDocumentsDirectory(
            imageData: clientMaskData,
            withName: ".\(uuid)_mask"
        )
        if let image = toPlatformImage(from: clientMaskData) {
            image.saveToiCloud(fileName: ".\(uuid)_mask")
        }
    }

    /// Saves all client assets (image, mask, and reference images) for a generation
    /// - Parameters:
    ///   - clientImage: Base64 encoded client image
    ///   - clientMask: Base64 encoded client mask
    ///   - clientReferenceImages: Array of reference image data
    ///   - uuid: The UUID for the file names
    static func saveClientAssets(
        clientImage: String?,
        clientMask: String?,
        clientReferenceImages: [ReferenceImageData]? = nil,
        uuid: UUID
    ) {
        saveClientImage(clientImage: clientImage, uuid: uuid)
        saveClientMask(clientMask: clientMask, uuid: uuid)
        saveClientReferenceImages(clientReferenceImages: clientReferenceImages, uuid: uuid)
    }

    /// Saves client last frame if provided
    /// - Parameters:
    ///   - clientLastFrame: Base64 encoded client last frame image
    ///   - uuid: The UUID for the file name
    static func saveClientLastFrame(clientLastFrame: String?, uuid: UUID) {
        guard let clientLastFrame,
              let clientLastFrameData = Data(base64Encoded: clientLastFrame, options: .ignoreUnknownCharacters)
        else { return }

        _ = saveImageToDocumentsDirectory(
            imageData: clientLastFrameData,
            withName: ".\(uuid)_lastframe"
        )
        if let image = toPlatformImage(from: clientLastFrameData) {
            image.saveToiCloud(fileName: ".\(uuid)_lastframe")
        }
    }

    /// Saves client reference images if provided
    /// - Parameters:
    ///   - clientReferenceImages: Array of reference image data
    ///   - uuid: The UUID for the file names
    static func saveClientReferenceImages(clientReferenceImages: [ReferenceImageData]?, uuid: UUID) {
        guard let clientReferenceImages, !clientReferenceImages.isEmpty else { return }

        for (index, refImage) in clientReferenceImages.enumerated() {
            guard let refImageData = Data(base64Encoded: refImage.base64Image, options: .ignoreUnknownCharacters)
            else { continue }

            _ = saveImageToDocumentsDirectory(
                imageData: refImageData,
                withName: ".\(uuid)_ref\(index)"
            )
            if let image = toPlatformImage(from: refImageData) {
                image.saveToiCloud(fileName: ".\(uuid)_ref\(index)")
            }
        }
    }

    /// Saves client video if provided
    /// - Parameters:
    ///   - clientVideo: Base64 encoded client video
    ///   - uuid: The UUID for the file name
    static func saveClientVideo(clientVideo: String?, uuid: UUID) {
        guard let clientVideo,
              let clientVideoData = Data(base64Encoded: clientVideo, options: .ignoreUnknownCharacters)
        else { return }

        _ = saveVideoToDocumentsDirectory(videoData: clientVideoData, withName: ".\(uuid)_refvideo")
        saveVideoToiCloud(videoData: clientVideoData, fileName: ".\(uuid)_refvideo")
    }

    /// Saves all video client assets (image, mask, last frame, reference images, reference video) for a generation
    /// - Parameters:
    ///   - clientImage: Base64 encoded client image
    ///   - clientMask: Base64 encoded client mask
    ///   - clientLastFrame: Base64 encoded client last frame
    ///   - clientReferenceImages: Array of reference image data
    ///   - clientVideo: Base64 encoded client video
    ///   - uuid: The UUID for the file names
    static func saveVideoClientAssets(
        clientImage: String?,
        clientMask: String?,
        clientLastFrame: String?,
        clientReferenceImages: [ReferenceImageData]?,
        clientVideo: String?,
        uuid: UUID
    ) {
        saveClientImage(clientImage: clientImage, uuid: uuid)
        saveClientMask(clientMask: clientMask, uuid: uuid)
        saveClientLastFrame(clientLastFrame: clientLastFrame, uuid: uuid)
        saveClientReferenceImages(clientReferenceImages: clientReferenceImages, uuid: uuid)
        saveClientVideo(clientVideo: clientVideo, uuid: uuid)
    }
}
