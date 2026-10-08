// MARK: - VideoExportService.swift

// Service for exporting storyboard videos.
//
// VideoExportService handles combining multiple video scenes into a single
// video file using AVFoundation's composition APIs.
//
// ## Export Modes
// - **Google + Auto-extend**: Last scene contains full video, export directly
// - **Other cases**: Combine all scene videos sequentially

import AVFoundation
import Foundation
import OSLog

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Result of a video export operation.
struct VideoExportResult {
    /// Whether the export succeeded
    let success: Bool
    /// URL of the exported video (if successful)
    let outputURL: URL?
    /// Error message (if failed)
    let errorMessage: String?
}

/// Service for combining and exporting storyboard videos.
actor VideoExportService {
    /// Shared instance for singleton access
    static let shared = VideoExportService()

    private init() {}

    // MARK: - Export Full Storyboard Video

    /// Exports the complete storyboard video.
    ///
    /// For Google + Auto-extend mode, returns the last scene's video directly.
    /// For other modes, combines all scene videos into a single output file.
    ///
    /// - Parameters:
    ///   - videoURLs: Array of video URLs for each completed scene (in order)
    ///   - isAutoExtendGoogle: Whether this is Google provider with auto-extend mode
    ///   - outputFileName: Name for the output file
    /// - Returns: Export result with output URL or error message
    func exportStoryboard(
        videoURLs: [URL],
        isAutoExtendGoogle: Bool,
        outputFileName: String
    ) async -> VideoExportResult {
        guard !videoURLs.isEmpty else {
            return VideoExportResult(
                success: false,
                outputURL: nil,
                errorMessage: "No videos to export"
            )
        }

        // For Google + Auto-extend, the last video contains the full content
        if isAutoExtendGoogle {
            return await exportSingleVideo(
                sourceURL: videoURLs.last!,
                outputFileName: outputFileName
            )
        }

        // For other cases, combine all videos
        return await combineVideos(
            videoURLs: videoURLs,
            outputFileName: outputFileName
        )
    }

    // MARK: - Export Single Video

    /// Exports a single video by copying to a temporary location.
    private func exportSingleVideo(
        sourceURL: URL,
        outputFileName: String
    ) async -> VideoExportResult {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(outputFileName).mp4")

        do {
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }

            try FileManager.default.copyItem(at: sourceURL, to: outputURL)

            return VideoExportResult(
                success: true,
                outputURL: outputURL,
                errorMessage: nil
            )
        } catch {
            return VideoExportResult(
                success: false,
                outputURL: nil,
                errorMessage: "Failed to copy video: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Combine Videos

    /// Combines multiple video files into a single output video.
    ///
    /// Uses AVMutableComposition to sequentially append video tracks.
    /// Audio tracks are also included if present.
    private func combineVideos(
        videoURLs: [URL],
        outputFileName: String
    ) async -> VideoExportResult {
        let composition = AVMutableComposition()

        // Create video and audio tracks
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return VideoExportResult(
                success: false,
                outputURL: nil,
                errorMessage: "Failed to create video track"
            )
        }

        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var currentTime = CMTime.zero
        var videoSize = CGSize.zero

        // Add each video to the composition
        for (index, videoURL) in videoURLs.enumerated() {
            let asset = AVURLAsset(url: videoURL)

            do {
                // Load video track
                guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    AppLogger.storage.error("Warning: No video track found in video \(index + 1, privacy: .public)")
                    continue
                }

                // Get track properties
                let (naturalSize, preferredTransform, duration) = try await sourceVideoTrack.load(
                    .naturalSize,
                    .preferredTransform,
                    .timeRange
                )

                // Set video size from first video
                if videoSize == .zero {
                    let transformedSize = naturalSize.applying(preferredTransform)
                    videoSize = CGSize(
                        width: abs(transformedSize.width),
                        height: abs(transformedSize.height)
                    )
                }

                // Insert video track
                let videoDuration = duration.duration
                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: videoDuration),
                    of: sourceVideoTrack,
                    at: currentTime
                )

                // Apply transform (handles rotation)
                videoTrack.preferredTransform = preferredTransform

                // Insert audio track if available
                if let audioTrack,
                   let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first
                {
                    try audioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: videoDuration),
                        of: sourceAudioTrack,
                        at: currentTime
                    )
                }

                currentTime = CMTimeAdd(currentTime, videoDuration)

            } catch {
                AppLogger.storage
                    .error(
                        "Warning: Failed to add video \(index + 1, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                continue
            }
        }

        // Ensure we have content
        guard currentTime > .zero else {
            return VideoExportResult(
                success: false,
                outputURL: nil,
                errorMessage: "No video content could be combined"
            )
        }

        // Export the composition
        return await exportComposition(
            composition: composition,
            videoSize: videoSize,
            outputFileName: outputFileName
        )
    }

    // MARK: - Export Composition

    /// Exports an AVComposition to a video file.
    private func exportComposition(
        composition: AVMutableComposition,
        videoSize: CGSize,
        outputFileName: String
    ) async -> VideoExportResult {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(outputFileName).mp4")

        // Remove existing file
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            return VideoExportResult(
                success: false,
                outputURL: nil,
                errorMessage: "Failed to create export session"
            )
        }

        exportSession.shouldOptimizeForNetworkUse = true

        do {
            try await exportSession.export(to: outputURL, as: .mp4)
            return VideoExportResult(
                success: true,
                outputURL: outputURL,
                errorMessage: nil
            )
        } catch {
            return VideoExportResult(
                success: false,
                outputURL: nil,
                errorMessage: error.localizedDescription
            )
        }
    }
}

// MARK: - Save Panel Extension

#if os(macOS)
extension VideoExportService {
    /// Shows a save panel and saves the video to the user-selected location.
    ///
    /// - Parameters:
    ///   - sourceURL: URL of the video to save
    ///   - suggestedName: Suggested filename
    /// - Returns: Whether the save was successful
    @MainActor
    func saveWithPanel(sourceURL: URL, suggestedName: String) async -> Bool {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Storyboard Video"
        savePanel.message = "Choose a location to save your storyboard video."
        savePanel.allowedContentTypes = [.mpeg4Movie]
        savePanel.nameFieldStringValue = suggestedName
        savePanel.canCreateDirectories = true

        let response = await savePanel.beginSheetModal(
            for: NSApplication.shared.keyWindow ?? NSWindow()
        )

        guard response == .OK, let destinationURL = savePanel.url else {
            return false
        }

        do {
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return true
        } catch {
            AppLogger.storage.error("Failed to save video: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
#endif
