// MARK: - ImageAdapter.swift

// Cross-platform image handling utilities for macOS and iOS.
//
// This file provides a comprehensive set of image manipulation functions
// that work identically on both macOS (NSImage) and iOS (UIImage).
//
// ## Platform Abstractions
// - `PlatformImage`: NSImage on macOS, UIImage on iOS
// - `UniversalColor`: NSColor on macOS, UIColor on iOS
//
// ## Key Features
// - Load/save images from Documents directory
// - Load/save images from iCloud Documents
// - Base64 encoding/decoding
// - Image resizing and compression
// - Dominant color extraction (k-means clustering)
// - Aspect ratio calculations
//
// ## Storage Strategy
// Images are stored in both local Documents (for fast access) and
// iCloud Documents (for sync). Local copies act as cache.
//
// ## Dominant Colors
// Uses k-means clustering to extract dominant colors from images.
// These are displayed in the generation detail view.

import OSLog
import SwiftUI

#if os(macOS)
import AppKit

/// Platform-agnostic color type (NSColor on macOS)
typealias UniversalColor = NSColor
/// Platform-agnostic image type (NSImage on macOS)
typealias PlatformImage = NSImage
#else
import UIKit

/// Platform-agnostic color type (UIColor on iOS)
typealias UniversalColor = UIColor
/// Platform-agnostic image type (UIImage on iOS)
typealias PlatformImage = UIImage
#endif

func loadImageFromDocumentsDirectory(withName name: String) -> PlatformImage? {
    let fileManager = FileManager.default
    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let imageFileURL = documentsURL.appendingPathComponent("\(name).png")

    if fileManager.fileExists(atPath: imageFileURL.path) {
        if let imageData = try? Data(contentsOf: imageFileURL) {
            #if os(macOS)
            return NSImage(data: imageData)
            #else
            return UIImage(data: imageData)
            #endif
        }
    }
    return nil
}

func loadImageFromiCloud(_ fileName: String) -> PlatformImage? {
    if let image = loadImageFromDocumentsDirectory(withName: fileName) {
        return image
    }

    guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
        .appendingPathComponent("Documents")
    else {
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

        let fileUrl = containerURL.appendingPathComponent("\(fileName).png")

        var isDirectory: ObjCBool = false
        let existsLocally = FileManager.default.fileExists(atPath: fileUrl.path, isDirectory: &isDirectory)

        if !existsLocally {
            do {
                let resourceValues = try fileUrl.resourceValues(forKeys: [
                    .ubiquitousItemIsUploadedKey,
                    .ubiquitousItemDownloadingStatusKey,
                ])

                if let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus {
                    if downloadStatus == .notDownloaded {
                        try FileManager.default.startDownloadingUbiquitousItem(at: fileUrl)
                        return nil
                    }
                }
            } catch {
                return nil
            }
        }

        let data = try Data(contentsOf: fileUrl)

        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        #else
        guard let image = UIImage(data: data) else { return nil }
        #endif
        return image
    } catch {
        return nil
    }
}

func saveImageToDocumentsDirectory(imageData: Data, withName name: String) -> URL? {
    let fileManager = FileManager.default
    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let imageFileURL = documentsURL.appendingPathComponent("\(name).png")

    do {
        try imageData.write(to: imageFileURL)
        AppLogger.storage.debug("Image saved to: \(imageFileURL.path, privacy: .public)")
        return imageFileURL
    } catch {
        AppLogger.storage.error("Error saving image: \(error.localizedDescription, privacy: .public)")
        return nil
    }
}

func getImageSizeInBytes(imageURL: URL) -> Int? {
    (try? imageURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
}

func toPlatformImage(base64: String) -> PlatformImage? {
    guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
        return nil
    }
    return toPlatformImage(from: data)
}

func toPlatformImage(from data: Data) -> PlatformImage? {
    #if os(macOS)
    return NSImage(data: data)
    #else
    return UIImage(data: data)
    #endif
}

extension PlatformImage {
    /// Returns the total pixel count (width * height) of the image
    var pixelCount: Int {
        #if os(macOS)
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return Int(size.width * size.height)
        }
        return cgImage.width * cgImage.height
        #else
        guard let cgImage else {
            return Int(size.width * size.height)
        }
        return cgImage.width * cgImage.height
        #endif
    }

    /// Returns the pixel dimensions of the image
    var pixelSize: CGSize {
        #if os(macOS)
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return size
        }
        return CGSize(width: cgImage.width, height: cgImage.height)
        #else
        guard let cgImage else {
            return size
        }
        return CGSize(width: cgImage.width, height: cgImage.height)
        #endif
    }

    /// Resizes the image to fit within the specified maximum pixel count while maintaining aspect ratio
    func resizedToFit(maxPixels: Int) -> PlatformImage {
        let currentPixels = pixelCount
        if currentPixels <= maxPixels {
            return self
        }

        let currentSize = pixelSize
        let scale = sqrt(Double(maxPixels) / Double(currentPixels))
        let newWidth = floor(currentSize.width * scale)
        let newHeight = floor(currentSize.height * scale)
        let targetSize = CGSize(width: newWidth, height: newHeight)

        return resizeImage(targetSize: targetSize) ?? self
    }

    /// Compresses the image to fit within the specified maximum file size in bytes.
    func compressedToFit(maxSizeBytes: Int) -> PlatformImage {
        let currentSize = estimatedDataSize()
        if currentSize <= maxSizeBytes {
            return self
        }

        var quality: CGFloat = 0.9
        let minQuality: CGFloat = 0.1
        let qualityStep: CGFloat = 0.1

        while quality >= minQuality {
            #if os(macOS)
            guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return self
            }
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
            else {
                quality -= qualityStep
                continue
            }
            if jpegData.count <= maxSizeBytes, let compressedImage = NSImage(data: jpegData) {
                return compressedImage
            }
            #else
            guard let jpegData = jpegData(compressionQuality: quality) else {
                quality -= qualityStep
                continue
            }
            if jpegData.count <= maxSizeBytes, let compressedImage = UIImage(data: jpegData) {
                return compressedImage
            }
            #endif
            quality -= qualityStep
        }

        #if os(macOS)
        if let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: minQuality]),
               let compressedImage = NSImage(data: jpegData)
            {
                return compressedImage
            }
        }
        #else
        if let jpegData = jpegData(compressionQuality: minQuality),
           let compressedImage = UIImage(data: jpegData)
        {
            return compressedImage
        }
        #endif

        return self
    }

    /// Returns the estimated data size of the image in bytes using JPEG compression.
    func estimatedDataSize(quality: CGFloat = 0.9) -> Int {
        #if os(macOS)
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 0
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality]) {
            return jpegData.count
        }
        return 0
        #else
        return jpegData(compressionQuality: quality)?.count ?? 0
        #endif
    }

    func saveToiCloud(fileName: String) {
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

            let fileURL = containerURL.appendingPathComponent("\(fileName).png")

            #if os(macOS)
            guard let tiffData = tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapImage.representation(using: .png, properties: [:])
            else {
                AppLogger.storage.error("Failed to create PNG data from NSImage")
                return
            }
            #else
            guard let pngData = self.pngData() else {
                AppLogger.storage.error("Failed to create PNG data from UIImage")
                return
            }
            #endif

            try pngData.write(to: fileURL)
            AppLogger.storage.debug("Image saved to iCloud: \(fileURL.path, privacy: .public)")

            #if os(macOS)
            try FileManager.default.setAttributes([FileAttributeKey.extensionHidden: true], ofItemAtPath: fileURL.path)
            #endif
        } catch {
            AppLogger.storage.error("Error saving image to iCloud: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Converts the image to PNG data
    func toPNGData() -> Data? {
        #if os(macOS)
        if let tiffData = tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:])
        {
            return pngData
        }

        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
        #else
        return pngData()
        #endif
    }

    func toBase64PNG() -> String? {
        guard let pngData = toPNGData() else {
            return nil
        }
        return pngData.base64EncodedString()
    }

    /// Converts the image to base64 JPEG string with the specified quality
    func toBase64JPEG(quality: CGFloat = 0.9) -> String? {
        #if os(macOS)
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            return nil
        }
        return jpegData.base64EncodedString()
        #else
        guard let jpegData = jpegData(compressionQuality: quality) else {
            return nil
        }
        return jpegData.base64EncodedString()
        #endif
    }

    /// Converts the image to base64, automatically resizing and compressing as needed.
    /// - Parameters:
    ///   - maxPixels: Maximum allowed pixels (width * height). Image will be resized if exceeded.
    ///   - maxSizeBytes: Maximum allowed file size in bytes. Image will be compressed if exceeded.
    /// - Returns: Base64 encoded string of the image
    func toBase64(maxPixels: Int? = nil, maxSizeBytes: Int? = nil) -> String? {
        var imageToEncode: PlatformImage = self

        if let maxPx = maxPixels, pixelCount > maxPx {
            imageToEncode = resizedToFit(maxPixels: maxPx)
        }

        guard let maxSize = maxSizeBytes else {
            return imageToEncode.toBase64PNG()
        }

        let estimatedSize = imageToEncode.estimatedDataSize()
        if estimatedSize <= maxSize {
            return imageToEncode.toBase64JPEG(quality: 0.9)
        }

        var quality: CGFloat = 0.9
        let minQuality: CGFloat = 0.1
        let qualityStep: CGFloat = 0.1

        while quality >= minQuality {
            #if os(macOS)
            guard let cgImage = imageToEncode.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return imageToEncode.toBase64PNG()
            }
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
            else {
                quality -= qualityStep
                continue
            }
            if jpegData.count <= maxSize {
                return jpegData.base64EncodedString()
            }
            #else
            guard let jpegData = imageToEncode.jpegData(compressionQuality: quality) else {
                quality -= qualityStep
                continue
            }
            if jpegData.count <= maxSize {
                return jpegData.base64EncodedString()
            }
            #endif
            quality -= qualityStep
        }

        return imageToEncode.toBase64JPEG(quality: minQuality)
    }

    func toImage() -> Image {
        #if os(macOS)
        return Image(nsImage: self)
        #else
        return Image(uiImage: self)
        #endif
    }

    #if os(macOS)
    func saveImageToDownloads(fileName: String) {
        let savePanel = NSSavePanel()
        savePanel.title = "Save your image"
        savePanel.message = "Choose the location to save the image."
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "illustrate_\(fileName)"

        savePanel.begin { response in
            if response == .OK {
                guard let url = savePanel.url else { return }

                if let tiffData = self.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapImage.representation(using: .png, properties: [:])
                {
                    do {
                        try pngData.write(to: url)
                        AppLogger.storage.debug("Image saved to \(url, privacy: .public)")
                    } catch {
                        AppLogger.storage.error("Error saving image: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
        }
    }

    func shareImage() {
        let imageToShare = [self]
        let picker = NSSharingServicePicker(items: imageToShare)

        if let window = NSApplication.shared.keyWindow {
            picker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
        }
    }

    func resizeImage(scale: CGFloat) -> PlatformImage? {
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let resizedImage = NSImage(size: newSize)

        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        resizedImage.unlockFocus()

        guard let cgImage = resizedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: newSize)
    }
    #else
    func resizeImage(scale: CGFloat) -> PlatformImage? {
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            context.cgContext.interpolationQuality = .high
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    #endif

    func resizeImage(targetSize: CGSize) -> PlatformImage? {
        #if os(macOS)
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let scaledSize = CGSize(width: targetSize.width / scale, height: targetSize.height / scale)

        let newImage = NSImage(size: scaledSize)
        newImage.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high
        let rect = NSRect(origin: .zero, size: scaledSize)
        draw(in: rect, from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1.0)

        newImage.unlockFocus()

        guard let cgImage = newImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: scaledSize)
        #else
        let scale = UIScreen.main.scale
        let scaledSize = CGSize(width: targetSize.width / scale, height: targetSize.height / scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale

        let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
        let resizedImage = renderer.image { context in
            context.cgContext.interpolationQuality = .high
            self.draw(in: CGRect(origin: .zero, size: scaledSize))
        }

        if let cgImage = resizedImage.cgImage {
            return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
        }
        return nil
        #endif
    }
}

func getDominantColors(imageURL: URL, clusterCount: Int = 6) -> [String] {
    if let imageData = try? Data(contentsOf: imageURL) {
        #if canImport(UIKit)
        if let image = UIImage(data: imageData) {
            return dominantColorsFromImage(image, clusterCount: clusterCount)
        }
        #elseif canImport(AppKit)
        if let image = NSImage(data: imageData) {
            return dominantColorsFromImage(image, clusterCount: clusterCount)
        }
        #endif
    }
    return []
}

func getDominantColors(from image: PlatformImage, clusterCount: Int = 6) -> [String] {
    dominantColorsFromImage(image, clusterCount: clusterCount)
}

#if os(macOS)
func dominantColorsFromImage(_ image: NSImage, clusterCount: Int) -> [String] {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
    return dominantColorsFromCGImage(cgImage, clusterCount: clusterCount)
}
#else
func dominantColorsFromImage(_ image: UIImage, clusterCount: Int) -> [String] {
    guard let cgImage = image.cgImage else { return [] }
    return dominantColorsFromCGImage(cgImage, clusterCount: clusterCount)
}
#endif

func samplePixels(from image: CGImage, sampleCount: Int) -> [(r: CGFloat, g: CGFloat, b: CGFloat)] {
    let width = image.width
    let height = image.height
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let bitsPerComponent = 8
    var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
    let context = CGContext(
        data: &pixelData,
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    context?.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

    var sampledPixels = [(r: CGFloat, g: CGFloat, b: CGFloat)]()
    let alphaThreshold: UInt8 = 128
    let maxAttempts = sampleCount * 5
    var attempts = 0

    while sampledPixels.count < sampleCount, attempts < maxAttempts {
        attempts += 1
        let x = Int(arc4random_uniform(UInt32(width)))
        let y = Int(arc4random_uniform(UInt32(height)))
        let pixelIndex = (y * width + x) * bytesPerPixel
        let alpha = pixelData[pixelIndex + 3]

        if alpha < alphaThreshold {
            continue
        }

        let alphaFactor = CGFloat(alpha) / 255.0
        let r = CGFloat(pixelData[pixelIndex]) / 255.0 / alphaFactor
        let g = CGFloat(pixelData[pixelIndex + 1]) / 255.0 / alphaFactor
        let b = CGFloat(pixelData[pixelIndex + 2]) / 255.0 / alphaFactor
        sampledPixels.append((r: min(r, 1.0), g: min(g, 1.0), b: min(b, 1.0)))
    }
    return sampledPixels
}

func downsample(image: CGImage, to size: CGSize) -> CGImage? {
    let widthRatio = size.width / CGFloat(image.width)
    let heightRatio = size.height / CGFloat(image.height)
    let scaleFactor = min(widthRatio, heightRatio)

    let newWidth = CGFloat(image.width) * scaleFactor
    let newHeight = CGFloat(image.height) * scaleFactor

    let context = CGContext(
        data: nil,
        width: Int(newWidth),
        height: Int(newHeight),
        bitsPerComponent: image.bitsPerComponent,
        bytesPerRow: 0,
        space: image.colorSpace!,
        bitmapInfo: image.bitmapInfo.rawValue
    )

    context?.interpolationQuality = .high
    context?.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

    return context?.makeImage()
}

func dominantColorsFromCGImage(_ cgImage: CGImage, clusterCount: Int) -> [String] {
    let startTime = CFAbsoluteTimeGetCurrent()

    let targetSize = CGSize(width: 100, height: 100)
    if let downsampledImage = downsample(image: cgImage, to: targetSize) {
        let sampledPixels = samplePixels(from: downsampledImage, sampleCount: 1000)

        let clusters = kMeansWithTimeCheck(pixels: sampledPixels, clusterCount: clusterCount, startTime: startTime)

        guard let clusters else {
            return []
        }

        return clusters.map { color in
            UniversalColor(red: color.r, green: color.g, blue: color.b, alpha: 1.0).hexString
        }
    }
    return []
}

func kMeansWithTimeCheck(
    pixels: [(r: CGFloat, g: CGFloat, b: CGFloat)],
    clusterCount: Int,
    startTime: CFAbsoluteTime
) -> [(
    r: CGFloat,
    g: CGFloat,
    b: CGFloat
)]? {
    var clusters = [(r: CGFloat, g: CGFloat, b: CGFloat)]()
    var previousClusters = [(r: CGFloat, g: CGFloat, b: CGFloat)]()

    for _ in 0 ..< clusterCount {
        let randomPixel = pixels[Int(arc4random_uniform(UInt32(pixels.count)))]
        clusters.append(randomPixel)
    }

    repeat {
        if CFAbsoluteTimeGetCurrent() - startTime > 1.0 {
            return nil
        }

        previousClusters = clusters

        var pixelGroups = [[(r: CGFloat, g: CGFloat, b: CGFloat)]](repeating: [], count: clusterCount)

        for pixel in pixels {
            let nearestClusterIndex = clusters.enumerated().min(by: { distance(pixel, $0.element) < distance(
                pixel,
                $1.element
            ) })!.offset
            pixelGroups[nearestClusterIndex].append(pixel)
        }

        clusters = pixelGroups.enumerated().map { index, group in
            guard !group.isEmpty else { return previousClusters[index] }
            let count = CGFloat(group.count)
            let r = group.reduce(0) { $0 + $1.r } / count
            let g = group.reduce(0) { $0 + $1.g } / count
            let b = group.reduce(0) { $0 + $1.b } / count
            return (r: r, g: g, b: b)
        }
    } while !clustersEqual(clusters, previousClusters)

    return clusters
}

func kMeans(pixels: [(r: CGFloat, g: CGFloat, b: CGFloat)], clusterCount: Int, maxIterations: Int = 100) -> [(
    r: CGFloat,
    g: CGFloat,
    b: CGFloat
)] {
    var clusters = [(r: CGFloat, g: CGFloat, b: CGFloat)]()
    var previousClusters = [(r: CGFloat, g: CGFloat, b: CGFloat)]()

    for _ in 0 ..< clusterCount {
        let randomPixel = pixels[Int(arc4random_uniform(UInt32(pixels.count)))]
        clusters.append(randomPixel)
    }

    var iteration = 0
    repeat {
        iteration += 1
        previousClusters = clusters

        var pixelGroups = [[(r: CGFloat, g: CGFloat, b: CGFloat)]](repeating: [], count: clusterCount)

        for pixel in pixels {
            let nearestClusterIndex = clusters.enumerated().min(by: { distance(pixel, $0.element) < distance(
                pixel,
                $1.element
            ) })!.offset
            pixelGroups[nearestClusterIndex].append(pixel)
        }

        clusters = pixelGroups.enumerated().map { index, group in
            guard !group.isEmpty else { return previousClusters[index] }
            let count = CGFloat(group.count)
            let r = group.reduce(0) { $0 + $1.r } / count
            let g = group.reduce(0) { $0 + $1.g } / count
            let b = group.reduce(0) { $0 + $1.b } / count
            return (r: r, g: g, b: b)
        }
    } while !clustersEqual(clusters, previousClusters) && iteration < maxIterations

    return clusters
}

func clustersEqual(_ a: [(r: CGFloat, g: CGFloat, b: CGFloat)], _ b: [(r: CGFloat, g: CGFloat, b: CGFloat)]) -> Bool {
    guard a.count == b.count else { return false }
    for i in 0 ..< a.count {
        if a[i] != b[i] {
            return false
        }
    }
    return true
}

func distance(_ a: (r: CGFloat, g: CGFloat, b: CGFloat), _ b: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
    let rDiff = a.r - b.r
    let gDiff = a.g - b.g
    let bDiff = a.b - b.b
    return sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff)
}

extension UniversalColor {
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

#if os(macOS)
extension NSColor {
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }

        guard hexString.count == 6 || hexString.count == 8 else {
            return nil
        }

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        let red, green, blue, alpha: CGFloat
        if hexString.count == 6 {
            red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgbValue & 0x0000FF) / 255.0
            alpha = 1.0
        } else {
            red = CGFloat((rgbValue & 0xFF00_0000) >> 24) / 255.0
            green = CGFloat((rgbValue & 0x00FF_0000) >> 16) / 255.0
            blue = CGFloat((rgbValue & 0x0000_FF00) >> 8) / 255.0
            alpha = CGFloat(rgbValue & 0x0000_00FF) / 255.0
        }

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

func getUniversalColorFromHex(hexString: String) -> NSColor {
    NSColor(hex: hexString) ?? NSColor.clear
}
#else
func getUniversalColorFromHex(hexString: String) -> UIColor {
    var rgbValue: UInt64 = 0
    let scanner = Scanner(string: hexString.replacingOccurrences(of: "#", with: ""))

    scanner.scanHexInt64(&rgbValue)

    let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
    let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
    let b = Double(rgbValue & 0x0000FF) / 255.0

    return UIColor(red: r, green: g, blue: b, alpha: 1.0)
}
#endif

func getVideoDimensions(resolution: String, aspectRatio: String) -> (width: Int, height: Int) {
    let dimensionMap: [String: [String: (Int, Int)]] = [
        "480p": [
            "16:9": (854, 480),
            "9:16": (480, 854),
            "4:3": (640, 480),
            "3:4": (480, 640),
            "1:1": (480, 480),
            "21:9": (1120, 480),
            "9:21": (480, 1120),
            "3:2": (720, 480),
            "2:3": (480, 720),
        ],
        "720p": [
            "16:9": (1280, 720),
            "9:16": (720, 1280),
            "4:3": (960, 720),
            "3:4": (720, 960),
            "1:1": (720, 720),
            "21:9": (1680, 720),
            "9:21": (720, 1680),
            "3:2": (1080, 720),
            "2:3": (720, 1080),
        ],
        "1080p": [
            "16:9": (1920, 1080),
            "9:16": (1080, 1920),
            "4:3": (1440, 1080),
            "3:4": (1080, 1440),
            "1:1": (1080, 1080),
            "21:9": (2520, 1080),
            "9:21": (1080, 2520),
            "3:2": (1620, 1080),
            "2:3": (1080, 1620),
        ],
    ]

    if let resolutionMap = dimensionMap[resolution],
       let dimensions = resolutionMap[aspectRatio]
    {
        return dimensions
    }

    let baseHeight = switch resolution {
    case "480p": 480
    case "720p": 720
    case "1080p": 1080
    default: 1080
    }

    let ratioParts = aspectRatio.split(separator: ":")
    if ratioParts.count == 2,
       let ratioW = Double(ratioParts[0]),
       let ratioH = Double(ratioParts[1]),
       ratioW > 0, ratioH > 0
    {
        let ratio = ratioW / ratioH
        if ratio >= 1 {
            let width = Int(Double(baseHeight) * ratio)
            return (width, baseHeight)
        } else {
            let height = Int(Double(baseHeight) / ratio)
            return (baseHeight, height)
        }
    }

    return (1920, 1080)
}
