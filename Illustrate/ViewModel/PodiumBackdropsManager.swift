// MARK: - PodiumBackdropsManager.swift

// Manages downloading and caching of podium backdrop assets for product photoshoots.
//
// PodiumBackdropsManager handles:
// - Downloading per-dimension backdrop ZIPs from CDN (full-size + thumbnails)
// - Extracting to local Application Support directory
// - Providing image URLs for each aspect ratio (full and thumbnail)
// - Progress tracking during download/extraction
//
// ## Asset Structure
// Each dimension has both full-size and thumbnail ZIP files hosted at:
// - Full: https://cdn.illustrate.so/brand_product_photoshoots/4_3.zip
// - Thumbnails: https://cdn.illustrate.so/brand_product_photoshoots/4_3_thumbnails.zip
//
// Full ZIP extracts to: 4_3/pod_4_3_00001.png ... pod_4_3_00250.png
// Thumbnail ZIP extracts to: 4_3_thumbnails/pod_4_3_00001.png ... (same names)
//
// ## Usage
// ```swift
// @StateObject var backdropsManager = PodiumBackdropsManager.shared
//
// if backdropsManager.isReady(for: .portrait2x3) {
//     // Use backdropsManager.thumbnailURL(for: .portrait2x3, index: 1) for previews
//     // Use backdropsManager.imageURL(for: .portrait2x3, index: 1) for full-size
// } else {
//     // Show download UI with backdropsManager.downloadIfNeeded(for: .portrait2x3)
// }
// ```

import Combine
import Foundation
import OSLog
import SwiftUI
import ZIPFoundation

// MARK: - Download State

/// Represents the current state of backdrop asset downloading for a dimension.
enum BackdropDownloadState: Equatable {
    case notDownloaded
    case downloading
    case extracting
    case ready
    case failed(String)

    var isLoading: Bool {
        switch self {
        case .downloading, .extracting: true
        default: false
        }
    }

    var statusMessage: String {
        switch self {
        case .notDownloaded: "Not downloaded"
        case .downloading: "Downloading backdrop templates..."
        case .extracting: "Extracting..."
        case .ready: "Ready"
        case let .failed(error): "Failed: \(error)"
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

// MARK: - PodiumBackdropsManager

/// Singleton manager for podium backdrop assets.
///
/// Handles downloading, extracting, and caching backdrop images
/// from CDN for use in product photoshoots. Downloads are per-dimension
/// to allow faster, on-demand asset fetching.
@MainActor
final class PodiumBackdropsManager: ObservableObject {
    static let shared = PodiumBackdropsManager()

    // MARK: - Configuration

    /// Base URL for backdrop ZIP files
    private let cdnBaseURL = "https://cdn.illustrate.so/brand_product_photoshoots"

    /// Number of images per aspect ratio folder
    let imagesPerFolder = 250

    /// Version identifier for cache invalidation
    private let assetVersion = "v1"

    // MARK: - Published State

    /// Download state per dimension
    @Published private(set) var dimensionStates: [PhotoshootDimension: BackdropDownloadState] = [:]

    /// Download progress per dimension (0.0 to 1.0)
    @Published private(set) var dimensionProgress: [PhotoshootDimension: Double] = [:]

    // MARK: - Private Properties

    private var downloadTasks: [PhotoshootDimension: URLSessionDownloadTask] = [:]
    private var progressObservations: [PhotoshootDimension: NSKeyValueObservation] = [:]

    // MARK: - Paths

    /// Base directory for all cached backdrops
    private var baseDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("PodiumBackdrops", isDirectory: true)
    }

    /// Directory for the current asset version
    private var versionedDirectory: URL {
        baseDirectory.appendingPathComponent(assetVersion, isDirectory: true)
    }

    /// Returns the completion marker URL for a specific dimension
    private func completionMarkerURL(for dimension: PhotoshootDimension) -> URL {
        versionedDirectory.appendingPathComponent(".\(dimension.podiumFolderName).complete")
    }

    /// Returns the remote ZIP URL for a specific dimension
    private func remoteURL(for dimension: PhotoshootDimension) -> URL {
        URL(string: "\(cdnBaseURL)/\(dimension.podiumFolderName).zip")!
    }

    /// Returns the remote thumbnail ZIP URL for a specific dimension
    private func remoteThumbnailURL(for dimension: PhotoshootDimension) -> URL {
        URL(string: "\(cdnBaseURL)/\(dimension.podiumFolderName)_thumbnails.zip")!
    }

    // MARK: - Initialization

    private init() {
        checkInitialStates()
    }

    // MARK: - Public API

    /// Whether backdrops for a specific dimension are downloaded and ready
    func isReady(for dimension: PhotoshootDimension) -> Bool {
        dimensionStates[dimension] == .ready
    }

    /// Returns the download state for a specific dimension
    func state(for dimension: PhotoshootDimension) -> BackdropDownloadState {
        dimensionStates[dimension] ?? .notDownloaded
    }

    /// Returns the download progress for a specific dimension
    func progress(for dimension: PhotoshootDimension) -> Double {
        dimensionProgress[dimension] ?? 0
    }

    /// Returns the local file URL for a backdrop image.
    ///
    /// - Parameters:
    ///   - dimension: The photoshoot dimension (aspect ratio)
    ///   - index: Image index (1-250)
    /// - Returns: URL to the local image file, or nil if not ready
    func imageURL(for dimension: PhotoshootDimension, index: Int) -> URL? {
        guard isReady(for: dimension), index >= 1, index <= imagesPerFolder else { return nil }

        let folder = dimension.podiumFolderName
        let filename = String(format: "pod_%@_%05d.png", folder, index)

        return versionedDirectory
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent(filename)
    }

    /// Returns the local file URL for a backdrop thumbnail image.
    ///
    /// - Parameters:
    ///   - dimension: The photoshoot dimension (aspect ratio)
    ///   - index: Image index (1-250)
    /// - Returns: URL to the local thumbnail file, or nil if not ready
    func thumbnailURL(for dimension: PhotoshootDimension, index: Int) -> URL? {
        guard isReady(for: dimension), index >= 1, index <= imagesPerFolder else { return nil }

        let folder = dimension.podiumFolderName
        let thumbnailFolder = "\(folder)_thumbnails"
        // Thumbnail images have the same filename (without _thumbnails suffix)
        let filename = String(format: "pod_%@_%05d.png", folder, index)

        return versionedDirectory
            .appendingPathComponent(thumbnailFolder, isDirectory: true)
            .appendingPathComponent(filename)
    }

    /// Returns all available image URLs for a given dimension.
    ///
    /// - Parameter dimension: The photoshoot dimension
    /// - Returns: Array of image URLs (1 to 250)
    func allImageURLs(for dimension: PhotoshootDimension) -> [URL] {
        guard isReady(for: dimension) else { return [] }

        return (1 ... imagesPerFolder).compactMap { index in
            imageURL(for: dimension, index: index)
        }
    }

    /// Loads an image from the cache.
    ///
    /// This is a static nonisolated method to allow background loading without MainActor access.
    ///
    /// - Parameters:
    ///   - dimension: The photoshoot dimension
    ///   - index: Image index (1-250)
    /// - Returns: The loaded image, or nil if not available
    nonisolated static func loadImage(for dimension: PhotoshootDimension, index: Int) -> PlatformImage? {
        guard index >= 1, index <= 250 else { return nil }

        // Build path directly (nonisolated - no actor state access)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = dimension.podiumFolderName
        let filename = String(format: "pod_%@_%05d.png", folder, index)
        let url = appSupport
            .appendingPathComponent("PodiumBackdrops", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        #if os(macOS)
        return NSImage(contentsOf: url)
        #else
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
        #endif
    }

    /// Loads a thumbnail image from the cache.
    ///
    /// - Parameters:
    ///   - dimension: The photoshoot dimension
    ///   - index: Image index (1-250)
    /// - Returns: The loaded thumbnail image, or nil if not available
    func loadThumbnail(for dimension: PhotoshootDimension, index: Int) -> PlatformImage? {
        guard let url = thumbnailURL(for: dimension, index: index) else { return nil }

        #if os(macOS)
        return NSImage(contentsOf: url)
        #else
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
        #endif
    }

    /// Starts downloading backdrops for a specific dimension if not already downloaded.
    ///
    /// Safe to call multiple times - will no-op if already downloading or ready.
    func downloadIfNeeded(for dimension: PhotoshootDimension) {
        let currentState = dimensionStates[dimension] ?? .notDownloaded
        guard currentState == .notDownloaded || currentState.isFailure else { return }

        Task {
            await performDownload(for: dimension)
        }
    }

    /// Retries download for a specific dimension after a failure.
    func retry(for dimension: PhotoshootDimension) {
        dimensionStates[dimension] = .notDownloaded
        downloadIfNeeded(for: dimension)
    }

    /// Cancels an in-progress download for a specific dimension.
    func cancelDownload(for dimension: PhotoshootDimension) {
        downloadTasks[dimension]?.cancel()
        downloadTasks[dimension] = nil
        progressObservations[dimension] = nil
        dimensionStates[dimension] = .notDownloaded
        dimensionProgress[dimension] = 0
    }

    /// Deletes cached backdrops for a specific dimension.
    func clearCache(for dimension: PhotoshootDimension) {
        cancelDownload(for: dimension)

        let folderURL = versionedDirectory.appendingPathComponent(dimension.podiumFolderName, isDirectory: true)
        let thumbnailFolderURL = versionedDirectory.appendingPathComponent(
            "\(dimension.podiumFolderName)_thumbnails",
            isDirectory: true
        )
        try? FileManager.default.removeItem(at: folderURL)
        try? FileManager.default.removeItem(at: thumbnailFolderURL)
        try? FileManager.default.removeItem(at: completionMarkerURL(for: dimension))

        dimensionStates[dimension] = .notDownloaded
        dimensionProgress[dimension] = 0
    }

    /// Deletes all cached backdrops.
    func clearAllCache() {
        for dimension in PhotoshootDimension.allCases {
            cancelDownload(for: dimension)
        }

        try? FileManager.default.removeItem(at: baseDirectory)

        for dimension in PhotoshootDimension.allCases {
            dimensionStates[dimension] = .notDownloaded
            dimensionProgress[dimension] = 0
        }
    }

    // MARK: - Private Methods

    private func checkInitialStates() {
        for dimension in PhotoshootDimension.allCases {
            if FileManager.default.fileExists(atPath: completionMarkerURL(for: dimension).path) {
                dimensionStates[dimension] = .ready
            } else {
                dimensionStates[dimension] = .notDownloaded
            }
            dimensionProgress[dimension] = 0
        }
    }

    private func performDownload(for dimension: PhotoshootDimension) async {
        dimensionStates[dimension] = .downloading
        dimensionProgress[dimension] = 0
        AppLogger.storage.info("PodiumBackdrops: Starting download for \(dimension.rawValue, privacy: .public)")

        do {
            // Create directories for both full and thumbnail
            let dimensionDirectory = versionedDirectory.appendingPathComponent(
                dimension.podiumFolderName,
                isDirectory: true
            )
            let thumbnailDirectory = versionedDirectory.appendingPathComponent(
                "\(dimension.podiumFolderName)_thumbnails",
                isDirectory: true
            )
            try FileManager.default.createDirectory(at: dimensionDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)

            // Download both ZIPs in parallel
            async let fullZipTask = downloadZIP(for: dimension, isThumbnail: false)
            async let thumbnailZipTask = downloadZIP(for: dimension, isThumbnail: true)

            let (tempFullZipURL, tempThumbnailZipURL) = try await (fullZipTask, thumbnailZipTask)

            // Extract both
            dimensionStates[dimension] = .extracting
            try await extractZIP(from: tempFullZipURL, for: dimension, isThumbnail: false)
            try await extractZIP(from: tempThumbnailZipURL, for: dimension, isThumbnail: true)

            // Clean up temp files
            try? FileManager.default.removeItem(at: tempFullZipURL)
            try? FileManager.default.removeItem(at: tempThumbnailZipURL)

            // Mark complete
            FileManager.default.createFile(atPath: completionMarkerURL(for: dimension).path, contents: nil)

            dimensionStates[dimension] = .ready
            dimensionProgress[dimension] = 1.0
            AppLogger.storage.notice("PodiumBackdrops: Download completed for \(dimension.rawValue, privacy: .public)")

        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                dimensionStates[dimension] = .notDownloaded
                AppLogger.storage
                    .debug("PodiumBackdrops: Download cancelled for \(dimension.rawValue, privacy: .public)")
            } else {
                dimensionStates[dimension] = .failed(error.localizedDescription)
                AppLogger.storage
                    .error(
                        "PodiumBackdrops: Download failed for \(dimension.rawValue, privacy: .public) - \(error.localizedDescription, privacy: .public)"
                    )
            }
            dimensionProgress[dimension] = 0
        }
    }

    private func downloadZIP(for dimension: PhotoshootDimension, isThumbnail: Bool) async throws -> URL {
        let url = isThumbnail ? remoteThumbnailURL(for: dimension) : remoteURL(for: dimension)

        let (tempURL, _) = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
            let session = URLSession(configuration: .default)
            let task = session.downloadTask(with: url) { downloadedURL, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let downloadedURL, let response {
                    // Move to a stable temp location before returning
                    let stableURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString + ".zip")
                    do {
                        try FileManager.default.moveItem(at: downloadedURL, to: stableURL)
                        continuation.resume(returning: (stableURL, response))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(throwing: URLError(.unknown))
                }
            }

            // Observe download progress (only for full download, thumbnails are small)
            if !isThumbnail {
                progressObservations[dimension] = task.progress
                    .observe(\.fractionCompleted) { [weak self] progress, _ in
                        Task { @MainActor in
                            // Download is 80% of total progress, extraction is 20%
                            self?.dimensionProgress[dimension] = progress.fractionCompleted * 0.8
                        }
                    }

                downloadTasks[dimension] = task
            }
            task.resume()
        }

        return tempURL
    }

    private func extractZIP(from zipURL: URL, for dimension: PhotoshootDimension, isThumbnail: Bool) async throws {
        let folderName = isThumbnail ? "\(dimension.podiumFolderName)_thumbnails" : dimension.podiumFolderName
        let destinationDirectory = versionedDirectory.appendingPathComponent(
            folderName,
            isDirectory: true
        )

        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default

            // Ensure destination directory exists
            if !fileManager.fileExists(atPath: destinationDirectory.path) {
                try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            }

            // Use ZIPFoundation to extract
            let archive = try Archive(url: zipURL, accessMode: .read, pathEncoding: nil)

            let totalEntries = archive.makeIterator().reduce(0) { count, _ in count + 1 }
            var extractedCount = 0

            for entry in archive {
                // Only extract files (skip directories)
                guard entry.type == .file else {
                    extractedCount += 1
                    continue
                }

                // Use only the filename, ignoring any folder structure in the ZIP
                let filename = URL(fileURLWithPath: entry.path).lastPathComponent
                let destinationURL = destinationDirectory.appendingPathComponent(filename)

                // Skip if not a PNG file
                guard filename.hasSuffix(".png") else {
                    extractedCount += 1
                    continue
                }

                // Remove existing file if present (to allow overwrite)
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try? fileManager.removeItem(at: destinationURL)
                }

                // Extract entry
                _ = try archive.extract(entry, to: destinationURL)

                extractedCount += 1

                // Update progress only for full images (extraction is 20% of total, from 80% to 100%)
                if !isThumbnail {
                    let extractionProgress = Double(extractedCount) / Double(totalEntries)
                    await MainActor.run {
                        self.dimensionProgress[dimension] = 0.8 + (extractionProgress * 0.2)
                    }
                }
            }
        }.value
    }
}

// MARK: - PhotoshootDimension Extension

extension PhotoshootDimension {
    /// Folder name in the podium backdrops ZIP
    var podiumFolderName: String {
        switch self {
        case .portrait9x16: "9_16"
        case .landscape16x9: "16_9"
        case .portrait3x4: "3_4"
        case .landscape4x3: "4_3"
        case .portrait2x3: "2_3"
        case .landscape3x2: "3_2"
        }
    }

    /// Human-readable description for download prompt
    var backdropDownloadDescription: String {
        "Download pre-generated backdrops that suit your product for \(rawValue) aspect ratios."
    }
}
