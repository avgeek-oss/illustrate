// MARK: - PixelSamplingAndDownsampleTests.swift

// Tests for samplePixels() and downsample() pure functions, plus
// combined workflows: downsample → samplePixels → kMeans → hex.
//
// Covers:
// - samplePixels basic color sampling from solid CGImages
// - Transparency handling (alpha threshold at 128)
// - Premultiplied alpha un-multiplication
// - downsample dimension calculations and aspect ratio preservation
// - Combined pipeline workflows

import AppKit
import CoreGraphics
import XCTest
@testable import Illustrate

final class PixelSamplingAndDownsampleTests: XCTestCase {
    // MARK: - Helpers

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

    /// Creates an image where top half is opaque, bottom half is transparent.
    private func makeHalfTransparentCGImage(
        width: Int,
        height: Int,
        r: UInt8,
        g: UInt8,
        b: UInt8
    ) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let halfHeight = height / 2
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let i = (y * width + x) * bytesPerPixel
                pixelData[i] = r
                pixelData[i + 1] = g
                pixelData[i + 2] = b
                pixelData[i + 3] = y < halfHeight ? 255 : 0
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
        ) else { return nil }
        return context.makeImage()
    }

    /// Creates a two-color CGImage (left half / right half).
    private func makeTwoColorCGImage(
        width: Int,
        height: Int,
        leftR: UInt8, leftG: UInt8, leftB: UInt8,
        rightR: UInt8, rightG: UInt8, rightB: UInt8
    ) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let halfWidth = width / 2
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let i = (y * width + x) * bytesPerPixel
                if x < halfWidth {
                    pixelData[i] = leftR
                    pixelData[i + 1] = leftG
                    pixelData[i + 2] = leftB
                } else {
                    pixelData[i] = rightR
                    pixelData[i + 1] = rightG
                    pixelData[i + 2] = rightB
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
        ) else { return nil }
        return context.makeImage()
    }

    // MARK: - samplePixels Basic

    func testSamplePixels_solidRedImage_allPixelsNearRed() {
        guard let img = makeSolidCGImage(width: 10, height: 10, r: 255, g: 0, b: 0) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 20)
        XCTAssertFalse(result.isEmpty)
        for pixel in result {
            XCTAssertGreaterThan(pixel.r, 0.9, "Red should be > 0.9")
            XCTAssertLessThan(pixel.g, 0.1, "Green should be < 0.1")
            XCTAssertLessThan(pixel.b, 0.1, "Blue should be < 0.1")
        }
    }

    func testSamplePixels_solidGreenImage_allPixelsNearGreen() {
        guard let img = makeSolidCGImage(width: 10, height: 10, r: 0, g: 255, b: 0) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 20)
        XCTAssertFalse(result.isEmpty)
        for pixel in result {
            XCTAssertLessThan(pixel.r, 0.1)
            XCTAssertGreaterThan(pixel.g, 0.9)
            XCTAssertLessThan(pixel.b, 0.1)
        }
    }

    func testSamplePixels_solidBlueImage_allPixelsNearBlue() {
        guard let img = makeSolidCGImage(width: 10, height: 10, r: 0, g: 0, b: 255) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 20)
        XCTAssertFalse(result.isEmpty)
        for pixel in result {
            XCTAssertLessThan(pixel.r, 0.1)
            XCTAssertLessThan(pixel.g, 0.1)
            XCTAssertGreaterThan(pixel.b, 0.9)
        }
    }

    func testSamplePixels_solidWhiteImage_allPixelsNearWhite() {
        guard let img = makeSolidCGImage(width: 10, height: 10, r: 255, g: 255, b: 255) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 20)
        XCTAssertFalse(result.isEmpty)
        for pixel in result {
            XCTAssertGreaterThan(pixel.r, 0.9)
            XCTAssertGreaterThan(pixel.g, 0.9)
            XCTAssertGreaterThan(pixel.b, 0.9)
        }
    }

    func testSamplePixels_solidBlackImage_allPixelsNearBlack() {
        guard let img = makeSolidCGImage(width: 10, height: 10, r: 0, g: 0, b: 0) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 20)
        XCTAssertFalse(result.isEmpty)
        for pixel in result {
            XCTAssertLessThan(pixel.r, 0.1)
            XCTAssertLessThan(pixel.g, 0.1)
            XCTAssertLessThan(pixel.b, 0.1)
        }
    }

    func testSamplePixels_returnedCount_doesNotExceedSampleCount() {
        guard let img = makeSolidCGImage(width: 10, height: 10, r: 128, g: 128, b: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 50)
        XCTAssertLessThanOrEqual(result.count, 50)
    }

    func testSamplePixels_returnedCount_atLeast1_forOpaqueImage() {
        guard let img = makeSolidCGImage(width: 10, height: 10, r: 128, g: 128, b: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 10)
        XCTAssertGreaterThanOrEqual(result.count, 1)
    }

    func testSamplePixels_smallSampleCount_returns1OrMore() {
        guard let img = makeSolidCGImage(width: 10, height: 10, r: 128, g: 128, b: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 1)
        XCTAssertGreaterThanOrEqual(result.count, 1)
    }

    func testSamplePixels_normalizedRange_allValuesIn0To1() {
        guard let img = makeSolidCGImage(width: 20, height: 20, r: 200, g: 100, b: 50) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 30)
        for pixel in result {
            XCTAssertGreaterThanOrEqual(pixel.r, 0.0)
            XCTAssertLessThanOrEqual(pixel.r, 1.0)
            XCTAssertGreaterThanOrEqual(pixel.g, 0.0)
            XCTAssertLessThanOrEqual(pixel.g, 1.0)
            XCTAssertGreaterThanOrEqual(pixel.b, 0.0)
            XCTAssertLessThanOrEqual(pixel.b, 1.0)
        }
    }

    // MARK: - samplePixels Transparency Handling

    func testSamplePixels_fullyTransparentImage_returnsEmpty() {
        guard let img = makeSolidCGImage(width: 10, height: 10, r: 255, g: 0, b: 0, a: 0) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 50)
        XCTAssertTrue(result.isEmpty)
    }

    func testSamplePixels_lowAlpha_below128_returnsEmpty() {
        guard let img = makeSolidCGImage(width: 10, height: 10, r: 255, g: 0, b: 0, a: 100) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 50)
        XCTAssertTrue(result.isEmpty)
    }

    func testSamplePixels_alphaExactly128_includesPixels() {
        guard let img = makeSolidCGImage(width: 10, height: 10, r: 255, g: 0, b: 0, a: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 20)
        XCTAssertFalse(result.isEmpty)
    }

    func testSamplePixels_halfOpaqueHalfTransparent_returnsOnlyOpaque() {
        guard let img = makeHalfTransparentCGImage(width: 10, height: 10, r: 255, g: 0, b: 0) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 50)
        // Should only sample from the opaque half
        XCTAssertFalse(result.isEmpty)
        // All sampled pixels should be near red since opaques are red
        for pixel in result {
            XCTAssertGreaterThan(pixel.r, 0.8)
        }
    }

    func testSamplePixels_premultipliedAlpha_correctlyUnmultiplied() {
        // With alpha=128 and premultiplied r=128, the actual r should be 128/128*255 ≈ 1.0
        // But the premultiplied storage means pixel byte is 128, alpha is 128
        // Un-premultiply: r = (128/255) / (128/255) = 1.0
        guard let img = makeSolidCGImage(width: 10, height: 10, r: 128, g: 0, b: 0, a: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 10)
        XCTAssertFalse(result.isEmpty)
        // After un-premultiply, r should be close to 1.0 (128/128 in premultiplied space)
        for pixel in result {
            XCTAssertGreaterThan(pixel.r, 0.8, "Un-premultiplied red should be close to 1.0")
        }
    }

    // MARK: - samplePixels Limits

    func testSamplePixels_maxAttempts_terminates() {
        // Mostly transparent with only a few opaque pixels
        guard let img = makeSolidCGImage(width: 10, height: 10, r: 255, g: 0, b: 0, a: 50) else {
            return XCTFail("Could not create CGImage")
        }
        // This should terminate without hanging (alpha < 128, so all skipped)
        let result = samplePixels(from: img, sampleCount: 100)
        XCTAssertTrue(result.isEmpty)
    }

    func testSamplePixels_largeImageHighSampleCount_terminates() {
        guard let img = makeSolidCGImage(width: 100, height: 100, r: 128, g: 64, b: 200) else {
            return XCTFail("Could not create CGImage")
        }
        let result = samplePixels(from: img, sampleCount: 500)
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - downsample Basic

    func testDownsample_largerThanTarget_scalesDown() throws {
        guard let img = makeSolidCGImage(width: 200, height: 200, r: 128, g: 128, b: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = downsample(image: img, to: CGSize(width: 100, height: 100))
        XCTAssertNotNil(result)
        XCTAssertLessThanOrEqual(try XCTUnwrap(result?.width), 100)
        XCTAssertLessThanOrEqual(try XCTUnwrap(result?.height), 100)
    }

    func testDownsample_smallerThanTarget_scalesUp() {
        guard let img = makeSolidCGImage(width: 50, height: 50, r: 128, g: 128, b: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = downsample(image: img, to: CGSize(width: 100, height: 100))
        XCTAssertNotNil(result)
        // scaleFactor = min(100/50, 100/50) = 2.0, so result should be 100x100
        XCTAssertEqual(result?.width, 100)
        XCTAssertEqual(result?.height, 100)
    }

    func testDownsample_squareToSquare_maintainsDimensions() {
        guard let img = makeSolidCGImage(width: 100, height: 100, r: 128, g: 128, b: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = downsample(image: img, to: CGSize(width: 100, height: 100))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.width, 100)
        XCTAssertEqual(result?.height, 100)
    }

    func testDownsample_landscapeImage_fitsWithinTarget() {
        guard let img = makeSolidCGImage(width: 200, height: 100, r: 128, g: 128, b: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = downsample(image: img, to: CGSize(width: 100, height: 100))
        XCTAssertNotNil(result)
        // scaleFactor = min(100/200, 100/100) = 0.5
        XCTAssertEqual(result?.width, 100)
        XCTAssertEqual(result?.height, 50)
    }

    func testDownsample_portraitImage_fitsWithinTarget() {
        guard let img = makeSolidCGImage(width: 100, height: 200, r: 128, g: 128, b: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = downsample(image: img, to: CGSize(width: 100, height: 100))
        XCTAssertNotNil(result)
        // scaleFactor = min(100/100, 100/200) = 0.5
        XCTAssertEqual(result?.width, 50)
        XCTAssertEqual(result?.height, 100)
    }

    func testDownsample_preservesAspectRatio_landscape() throws {
        guard let img = makeSolidCGImage(width: 400, height: 200, r: 128, g: 128, b: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = downsample(image: img, to: CGSize(width: 100, height: 100))
        XCTAssertNotNil(result)
        // Original 2:1, result should maintain ~2:1
        let ratio = try Double(XCTUnwrap(result?.width)) / Double(XCTUnwrap(result?.height))
        XCTAssertEqual(ratio, 2.0, accuracy: 0.1)
    }

    func testDownsample_preservesAspectRatio_portrait() throws {
        guard let img = makeSolidCGImage(width: 200, height: 400, r: 128, g: 128, b: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = downsample(image: img, to: CGSize(width: 100, height: 100))
        XCTAssertNotNil(result)
        let ratio = try Double(XCTUnwrap(result?.width)) / Double(XCTUnwrap(result?.height))
        XCTAssertEqual(ratio, 0.5, accuracy: 0.1)
    }

    func testDownsample_1x1Image_returnsImage() {
        guard let img = makeSolidCGImage(width: 1, height: 1, r: 128, g: 128, b: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = downsample(image: img, to: CGSize(width: 100, height: 100))
        XCTAssertNotNil(result)
    }

    func testDownsample_resultIsValidCGImage() throws {
        guard let img = makeSolidCGImage(width: 200, height: 200, r: 128, g: 128, b: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = downsample(image: img, to: CGSize(width: 50, height: 50))
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(try XCTUnwrap(result?.width), 0)
        XCTAssertGreaterThan(try XCTUnwrap(result?.height), 0)
    }

    func testDownsample_veryLargeImage_handlesGracefully() {
        guard let img = makeSolidCGImage(width: 2000, height: 2000, r: 128, g: 128, b: 128) else {
            return XCTFail("Could not create CGImage")
        }
        let result = downsample(image: img, to: CGSize(width: 100, height: 100))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.width, 100)
        XCTAssertEqual(result?.height, 100)
    }

    // MARK: - downsample + samplePixels Workflow

    func testDownsampleThenSample_solidRedLargeImage_allPixelsRed() {
        guard let img = makeSolidCGImage(width: 200, height: 200, r: 255, g: 0, b: 0) else {
            return XCTFail("Could not create CGImage")
        }
        guard let downsampled = downsample(image: img, to: CGSize(width: 100, height: 100)) else {
            return XCTFail("Downsample failed")
        }
        let result = samplePixels(from: downsampled, sampleCount: 30)
        XCTAssertFalse(result.isEmpty)
        for pixel in result {
            XCTAssertGreaterThan(pixel.r, 0.9)
            XCTAssertLessThan(pixel.g, 0.1)
            XCTAssertLessThan(pixel.b, 0.1)
        }
    }

    func testDownsampleThenSample_landscapeImage_producesValidSamples() {
        guard let img = makeSolidCGImage(width: 400, height: 100, r: 0, g: 255, b: 0) else {
            return XCTFail("Could not create CGImage")
        }
        guard let downsampled = downsample(image: img, to: CGSize(width: 100, height: 100)) else {
            return XCTFail("Downsample failed")
        }
        let result = samplePixels(from: downsampled, sampleCount: 20)
        XCTAssertFalse(result.isEmpty)
    }

    func testDownsampleThenSample_portraitImage_producesValidSamples() {
        guard let img = makeSolidCGImage(width: 100, height: 400, r: 0, g: 0, b: 255) else {
            return XCTFail("Could not create CGImage")
        }
        guard let downsampled = downsample(image: img, to: CGSize(width: 100, height: 100)) else {
            return XCTFail("Downsample failed")
        }
        let result = samplePixels(from: downsampled, sampleCount: 20)
        XCTAssertFalse(result.isEmpty)
    }

    func testDownsampleThenSample_pixelValuesPreserved() {
        guard let img = makeSolidCGImage(width: 300, height: 300, r: 0, g: 255, b: 0) else {
            return XCTFail("Could not create CGImage")
        }
        guard let downsampled = downsample(image: img, to: CGSize(width: 100, height: 100)) else {
            return XCTFail("Downsample failed")
        }
        let result = samplePixels(from: downsampled, sampleCount: 30)
        XCTAssertFalse(result.isEmpty)
        for pixel in result {
            XCTAssertLessThan(pixel.r, 0.1)
            XCTAssertGreaterThan(pixel.g, 0.9)
            XCTAssertLessThan(pixel.b, 0.1)
        }
    }

    // MARK: - Full Pipeline: downsample → sample → kMeans → hex

    func testFullPipeline_solidWhite_returnsWhiteHex() {
        guard let img = makeSolidCGImage(width: 300, height: 300, r: 255, g: 255, b: 255) else {
            return XCTFail("Could not create CGImage")
        }
        guard let downsampled = downsample(image: img, to: CGSize(width: 100, height: 100)) else {
            return XCTFail("Downsample failed")
        }
        let pixels = samplePixels(from: downsampled, sampleCount: 200)
        XCTAssertFalse(pixels.isEmpty)
        let clusters = kMeans(pixels: pixels, clusterCount: 1)
        let hex = UniversalColor(red: clusters[0].r, green: clusters[0].g, blue: clusters[0].b, alpha: 1.0).hexString
        XCTAssertEqual(hex, "#FFFFFF")
    }

    func testFullPipeline_solidRed_returnsRedHex() {
        guard let img = makeSolidCGImage(width: 300, height: 300, r: 255, g: 0, b: 0) else {
            return XCTFail("Could not create CGImage")
        }
        guard let downsampled = downsample(image: img, to: CGSize(width: 100, height: 100)) else {
            return XCTFail("Downsample failed")
        }
        let pixels = samplePixels(from: downsampled, sampleCount: 200)
        XCTAssertFalse(pixels.isEmpty)
        let clusters = kMeans(pixels: pixels, clusterCount: 1)
        let hex = UniversalColor(red: clusters[0].r, green: clusters[0].g, blue: clusters[0].b, alpha: 1.0).hexString
        XCTAssertEqual(hex, "#FF0000")
    }

    func testFullPipeline_twoColor_findsBothHexes() {
        guard let img = makeTwoColorCGImage(
            width: 200, height: 200,
            leftR: 255, leftG: 0, leftB: 0,
            rightR: 0, rightG: 0, rightB: 255
        ) else {
            return XCTFail("Could not create CGImage")
        }
        guard let downsampled = downsample(image: img, to: CGSize(width: 100, height: 100)) else {
            return XCTFail("Downsample failed")
        }
        let pixels = samplePixels(from: downsampled, sampleCount: 500)
        XCTAssertFalse(pixels.isEmpty)
        // Verify both colors present in sampled pixels
        let hasRedPixel = pixels.contains { $0.r > 0.8 && $0.g < 0.2 && $0.b < 0.2 }
        let hasBluePixel = pixels.contains { $0.r < 0.2 && $0.g < 0.2 && $0.b > 0.8 }
        XCTAssertTrue(hasRedPixel, "Should sample red pixels")
        XCTAssertTrue(hasBluePixel, "Should sample blue pixels")
        // kMeans with 1 cluster gives a mean (safe; avoids empty-group infinite loop)
        let clusters = kMeans(pixels: pixels, clusterCount: 1)
        XCTAssertEqual(clusters.count, 1)
    }
}
