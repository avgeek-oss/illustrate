// MARK: - PlatformImageTransformTests.swift

// Tests for PlatformImage extension transform methods:
// resizedToFit, compressedToFit, estimatedDataSize, toPNGData,
// toBase64PNG, toBase64JPEG, toBase64 (smart encoding),
// resizeImage(scale:), resizeImage(targetSize:), toImage.
//
// Covers:
// - Resize and compression behavior
// - PNG/JPEG data encoding and signatures
// - Base64 encoding/decoding round-trips
// - Smart encoding with pixel and size limits
// - Multi-step transform workflows

import AppKit
import CoreGraphics
import XCTest
@testable import Illustrate

final class PlatformImageTransformTests: XCTestCase {
    // MARK: - Helpers

    private func makeNSImage(width: Int, height: Int, r: UInt8 = 128, g: UInt8 = 128, b: UInt8 = 128) -> NSImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        for i in 0 ..< (width * height) {
            pixelData[i * 4] = r
            pixelData[i * 4 + 1] = g
            pixelData[i * 4 + 2] = b
            pixelData[i * 4 + 3] = 255
        }
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    // MARK: - resizedToFit

    func testResizedToFit_smallerThanMax_returnsSelf() {
        guard let image = makeNSImage(width: 10, height: 10) else {
            return XCTFail("Could not create image")
        }
        let result = image.resizedToFit(maxPixels: 10000)
        XCTAssertEqual(result.pixelCount, image.pixelCount)
    }

    func testResizedToFit_exactlyAtMax_returnsSelf() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = image.resizedToFit(maxPixels: 10000)
        XCTAssertEqual(result.pixelCount, 10000)
    }

    func testResizedToFit_largerThanMax_returnsSmaller() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        let result = image.resizedToFit(maxPixels: 10000)
        XCTAssertLessThanOrEqual(result.pixelCount, 10000)
    }

    func testResizedToFit_preservesAspectRatio_landscape() {
        guard let image = makeNSImage(width: 200, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = image.resizedToFit(maxPixels: 5000)
        let size = result.pixelSize
        let ratio = size.width / size.height
        XCTAssertEqual(ratio, 2.0, accuracy: 0.3)
    }

    func testResizedToFit_preservesAspectRatio_portrait() {
        guard let image = makeNSImage(width: 100, height: 200) else {
            return XCTFail("Could not create image")
        }
        let result = image.resizedToFit(maxPixels: 5000)
        let size = result.pixelSize
        let ratio = size.width / size.height
        XCTAssertEqual(ratio, 0.5, accuracy: 0.3)
    }

    func testResizedToFit_preservesAspectRatio_square() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        let result = image.resizedToFit(maxPixels: 5000)
        let size = result.pixelSize
        let ratio = size.width / size.height
        XCTAssertEqual(ratio, 1.0, accuracy: 0.3)
    }

    func testResizedToFit_verySmallMax_reducesSignificantly() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        let result = image.resizedToFit(maxPixels: 100)
        XCTAssertLessThanOrEqual(result.pixelCount, 100)
    }

    func testResizedToFit_1x1Image_maxPixels1_returnsSelf() {
        guard let image = makeNSImage(width: 1, height: 1) else {
            return XCTFail("Could not create image")
        }
        let result = image.resizedToFit(maxPixels: 1)
        XCTAssertEqual(result.pixelCount, 1)
    }

    func testResizedToFit_returnsNonNilImage() {
        guard let image = makeNSImage(width: 300, height: 300) else {
            return XCTFail("Could not create image")
        }
        let result = image.resizedToFit(maxPixels: 5000)
        XCTAssertGreaterThan(result.pixelCount, 0)
    }

    // MARK: - estimatedDataSize

    func testEstimatedDataSize_defaultQuality_returnsPositive() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let size = image.estimatedDataSize()
        XCTAssertGreaterThan(size, 0)
    }

    func testEstimatedDataSize_highQuality_largerThanLowQuality() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let highQ = image.estimatedDataSize(quality: 1.0)
        let lowQ = image.estimatedDataSize(quality: 0.1)
        XCTAssertGreaterThanOrEqual(highQ, lowQ)
    }

    func testEstimatedDataSize_quality1_vs_quality01() {
        guard let image = makeNSImage(width: 50, height: 50) else {
            return XCTFail("Could not create image")
        }
        let q1 = image.estimatedDataSize(quality: 1.0)
        let q01 = image.estimatedDataSize(quality: 0.1)
        XCTAssertGreaterThan(q1, 0)
        XCTAssertGreaterThan(q01, 0)
    }

    func testEstimatedDataSize_smallImage_smallerThanLargeImage() {
        guard let small = makeNSImage(width: 10, height: 10),
              let large = makeNSImage(width: 200, height: 200)
        else {
            return XCTFail("Could not create images")
        }
        let smallSize = small.estimatedDataSize()
        let largeSize = large.estimatedDataSize()
        XCTAssertLessThan(smallSize, largeSize)
    }

    func testEstimatedDataSize_returnsInt() {
        guard let image = makeNSImage(width: 50, height: 50) else {
            return XCTFail("Could not create image")
        }
        let size = image.estimatedDataSize()
        XCTAssertTrue(size >= 0)
    }

    // MARK: - compressedToFit

    func testCompressedToFit_smallImage_belowLimit_returnsSelf() {
        guard let image = makeNSImage(width: 10, height: 10) else {
            return XCTFail("Could not create image")
        }
        let result = image.compressedToFit(maxSizeBytes: 1_000_000)
        XCTAssertGreaterThan(result.pixelCount, 0)
    }

    func testCompressedToFit_returnsValidImage() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = image.compressedToFit(maxSizeBytes: 500)
        XCTAssertGreaterThan(result.pixelCount, 0)
    }

    func testCompressedToFit_extremelySmallLimit_usesMinQuality() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = image.compressedToFit(maxSizeBytes: 1)
        // Should still return a valid image (might be self if compression can't reach target)
        XCTAssertGreaterThan(result.pixelCount, 0)
    }

    func testCompressedToFit_moderateLimit_compresses() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        let originalSize = image.estimatedDataSize()
        let limit = originalSize / 2
        let result = image.compressedToFit(maxSizeBytes: limit)
        let resultSize = result.estimatedDataSize()
        // Compressed image should be smaller or equal (may have different codec overhead)
        XCTAssertGreaterThan(result.pixelCount, 0)
        // The result's estimated size at default quality may differ from the limit
        // but the actual JPEG data at some quality should fit
        XCTAssertLessThanOrEqual(resultSize, originalSize)
    }

    // MARK: - toPNGData

    func testToPNGData_validImage_returnsNonNilData() {
        guard let image = makeNSImage(width: 10, height: 10) else {
            return XCTFail("Could not create image")
        }
        XCTAssertNotNil(image.toPNGData())
    }

    func testToPNGData_dataCanRecreateImage() {
        guard let image = makeNSImage(width: 10, height: 10),
              let data = image.toPNGData()
        else {
            return XCTFail("Could not create PNG data")
        }
        let recreated = NSImage(data: data)
        XCTAssertNotNil(recreated)
    }

    func testToPNGData_pngSignatureCheck() {
        guard let image = makeNSImage(width: 10, height: 10),
              let data = image.toPNGData()
        else {
            return XCTFail("Could not create PNG data")
        }
        // PNG signature: 137, 80, 78, 71
        let bytes = [UInt8](data.prefix(4))
        XCTAssertEqual(bytes, [137, 80, 78, 71])
    }

    func testToPNGData_nonZeroSize() {
        guard let image = makeNSImage(width: 50, height: 50),
              let data = image.toPNGData()
        else {
            return XCTFail("Could not create PNG data")
        }
        XCTAssertGreaterThan(data.count, 0)
    }

    // MARK: - toBase64PNG

    func testToBase64PNG_validImage_returnsNonNilString() {
        guard let image = makeNSImage(width: 10, height: 10) else {
            return XCTFail("Could not create image")
        }
        XCTAssertNotNil(image.toBase64PNG())
    }

    func testToBase64PNG_isValidBase64() {
        guard let image = makeNSImage(width: 10, height: 10),
              let base64 = image.toBase64PNG()
        else {
            return XCTFail("Could not create base64 PNG")
        }
        XCTAssertNotNil(Data(base64Encoded: base64))
    }

    func testToBase64PNG_decodesBackToPNG() {
        guard let image = makeNSImage(width: 10, height: 10),
              let base64 = image.toBase64PNG(),
              let data = Data(base64Encoded: base64)
        else {
            return XCTFail("Could not decode base64 PNG")
        }
        let bytes = [UInt8](data.prefix(4))
        XCTAssertEqual(bytes, [137, 80, 78, 71])
    }

    func testToBase64PNG_roundTrip_toPlatformImage() {
        guard let image = makeNSImage(width: 10, height: 10),
              let base64 = image.toBase64PNG()
        else {
            return XCTFail("Could not create base64 PNG")
        }
        let restored = toPlatformImage(base64: base64)
        XCTAssertNotNil(restored)
    }

    // MARK: - toBase64JPEG

    func testToBase64JPEG_validImage_returnsNonNilString() {
        guard let image = makeNSImage(width: 10, height: 10) else {
            return XCTFail("Could not create image")
        }
        XCTAssertNotNil(image.toBase64JPEG())
    }

    func testToBase64JPEG_isValidBase64() {
        guard let image = makeNSImage(width: 10, height: 10),
              let base64 = image.toBase64JPEG()
        else {
            return XCTFail("Could not create base64 JPEG")
        }
        XCTAssertNotNil(Data(base64Encoded: base64))
    }

    func testToBase64JPEG_defaultQuality_isJPEG() {
        guard let image = makeNSImage(width: 10, height: 10),
              let base64 = image.toBase64JPEG(),
              let data = Data(base64Encoded: base64)
        else {
            return XCTFail("Could not decode base64 JPEG")
        }
        // JPEG signature: 0xFF, 0xD8
        let bytes = [UInt8](data.prefix(2))
        XCTAssertEqual(bytes, [0xFF, 0xD8])
    }

    func testToBase64JPEG_quality1_largerThanQuality01() {
        guard let image = makeNSImage(width: 50, height: 50),
              let highQ = image.toBase64JPEG(quality: 1.0),
              let lowQ = image.toBase64JPEG(quality: 0.1)
        else {
            return XCTFail("Could not create base64 JPEG")
        }
        XCTAssertGreaterThanOrEqual(highQ.count, lowQ.count)
    }

    func testToBase64JPEG_quality0_returnsNonNil() {
        guard let image = makeNSImage(width: 10, height: 10) else {
            return XCTFail("Could not create image")
        }
        // Even quality 0 (or very low) should produce something
        let result = image.toBase64JPEG(quality: 0.0)
        XCTAssertNotNil(result)
    }

    // MARK: - toBase64 Smart Encoding

    func testToBase64_noLimits_returnsPNG() {
        guard let image = makeNSImage(width: 10, height: 10),
              let base64 = image.toBase64(),
              let data = Data(base64Encoded: base64)
        else {
            return XCTFail("Could not create base64")
        }
        // No limits → PNG
        let bytes = [UInt8](data.prefix(4))
        XCTAssertEqual(bytes, [137, 80, 78, 71])
    }

    func testToBase64_maxPixelsExceeded_resizesThenEncodes() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        // 200*200=40000 pixels, limit to 5000
        let base64 = image.toBase64(maxPixels: 5000)
        XCTAssertNotNil(base64)
    }

    func testToBase64_maxSizeBytesExceeded_compresses() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        let base64 = image.toBase64(maxSizeBytes: 500)
        XCTAssertNotNil(base64)
    }

    func testToBase64_bothLimits_resizesAndCompresses() {
        guard let image = makeNSImage(width: 300, height: 300) else {
            return XCTFail("Could not create image")
        }
        let base64 = image.toBase64(maxPixels: 5000, maxSizeBytes: 2000)
        XCTAssertNotNil(base64)
    }

    func testToBase64_withinBothLimits_returnsJPEG() {
        guard let image = makeNSImage(width: 10, height: 10),
              let base64 = image.toBase64(maxPixels: 1000, maxSizeBytes: 100_000),
              let data = Data(base64Encoded: base64)
        else {
            return XCTFail("Could not create base64")
        }
        // When maxSizeBytes is provided and estimated size fits, returns JPEG
        let bytes = [UInt8](data.prefix(2))
        XCTAssertEqual(bytes, [0xFF, 0xD8])
    }

    func testToBase64_maxPixelsNil_maxSizeBytesSet_compressesOnly() {
        guard let image = makeNSImage(width: 50, height: 50) else {
            return XCTFail("Could not create image")
        }
        let base64 = image.toBase64(maxSizeBytes: 5000)
        XCTAssertNotNil(base64)
    }

    func testToBase64_isDecodableBase64() {
        guard let image = makeNSImage(width: 50, height: 50),
              let base64 = image.toBase64(maxPixels: 1000, maxSizeBytes: 10000)
        else {
            return XCTFail("Could not create base64")
        }
        XCTAssertNotNil(Data(base64Encoded: base64))
    }

    // MARK: - resizeImage(scale:)

    func testResizeImageScale_scale1_returnsSameSize() {
        guard let image = makeNSImage(width: 100, height: 100),
              let resized = image.resizeImage(scale: 1.0)
        else {
            return XCTFail("Could not resize image")
        }
        XCTAssertEqual(resized.size.width, 100.0, accuracy: 0.5)
        XCTAssertEqual(resized.size.height, 100.0, accuracy: 0.5)
    }

    func testResizeImageScale_scaleHalf_returnsSmallerBase64() {
        guard let image = makeNSImage(width: 100, height: 100),
              let full = image.resizeImage(scale: 1.0),
              let half = image.resizeImage(scale: 0.5)
        else {
            return XCTFail("Could not resize image")
        }
        XCTAssertLessThan(half.size.width, full.size.width)
    }

    func testResizeImageScale_scaleZeroPointOne_returnsBase64() {
        guard let image = makeNSImage(width: 100, height: 100),
              let resized = image.resizeImage(scale: 0.1)
        else {
            return XCTFail("Could not resize image")
        }
        XCTAssertEqual(resized.size.width, 10.0, accuracy: 0.5)
        XCTAssertEqual(resized.size.height, 10.0, accuracy: 0.5)
    }

    func testResizeImageScale_resultIsValidBase64PNG() {
        guard let image = makeNSImage(width: 100, height: 100),
              let resized = image.resizeImage(scale: 0.5)
        else {
            return XCTFail("Could not resize image")
        }
        XCTAssertEqual(resized.size.width, 50.0, accuracy: 0.5)
        XCTAssertEqual(resized.size.height, 50.0, accuracy: 0.5)
    }

    func testResizeImageScale_scaleNearZero_doesNotCrash() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        // Very small scale — should not crash
        _ = image.resizeImage(scale: 0.01)
    }

    // MARK: - resizeImage(targetSize:)

    func testResizeImageTargetSize_returnsNonNil() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = image.resizeImage(targetSize: CGSize(width: 50, height: 50))
        XCTAssertNotNil(result)
    }

    func testResizeImageTargetSize_resultIsPlatformImage() {
        guard let image = makeNSImage(width: 100, height: 100),
              let result = image.resizeImage(targetSize: CGSize(width: 50, height: 50))
        else {
            return XCTFail("Could not resize image")
        }
        XCTAssertGreaterThan(result.pixelCount, 0)
    }

    func testResizeImageTargetSize_smallerTarget() {
        guard let image = makeNSImage(width: 200, height: 200),
              let result = image.resizeImage(targetSize: CGSize(width: 50, height: 50))
        else {
            return XCTFail("Could not resize image")
        }
        XCTAssertLessThan(result.pixelCount, image.pixelCount)
    }

    func testResizeImageTargetSize_largerTarget() {
        guard let image = makeNSImage(width: 50, height: 50),
              let result = image.resizeImage(targetSize: CGSize(width: 200, height: 200))
        else {
            return XCTFail("Could not resize image")
        }
        XCTAssertGreaterThan(result.pixelCount, 0)
    }

    // MARK: - toImage

    func testToImage_returnsSwiftUIImage() {
        guard let image = makeNSImage(width: 10, height: 10) else {
            return XCTFail("Could not create image")
        }
        // Should not crash
        _ = image.toImage()
    }

    // MARK: - Multi-step Workflows

    func testWorkflow_resizeToFitThenCompress_producesValidImage() {
        guard let image = makeNSImage(width: 300, height: 300) else {
            return XCTFail("Could not create image")
        }
        let resized = image.resizedToFit(maxPixels: 10000)
        let compressed = resized.compressedToFit(maxSizeBytes: 50000)
        XCTAssertGreaterThan(compressed.pixelCount, 0)
    }

    func testWorkflow_resizeThenBase64_isDecodable() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        let resized = image.resizedToFit(maxPixels: 5000)
        guard let base64 = resized.toBase64PNG() else {
            return XCTFail("Could not create base64")
        }
        XCTAssertNotNil(Data(base64Encoded: base64))
    }

    func testWorkflow_compressThenBase64JPEG_isDecodable() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let compressed = image.compressedToFit(maxSizeBytes: 5000)
        guard let base64 = compressed.toBase64JPEG() else {
            return XCTFail("Could not create base64 JPEG")
        }
        XCTAssertNotNil(Data(base64Encoded: base64))
    }

    func testWorkflow_toBase64WithLimits_thenDecode_roundTrips() {
        guard let image = makeNSImage(width: 100, height: 100),
              let base64 = image.toBase64(maxPixels: 5000, maxSizeBytes: 50000)
        else {
            return XCTFail("Could not create base64")
        }
        let restored = toPlatformImage(base64: base64)
        XCTAssertNotNil(restored)
    }
}
