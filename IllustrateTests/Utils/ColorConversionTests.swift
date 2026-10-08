// MARK: - ColorConversionTests.swift

import SwiftUI
import XCTest
@testable import Illustrate

final class ColorConversionTests: XCTestCase {
    // MARK: - colorFromHex Tests

    func testValidHexWithoutHash() {
        let color = colorFromHex("FF0000")
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert to sRGB color space")
            return
        }

        XCTAssertEqual(Int(rgbColor.redComponent * 255), 255, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.greenComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.blueComponent * 255), 0, accuracy: 1)
    }

    func testValidHexWithHash() {
        let color = colorFromHex("#00FF00")
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert to sRGB color space")
            return
        }

        XCTAssertEqual(Int(rgbColor.redComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.greenComponent * 255), 255, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.blueComponent * 255), 0, accuracy: 1)
    }

    func testBlueColor() {
        let color = colorFromHex("0000FF")
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert to sRGB color space")
            return
        }

        XCTAssertEqual(Int(rgbColor.redComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.greenComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.blueComponent * 255), 255, accuracy: 1)
    }

    func testWhiteColor() {
        let color = colorFromHex("FFFFFF")
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert to sRGB color space")
            return
        }

        XCTAssertEqual(Int(rgbColor.redComponent * 255), 255, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.greenComponent * 255), 255, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.blueComponent * 255), 255, accuracy: 1)
    }

    func testBlackColor() {
        let color = colorFromHex("000000")
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert to sRGB color space")
            return
        }

        XCTAssertEqual(Int(rgbColor.redComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.greenComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.blueComponent * 255), 0, accuracy: 1)
    }

    func testCustomColor() {
        // Test a custom color: #3478F6 (light blue)
        let color = colorFromHex("3478F6")
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert to sRGB color space")
            return
        }

        XCTAssertEqual(Int(rgbColor.redComponent * 255), 52, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.greenComponent * 255), 120, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.blueComponent * 255), 246, accuracy: 1)
    }

    func testLowercaseHex() {
        let color = colorFromHex("ff00ff")
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert to sRGB color space")
            return
        }

        XCTAssertEqual(Int(rgbColor.redComponent * 255), 255, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.greenComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.blueComponent * 255), 255, accuracy: 1)
    }

    func testMixedCaseHex() {
        let color = colorFromHex("FfAa00")
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert to sRGB color space")
            return
        }

        XCTAssertEqual(Int(rgbColor.redComponent * 255), 255, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.greenComponent * 255), 170, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.blueComponent * 255), 0, accuracy: 1)
    }

    func testHexWithWhitespace() {
        let color = colorFromHex("  FF0000  ")
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert to sRGB color space")
            return
        }

        XCTAssertEqual(Int(rgbColor.redComponent * 255), 255, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.greenComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.blueComponent * 255), 0, accuracy: 1)
    }

    func testInvalidHexTooShort() {
        // Invalid hex should return black
        let color = colorFromHex("FF00")
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert to sRGB color space")
            return
        }

        XCTAssertEqual(Int(rgbColor.redComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.greenComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.blueComponent * 255), 0, accuracy: 1)
    }

    func testInvalidHexTooLong() {
        // Invalid hex should return black
        let color = colorFromHex("FF00FF00")
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert to sRGB color space")
            return
        }

        XCTAssertEqual(Int(rgbColor.redComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.greenComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.blueComponent * 255), 0, accuracy: 1)
    }

    func testInvalidHexNonHexCharacters() {
        // Invalid hex should return black
        let color = colorFromHex("GGGGGG")
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert to sRGB color space")
            return
        }

        XCTAssertEqual(Int(rgbColor.redComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.greenComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.blueComponent * 255), 0, accuracy: 1)
    }

    func testEmptyHexString() {
        // Empty string should return black
        let color = colorFromHex("")
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert to sRGB color space")
            return
        }

        XCTAssertEqual(Int(rgbColor.redComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.greenComponent * 255), 0, accuracy: 1)
        XCTAssertEqual(Int(rgbColor.blueComponent * 255), 0, accuracy: 1)
    }

    // MARK: - hexFromColor Tests

    func testHexFromRedColor() {
        // Use explicit RGB values to ensure sRGB color space
        let color = Color(red: 1.0, green: 0.0, blue: 0.0)
        let hex = hexFromColor(color)
        // Red in sRGB should be FF0000
        XCTAssertEqual(hex, "FF0000")
    }

    func testHexFromGreenColor() {
        // Use explicit RGB values to ensure sRGB color space
        let color = Color(red: 0.0, green: 1.0, blue: 0.0)
        let hex = hexFromColor(color)
        // Green in sRGB should be 00FF00
        XCTAssertEqual(hex, "00FF00")
    }

    func testHexFromBlueColor() {
        // Use explicit RGB values to ensure sRGB color space
        let color = Color(red: 0.0, green: 0.0, blue: 1.0)
        let hex = hexFromColor(color)
        // Blue in sRGB should be 0000FF
        XCTAssertEqual(hex, "0000FF")
    }

    func testHexFromWhiteColor() {
        let color = Color.white
        let hex = hexFromColor(color)
        XCTAssertEqual(hex, "FFFFFF")
    }

    func testHexFromBlackColor() {
        let color = Color.black
        let hex = hexFromColor(color)
        XCTAssertEqual(hex, "000000")
    }

    func testHexFromCustomColor() {
        // Create a custom color from known RGB values
        let color = Color(red: 0.5, green: 0.75, blue: 1.0)
        let hex = hexFromColor(color)

        // Convert back to verify
        let convertedColor = colorFromHex(hex)
        let nsColor = NSColor(convertedColor)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert to sRGB color space")
            return
        }

        // Allow small tolerance for rounding
        XCTAssertEqual(rgbColor.redComponent, 0.5, accuracy: 0.01)
        XCTAssertEqual(rgbColor.greenComponent, 0.75, accuracy: 0.01)
        XCTAssertEqual(rgbColor.blueComponent, 1.0, accuracy: 0.01)
    }

    // MARK: - Round-Trip Conversion Tests

    func testRoundTripConversionRed() {
        let originalHex = "FF0000"
        let color = colorFromHex(originalHex)
        let convertedHex = hexFromColor(color)
        XCTAssertEqual(convertedHex, originalHex)
    }

    func testRoundTripConversionGreen() {
        let originalHex = "00FF00"
        let color = colorFromHex(originalHex)
        let convertedHex = hexFromColor(color)
        XCTAssertEqual(convertedHex, originalHex)
    }

    func testRoundTripConversionBlue() {
        let originalHex = "0000FF"
        let color = colorFromHex(originalHex)
        let convertedHex = hexFromColor(color)
        XCTAssertEqual(convertedHex, originalHex)
    }

    func testRoundTripConversionCustom() {
        let originalHex = "3478F6"
        let color = colorFromHex(originalHex)
        let convertedHex = hexFromColor(color)
        XCTAssertEqual(convertedHex, originalHex)
    }

    func testRoundTripConversionGrayscale() {
        let originalHex = "808080"
        let color = colorFromHex(originalHex)
        let convertedHex = hexFromColor(color)
        XCTAssertEqual(convertedHex, originalHex)
    }

    // MARK: - filterHexInput Tests

    func testFilterHexInputValidCharacters() {
        let filtered = filterHexInput("ABCDEF")
        XCTAssertEqual(filtered, "ABCDEF")
    }

    func testFilterHexInputLowercase() {
        let filtered = filterHexInput("abcdef")
        XCTAssertEqual(filtered, "ABCDEF")
    }

    func testFilterHexInputMixedCase() {
        let filtered = filterHexInput("aBcDeF")
        XCTAssertEqual(filtered, "ABCDEF")
    }

    func testFilterHexInputNumbers() {
        let filtered = filterHexInput("123456")
        XCTAssertEqual(filtered, "123456")
    }

    func testFilterHexInputMixedValid() {
        let filtered = filterHexInput("A1B2C3")
        XCTAssertEqual(filtered, "A1B2C3")
    }

    func testFilterHexInputInvalidCharacters() {
        let filtered = filterHexInput("GHIJKL")
        XCTAssertEqual(filtered, "")
    }

    func testFilterHexInputMixedValidInvalid() {
        let filtered = filterHexInput("AB12XY")
        XCTAssertEqual(filtered, "AB12")
    }

    func testFilterHexInputSpecialCharacters() {
        let filtered = filterHexInput("FF-00-00")
        XCTAssertEqual(filtered, "FF0000")
    }

    func testFilterHexInputMaxLength() {
        let filtered = filterHexInput("ABCDEF1234")
        XCTAssertEqual(filtered, "ABCDEF")
        XCTAssertEqual(filtered.count, 6)
    }

    func testFilterHexInputEmptyString() {
        let filtered = filterHexInput("")
        XCTAssertEqual(filtered, "")
    }

    func testFilterHexInputWhitespace() {
        let filtered = filterHexInput("  FF 00 00  ")
        XCTAssertEqual(filtered, "FF0000")
    }

    func testFilterHexInputWithHash() {
        let filtered = filterHexInput("#FF0000")
        XCTAssertEqual(filtered, "FF0000")
    }
}
