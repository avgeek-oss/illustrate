// MARK: - PlatformImagePropertyTests.swift

// Tests for PlatformImage extension properties: pixelCount, pixelSize.
//
// Covers:
// - pixelCount for various image dimensions
// - pixelSize for various image dimensions
// - Consistency between pixelCount and pixelSize

import AppKit
import CoreGraphics
import XCTest
@testable import Illustrate

final class PlatformImagePropertyTests: XCTestCase {
    // MARK: - Helpers

    private func makeNSImage(width: Int, height: Int) -> NSImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        var pixelData = [UInt8](repeating: 128, count: width * height * bytesPerPixel)
        for i in 0 ..< (width * height) {
            pixelData[i * 4 + 3] = 255 // alpha
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

    // MARK: - pixelCount

    func testPixelCount_10x10_returns100() {
        guard let image = makeNSImage(width: 10, height: 10) else {
            return XCTFail("Could not create image")
        }
        XCTAssertEqual(image.pixelCount, 100)
    }

    func testPixelCount_1x1_returns1() {
        guard let image = makeNSImage(width: 1, height: 1) else {
            return XCTFail("Could not create image")
        }
        XCTAssertEqual(image.pixelCount, 1)
    }

    func testPixelCount_100x200_returns20000() {
        guard let image = makeNSImage(width: 100, height: 200) else {
            return XCTFail("Could not create image")
        }
        XCTAssertEqual(image.pixelCount, 20000)
    }

    func testPixelCount_1x1000_returns1000() {
        guard let image = makeNSImage(width: 1, height: 1000) else {
            return XCTFail("Could not create image")
        }
        XCTAssertEqual(image.pixelCount, 1000)
    }

    func testPixelCount_squareImage() {
        guard let image = makeNSImage(width: 50, height: 50) else {
            return XCTFail("Could not create image")
        }
        XCTAssertEqual(image.pixelCount, 2500)
    }

    func testPixelCount_landscapeImage() {
        guard let image = makeNSImage(width: 200, height: 100) else {
            return XCTFail("Could not create image")
        }
        XCTAssertEqual(image.pixelCount, 20000)
    }

    func testPixelCount_portraitImage() {
        guard let image = makeNSImage(width: 100, height: 200) else {
            return XCTFail("Could not create image")
        }
        XCTAssertEqual(image.pixelCount, 20000)
    }

    // MARK: - pixelSize

    func testPixelSize_10x10() {
        guard let image = makeNSImage(width: 10, height: 10) else {
            return XCTFail("Could not create image")
        }
        XCTAssertEqual(image.pixelSize.width, 10)
        XCTAssertEqual(image.pixelSize.height, 10)
    }

    func testPixelSize_100x200() {
        guard let image = makeNSImage(width: 100, height: 200) else {
            return XCTFail("Could not create image")
        }
        XCTAssertEqual(image.pixelSize.width, 100)
        XCTAssertEqual(image.pixelSize.height, 200)
    }

    func testPixelSize_1x1() {
        guard let image = makeNSImage(width: 1, height: 1) else {
            return XCTFail("Could not create image")
        }
        XCTAssertEqual(image.pixelSize.width, 1)
        XCTAssertEqual(image.pixelSize.height, 1)
    }

    func testPixelSize_landscape() {
        guard let image = makeNSImage(width: 300, height: 100) else {
            return XCTFail("Could not create image")
        }
        XCTAssertEqual(image.pixelSize.width, 300)
        XCTAssertEqual(image.pixelSize.height, 100)
    }

    func testPixelSize_portrait() {
        guard let image = makeNSImage(width: 100, height: 300) else {
            return XCTFail("Could not create image")
        }
        XCTAssertEqual(image.pixelSize.width, 100)
        XCTAssertEqual(image.pixelSize.height, 300)
    }

    func testPixelSize_widthAndHeight_arePositive() {
        guard let image = makeNSImage(width: 50, height: 75) else {
            return XCTFail("Could not create image")
        }
        XCTAssertGreaterThan(image.pixelSize.width, 0)
        XCTAssertGreaterThan(image.pixelSize.height, 0)
    }

    // MARK: - pixelCount + pixelSize Consistency

    func testConsistency_pixelCountEqualsWidthTimesHeight() {
        guard let image = makeNSImage(width: 123, height: 456) else {
            return XCTFail("Could not create image")
        }
        let size = image.pixelSize
        XCTAssertEqual(image.pixelCount, Int(size.width) * Int(size.height))
    }

    func testConsistency_multipleImages_allConsistent() {
        let dimensions: [(Int, Int)] = [(10, 10), (50, 100), (200, 300), (1, 500)]
        for (w, h) in dimensions {
            guard let image = makeNSImage(width: w, height: h) else {
                XCTFail("Could not create \(w)x\(h) image")
                continue
            }
            let size = image.pixelSize
            XCTAssertEqual(
                image.pixelCount,
                Int(size.width) * Int(size.height),
                "Inconsistent for \(w)x\(h)"
            )
        }
    }
}
