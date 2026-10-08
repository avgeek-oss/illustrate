// MARK: - VideoAdapter.swift

// Cross-platform video handling utilities for macOS and iOS.
//
// This file provides video manipulation functions for loading, saving,
// and extracting frames from video files.
//
// ## Key Features
// - Load/save videos from Documents directory
// - Load/save videos from iCloud Documents
// - Extract video dimensions
// - Extract first frame as thumbnail
// - Save/share video files (macOS)
//
// ## Storage Strategy
// Videos follow the same pattern as images:
// - Stored in both local Documents and iCloud Documents
// - First frame extracted and saved as thumbnail image
// - Thumbnails enable video preview without loading full file
//
// ## Frame Extraction
// Uses AVFoundation's AVAssetImageGenerator to extract frames.
// First frame is used as the video thumbnail throughout the app.

import AVFoundation
import OSLog
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Loads a video URL from the local Documents directory.
///
/// - Parameter name: Video filename (without extension)
/// - Returns: URL if the video exists, nil otherwise
func loadVideoUrlFromDocumentsDirectory(withName name: String) -> URL? {
    let fileManager = FileManager.default
    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let videoFileURL = documentsURL.appendingPathComponent("\(name).mp4")

    if fileManager.fileExists(atPath: videoFileURL.path) {
        return videoFileURL
    }
    return nil
}

func getVideoSizeInBytes(videoURL: URL) -> Int? {
    (try? videoURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
}

func getActualVideoDimensions(videoURL: URL) async -> String? {
    let asset = AVURLAsset(url: videoURL)
    do {
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }
        let (naturalSize, preferredTransform) = try await track.load(.naturalSize, .preferredTransform)
        let size = naturalSize.applying(preferredTransform)
        let width = abs(Int(size.width))
        let height = abs(Int(size.height))
        return "\(width)x\(height)"
    } catch {
        AppLogger.storage.error("Error loading video dimensions: \(error.localizedDescription, privacy: .public)")
        return nil
    }
}

func loadVideoFromiCloud(_ fileName: String) -> URL? {
    if let video = loadVideoUrlFromDocumentsDirectory(withName: fileName) {
        return video
    }

    guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
        .appendingPathComponent("Documents")
    else {
        AppLogger.storage.error("iCloud container not available")
        return nil
    }

    do {
        if !FileManager.default.fileExists(atPath: containerURL.path) {
            try FileManager.default.createDirectory(
                at: containerURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        var fileUrl: URL? = containerURL.appendingPathComponent("\(fileName).mp4")
        let data = try Data(contentsOf: fileUrl!)

        fileUrl = saveVideoToDocumentsDirectory(videoData: data, withName: fileName)
        return fileUrl
    } catch {
        AppLogger.storage.error("Error loading video: \(error.localizedDescription, privacy: .public)")
        return nil
    }
}

func saveVideoToiCloud(videoData: Data, fileName: String) {
    guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
        .appendingPathComponent("Documents")
    else {
        AppLogger.storage.error("iCloud container not available")
        return
    }

    do {
        if !FileManager.default.fileExists(atPath: containerURL.path) {
            try FileManager.default.createDirectory(
                at: containerURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        let fileURL = containerURL.appendingPathComponent("\(fileName).mp4")

        try videoData.write(to: fileURL)
        AppLogger.storage.debug("Video saved to iCloud: \(fileURL.path, privacy: .public)")
    } catch {
        AppLogger.storage.error("Error saving video to iCloud: \(error.localizedDescription, privacy: .public)")
    }
}

func saveVideoToDocumentsDirectory(videoData: Data, withName name: String) -> URL? {
    let fileManager = FileManager.default
    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let videoFileURL = documentsURL.appendingPathComponent("\(name).mp4")

    do {
        try videoData.write(to: videoFileURL)
        AppLogger.storage.debug("Video saved to: \(videoFileURL.path, privacy: .public)")
        return videoFileURL
    } catch {
        AppLogger.storage.error("Error saving video: \(error.localizedDescription, privacy: .public)")
        return nil
    }
}

#if os(macOS)
func saveVideoToDownloads(url: URL, fileName: String) {
    let savePanel = NSSavePanel()
    savePanel.title = "Save your video"
    savePanel.message = "Choose the location to save the video."
    savePanel.allowedContentTypes = [.mpeg4Movie]
    savePanel.nameFieldStringValue = "illustrate_\(fileName)"

    savePanel.begin { response in
        if response == .OK {
            guard let savePanelUrl = savePanel.url else { return }

            do {
                try FileManager.default.copyItem(at: url, to: savePanelUrl)
                AppLogger.storage.debug("Video saved to \(savePanelUrl, privacy: .public)")
            } catch {
                AppLogger.storage.error("Error saving video: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

func shareVideo(url: URL) {
    let videoToShare = [url]
    let picker = NSSharingServicePicker(items: videoToShare)

    if let window = NSApplication.shared.keyWindow {
        picker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
    }
}
#endif

func extractFirstFrameFromVideo(base64Video: String) async -> PlatformImage? {
    guard let videoData = Data(base64Encoded: base64Video) else {
        return nil
    }
    return await extractFirstFrameFromVideoData(videoData)
}

func extractFirstFrameFromVideoData(_ videoData: Data) async -> PlatformImage? {
    let tempDirectory = FileManager.default.temporaryDirectory
    let videoURL = tempDirectory.appendingPathComponent("tempVideo_\(UUID().uuidString).mp4")

    do {
        try videoData.write(to: videoURL)
    } catch {
        AppLogger.storage.error("Error writing video data to file: \(error.localizedDescription, privacy: .public)")
        return nil
    }

    let result = await getFirstFrameImage(from: videoURL)
    try? FileManager.default.removeItem(at: videoURL)
    return result
}

func getFirstFrameAsBase64Image(from videoURL: URL) async -> String? {
    guard let image = await getFirstFrameImage(from: videoURL) else { return nil }
    return image.toBase64PNG()
}

func getFirstFrameImage(from videoURL: URL) async -> PlatformImage? {
    let asset = AVURLAsset(url: videoURL)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true

    return await withCheckedContinuation { continuation in
        imageGenerator.generateCGImageAsynchronously(for: .zero) { cgImage, _, error in
            if let error {
                AppLogger.storage.error("Error extracting first frame: \(error.localizedDescription, privacy: .public)")
                continuation.resume(returning: nil)
                return
            }

            guard let cgImage else {
                AppLogger.storage.error("Error extracting frame: No CGImage returned")
                continuation.resume(returning: nil)
                return
            }

            #if os(macOS)
            let image = NSImage(cgImage: cgImage, size: NSImage(cgImage: cgImage, size: .zero).size)
            continuation.resume(returning: image)
            #else
            let image = UIImage(cgImage: cgImage)
            continuation.resume(returning: image)
            #endif
        }
    }
}
