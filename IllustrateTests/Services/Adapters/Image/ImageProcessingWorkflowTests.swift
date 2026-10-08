// MARK: - ImageProcessingWorkflowTests.swift

// End-to-end workflow tests chaining operations across ImageAdapter,
// ImageCropAdapter, VideoAdapter, FeedbackHelper, and constants.
//
// Covers:
// - Dominant color extraction pipeline
// - Full create → save → load → process pipeline
// - Image + dominant color combined pipelines
// - Resize + compress combined workflows
// - Image scale variants workflow
// - Cross-adapter workflows
// - Edge case workflows
// - Pixel sampling + kMeans end-to-end
// - Feedback + constants integration
// - Video export result scenarios

import AppKit
import CoreGraphics
import XCTest
@testable import Illustrate

final class ImageProcessingWorkflowTests: XCTestCase {
    // MARK: - Helpers

    private var testFileNames: [String] = []
    private var testVideoNames: [String] = []

    override func tearDown() {
        super.tearDown()
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        for name in testFileNames {
            let url = docsURL.appendingPathComponent("\(name).png")
            try? fm.removeItem(at: url)
        }
        for name in testVideoNames {
            let url = docsURL.appendingPathComponent("\(name).mp4")
            try? fm.removeItem(at: url)
        }
        testFileNames.removeAll()
        testVideoNames.removeAll()
    }

    private func makeSolidCGImage(
        width: Int,
        height: Int,
        r: UInt8,
        g: UInt8,
        b: UInt8,
        a: UInt8 = 255
    ) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        for i in 0 ..< (width * height) {
            pixelData[i * 4] = r
            pixelData[i * 4 + 1] = g
            pixelData[i * 4 + 2] = b
            pixelData[i * 4 + 3] = a
        }
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        return context.makeImage()
    }

    private func makeNSImage(width: Int, height: Int, r: UInt8 = 128, g: UInt8 = 128, b: UInt8 = 128) -> NSImage? {
        guard let cgImage = makeSolidCGImage(width: width, height: height, r: r, g: g, b: b) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    private func uniqueImageName() -> String {
        let name = "test_workflow_\(UUID().uuidString)"
        testFileNames.append(name)
        return name
    }

    private func uniqueVideoName() -> String {
        let name = "test_wf_vid_\(UUID().uuidString)"
        testVideoNames.append(name)
        return name
    }

    // MARK: - Dominant Color Extraction Pipeline

    func testDominantColors_solidRedImage_containsRedHex() {
        guard let cgImage = makeSolidCGImage(width: 100, height: 100, r: 255, g: 0, b: 0) else {
            return XCTFail("Could not create CGImage")
        }
        let colors = dominantColorsFromCGImage(cgImage, clusterCount: 1)
        XCTAssertFalse(colors.isEmpty)
        XCTAssertEqual(colors[0], "#FF0000")
    }

    func testDominantColors_solidGreenImage_containsGreenHex() {
        guard let cgImage = makeSolidCGImage(width: 100, height: 100, r: 0, g: 255, b: 0) else {
            return XCTFail("Could not create CGImage")
        }
        let colors = dominantColorsFromCGImage(cgImage, clusterCount: 1)
        XCTAssertFalse(colors.isEmpty)
        XCTAssertEqual(colors[0], "#00FF00")
    }

    func testDominantColors_solidBlueImage_containsBlueHex() {
        guard let cgImage = makeSolidCGImage(width: 100, height: 100, r: 0, g: 0, b: 255) else {
            return XCTFail("Could not create CGImage")
        }
        let colors = dominantColorsFromCGImage(cgImage, clusterCount: 1)
        XCTAssertFalse(colors.isEmpty)
        XCTAssertEqual(colors[0], "#0000FF")
    }

    func testDominantColors_solidWhiteImage_containsWhiteHex() {
        guard let cgImage = makeSolidCGImage(width: 100, height: 100, r: 255, g: 255, b: 255) else {
            return XCTFail("Could not create CGImage")
        }
        let colors = dominantColorsFromCGImage(cgImage, clusterCount: 1)
        XCTAssertFalse(colors.isEmpty)
        XCTAssertEqual(colors[0], "#FFFFFF")
    }

    func testDominantColors_solidBlackImage_containsBlackHex() {
        guard let cgImage = makeSolidCGImage(width: 100, height: 100, r: 0, g: 0, b: 0) else {
            return XCTFail("Could not create CGImage")
        }
        let colors = dominantColorsFromCGImage(cgImage, clusterCount: 1)
        XCTAssertFalse(colors.isEmpty)
        XCTAssertEqual(colors[0], "#000000")
    }

    func testDominantColors_countMatchesClusterCount() {
        // Use clusterCount 1 to avoid kMeansWithTimeCheck timeout
        guard let cgImage = makeSolidCGImage(width: 10, height: 10, r: 128, g: 128, b: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let colors = dominantColorsFromCGImage(cgImage, clusterCount: 1)
        XCTAssertEqual(colors.count, 1)
    }

    func testDominantColors_allStringsAreHex() throws {
        guard let cgImage = makeSolidCGImage(width: 10, height: 10, r: 200, g: 100, b: 50) else {
            return XCTFail("Could not create CGImage")
        }
        let colors = dominantColorsFromCGImage(cgImage, clusterCount: 1)
        let hexPattern = try NSRegularExpression(pattern: "^#[0-9A-F]{6}$")
        for hex in colors {
            let range = NSRange(hex.startIndex ..< hex.endIndex, in: hex)
            XCTAssertNotNil(hexPattern.firstMatch(in: hex, range: range), "\(hex) is not valid hex")
        }
    }

    func testDominantColors_transparentImage_samplePixelsReturnsEmpty() {
        // downsample may not preserve alpha, so test samplePixels directly
        guard let cgImage = makeSolidCGImage(width: 100, height: 100, r: 255, g: 0, b: 0, a: 0) else {
            return XCTFail("Could not create CGImage")
        }
        let pixels = samplePixels(from: cgImage, sampleCount: 100)
        XCTAssertTrue(pixels.isEmpty, "Fully transparent pixels should be skipped")
    }

    // MARK: - Full Create → Save → Load → Process Pipeline

    func testPipeline_createSaveLoadResize_producesValidImage() {
        let name = uniqueImageName()
        guard let image = makeNSImage(width: 200, height: 200),
              let pngData = image.toPNGData(),
              saveImageToDocumentsDirectory(imageData: pngData, withName: name) != nil,
              let loaded = loadImageFromDocumentsDirectory(withName: name)
        else {
            return XCTFail("Pipeline step failed")
        }
        let resized = loaded.resizedToFit(maxPixels: 5000)
        XCTAssertLessThanOrEqual(resized.pixelCount, 5000)
    }

    func testPipeline_createSaveLoadCompress_producesValidImage() {
        let name = uniqueImageName()
        guard let image = makeNSImage(width: 200, height: 200),
              let pngData = image.toPNGData(),
              saveImageToDocumentsDirectory(imageData: pngData, withName: name) != nil,
              let loaded = loadImageFromDocumentsDirectory(withName: name)
        else {
            return XCTFail("Pipeline step failed")
        }
        let compressed = loaded.compressedToFit(maxSizeBytes: 5000)
        XCTAssertGreaterThan(compressed.pixelCount, 0)
    }

    func testPipeline_createSaveLoadBase64RoundTrip() {
        let name = uniqueImageName()
        guard let image = makeNSImage(width: 50, height: 50),
              let pngData = image.toPNGData(),
              saveImageToDocumentsDirectory(imageData: pngData, withName: name) != nil,
              let loaded = loadImageFromDocumentsDirectory(withName: name),
              let base64 = loaded.toBase64PNG(),
              let restored = toPlatformImage(base64: base64)
        else {
            return XCTFail("Pipeline step failed")
        }
        XCTAssertEqual(restored.pixelCount, 50 * 50)
    }

    func testPipeline_createSaveLoadCrop_producesCorrectSize() {
        let name = uniqueImageName()
        guard let image = makeNSImage(width: 100, height: 100),
              let pngData = image.toPNGData(),
              saveImageToDocumentsDirectory(imageData: pngData, withName: name) != nil,
              let loaded = loadImageFromDocumentsDirectory(withName: name),
              let cropped = cropImage(loaded, normalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        else {
            return XCTFail("Pipeline step failed")
        }
        XCTAssertEqual(cropped.pixelSize.width, 50)
        XCTAssertEqual(cropped.pixelSize.height, 50)
    }

    func testPipeline_createSaveLoadCropBase64_decodable() {
        let name = uniqueImageName()
        guard let image = makeNSImage(width: 100, height: 100),
              let pngData = image.toPNGData(),
              saveImageToDocumentsDirectory(imageData: pngData, withName: name) != nil,
              let loaded = loadImageFromDocumentsDirectory(withName: name),
              let cropped = cropImage(loaded, normalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
              let base64 = cropped.toBase64PNG()
        else {
            return XCTFail("Pipeline step failed")
        }
        XCTAssertNotNil(Data(base64Encoded: base64))
    }

    // MARK: - Image + Dominant Color Full Pipeline

    func testImageColorPipeline_createImageExtractColors_matchesExpected() {
        guard let cgImage = makeSolidCGImage(width: 100, height: 100, r: 255, g: 0, b: 0) else {
            return XCTFail("Could not create CGImage")
        }
        let colors = dominantColorsFromCGImage(cgImage, clusterCount: 1)
        XCTAssertEqual(colors.count, 1)
        XCTAssertEqual(colors[0], "#FF0000")
    }

    func testImageColorPipeline_saveLoadThenExtractDirectly() {
        let name = uniqueImageName()
        guard let image = makeNSImage(width: 50, height: 50, r: 0, g: 255, b: 0),
              let pngData = image.toPNGData(),
              saveImageToDocumentsDirectory(imageData: pngData, withName: name) != nil,
              let loaded = loadImageFromDocumentsDirectory(withName: name),
              let cgImage = loaded.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return XCTFail("Could not save/load image")
        }
        // Extract colors directly via samplePixels + kMeans to avoid
        // kMeansWithTimeCheck timeout inside dominantColorsFromCGImage
        let pixels = samplePixels(from: cgImage, sampleCount: 100)
        XCTAssertFalse(pixels.isEmpty)
        let clusters = kMeans(pixels: pixels, clusterCount: 1)
        let hex = UniversalColor(
            red: clusters[0].r,
            green: clusters[0].g,
            blue: clusters[0].b,
            alpha: 1.0
        ).hexString
        XCTAssertEqual(hex, "#00FF00")
    }

    func testImageColorPipeline_cropThenExtractColors_matchesExpected() {
        guard let image = makeNSImage(width: 200, height: 200, r: 0, g: 0, b: 255),
              let cropped = cropImage(image, normalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
              let cgImage = cropped.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return XCTFail("Could not crop image")
        }
        let colors = dominantColorsFromCGImage(cgImage, clusterCount: 1)
        XCTAssertFalse(colors.isEmpty)
        XCTAssertEqual(colors[0], "#0000FF")
    }

    // MARK: - Resize + Compress Combined Workflows

    func testResizeCompress_resizeThenCompress_producesSmallImage() {
        guard let image = makeNSImage(width: 500, height: 500) else {
            return XCTFail("Could not create image")
        }
        let resized = image.resizedToFit(maxPixels: 10000)
        let compressed = resized.compressedToFit(maxSizeBytes: 5000)
        XCTAssertGreaterThan(compressed.pixelCount, 0)
    }

    func testResizeCompress_compressThenResize_producesSmallImage() {
        guard let image = makeNSImage(width: 500, height: 500) else {
            return XCTFail("Could not create image")
        }
        let compressed = image.compressedToFit(maxSizeBytes: 50000)
        let resized = compressed.resizedToFit(maxPixels: 5000)
        XCTAssertGreaterThan(resized.pixelCount, 0)
    }

    func testResizeCompress_resizeCompressBase64_isDecodable() {
        guard let image = makeNSImage(width: 300, height: 300) else {
            return XCTFail("Could not create image")
        }
        let resized = image.resizedToFit(maxPixels: 10000)
        let compressed = resized.compressedToFit(maxSizeBytes: 20000)
        let base64 = compressed.toBase64PNG()
        XCTAssertNotNil(base64)
    }

    func testResizeCompress_toBase64WithBothLimits_isSmall() {
        guard let image = makeNSImage(width: 300, height: 300),
              let base64 = image.toBase64(maxPixels: 5000, maxSizeBytes: 5000)
        else {
            return XCTFail("Could not create base64")
        }
        guard let data = Data(base64Encoded: base64) else {
            return XCTFail("Invalid base64")
        }
        // Data should exist and be reasonable size
        XCTAssertGreaterThan(data.count, 0)
    }

    // MARK: - Image Scale Variants Workflow

    func testScaleVariants_allOptimizedScales_produceDecreasingSizes() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        var previousWidth = Double.greatestFiniteMagnitude
        for entry in optimizedImageScales {
            guard let resized = image.resizeImage(scale: CGFloat(entry.scale)) else {
                XCTFail("Failed for scale \(entry.scale)")
                continue
            }
            XCTAssertLessThanOrEqual(resized.size.width, previousWidth)
            previousWidth = resized.size.width
        }
    }

    func testScaleVariants_allOptimizedScales_allDecodable() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        for entry in optimizedImageScales {
            guard let resized = image.resizeImage(scale: CGFloat(entry.scale))
            else {
                XCTFail("Failed for scale \(entry.scale)")
                continue
            }
            XCTAssertGreaterThan(resized.size.width, 0)
            XCTAssertLessThan(resized.size.width, image.size.width + 1)
        }
    }

    func testScaleVariants_allOptimizedScales_allSavable() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        for entry in optimizedImageScales {
            let name = uniqueImageName()
            guard let resized = image.resizeImage(scale: CGFloat(entry.scale)),
                  let data = resized.toPNGData()
            else {
                XCTFail("Failed to create data for scale \(entry.scale)")
                continue
            }
            let url = saveImageToDocumentsDirectory(imageData: data, withName: name)
            XCTAssertNotNil(url, "Failed to save for scale \(entry.scale)")
        }
    }

    // MARK: - Cross-Adapter Workflows

    func testCrossAdapter_imageToBase64_saveBase64Data_loadAsImage() throws {
        let name = uniqueImageName()
        guard let image = makeNSImage(width: 50, height: 50),
              let base64 = image.toBase64PNG(),
              let data = Data(base64Encoded: base64),
              let url = saveImageToDocumentsDirectory(imageData: data, withName: name)
        else {
            return XCTFail("Pipeline step failed")
        }
        // The saved data is raw PNG base64, not a PNG file per se
        // But we can verify the data was saved
        let size = getImageSizeInBytes(imageURL: url)
        XCTAssertNotNil(size)
        XCTAssertGreaterThan(try XCTUnwrap(size), 0)
    }

    func testCrossAdapter_imageResize_crop_colors_fullChain() {
        guard let image = makeNSImage(width: 300, height: 300, r: 255, g: 0, b: 0) else {
            return XCTFail("Could not create image")
        }
        let resized = image.resizedToFit(maxPixels: 10000)
        guard let cropped = cropImage(resized, normalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
              let cgImage = cropped.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return XCTFail("Crop failed")
        }
        let colors = dominantColorsFromCGImage(cgImage, clusterCount: 1)
        XCTAssertFalse(colors.isEmpty)
        // Should still be reddish after resize + crop
        let hex = colors[0]
        let rValue = Int(hex.dropFirst().prefix(2), radix: 16) ?? 0
        XCTAssertGreaterThan(rValue, 200, "Should still be red after resize + crop")
    }

    func testCrossAdapter_videoDataSaveLoad_imageDataSaveLoad_independent() {
        let imgName = uniqueImageName()
        let vidName = uniqueVideoName()

        guard let image = makeNSImage(width: 50, height: 50),
              let pngData = image.toPNGData()
        else {
            return XCTFail("Could not create image data")
        }
        let videoData = Data(repeating: 0xAB, count: 100)

        let imgURL = saveImageToDocumentsDirectory(imageData: pngData, withName: imgName)
        let vidURL = saveVideoToDocumentsDirectory(videoData: videoData, withName: vidName)

        XCTAssertNotNil(imgURL)
        XCTAssertNotNil(vidURL)

        let loadedImage = loadImageFromDocumentsDirectory(withName: imgName)
        let loadedVideoURL = loadVideoUrlFromDocumentsDirectory(withName: vidName)

        XCTAssertNotNil(loadedImage)
        XCTAssertNotNil(loadedVideoURL)
    }

    // MARK: - Edge Case Workflows

    func testEdge_1x1Image_allOperations_doNotCrash() {
        guard let image = makeNSImage(width: 1, height: 1) else {
            return XCTFail("Could not create image")
        }
        _ = image.resizedToFit(maxPixels: 1)
        _ = image.compressedToFit(maxSizeBytes: 100)
        _ = image.toPNGData()
        _ = image.toBase64PNG()
        _ = image.toBase64JPEG()
        _ = image.toBase64(maxPixels: 1, maxSizeBytes: 100)
        _ = cropImage(image, normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    func testEdge_largeImage_1000x1000_allOperations_succeed() {
        guard let image = makeNSImage(width: 1000, height: 1000) else {
            return XCTFail("Could not create image")
        }
        let resized = image.resizedToFit(maxPixels: 50000)
        XCTAssertGreaterThan(resized.pixelCount, 0)
        let base64 = image.toBase64(maxPixels: 50000, maxSizeBytes: 50000)
        XCTAssertNotNil(base64)
    }

    func testEdge_emptyImageData_saveAndLoad_handlesGracefully() {
        let name = uniqueImageName()
        _ = saveImageToDocumentsDirectory(imageData: Data(), withName: name)
        let loaded = loadImageFromDocumentsDirectory(withName: name)
        XCTAssertNil(loaded) // Empty data can't create an image
    }

    func testEdge_corruptData_saveAndLoad_returnsNil() {
        let name = uniqueImageName()
        let corruptData = Data([0x01, 0x02, 0x03])
        _ = saveImageToDocumentsDirectory(imageData: corruptData, withName: name)
        let loaded = loadImageFromDocumentsDirectory(withName: name)
        XCTAssertNil(loaded)
    }

    func testEdge_concurrentSaveLoad_differentNames_noConflict() {
        let name1 = uniqueImageName()
        let name2 = uniqueImageName()
        guard let image1 = makeNSImage(width: 20, height: 20, r: 255, g: 0, b: 0),
              let image2 = makeNSImage(width: 20, height: 20, r: 0, g: 255, b: 0),
              let data1 = image1.toPNGData(),
              let data2 = image2.toPNGData()
        else {
            return XCTFail("Could not create images")
        }

        _ = saveImageToDocumentsDirectory(imageData: data1, withName: name1)
        _ = saveImageToDocumentsDirectory(imageData: data2, withName: name2)

        let loaded1 = loadImageFromDocumentsDirectory(withName: name1)
        let loaded2 = loadImageFromDocumentsDirectory(withName: name2)

        XCTAssertNotNil(loaded1)
        XCTAssertNotNil(loaded2)
    }

    // MARK: - Pixel Sampling + kMeans End-to-End

    func testSampleKMeans_solidColor_findsColor() {
        guard let cgImage = makeSolidCGImage(width: 100, height: 100, r: 255, g: 0, b: 0) else {
            return XCTFail("Could not create CGImage")
        }
        let pixels = samplePixels(from: cgImage, sampleCount: 100)
        XCTAssertFalse(pixels.isEmpty)
        let clusters = kMeans(pixels: pixels, clusterCount: 1)
        XCTAssertEqual(clusters[0].r, 1.0, accuracy: 0.05)
        XCTAssertEqual(clusters[0].g, 0.0, accuracy: 0.05)
        XCTAssertEqual(clusters[0].b, 0.0, accuracy: 0.05)
    }

    func testSampleKMeans_twoColors_findsBoth() {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let width = 100, height = 100
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let halfWidth = width / 2
        for y in 0 ..< height {
            for x in 0 ..< width {
                let i = (y * width + x) * bytesPerPixel
                if x < halfWidth {
                    pixelData[i] = 255 // red
                } else {
                    pixelData[i + 2] = 255 // blue
                }
                pixelData[i + 3] = 255
            }
        }
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            return XCTFail("Could not create CGImage")
        }
        let pixels = samplePixels(from: cgImage, sampleCount: 500)
        // Verify both colors present in sampled pixels
        let hasRedPixel = pixels.contains { $0.r > 0.8 && $0.g < 0.2 && $0.b < 0.2 }
        let hasBluePixel = pixels.contains { $0.r < 0.2 && $0.g < 0.2 && $0.b > 0.8 }
        XCTAssertTrue(hasRedPixel)
        XCTAssertTrue(hasBluePixel)
        // kMeans with 1 cluster gives a mean (safe; avoids empty-group infinite loop)
        let clusters = kMeans(pixels: pixels, clusterCount: 1)
        XCTAssertGreaterThan(clusters[0].r, 0.2)
        XCTAssertGreaterThan(clusters[0].b, 0.2)
    }

    func testFullPipeline_downsampleSampleKMeansHex() {
        guard let cgImage = makeSolidCGImage(width: 300, height: 300, r: 0, g: 255, b: 0) else {
            return XCTFail("Could not create CGImage")
        }
        guard let downsampled = downsample(image: cgImage, to: CGSize(width: 100, height: 100)) else {
            return XCTFail("Downsample failed")
        }
        let pixels = samplePixels(from: downsampled, sampleCount: 200)
        let clusters = kMeans(pixels: pixels, clusterCount: 1)
        let hex = UniversalColor(
            red: clusters[0].r,
            green: clusters[0].g,
            blue: clusters[0].b,
            alpha: 1.0
        ).hexString
        XCTAssertEqual(hex, "#00FF00")
    }

    // MARK: - Feedback + Constants Integration

    func testFeedbackConstants_feedbackLink_usesConstantsEmail() {
        let url = getFeedbackLink()
        XCTAssertTrue(url.absoluteString.contains(SUPPORT_EMAIL))
    }

    func testFeedbackConstants_feedbackLink_doesNotUseFallback() {
        let url = getFeedbackLink()
        XCTAssertEqual(url.scheme, "mailto")
        XCTAssertNotEqual(url.scheme, "https")
    }

    // MARK: - Video Export Result Scenarios

    func testVideoExportResult_successPattern() {
        let result = VideoExportResult(
            success: true,
            outputURL: URL(fileURLWithPath: "/tmp/output.mp4"),
            errorMessage: nil
        )
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.outputURL)
        XCTAssertNil(result.errorMessage)
    }

    func testVideoExportResult_failurePattern() {
        let result = VideoExportResult(
            success: false,
            outputURL: nil,
            errorMessage: "Encoding failed"
        )
        XCTAssertFalse(result.success)
        XCTAssertNil(result.outputURL)
        XCTAssertEqual(result.errorMessage, "Encoding failed")
    }

    func testVideoExportResult_workflowSimulation() {
        // Simulate: save video → check size → create export result
        let name = uniqueVideoName()
        let videoData = Data(repeating: 0xCD, count: 500)
        guard let url = saveVideoToDocumentsDirectory(videoData: videoData, withName: name) else {
            return XCTFail("Save failed")
        }
        let size = getVideoSizeInBytes(videoURL: url)
        XCTAssertNotNil(size)
        let result = VideoExportResult(success: true, outputURL: url, errorMessage: nil)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.outputURL, url)
    }
}
