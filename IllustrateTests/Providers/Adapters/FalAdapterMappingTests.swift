// MARK: - FalAdapterMappingTests.swift

// Workflow tests for Fal adapter dimension/aspect ratio mapping functions.
//
// Tests cover:
// - FalFluxBase.getImageSize(): 7 specific dimension→preset mappings + default fallback
// - FalLumaBase.normalizeAspectRatio(): passthrough, WxH→nearest candidate, invalid input
// - FalLumaBase.clampDouble(): nil safety, boundary clamping, within-range passthrough
// - FalKlingBase.getAspectRatio(): string-based pattern matching for video dimensions
//
// Note: Base classes have abstract properties (modelCode, etc.) that fatalError.
// Test subclasses provide safe overrides to avoid crashes during testing.

import XCTest
@testable import IllustrateProviders

// MARK: - Test Subclasses

/// Minimal FalFluxBase subclass for testing internal methods without triggering fatalError
private class TestFalFlux: FalFluxBase {
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_PRO
    }

    override var costPerMegapixel: Double {
        0.05
    }
}

/// Minimal FalLumaBase subclass for testing internal methods
private class TestFalLuma: FalLumaBase {
    override var modelCode: EnumProviderModelCode {
        .FAL_LUMA_PHOTON
    }
}

/// Minimal FalKlingBase subclass for testing internal methods
private class TestFalKling: FalKlingBase {
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V21_MASTER_T2V
    }

    override var costPerSecond: Double {
        0.28
    }
}

final class FalAdapterMappingTests: XCTestCase {
    private var flux: TestFalFlux!
    private var luma: TestFalLuma!
    private var kling: TestFalKling!

    override func setUp() {
        super.setUp()
        flux = TestFalFlux()
        luma = TestFalLuma()
        kling = TestFalKling()
    }

    override func tearDown() {
        flux = nil
        luma = nil
        kling = nil
        super.tearDown()
    }

    // MARK: - FalFluxBase.getImageSize() Tests

    func testFlux_GetImageSize_1024x1024_SquareHD() {
        XCTAssertEqual(flux.getImageSize("1024x1024"), "square_hd")
    }

    func testFlux_GetImageSize_1920x1080_Landscape16_9() {
        XCTAssertEqual(flux.getImageSize("1920x1080"), "landscape_16_9")
    }

    func testFlux_GetImageSize_1440x1080_Landscape4_3() {
        XCTAssertEqual(flux.getImageSize("1440x1080"), "landscape_4_3")
    }

    func testFlux_GetImageSize_1080x1920_Portrait16_9() {
        XCTAssertEqual(flux.getImageSize("1080x1920"), "portrait_16_9")
    }

    func testFlux_GetImageSize_1080x1440_Portrait4_3() {
        XCTAssertEqual(flux.getImageSize("1080x1440"), "portrait_4_3")
    }

    func testFlux_GetImageSize_1344x768_Landscape16_9() {
        XCTAssertEqual(flux.getImageSize("1344x768"), "landscape_16_9")
    }

    func testFlux_GetImageSize_768x1344_Portrait16_9() {
        XCTAssertEqual(flux.getImageSize("768x1344"), "portrait_16_9")
    }

    func testFlux_GetImageSize_Unknown_DefaultsToLandscape4_3() {
        XCTAssertEqual(flux.getImageSize("2048x2048"), "landscape_4_3")
    }

    func testFlux_GetImageSize_SmallUnknown_DefaultsToLandscape4_3() {
        XCTAssertEqual(flux.getImageSize("500x500"), "landscape_4_3")
    }

    func testFlux_GetImageSize_EmptyString_DefaultsToLandscape4_3() {
        XCTAssertEqual(flux.getImageSize(""), "landscape_4_3")
    }

    func testFlux_GetImageSize_AllMappings_ProduceFalPresets() {
        let knownInputs = [
            "1024x1024", "1920x1080", "1440x1080",
            "1080x1920", "1080x1440", "1344x768", "768x1344",
        ]
        let validPresets = Set([
            "square_hd", "landscape_16_9", "landscape_4_3",
            "portrait_16_9", "portrait_4_3",
        ])
        for input in knownInputs {
            let preset = flux.getImageSize(input)
            XCTAssertTrue(
                validPresets.contains(preset),
                "\(input) → \(preset) is not a known Fal preset"
            )
        }
    }

    // MARK: - FalLumaBase.normalizeAspectRatio() Tests

    func testLuma_NormalizeAR_Passthrough_16_9() {
        XCTAssertEqual(luma.normalizeAspectRatio(from: "16:9"), "16:9")
    }

    func testLuma_NormalizeAR_Passthrough_9_16() {
        XCTAssertEqual(luma.normalizeAspectRatio(from: "9:16"), "9:16")
    }

    func testLuma_NormalizeAR_Passthrough_1_1() {
        XCTAssertEqual(luma.normalizeAspectRatio(from: "1:1"), "1:1")
    }

    func testLuma_NormalizeAR_Passthrough_21_9() {
        XCTAssertEqual(luma.normalizeAspectRatio(from: "21:9"), "21:9")
    }

    func testLuma_NormalizeAR_1920x1080_Maps16_9() {
        XCTAssertEqual(luma.normalizeAspectRatio(from: "1920x1080"), "16:9")
    }

    func testLuma_NormalizeAR_1080x1920_Maps9_16() {
        XCTAssertEqual(luma.normalizeAspectRatio(from: "1080x1920"), "9:16")
    }

    func testLuma_NormalizeAR_1024x1024_Maps1_1() {
        XCTAssertEqual(luma.normalizeAspectRatio(from: "1024x1024"), "1:1")
    }

    func testLuma_NormalizeAR_1280x720_Maps16_9() {
        // 1280/720 = 1.778 ≈ 16:9 = 1.778
        XCTAssertEqual(luma.normalizeAspectRatio(from: "1280x720"), "16:9")
    }

    func testLuma_NormalizeAR_640x480_Maps4_3() {
        // 640/480 = 1.333 ≈ 4:3 = 1.333
        XCTAssertEqual(luma.normalizeAspectRatio(from: "640x480"), "4:3")
    }

    func testLuma_NormalizeAR_480x640_Maps3_4() {
        // 480/640 = 0.75 ≈ 3:4 = 0.75
        XCTAssertEqual(luma.normalizeAspectRatio(from: "480x640"), "3:4")
    }

    func testLuma_NormalizeAR_1200x1200_Maps1_1() {
        XCTAssertEqual(luma.normalizeAspectRatio(from: "1200x1200"), "1:1")
    }

    func testLuma_NormalizeAR_3840x2160_Maps16_9() {
        XCTAssertEqual(luma.normalizeAspectRatio(from: "3840x2160"), "16:9")
    }

    func testLuma_NormalizeAR_InvalidInput_FallsBackTo1_1() {
        XCTAssertEqual(luma.normalizeAspectRatio(from: "invalid"), "1:1")
    }

    func testLuma_NormalizeAR_AllCandidatesReachable() {
        // Verify that each of the 7 candidates can be reached
        let testCases: [(input: String, expected: String)] = [
            ("1024x1024", "1:1"),
            ("1920x1080", "16:9"),
            ("1080x1920", "9:16"),
            ("640x480", "4:3"),
            ("480x640", "3:4"),
            ("2520x1080", "21:9"), // 2520/1080 = 2.333 ≈ 21:9 = 2.333
            ("1080x2520", "9:21"), // 1080/2520 = 0.429 ≈ 9:21 = 0.429
        ]
        for (input, expected) in testCases {
            XCTAssertEqual(
                luma.normalizeAspectRatio(from: input),
                expected,
                "Expected \(input) → \(expected)"
            )
        }
    }

    // MARK: - FalLumaBase.clampDouble() Tests

    func testLuma_ClampDouble_Nil_ReturnsDefault() {
        XCTAssertEqual(luma.clampDouble(nil, min: 0, max: 1, defaultValue: 0.5), 0.5)
    }

    func testLuma_ClampDouble_WithinRange_ReturnsSameValue() {
        XCTAssertEqual(luma.clampDouble(0.7, min: 0, max: 1, defaultValue: 0.5), 0.7)
    }

    func testLuma_ClampDouble_BelowMin_ReturnsMin() {
        XCTAssertEqual(luma.clampDouble(-0.5, min: 0, max: 1, defaultValue: 0.5), 0)
    }

    func testLuma_ClampDouble_AboveMax_ReturnsMax() {
        XCTAssertEqual(luma.clampDouble(1.5, min: 0, max: 1, defaultValue: 0.5), 1)
    }

    func testLuma_ClampDouble_ExactlyAtMin_ReturnsMin() {
        XCTAssertEqual(luma.clampDouble(0.0, min: 0, max: 1, defaultValue: 0.5), 0)
    }

    func testLuma_ClampDouble_ExactlyAtMax_ReturnsMax() {
        XCTAssertEqual(luma.clampDouble(1.0, min: 0, max: 1, defaultValue: 0.5), 1)
    }

    // MARK: - FalKlingBase.getAspectRatio() Tests

    private func makeVideoRequest(dimensions: String) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: "test",
            dimensions: dimensions,
            providerKey: ProviderKeyInfo(
                providerId: UUID(),
                providerCode: .FAL_AI,
                projectId: UUID()
            ),
            providerSecret: "test"
        )
    }

    func testKling_GetAR_Contains16_9() {
        let result = kling.getAspectRatio(from: makeVideoRequest(dimensions: "16:9"))
        XCTAssertEqual(result, "16:9")
    }

    func testKling_GetAR_ContainsLandscape() {
        let result = kling.getAspectRatio(from: makeVideoRequest(dimensions: "landscape"))
        XCTAssertEqual(result, "16:9")
    }

    func testKling_GetAR_Contains9_16() {
        let result = kling.getAspectRatio(from: makeVideoRequest(dimensions: "9:16"))
        XCTAssertEqual(result, "9:16")
    }

    func testKling_GetAR_ContainsPortrait() {
        let result = kling.getAspectRatio(from: makeVideoRequest(dimensions: "portrait"))
        XCTAssertEqual(result, "9:16")
    }

    func testKling_GetAR_Contains1_1() {
        let result = kling.getAspectRatio(from: makeVideoRequest(dimensions: "1:1"))
        XCTAssertEqual(result, "1:1")
    }

    func testKling_GetAR_ContainsSquare() {
        let result = kling.getAspectRatio(from: makeVideoRequest(dimensions: "square"))
        XCTAssertEqual(result, "1:1")
    }

    func testKling_GetAR_Empty_ReturnsNil() {
        let result = kling.getAspectRatio(from: makeVideoRequest(dimensions: ""))
        XCTAssertNil(result)
    }

    func testKling_GetAR_UnrecognizedPattern_ReturnsDimensions() {
        let result = kling.getAspectRatio(from: makeVideoRequest(dimensions: "1920x1080"))
        XCTAssertEqual(result, "1920x1080")
    }
}
