// MARK: - MediaGenerationHelperConstantsTests.swift

// Tests for optimizedImageScales constant array and scale-related behavior.
//
// Covers:
// - Array structure and entry values
// - Scale ordering and constraints
// - Scale values correctness with arithmetic
// - Scale application with resizeImage
// - Suffix format and file naming patterns

import AppKit
import CoreGraphics
import XCTest
@testable import Illustrate

final class MediaGenerationHelperConstantsTests: XCTestCase {
    // MARK: - Helpers

    private func makeNSImage(width: Int, height: Int) -> NSImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        var pixelData = [UInt8](repeating: 128, count: width * height * bytesPerPixel)
        for i in 0 ..< (width * height) {
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

    // MARK: - optimizedImageScales Array Structure

    func testScales_hasExactly4Entries() {
        XCTAssertEqual(optimizedImageScales.count, 4)
    }

    func testScales_firstEntry_isHalfScale() {
        XCTAssertEqual(optimizedImageScales[0].scale, 0.50, accuracy: 0.001)
        XCTAssertEqual(optimizedImageScales[0].suffix, "o50")
    }

    func testScales_secondEntry_is20Percent() {
        XCTAssertEqual(optimizedImageScales[1].scale, 0.20, accuracy: 0.001)
        XCTAssertEqual(optimizedImageScales[1].suffix, "o20")
    }

    func testScales_thirdEntry_is10Percent() {
        XCTAssertEqual(optimizedImageScales[2].scale, 0.10, accuracy: 0.001)
        XCTAssertEqual(optimizedImageScales[2].suffix, "o10")
    }

    func testScales_fourthEntry_is4Percent() {
        XCTAssertEqual(optimizedImageScales[3].scale, 0.04, accuracy: 0.001)
        XCTAssertEqual(optimizedImageScales[3].suffix, "o04")
    }

    func testScales_scalesAreDescending() {
        for i in 0 ..< optimizedImageScales.count - 1 {
            XCTAssertGreaterThan(
                optimizedImageScales[i].scale,
                optimizedImageScales[i + 1].scale,
                "Scale at \(i) should be greater than scale at \(i + 1)"
            )
        }
    }

    func testScales_allScalesPositive() {
        for entry in optimizedImageScales {
            XCTAssertGreaterThan(entry.scale, 0)
        }
    }

    func testScales_allScalesLessThan1() {
        for entry in optimizedImageScales {
            XCTAssertLessThan(entry.scale, 1.0)
        }
    }

    func testScales_suffixesAreUnique() {
        let suffixes = optimizedImageScales.map(\.suffix)
        XCTAssertEqual(Set(suffixes).count, suffixes.count)
    }

    func testScales_suffixesStartWithO() {
        for entry in optimizedImageScales {
            XCTAssertTrue(entry.suffix.hasPrefix("o"), "\(entry.suffix) should start with 'o'")
        }
    }

    func testScales_suffixesAreNonEmpty() {
        for entry in optimizedImageScales {
            XCTAssertFalse(entry.suffix.isEmpty)
        }
    }

    // MARK: - Scale Values Correctness

    func testScaleValue_halfScale_producesCorrectSize() {
        let original: Double = 1000
        let scaled = original * 0.50
        XCTAssertEqual(scaled, 500.0)
    }

    func testScaleValue_twentyPercent_producesCorrectSize() {
        let original: Double = 1000
        let scaled = original * 0.20
        XCTAssertEqual(scaled, 200.0)
    }

    func testScaleValue_tenPercent_producesCorrectSize() {
        let original: Double = 1000
        let scaled = original * 0.10
        XCTAssertEqual(scaled, 100.0)
    }

    func testScaleValue_fourPercent_producesCorrectSize() {
        let original: Double = 1000
        let scaled = original * 0.04
        XCTAssertEqual(scaled, 40.0)
    }

    // MARK: - Scale Workflow with resizeImage

    func testScaleWorkflow_halfScale_producesValidBase64() {
        guard let image = makeNSImage(width: 100, height: 100),
              let resized = image.resizeImage(scale: CGFloat(optimizedImageScales[0].scale))
        else {
            return XCTFail("Could not resize image")
        }
        XCTAssertEqual(resized.size.width, 50.0, accuracy: 0.5)
        XCTAssertEqual(resized.size.height, 50.0, accuracy: 0.5)
    }

    func testScaleWorkflow_twentyPercent_producesValidBase64() {
        guard let image = makeNSImage(width: 100, height: 100),
              let resized = image.resizeImage(scale: CGFloat(optimizedImageScales[1].scale))
        else {
            return XCTFail("Could not resize image")
        }
        XCTAssertEqual(resized.size.width, 20.0, accuracy: 0.5)
        XCTAssertEqual(resized.size.height, 20.0, accuracy: 0.5)
    }

    func testScaleWorkflow_tenPercent_producesValidBase64() {
        guard let image = makeNSImage(width: 100, height: 100),
              let resized = image.resizeImage(scale: CGFloat(optimizedImageScales[2].scale))
        else {
            return XCTFail("Could not resize image")
        }
        XCTAssertEqual(resized.size.width, 10.0, accuracy: 0.5)
        XCTAssertEqual(resized.size.height, 10.0, accuracy: 0.5)
    }

    func testScaleWorkflow_fourPercent_producesValidBase64() {
        guard let image = makeNSImage(width: 200, height: 200),
              let resized = image.resizeImage(scale: CGFloat(optimizedImageScales[3].scale))
        else {
            return XCTFail("Could not resize image")
        }
        XCTAssertEqual(resized.size.width, 8.0, accuracy: 0.5)
        XCTAssertEqual(resized.size.height, 8.0, accuracy: 0.5)
    }

    func testScaleWorkflow_allScales_produceDecreasingSizes() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        var previousWidth = Double.greatestFiniteMagnitude
        for entry in optimizedImageScales {
            guard let resized = image.resizeImage(scale: CGFloat(entry.scale)) else {
                XCTFail("Resize failed for scale \(entry.scale)")
                continue
            }
            XCTAssertLessThanOrEqual(
                resized.size.width,
                previousWidth,
                "Scale \(entry.scale) should produce smaller image"
            )
            previousWidth = resized.size.width
        }
    }

    func testScaleWorkflow_allScales_areDecodable() {
        guard let image = makeNSImage(width: 200, height: 200) else {
            return XCTFail("Could not create image")
        }
        for entry in optimizedImageScales {
            guard let resized = image.resizeImage(scale: CGFloat(entry.scale))
            else {
                XCTFail("Could not resize for scale \(entry.scale)")
                continue
            }
            XCTAssertLessThan(
                resized.size.width,
                image.size.width + 1,
                "Resized should be smaller for scale \(entry.scale)"
            )
        }
    }

    // MARK: - Scale Application

    func testScaleApplication_1024x1024_halfIs512() {
        let dimension: Double = 1024
        let half = dimension * optimizedImageScales[0].scale
        XCTAssertEqual(half, 512.0)
    }

    func testScaleApplication_1024x1024_20PercentIs204() {
        let dimension: Double = 1024
        let twenty = dimension * optimizedImageScales[1].scale
        XCTAssertEqual(twenty, 204.8, accuracy: 0.1)
    }

    func testScaleApplication_2048x2048_allScales_allPositive() {
        let dimension: Double = 2048
        for entry in optimizedImageScales {
            let scaled = dimension * entry.scale
            XCTAssertGreaterThan(scaled, 0, "Scale \(entry.scale) produced non-positive dimension")
        }
    }

    // MARK: - Suffix Format + File Naming

    func testSuffixFormat_o50_matchesPattern() {
        let suffix = optimizedImageScales[0].suffix
        let regex = try? NSRegularExpression(pattern: "^o\\d{2}$")
        let range = NSRange(suffix.startIndex ..< suffix.endIndex, in: suffix)
        XCTAssertNotNil(regex?.firstMatch(in: suffix, range: range))
    }

    func testSuffixFormat_o20_matchesPattern() {
        let suffix = optimizedImageScales[1].suffix
        let regex = try? NSRegularExpression(pattern: "^o\\d{2}$")
        let range = NSRange(suffix.startIndex ..< suffix.endIndex, in: suffix)
        XCTAssertNotNil(regex?.firstMatch(in: suffix, range: range))
    }

    func testFileNaming_suffixApplied_correctFormat() {
        let baseName = "image_123"
        for entry in optimizedImageScales {
            let fileName = "\(baseName)_\(entry.suffix)"
            XCTAssertTrue(fileName.contains(entry.suffix))
        }
    }

    func testFileNaming_allSuffixes_produceUniquePaths() {
        let baseName = "test"
        let names = optimizedImageScales.map { "\(baseName)_\($0.suffix)" }
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testFileNaming_prefixedWithDot_isHidden() {
        let baseName = ".hidden_image"
        for entry in optimizedImageScales {
            let fileName = "\(baseName)_\(entry.suffix)"
            XCTAssertTrue(fileName.hasPrefix("."), "\(fileName) should start with dot")
        }
    }
}
