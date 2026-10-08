// MARK: - ImageCropTests.swift

// Tests for cropImage() function which applies a normalized (0-1) crop rect.
//
// Covers:
// - Full rect, half-width, half-height, quarter crops
// - Aspect ratio scenarios
// - Edge cases: zero-width/height, 1-pixel, edge crops
// - Workflows: crop → resize, crop → base64, crop → save → load

import AppKit
import CoreGraphics
import XCTest
@testable import Illustrate

final class ImageCropTests: XCTestCase {
    // MARK: - Helpers

    private var testFileNames: [String] = []

    override func tearDown() {
        super.tearDown()
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        for name in testFileNames {
            let url = docsURL.appendingPathComponent("\(name).png")
            try? fm.removeItem(at: url)
        }
        testFileNames.removeAll()
    }

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

    // MARK: - cropImage Basic

    func testCrop_fullRect_returnsSameSize() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = cropImage(image, normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pixelSize.width, 100)
        XCTAssertEqual(result?.pixelSize.height, 100)
    }

    func testCrop_halfWidth_returnsHalfWidth() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = cropImage(image, normalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 1))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pixelSize.width, 50)
        XCTAssertEqual(result?.pixelSize.height, 100)
    }

    func testCrop_halfHeight_returnsHalfHeight() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = cropImage(image, normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 0.5))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pixelSize.width, 100)
        XCTAssertEqual(result?.pixelSize.height, 50)
    }

    func testCrop_quarterImage_topLeft() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = cropImage(image, normalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pixelSize.width, 50)
        XCTAssertEqual(result?.pixelSize.height, 50)
    }

    func testCrop_quarterImage_bottomRight() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = cropImage(image, normalizedRect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pixelSize.width, 50)
        XCTAssertEqual(result?.pixelSize.height, 50)
    }

    func testCrop_centerCrop() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = cropImage(image, normalizedRect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pixelSize.width, 50)
        XCTAssertEqual(result?.pixelSize.height, 50)
    }

    func testCrop_thinSlice_horizontal() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = cropImage(image, normalizedRect: CGRect(x: 0, y: 0.4, width: 1, height: 0.1))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pixelSize.width, 100)
        XCTAssertEqual(result?.pixelSize.height, 10)
    }

    func testCrop_thinSlice_vertical() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = cropImage(image, normalizedRect: CGRect(x: 0.4, y: 0, width: 0.1, height: 1))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pixelSize.width, 10)
        XCTAssertEqual(result?.pixelSize.height, 100)
    }

    func testCrop_returnsNonNil() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        let result = cropImage(image, normalizedRect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8))
        XCTAssertNotNil(result)
    }

    func testCrop_resultIsValidPlatformImage() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        guard let result = cropImage(image, normalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)) else {
            return XCTFail("Crop returned nil")
        }
        XCTAssertGreaterThan(result.pixelCount, 0)
    }

    // MARK: - cropImage Aspect Ratio

    func testCrop_landscapeCrop_preservesAspectRatio() throws {
        guard let image = makeNSImage(width: 200, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = cropImage(image, normalizedRect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8))
        XCTAssertNotNil(result)
        // 200*0.8=160, 100*0.8=80 → still landscape
        let ratio = try XCTUnwrap(result?.pixelSize.width) / result!.pixelSize.height
        XCTAssertGreaterThan(ratio, 1.0)
    }

    func testCrop_portraitCrop_fromLandscapeImage() throws {
        guard let image = makeNSImage(width: 200, height: 100) else {
            return XCTFail("Could not create image")
        }
        // Portrait-ish crop: narrow width, full height
        let result = cropImage(image, normalizedRect: CGRect(x: 0.4, y: 0, width: 0.2, height: 1))
        XCTAssertNotNil(result)
        // 200*0.2=40, 100*1=100 → portrait
        let ratio = try XCTUnwrap(result?.pixelSize.width) / result!.pixelSize.height
        XCTAssertLessThan(ratio, 1.0)
    }

    func testCrop_squareCrop_fromRectangularImage() {
        guard let image = makeNSImage(width: 200, height: 100) else {
            return XCTFail("Could not create image")
        }
        // Square crop: 100x100 from center of 200x100
        let result = cropImage(image, normalizedRect: CGRect(x: 0.25, y: 0, width: 0.5, height: 1))
        XCTAssertNotNil(result)
        // 200*0.5=100, 100*1=100
        XCTAssertEqual(result?.pixelSize.width, 100)
        XCTAssertEqual(result?.pixelSize.height, 100)
    }

    // MARK: - cropImage Edge Cases

    func testCrop_zeroWidthRect_returnsNil() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = cropImage(image, normalizedRect: CGRect(x: 0.5, y: 0, width: 0, height: 1))
        XCTAssertNil(result)
    }

    func testCrop_zeroHeightRect_returnsNil() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = cropImage(image, normalizedRect: CGRect(x: 0, y: 0.5, width: 1, height: 0))
        XCTAssertNil(result)
    }

    func testCrop_verySmallCrop_1Pixel() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        // 100 * 0.01 = 1 pixel
        let result = cropImage(image, normalizedRect: CGRect(x: 0, y: 0, width: 0.01, height: 0.01))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pixelSize.width, 1)
        XCTAssertEqual(result?.pixelSize.height, 1)
    }

    func testCrop_rectAtEdge_bottomRight() {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        let result = cropImage(image, normalizedRect: CGRect(x: 0.9, y: 0.9, width: 0.1, height: 0.1))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pixelSize.width, 10)
        XCTAssertEqual(result?.pixelSize.height, 10)
    }

    // MARK: - cropImage Workflow

    func testCropWorkflow_cropThenResize_producesValidImage() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        guard let cropped = cropImage(image, normalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)) else {
            return XCTFail("Crop returned nil")
        }
        let resized = cropped.resizedToFit(maxPixels: 1000)
        XCTAssertGreaterThan(resized.pixelCount, 0)
    }

    func testCropWorkflow_cropThenBase64_isDecodable() throws {
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        guard let cropped = cropImage(image, normalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)) else {
            return XCTFail("Crop returned nil")
        }
        let base64 = cropped.toBase64PNG()
        XCTAssertNotNil(base64)
        XCTAssertNotNil(try Data(base64Encoded: XCTUnwrap(base64)))
    }

    func testCropWorkflow_cropThenSave_thenLoad_roundTrips() {
        let name = "test_crop_\(UUID().uuidString)"
        testFileNames.append(name)
        guard let image = makeNSImage(width: 100, height: 100) else {
            return XCTFail("Could not create image")
        }
        guard let cropped = cropImage(image, normalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
              let pngData = cropped.toPNGData(),
              saveImageToDocumentsDirectory(imageData: pngData, withName: name) != nil
        else {
            return XCTFail("Save returned nil")
        }
        let loaded = loadImageFromDocumentsDirectory(withName: name)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.pixelSize.width, 50)
        XCTAssertEqual(loaded?.pixelSize.height, 50)
    }

    func testCropWorkflow_multipleCrops_produceDifferentSizes() throws {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        let crop1 = cropImage(image, normalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        let crop2 = cropImage(image, normalizedRect: CGRect(x: 0, y: 0, width: 0.25, height: 0.25))
        XCTAssertNotNil(crop1)
        XCTAssertNotNil(crop2)
        XCTAssertGreaterThan(try XCTUnwrap(crop1?.pixelCount), try XCTUnwrap(crop2?.pixelCount))
    }

    func testCropWorkflow_cropThenDominantColors_returnsHexes() {
        guard let image = makeNSImage(width: 200, height: 200, r: 255, g: 0, b: 0) else {
            return XCTFail("Could not create image")
        }
        guard let cropped = cropImage(image, normalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
              let cgImage = cropped.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return XCTFail("Could not get CGImage")
        }
        let colors = dominantColorsFromCGImage(cgImage, clusterCount: 1)
        XCTAssertFalse(colors.isEmpty)
        XCTAssertTrue(colors[0].hasPrefix("#"))
    }

    // MARK: - Large Image

    func testCrop_largeImage_1000x1000_centerCrop_succeeds() {
        guard let image = makeNSImage(width: 1000, height: 1000) else {
            return XCTFail("Could not create image")
        }
        let result = cropImage(image, normalizedRect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pixelSize.width, 500)
        XCTAssertEqual(result?.pixelSize.height, 500)
    }
}
