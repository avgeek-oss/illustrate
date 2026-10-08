// MARK: - OpenAICostTests.swift

// Cost estimation tests for OpenAI provider adapters.
//
// Tests cover:
// - Sora Base: per-second pricing with model-tier and dimension branching
// - GPT Image Base: (modelCode, quality, dimensions) cost matrix
// - DALL-E 3: quality × dimension cost matrix (verified via expected values)
// - formatCost(): USD formatting
// - Cross-model cost ordering and scaling workflows

import XCTest
@testable import IllustrateProviders

// MARK: - Sora Cost Tests

final class OpenAISoraCostTests: XCTestCase {
    // MARK: - Helpers

    private func makeSora(_ modelCode: EnumProviderModelCode) -> G_OPENAI_SORA_BASE {
        G_OPENAI_SORA_BASE(modelCode: modelCode, modelName: "sora-test")
    }

    private func costRequest(
        dimensions: String? = nil,
        durationSeconds: Int? = nil,
        numberOfVideos: Int? = nil
    ) -> VideoGenerationCostRequest {
        VideoGenerationCostRequest(
            dimensions: dimensions,
            durationSeconds: durationSeconds,
            numberOfVideos: numberOfVideos
        )
    }

    // MARK: - Sora 2 ($0.10/sec)

    func testSora2_4Sec_Returns040() {
        let adapter = makeSora(.OPENAI_SORA_2)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 4))
        XCTAssertEqual(cost, 0.40, accuracy: 0.001)
    }

    func testSora2_10Sec_Returns100() {
        let adapter = makeSora(.OPENAI_SORA_2)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 10))
        XCTAssertEqual(cost, 1.00, accuracy: 0.001)
    }

    func testSora2_4Sec_3Videos_Returns120() {
        let adapter = makeSora(.OPENAI_SORA_2)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 4, numberOfVideos: 3))
        XCTAssertEqual(cost, 1.20, accuracy: 0.001)
    }

    // MARK: - Sora 2 Pro (dimension-aware: $0.30 standard, $0.50 high-res)

    func testSoraPro_StandardDims_4Sec_Returns120() {
        let adapter = makeSora(.OPENAI_SORA_2_PRO)
        let cost = adapter.getCostEstimate(request: costRequest(dimensions: "1280x720", durationSeconds: 4))
        XCTAssertEqual(cost, 1.20, accuracy: 0.001)
    }

    func testSoraPro_HighRes1792x1024_4Sec_Returns200() {
        let adapter = makeSora(.OPENAI_SORA_2_PRO)
        let cost = adapter.getCostEstimate(request: costRequest(dimensions: "1792x1024", durationSeconds: 4))
        XCTAssertEqual(cost, 2.00, accuracy: 0.001)
    }

    func testSoraPro_HighRes1024x1792_4Sec_Returns200() {
        let adapter = makeSora(.OPENAI_SORA_2_PRO)
        let cost = adapter.getCostEstimate(request: costRequest(dimensions: "1024x1792", durationSeconds: 4))
        XCTAssertEqual(cost, 2.00, accuracy: 0.001)
    }

    func testSoraPro_1280x720_4Sec_Returns120() {
        let adapter = makeSora(.OPENAI_SORA_2_PRO)
        let cost = adapter.getCostEstimate(request: costRequest(dimensions: "1280x720", durationSeconds: 4))
        XCTAssertEqual(cost, 1.20, accuracy: 0.001)
    }

    // MARK: - Default Model Code

    func testDefaultModelCode_FallsBackTo010PerSec() {
        let adapter = makeSora(.OPENAI_DALLE3)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 10))
        XCTAssertEqual(cost, 1.00, accuracy: 0.001)
    }

    // MARK: - Edge Cases

    func testNilDimensions_DefaultsTo1280x720() {
        let adapter = makeSora(.OPENAI_SORA_2_PRO)
        // nil dimensions → "1280x720" default → standard rate $0.30
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 4))
        XCTAssertEqual(cost, 1.20, accuracy: 0.001)
    }

    func testNilNumberOfVideos_DefaultsToOne() {
        let adapter = makeSora(.OPENAI_SORA_2)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 4, numberOfVideos: nil))
        XCTAssertEqual(cost, 0.40, accuracy: 0.001)
    }

    func testZeroDuration_ReturnsZero() {
        let adapter = makeSora(.OPENAI_SORA_2)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 0))
        XCTAssertEqual(cost, 0.0, accuracy: 0.001)
    }

    // MARK: - formatCost Tests

    func testFormatCost_Sora2_4Sec() {
        let adapter = makeSora(.OPENAI_SORA_2)
        let formatted = adapter.formatCost(request: costRequest(durationSeconds: 4))
        XCTAssertEqual(formatted, "$0.4")
    }

    func testFormatCost_Zero_ReturnsFree() {
        let adapter = makeSora(.OPENAI_SORA_2)
        let formatted = adapter.formatCost(request: costRequest(durationSeconds: 0))
        XCTAssertEqual(formatted, "Free")
    }

    // MARK: - Workflows

    func testWorkflow_SoraProHighRes_MoreExpensive_ThanStandardRes() {
        let adapter = makeSora(.OPENAI_SORA_2_PRO)
        let standardCost = adapter.getCostEstimate(request: costRequest(dimensions: "1280x720", durationSeconds: 4))
        let highResCost = adapter.getCostEstimate(request: costRequest(dimensions: "1792x1024", durationSeconds: 4))
        XCTAssertGreaterThan(highResCost, standardCost)
    }

    func testWorkflow_DurationScaling_Linear() {
        let adapter = makeSora(.OPENAI_SORA_2)
        let cost4 = adapter.getCostEstimate(request: costRequest(durationSeconds: 4))
        let cost8 = adapter.getCostEstimate(request: costRequest(durationSeconds: 8))
        XCTAssertEqual(cost8, cost4 * 2, accuracy: 0.001)
    }

    func testWorkflow_Determinism() {
        let adapter = makeSora(.OPENAI_SORA_2_PRO)
        let req = costRequest(dimensions: "1792x1024", durationSeconds: 8, numberOfVideos: 2)
        XCTAssertEqual(
            adapter.getCostEstimate(request: req),
            adapter.getCostEstimate(request: req)
        )
    }
}

// MARK: - GPT Image Cost Tests

final class OpenAIGPTImageCostTests: XCTestCase {
    // MARK: - Helpers

    private func makeGPTImage(_ modelCode: EnumProviderModelCode) -> G_OPENAI_GPT_IMAGE_BASE {
        G_OPENAI_GPT_IMAGE_BASE(modelCode: modelCode, modelName: "gpt-image-test")
    }

    private func costRequest(
        quality: String? = nil,
        dimensions: String? = nil,
        numberOfImages: Int? = nil
    ) -> ImageGenerationCostRequest {
        ImageGenerationCostRequest(
            quality: quality,
            dimensions: dimensions,
            numberOfImages: numberOfImages
        )
    }

    // MARK: - GPT Image 1 Pricing (dimension-independent)

    func testGPTImage1_High_Returns017() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1)
        let cost = adapter.getCostEstimate(request: costRequest(quality: "high", numberOfImages: 1))
        XCTAssertEqual(cost, 0.17, accuracy: 0.0001)
    }

    func testGPTImage1_Medium_Returns007() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1)
        let cost = adapter.getCostEstimate(request: costRequest(quality: "medium", numberOfImages: 1))
        XCTAssertEqual(cost, 0.07, accuracy: 0.0001)
    }

    func testGPTImage1_Low_Returns004() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1)
        let cost = adapter.getCostEstimate(request: costRequest(quality: "low", numberOfImages: 1))
        XCTAssertEqual(cost, 0.04, accuracy: 0.0001)
    }

    func testGPTImage1_High_3Images_Returns051() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1)
        let cost = adapter.getCostEstimate(request: costRequest(quality: "high", numberOfImages: 3))
        XCTAssertEqual(cost, 0.51, accuracy: 0.0001)
    }

    // MARK: - GPT Image 1 Mini Pricing (dimension-aware)

    func testGPTImageMini_Low_1024x1024_Returns0005() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1_MINI)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "low",
            dimensions: "1024x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.005, accuracy: 0.0001)
    }

    func testGPTImageMini_Medium_1024x1024_Returns0011() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1_MINI)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "medium",
            dimensions: "1024x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.011, accuracy: 0.0001)
    }

    func testGPTImageMini_High_1024x1024_Returns0036() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1_MINI)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "high",
            dimensions: "1024x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.036, accuracy: 0.0001)
    }

    func testGPTImageMini_Low_1024x1536_Returns0006() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1_MINI)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "low",
            dimensions: "1024x1536",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.006, accuracy: 0.0001)
    }

    func testGPTImageMini_Medium_1536x1024_Returns0015() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1_MINI)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "medium",
            dimensions: "1536x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.015, accuracy: 0.0001)
    }

    func testGPTImageMini_High_1024x1536_Returns0052() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1_MINI)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "high",
            dimensions: "1024x1536",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.052, accuracy: 0.0001)
    }

    // MARK: - GPT Image 1.5 Pricing (dimension-aware)

    func testGPTImage15_Low_1024x1024_Returns0009() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1_5)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "low",
            dimensions: "1024x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.009, accuracy: 0.0001)
    }

    func testGPTImage15_Medium_1024x1024_Returns0034() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1_5)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "medium",
            dimensions: "1024x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.034, accuracy: 0.0001)
    }

    func testGPTImage15_High_1024x1024_Returns0133() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1_5)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "high",
            dimensions: "1024x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.133, accuracy: 0.0001)
    }

    func testGPTImage15_Low_1536x1024_Returns0013() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1_5)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "low",
            dimensions: "1536x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.013, accuracy: 0.0001)
    }

    func testGPTImage15_Medium_1024x1536_Returns005() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1_5)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "medium",
            dimensions: "1024x1536",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.05, accuracy: 0.0001)
    }

    func testGPTImage15_High_1536x1024_Returns020() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1_5)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "high",
            dimensions: "1536x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.2, accuracy: 0.0001)
    }

    // MARK: - GPT Image 2 Pricing (token-metered estimates)

    func testGPTImage2_Low_1024x1024_Returns0006() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_2)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "low",
            dimensions: "1024x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.006, accuracy: 0.0001)
    }

    func testGPTImage2_Medium_1024x1024_Returns0053() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_2)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "medium",
            dimensions: "1024x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.053, accuracy: 0.0001)
    }

    func testGPTImage2_High_1024x1024_Returns0211() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_2)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "high",
            dimensions: "1024x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.211, accuracy: 0.0001)
    }

    func testGPTImage2_Low_1536x1024_Returns0005() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_2)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "low",
            dimensions: "1536x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.005, accuracy: 0.0001)
    }

    func testGPTImage2_Medium_1024x1536_Returns0041() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_2)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "medium",
            dimensions: "1024x1536",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.041, accuracy: 0.0001)
    }

    func testGPTImage2_High_1536x1024_Returns0165() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_2)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "high",
            dimensions: "1536x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.165, accuracy: 0.0001)
    }

    func testGPTImage2_AutoQuality_UsesMediumEstimate() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_2)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "auto",
            dimensions: "1024x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(cost, 0.053, accuracy: 0.0001)
    }

    func testGPTImage2_FlexibleSize_ScalesFromDocumentedEstimate() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_2)
        let cost = adapter.getCostEstimate(request: costRequest(
            quality: "medium",
            dimensions: "1920x1080",
            numberOfImages: 1
        ))
        XCTAssertGreaterThan(cost, 0.041)
    }

    // MARK: - Default Fallback

    func testDefaultFallback_Returns004() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1)
        // Use a quality that doesn't match any case
        let cost = adapter.getCostEstimate(request: costRequest(quality: "unknown", numberOfImages: 1))
        XCTAssertEqual(cost, 0.04, accuracy: 0.0001)
    }

    func testNilQuality_FallsBackToDefault() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1)
        let cost = adapter.getCostEstimate(request: costRequest(numberOfImages: 1))
        XCTAssertEqual(cost, 0.04, accuracy: 0.0001)
    }

    // MARK: - formatCost Tests

    func testFormatCost_GPTImage1_High() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1)
        let formatted = adapter.formatCost(request: costRequest(quality: "high", numberOfImages: 1))
        XCTAssertEqual(formatted, "$0.17")
    }

    func testFormatCost_GPTImageMini_Low() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1_MINI)
        let formatted = adapter.formatCost(request: costRequest(
            quality: "low",
            dimensions: "1024x1024",
            numberOfImages: 1
        ))
        XCTAssertEqual(formatted, "$0.005")
    }

    func testFormatCost_GPTImage2_HighIncludesVariableCostSuffix() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_2)
        let formatted = adapter.formatCost(request: costRequest(
            quality: "high",
            dimensions: "1024x1536",
            numberOfImages: 1
        ))
        XCTAssertEqual(formatted, "$0.17+")
    }

    // MARK: - Workflows

    func testWorkflow_QualityScaling_HighMoreExpensiveThanLow() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1)
        let lowCost = adapter.getCostEstimate(request: costRequest(quality: "low", numberOfImages: 1))
        let medCost = adapter.getCostEstimate(request: costRequest(quality: "medium", numberOfImages: 1))
        let highCost = adapter.getCostEstimate(request: costRequest(quality: "high", numberOfImages: 1))
        XCTAssertLessThan(lowCost, medCost)
        XCTAssertLessThan(medCost, highCost)
    }

    func testWorkflow_MiniCheaperThan15_SameQualityDimension() {
        let mini = makeGPTImage(.OPENAI_GPT_IMAGE_1_MINI)
        let v15 = makeGPTImage(.OPENAI_GPT_IMAGE_1_5)
        let req = costRequest(quality: "medium", dimensions: "1024x1024", numberOfImages: 1)
        XCTAssertLessThan(
            mini.getCostEstimate(request: req),
            v15.getCostEstimate(request: req)
        )
    }

    func testWorkflow_LargerDimensions_CostMoreOrEqual() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1_MINI)
        let smallCost = adapter.getCostEstimate(request: costRequest(
            quality: "medium",
            dimensions: "1024x1024",
            numberOfImages: 1
        ))
        let largeCost = adapter.getCostEstimate(request: costRequest(
            quality: "medium",
            dimensions: "1024x1536",
            numberOfImages: 1
        ))
        XCTAssertGreaterThan(largeCost, smallCost)
    }

    func testWorkflow_ImageCountScaling_Linear() {
        let adapter = makeGPTImage(.OPENAI_GPT_IMAGE_1)
        let cost1 = adapter.getCostEstimate(request: costRequest(quality: "high", numberOfImages: 1))
        let cost5 = adapter.getCostEstimate(request: costRequest(quality: "high", numberOfImages: 5))
        XCTAssertEqual(cost5, cost1 * 5, accuracy: 0.0001)
    }

    func testWorkflow_AllModels_NonNegativeCost() {
        let models: [EnumProviderModelCode] = [
            .OPENAI_GPT_IMAGE_1,
            .OPENAI_GPT_IMAGE_1_MINI,
            .OPENAI_GPT_IMAGE_1_5,
            .OPENAI_GPT_IMAGE_2,
        ]
        for code in models {
            let adapter = makeGPTImage(code)
            let cost = adapter.getCostEstimate(request: costRequest(quality: "medium", numberOfImages: 1))
            XCTAssertGreaterThan(cost, 0, "\(code) should produce positive cost")
        }
    }
}
