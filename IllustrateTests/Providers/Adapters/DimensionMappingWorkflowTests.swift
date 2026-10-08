// MARK: - DimensionMappingWorkflowTests.swift

// Cross-adapter workflow tests verifying consistency across the dimension
// mapping pipeline: user dimension input → adapter-specific format → pricing.
//
// Tests cover:
// - End-to-end dimension flows through multiple adapters
// - AspectRatioHelpers ↔ Luma normalizer consistency on standard dimensions
// - Flux preset → megapixel parse → pricing calculation chain
// - Aspect ratio round-trips across helper functions
// - Edge case consistency across adapters

import XCTest
@testable import IllustrateProviders

/// Minimal subclasses for workflow testing
private class WorkflowFlux: FalFluxBase {
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_PRO
    }

    override var costPerMegapixel: Double {
        0.05
    }
}

private class WorkflowLuma: FalLumaBase {
    override var modelCode: EnumProviderModelCode {
        .FAL_LUMA_PHOTON
    }
}

final class DimensionMappingWorkflowTests: XCTestCase {
    private var flux: WorkflowFlux!
    private var luma: WorkflowLuma!

    override func setUp() {
        super.setUp()
        flux = WorkflowFlux()
        luma = WorkflowLuma()
    }

    override func tearDown() {
        flux = nil
        luma = nil
        super.tearDown()
    }

    // MARK: - End-to-End Dimension Workflows

    func testWorkflow_Square_FluxAndLuma_BothHandleSquare() {
        // Flux: "1024x1024" → "square_hd"
        let fluxResult = flux.getImageSize("1024x1024")
        XCTAssertEqual(fluxResult, "square_hd")

        // Luma: "1024x1024" → "1:1"
        let lumaResult = luma.normalizeAspectRatio(from: "1024x1024")
        XCTAssertEqual(lumaResult, "1:1")

        // Both handle square input correctly (different formats, same concept)
    }

    func testWorkflow_Landscape_AspectRatioAndLuma_Agree() {
        // AspectRatioHelpers: "1920x1080" → "16:9"
        let aspectResult = convertToAspectRatio("1920x1080")
        XCTAssertEqual(aspectResult, "16:9")

        // Luma normalizer: "1920x1080" → "16:9"
        let lumaResult = luma.normalizeAspectRatio(from: "1920x1080")
        XCTAssertEqual(lumaResult, "16:9")

        // Both agree on standard landscape
        XCTAssertEqual(aspectResult, lumaResult)
    }

    func testWorkflow_Portrait_AspectRatioAndLuma_Agree() {
        let aspectResult = convertToAspectRatio("1080x1920")
        let lumaResult = luma.normalizeAspectRatio(from: "1080x1920")
        XCTAssertEqual(aspectResult, "9:16")
        XCTAssertEqual(lumaResult, "9:16")
    }

    func testWorkflow_StandardDimensions_AspectRatioAndLuma_Consistent() {
        let standardDims = ["1920x1080", "1080x1920", "1024x1024"]
        for dim in standardDims {
            let aspect = convertToAspectRatio(dim)
            let lumaAR = luma.normalizeAspectRatio(from: dim)
            XCTAssertEqual(
                aspect, lumaAR,
                "AspectRatioHelper and Luma should agree on \(dim)"
            )
        }
    }

    // MARK: - Flux → Megapixel → Pricing Chain

    func testWorkflow_FluxPreset_SquareHD_ParsesMegapixels() {
        let preset = flux.getImageSize("1024x1024")
        let megapixels = falParseMegapixels(from: preset)
        XCTAssertEqual(megapixels, 1.05, "square_hd should parse to 1.05 MP")
    }

    func testWorkflow_FluxPreset_ToPricingCalculation() {
        // Full chain: dimension → Flux preset → parse megapixels → calculate cost
        let preset = flux.getImageSize("1024x1024")
        let cost = falCalculateCost(
            pricing: .perMegapixel(0.05),
            dimensions: preset,
            numberOfImages: 1
        )
        XCTAssertEqual(cost, 0.05 * 1.05, accuracy: 0.001)
    }

    func testWorkflow_AllFluxPresets_ParseToPositiveMegapixels() {
        let knownInputs = [
            "1024x1024", "1920x1080", "1440x1080",
            "1080x1920", "1080x1440", "1344x768", "768x1344",
        ]
        for input in knownInputs {
            let preset = flux.getImageSize(input)
            let mp = falParseMegapixels(from: preset)
            XCTAssertGreaterThan(mp, 0, "Preset from \(input) → \(preset) should have positive MP")
        }
    }

    func testWorkflow_FluxPresets_MegapixelsInReasonableRange() {
        let inputs = ["1024x1024", "1920x1080", "1080x1920", "1440x1080"]
        for input in inputs {
            let preset = flux.getImageSize(input)
            let mp = falParseMegapixels(from: preset)
            XCTAssertGreaterThan(mp, 0.1, "MP too low for \(input)")
            XCTAssertLessThan(mp, 5.0, "MP too high for \(input)")
        }
    }

    func testWorkflow_FluxSquare_CheaperThanLandscape_SameRate() {
        // "square" (0.26 MP) should be cheaper than "landscape_4_3" (1.05 MP)
        let squarePreset = "square"
        let landscapePreset = flux.getImageSize("1440x1080") // → "landscape_4_3"
        XCTAssertEqual(landscapePreset, "landscape_4_3")

        let squareCost = falCalculateCost(pricing: .perMegapixel(0.05), dimensions: squarePreset, numberOfImages: 1)
        let landscapeCost = falCalculateCost(
            pricing: .perMegapixel(0.05),
            dimensions: landscapePreset,
            numberOfImages: 1
        )

        XCTAssertGreaterThan(landscapeCost, squareCost)
    }

    // MARK: - Aspect Ratio Round-Trip Workflows

    func testWorkflow_RoundTrip_DimensionToRatioToResult() {
        // "1920x1080" → ratio "16:9" → getAspectRatio(dimension:) → actualWidth/Height → convert back
        let ratio = convertToAspectRatio("1920x1080")
        XCTAssertEqual(ratio, "16:9")

        let result = getAspectRatio(dimension: "1920x1080")
        let backToRatio = convertToAspectRatio("\(result.actualWidth)x\(result.actualHeight)")
        XCTAssertEqual(backToRatio, "16:9")
    }

    func testWorkflow_GetAspectRatioResult_MatchesLumaNormalize() {
        let result = getAspectRatio(dimension: "1920x1080")
        let lumaAR = luma.normalizeAspectRatio(from: "1920x1080")
        XCTAssertEqual(result.ratio, lumaAR)
    }

    func testWorkflow_MultipleResolutions_SameRatio_SameAdapterOutput() {
        // Different resolutions of same aspect ratio should map to same Luma output
        let sixteenByNine = ["1920x1080", "1280x720", "3840x2160"]
        let results = sixteenByNine.map { luma.normalizeAspectRatio(from: $0) }
        for result in results {
            XCTAssertEqual(result, "16:9")
        }
    }

    // MARK: - Adapter Edge Cases

    func testWorkflow_Flux_UnknownDimension_FallbackStillParseable() {
        // Unknown dimension → "landscape_4_3" fallback → should still parse megapixels
        let preset = flux.getImageSize("999x999")
        XCTAssertEqual(preset, "landscape_4_3")
        let mp = falParseMegapixels(from: preset)
        XCTAssertEqual(mp, 1.05)
    }

    func testWorkflow_Luma_AlreadyNormalized_Passthrough() {
        let ratios = ["1:1", "16:9", "9:16", "4:3", "3:4", "21:9", "9:21"]
        for ratio in ratios {
            XCTAssertEqual(
                luma.normalizeAspectRatio(from: ratio),
                ratio,
                "Already-normalized \(ratio) should pass through"
            )
        }
    }

    func testWorkflow_SameFluxPreset_SameMegapixelCost() {
        // Multiple inputs that map to the same Flux preset → same cost
        let input1 = flux.getImageSize("1920x1080")
        let input2 = flux.getImageSize("1344x768")
        // Both map to "landscape_16_9"
        XCTAssertEqual(input1, input2)

        let cost1 = falCalculateCost(pricing: .perMegapixel(0.05), dimensions: input1, numberOfImages: 1)
        let cost2 = falCalculateCost(pricing: .perMegapixel(0.05), dimensions: input2, numberOfImages: 1)
        XCTAssertEqual(cost1, cost2, accuracy: 0.0001)
    }

    func testWorkflow_ClampDouble_PipelineForGenerationParams() {
        // Simulates parameter normalization: user provides nil → default → clamped
        let guidance = luma.clampDouble(nil, min: 1.0, max: 20.0, defaultValue: 7.5)
        XCTAssertEqual(guidance, 7.5)

        // User provides out-of-range value → clamped to max
        let highGuidance = luma.clampDouble(25.0, min: 1.0, max: 20.0, defaultValue: 7.5)
        XCTAssertEqual(highGuidance, 20.0)
    }

    func testWorkflow_4_3_ConsistencyAcrossHelpers() {
        // 640x480 should be recognized as 4:3 by both AspectRatioHelpers and Luma
        let helperResult = convertToAspectRatio("640x480")
        let lumaResult = luma.normalizeAspectRatio(from: "640x480")
        XCTAssertEqual(helperResult, "4:3")
        XCTAssertEqual(lumaResult, "4:3")
    }

    func testWorkflow_AspectRatioResult_DimensionsWorkWithFlux() {
        // Get actual dimensions from AspectRatioResult, pass to Flux
        let result = getAspectRatio(dimension: "16:9")
        // Should get 1920x1080 equivalent
        XCTAssertEqual(result.actualWidth, 1920)
        XCTAssertEqual(result.actualHeight, 1080)

        // That exact dimension is mapped by Flux
        let preset = flux.getImageSize("\(result.actualWidth)x\(result.actualHeight)")
        XCTAssertEqual(preset, "landscape_16_9")
    }

    func testWorkflow_PricingComparison_SquareVsSquareHD() {
        // "square" (0.26 MP) vs "square_hd" (1.05 MP) at same rate
        let squareCost = falCalculateCost(
            pricing: .perMegapixel(0.05),
            dimensions: "square",
            numberOfImages: 1
        )
        let squareHDCost = falCalculateCost(
            pricing: .perMegapixel(0.05),
            dimensions: "square_hd",
            numberOfImages: 1
        )
        // square_hd should be ~4x more expensive than square
        XCTAssertGreaterThan(squareHDCost, squareCost)
        let ratio = squareHDCost / squareCost
        XCTAssertEqual(ratio, 1.05 / 0.26, accuracy: 0.01)
    }
}
