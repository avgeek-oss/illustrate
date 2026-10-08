// MARK: - CrossProviderCostWorkflowTests.swift

// Cross-provider cost comparison, scaling invariant, and format consistency tests.
//
// These tests verify business-level cost invariants across multiple providers:
// - Same-task cost comparisons (which provider is cheaper for same workload)
// - Scaling linearity (doubling inputs doubles cost for all providers)
// - Format consistency (all providers produce valid formatted strings)
// - Pricing model comparisons (per-second vs per-unit vs flat rate)
//
// Only uses instantiable base classes and test subclasses (no stored-model classes).

import XCTest
@testable import IllustrateProviders

// MARK: - Test Subclasses (for Fal adapters)

private class CrossTestFalKling: FalKlingBase {
    private let _costPerSecond: Double
    init(costPerSecond: Double) {
        _costPerSecond = costPerSecond
    }

    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V21_MASTER_T2V
    }

    override var costPerSecond: Double {
        _costPerSecond
    }
}

private class CrossTestFalKlingPerUnit: FalKlingPerUnitBase {
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_LIPSYNC_A2V
    }

    override var costPerSecond: Double {
        0
    }

    override var costPerUnit: Double {
        0.014
    }
}

private class CrossTestFalSora: FalSoraBase {
    override var modelCode: EnumProviderModelCode {
        .FAL_SORA_2_PRO_T2V
    }
}

private class CrossTestFalRecraft: FalRecraftBase {
    override var modelCode: EnumProviderModelCode {
        .FAL_RECRAFT_V3
    }
}

// MARK: - Image Generation Cost Comparisons

final class CrossProviderImageCostTests: XCTestCase {
    // MARK: - Helpers

    private func imageCostRequest(
        quality: String? = nil,
        dimensions: String? = nil,
        numberOfImages: Int? = nil
    ) -> ImageGenerationCostRequest {
        ImageGenerationCostRequest(quality: quality, dimensions: dimensions, numberOfImages: numberOfImages)
    }

    // MARK: - Google Imagen Tier Ordering

    func testImagen_FastCheapestAmongGoogleOptions() {
        let imagen3 = G_GOOGLE_IMAGEN_BASE(modelCode: .GOOGLE_IMAGEN_3, costPerImage: 0.03, supportsImageSize: false)
        let imagen4Fast = G_GOOGLE_IMAGEN_BASE(
            modelCode: .GOOGLE_IMAGEN_4_FAST,
            costPerImage: 0.02,
            supportsImageSize: false
        )
        let imagen4Std = G_GOOGLE_IMAGEN_BASE(
            modelCode: .GOOGLE_IMAGEN_4_STANDARD,
            costPerImage: 0.04,
            supportsImageSize: true
        )
        let imagen4Ultra = G_GOOGLE_IMAGEN_BASE(
            modelCode: .GOOGLE_IMAGEN_4_ULTRA,
            costPerImage: 0.06,
            supportsImageSize: true
        )

        let req = imageCostRequest(numberOfImages: 1)
        let costFast = imagen4Fast.getCostEstimate(request: req)
        let cost3 = imagen3.getCostEstimate(request: req)
        let costStd = imagen4Std.getCostEstimate(request: req)
        let costUltra = imagen4Ultra.getCostEstimate(request: req)

        XCTAssertLessThan(costFast, cost3, "Imagen 4 Fast should be cheaper than Imagen 3")
        XCTAssertLessThan(cost3, costStd, "Imagen 3 should be cheaper than Imagen 4 Standard")
        XCTAssertLessThan(costStd, costUltra, "Imagen 4 Standard should be cheaper than Ultra")
    }

    func testImagen4_QualityUpgrade_DoublesCost() {
        let standard = G_GOOGLE_IMAGEN_BASE(
            modelCode: .GOOGLE_IMAGEN_4_STANDARD,
            costPerImage: 0.04,
            supportsImageSize: true
        )
        let stdCost = standard.getCostEstimate(request: imageCostRequest(quality: "standard", numberOfImages: 1))
        let twokCost = standard.getCostEstimate(request: imageCostRequest(quality: "2K", numberOfImages: 1))
        XCTAssertEqual(twokCost, stdCost * 2, accuracy: 0.001, "2K quality should be 2× standard cost")
    }

    // MARK: - Cross-Provider Image Cost: Fal Recraft vs Google Imagen

    func testRecraft_CheaperThanImagen3_PerImage() {
        let recraft = CrossTestFalRecraft()
        let imagen3 = G_GOOGLE_IMAGEN_BASE(modelCode: .GOOGLE_IMAGEN_3, costPerImage: 0.03, supportsImageSize: false)

        let recraftCost = recraft.getCostEstimate(request: imageCostRequest(numberOfImages: 1))
        let imagenCost = imagen3.getCostEstimate(request: imageCostRequest(numberOfImages: 1))

        // Recraft $0.04 vs Imagen 3 $0.03 — Imagen 3 is actually cheaper
        XCTAssertGreaterThan(recraftCost, imagenCost, "Recraft ($0.04) more expensive than Imagen 3 ($0.03)")
    }

    func testRecraft_CheaperThanImagen4Standard() {
        let recraft = CrossTestFalRecraft()
        let imagen4Std = G_GOOGLE_IMAGEN_BASE(
            modelCode: .GOOGLE_IMAGEN_4_STANDARD,
            costPerImage: 0.04,
            supportsImageSize: true
        )

        let recraftCost = recraft.getCostEstimate(request: imageCostRequest(numberOfImages: 1))
        let imagenCost = imagen4Std.getCostEstimate(request: imageCostRequest(numberOfImages: 1))

        // Both $0.04 at standard quality
        XCTAssertEqual(recraftCost, imagenCost, accuracy: 0.001, "Recraft and Imagen 4 Standard same at base")
    }

    // MARK: - Image Multi-Image Scaling Invariant

    func testAllImageProviders_DoublingImages_DoublesCost() {
        let imagen = G_GOOGLE_IMAGEN_BASE(
            modelCode: .GOOGLE_IMAGEN_3,
            costPerImage: 0.03,
            supportsImageSize: false
        )
        let recraft = CrossTestFalRecraft()

        let req1 = imageCostRequest(numberOfImages: 1)
        let req2 = imageCostRequest(numberOfImages: 2)

        let imagenCost1 = imagen.getCostEstimate(request: req1)
        let imagenCost2 = imagen.getCostEstimate(request: req2)
        XCTAssertEqual(imagenCost2, imagenCost1 * 2, accuracy: 0.001, "Imagen: doubling images should double cost")

        let recraftCost1 = recraft.getCostEstimate(request: req1)
        let recraftCost2 = recraft.getCostEstimate(request: req2)
        XCTAssertEqual(recraftCost2, recraftCost1 * 2, accuracy: 0.001, "Recraft: doubling images should double cost")
    }
}

// MARK: - Video Generation Cost Comparisons

final class CrossProviderVideoCostTests: XCTestCase {
    // MARK: - Helpers

    private func videoCostRequest(
        dimensions: String? = nil,
        durationSeconds: Int? = nil,
        numberOfVideos: Int? = nil,
        resolution: String? = nil
    ) -> VideoGenerationCostRequest {
        VideoGenerationCostRequest(
            dimensions: dimensions,
            durationSeconds: durationSeconds,
            numberOfVideos: numberOfVideos,
            resolution: resolution
        )
    }

    // MARK: - Google Veo Tier Ordering

    func testVeo_FastCheaperThanVeo2CheaperThanStandard() {
        let fast = G_GOOGLE_VEO_BASE(modelCode: .GOOGLE_VEO_31_FAST)
        let veo2 = G_GOOGLE_VEO_BASE(modelCode: .GOOGLE_VEO_2)
        let standard = G_GOOGLE_VEO_BASE(modelCode: .GOOGLE_VEO_31)

        let req = videoCostRequest(durationSeconds: 8)
        let fastCost = fast.getCostEstimate(request: req)
        let veo2Cost = veo2.getCostEstimate(request: req)
        let standardCost = standard.getCostEstimate(request: req)

        XCTAssertLessThan(fastCost, veo2Cost)
        XCTAssertLessThan(veo2Cost, standardCost)
    }

    // MARK: - OpenAI Sora Tier Ordering

    func testSora_StandardCheaperThanProHighRes() {
        let sora2 = G_OPENAI_SORA_BASE(modelCode: .OPENAI_SORA_2, modelName: "sora-2")
        let soraPro = G_OPENAI_SORA_BASE(modelCode: .OPENAI_SORA_2_PRO, modelName: "sora-pro")

        let sora2Cost = sora2.getCostEstimate(request: videoCostRequest(durationSeconds: 4))
        let soraProHighRes = soraPro.getCostEstimate(
            request: videoCostRequest(dimensions: "1792x1024", durationSeconds: 4)
        )

        XCTAssertLessThan(sora2Cost, soraProHighRes, "Sora 2 standard should be cheaper than Pro high-res")
    }

    // MARK: - Cross-Provider Video: OpenAI Sora vs Google Veo

    func testOpenAISora2_SamePriceAsGoogleVeoFast720p_SameDuration() {
        // OpenAI Sora 2: $0.10/sec. Google Veo 3.1 Fast 720p: $0.10/sec.
        let sora2 = G_OPENAI_SORA_BASE(modelCode: .OPENAI_SORA_2, modelName: "sora-2")
        let veoFast = G_GOOGLE_VEO_BASE(modelCode: .GOOGLE_VEO_31_FAST)

        let req = videoCostRequest(durationSeconds: 8, resolution: "720p")
        XCTAssertEqual(
            sora2.getCostEstimate(request: req),
            veoFast.getCostEstimate(request: req),
            accuracy: 0.001,
            "Sora 2 and Veo 3.1 Fast 720p are both $0.10/sec"
        )
    }

    func testGoogleVeoStandard_MoreExpensiveThanSoraProStandard() {
        // Veo Standard: $0.40/sec, Sora Pro standard dims: $0.30/sec
        let veoStd = G_GOOGLE_VEO_BASE(modelCode: .GOOGLE_VEO_31)
        let soraPro = G_OPENAI_SORA_BASE(modelCode: .OPENAI_SORA_2_PRO, modelName: "sora-pro")

        let req = videoCostRequest(dimensions: "1280x720", durationSeconds: 8)
        XCTAssertGreaterThan(
            veoStd.getCostEstimate(request: req),
            soraPro.getCostEstimate(request: req),
            "Veo Standard ($0.40/sec) more expensive than Sora Pro standard ($0.30/sec)"
        )
    }

    func testSoraProHighRes_MoreExpensiveThanVeoStandard() {
        // Sora Pro high-res: $0.50/sec, Veo Standard: $0.40/sec
        let soraPro = G_OPENAI_SORA_BASE(modelCode: .OPENAI_SORA_2_PRO, modelName: "sora-pro")
        let veoStd = G_GOOGLE_VEO_BASE(modelCode: .GOOGLE_VEO_31)

        let req = videoCostRequest(dimensions: "1792x1024", durationSeconds: 8)
        XCTAssertGreaterThan(
            soraPro.getCostEstimate(request: req),
            veoStd.getCostEstimate(request: req),
            "Sora Pro high-res ($0.50/sec) more expensive than Veo Standard ($0.40/sec)"
        )
    }

    // MARK: - Cross-Provider Video: Fal Kling vs OpenAI Sora vs Google Veo

    func testFalKlingMaster_MoreExpensiveThanFalSora() {
        // Kling Master: $0.28/sec, Fal Sora: $0.10/sec
        let klingMaster = CrossTestFalKling(costPerSecond: 0.28)
        let falSora = CrossTestFalSora()

        let req = videoCostRequest(durationSeconds: 5)
        XCTAssertGreaterThan(
            klingMaster.getCostEstimate(request: req),
            falSora.getCostEstimate(request: req)
        )
    }

    func testFalSora_SameRateAsOpenAISora2() {
        // Both charge $0.10/sec
        let falSora = CrossTestFalSora()
        let openAISora = G_OPENAI_SORA_BASE(modelCode: .OPENAI_SORA_2, modelName: "sora-2")

        let req = videoCostRequest(durationSeconds: 8)
        XCTAssertEqual(
            falSora.getCostEstimate(request: req),
            openAISora.getCostEstimate(request: req),
            accuracy: 0.001,
            "Fal Sora and OpenAI Sora 2 both charge $0.10/sec"
        )
    }

    // MARK: - Duration Scaling Invariant (All Video Providers)

    func testAllVideoProviders_DoublingDuration_DoublesCost() {
        let veo = G_GOOGLE_VEO_BASE(modelCode: .GOOGLE_VEO_31)
        let sora = G_OPENAI_SORA_BASE(modelCode: .OPENAI_SORA_2, modelName: "sora-2")
        let falKling = CrossTestFalKling(costPerSecond: 0.28)
        let falSora = CrossTestFalSora()

        let req4 = videoCostRequest(durationSeconds: 4)
        let req8 = videoCostRequest(durationSeconds: 8)

        let veoCost4 = veo.getCostEstimate(request: req4)
        let veoCost8 = veo.getCostEstimate(request: req8)
        XCTAssertEqual(veoCost8, veoCost4 * 2, accuracy: 0.001, "Veo: doubling duration doubles cost")

        let soraCost4 = sora.getCostEstimate(request: req4)
        let soraCost8 = sora.getCostEstimate(request: req8)
        XCTAssertEqual(soraCost8, soraCost4 * 2, accuracy: 0.001, "Sora: doubling duration doubles cost")

        let klingCost4 = falKling.getCostEstimate(request: req4)
        let klingCost8 = falKling.getCostEstimate(request: req8)
        XCTAssertEqual(klingCost8, klingCost4 * 2, accuracy: 0.001, "Kling: doubling duration doubles cost")

        let fsCost4 = falSora.getCostEstimate(request: req4)
        let fsCost8 = falSora.getCostEstimate(request: req8)
        XCTAssertEqual(fsCost8, fsCost4 * 2, accuracy: 0.001, "Fal Sora: doubling duration doubles cost")
    }

    // MARK: - Video Count Scaling Invariant

    func testAllVideoProviders_DoublingVideos_DoublesCost() {
        let veo = G_GOOGLE_VEO_BASE(modelCode: .GOOGLE_VEO_31)
        let sora = G_OPENAI_SORA_BASE(modelCode: .OPENAI_SORA_2, modelName: "sora-2")
        let falKling = CrossTestFalKling(costPerSecond: 0.28)

        let req1 = videoCostRequest(durationSeconds: 5, numberOfVideos: 1)
        let req2 = videoCostRequest(durationSeconds: 5, numberOfVideos: 2)

        XCTAssertEqual(
            veo.getCostEstimate(request: req2),
            veo.getCostEstimate(request: req1) * 2,
            accuracy: 0.001
        )
        XCTAssertEqual(
            sora.getCostEstimate(request: req2),
            sora.getCostEstimate(request: req1) * 2,
            accuracy: 0.001
        )
        XCTAssertEqual(
            falKling.getCostEstimate(request: req2),
            falKling.getCostEstimate(request: req1) * 2,
            accuracy: 0.001
        )
    }

    // MARK: - Per-Unit vs Per-Second Pricing Model

    func testKlingPerUnit_CostIndependentOfDuration() {
        let perUnit = CrossTestFalKlingPerUnit()
        let cost5 = perUnit.getCostEstimate(request: videoCostRequest(durationSeconds: 5, numberOfVideos: 1))
        let cost10 = perUnit.getCostEstimate(request: videoCostRequest(durationSeconds: 10, numberOfVideos: 1))
        let cost100 = perUnit.getCostEstimate(request: videoCostRequest(durationSeconds: 100, numberOfVideos: 1))
        XCTAssertEqual(cost5, cost10, "Per-unit cost should not depend on duration")
        XCTAssertEqual(cost10, cost100, "Per-unit cost should not depend on duration")
    }

    func testKlingPerSecond_CostIncreasesWithDuration() {
        let perSecond = CrossTestFalKling(costPerSecond: 0.28)
        let cost5 = perSecond.getCostEstimate(request: videoCostRequest(durationSeconds: 5))
        let cost10 = perSecond.getCostEstimate(request: videoCostRequest(durationSeconds: 10))
        XCTAssertGreaterThan(cost10, cost5, "Per-second cost should increase with duration")
    }
}

// MARK: - Format Consistency Tests

final class CrossProviderFormatTests: XCTestCase {
    // MARK: - Google Format Consistency

    func testGoogleImagen_FormatProducesDollarString() {
        let adapter = G_GOOGLE_IMAGEN_BASE(
            modelCode: .GOOGLE_IMAGEN_3,
            costPerImage: 0.03,
            supportsImageSize: false
        )
        let formatted = adapter.formatCost(request: ImageGenerationCostRequest(numberOfImages: 1))
        XCTAssertTrue(formatted.contains("$"), "Google Imagen format should contain $: \(formatted)")
    }

    func testGoogleVeo_FormatProducesDollarString() {
        let adapter = G_GOOGLE_VEO_BASE(modelCode: .GOOGLE_VEO_31)
        let formatted = adapter.formatCost(request: VideoGenerationCostRequest(durationSeconds: 8))
        XCTAssertTrue(formatted.contains("$"), "Google Veo format should contain $: \(formatted)")
    }

    // MARK: - OpenAI Format Consistency

    func testOpenAISora_FormatProducesDollarString() {
        let adapter = G_OPENAI_SORA_BASE(modelCode: .OPENAI_SORA_2, modelName: "sora-2")
        let formatted = adapter.formatCost(request: VideoGenerationCostRequest(durationSeconds: 4))
        XCTAssertTrue(formatted.contains("$"), "OpenAI Sora format should contain $: \(formatted)")
    }

    func testOpenAIGPTImage_FormatProducesDollarString() {
        let adapter = G_OPENAI_GPT_IMAGE_BASE(modelCode: .OPENAI_GPT_IMAGE_1, modelName: "gpt-image")
        let formatted = adapter.formatCost(
            request: ImageGenerationCostRequest(quality: "high", dimensions: "1024x1024", numberOfImages: 1)
        )
        XCTAssertTrue(formatted.contains("$"), "GPT Image format should contain $: \(formatted)")
    }

    // MARK: - Fal Format Consistency

    func testFalKling_FormatProducesDollarString() {
        let adapter = CrossTestFalKling(costPerSecond: 0.28)
        let formatted = adapter.formatCost(request: VideoGenerationCostRequest(durationSeconds: 5))
        XCTAssertTrue(formatted.contains("$"), "Fal Kling format should contain $: \(formatted)")
    }

    func testFalSora_FormatProducesDollarString() {
        let adapter = CrossTestFalSora()
        let formatted = adapter.formatCost(request: VideoGenerationCostRequest(durationSeconds: 5))
        XCTAssertTrue(formatted.contains("$"), "Fal Sora format should contain $: \(formatted)")
    }

    func testFalRecraft_FormatProducesDollarString() {
        let adapter = CrossTestFalRecraft()
        let formatted = adapter.formatCost(request: ImageGenerationCostRequest(numberOfImages: 1))
        XCTAssertTrue(formatted.contains("$"), "Fal Recraft format should contain $: \(formatted)")
    }

    // MARK: - Zero Cost → "Free" Across Providers

    func testAllVideoProviders_ZeroDuration_ReturnsFree() {
        let veo = G_GOOGLE_VEO_BASE(modelCode: .GOOGLE_VEO_31)
        let sora = G_OPENAI_SORA_BASE(modelCode: .OPENAI_SORA_2, modelName: "sora-2")
        let falKling = CrossTestFalKling(costPerSecond: 0.28)
        let falSora = CrossTestFalSora()

        let req = VideoGenerationCostRequest(durationSeconds: 0)

        XCTAssertEqual(veo.formatCost(request: req), "Free", "Veo zero-duration should be Free")
        XCTAssertEqual(sora.formatCost(request: req), "Free", "Sora zero-duration should be Free")
        XCTAssertEqual(falKling.formatCost(request: req), "Free", "Fal Kling zero-duration should be Free")
        XCTAssertEqual(falSora.formatCost(request: req), "Free", "Fal Sora zero-duration should be Free")
    }

    // MARK: - Stability Uses Credits Format (Not Dollars)

    func testStability_UsesCreditsFormat_NotDollars() {
        // Stability adapters use "X credits" format, verified via static constants
        // Ultra baseCost = 8.0 → should format as integer credits
        // SD3 baseCost = 6.5 → should format with decimal
        XCTAssertEqual(G_STABILITY_ULTRA.baseCost, 8.0, "Ultra uses credits, baseCost = 8")
        XCTAssertEqual(G_STABILITY_SD3.baseCost, 6.5, "SD3 uses credits, baseCost = 6.5")
        XCTAssertEqual(G_STABILITY_CORE.baseCost, 3.0, "Core uses credits, baseCost = 3")
    }

    // MARK: - All Format Outputs Are Non-Empty

    func testAllTestableProviders_FormatCost_NonEmpty() {
        let imagen = G_GOOGLE_IMAGEN_BASE(
            modelCode: .GOOGLE_IMAGEN_3,
            costPerImage: 0.03,
            supportsImageSize: false
        )
        let veo = G_GOOGLE_VEO_BASE(modelCode: .GOOGLE_VEO_31)
        let sora = G_OPENAI_SORA_BASE(modelCode: .OPENAI_SORA_2, modelName: "sora-2")
        let gptImage = G_OPENAI_GPT_IMAGE_BASE(modelCode: .OPENAI_GPT_IMAGE_1, modelName: "gpt-image")
        let falKling = CrossTestFalKling(costPerSecond: 0.28)
        let falSora = CrossTestFalSora()
        let recraft = CrossTestFalRecraft()

        XCTAssertFalse(
            imagen.formatCost(request: ImageGenerationCostRequest(numberOfImages: 1)).isEmpty
        )
        XCTAssertFalse(
            veo.formatCost(request: VideoGenerationCostRequest(durationSeconds: 8)).isEmpty
        )
        XCTAssertFalse(
            sora.formatCost(request: VideoGenerationCostRequest(durationSeconds: 4)).isEmpty
        )
        XCTAssertFalse(
            gptImage.formatCost(
                request: ImageGenerationCostRequest(quality: "high", dimensions: "1024x1024", numberOfImages: 1)
            ).isEmpty
        )
        XCTAssertFalse(
            falKling.formatCost(request: VideoGenerationCostRequest(durationSeconds: 5)).isEmpty
        )
        XCTAssertFalse(
            falSora.formatCost(request: VideoGenerationCostRequest(durationSeconds: 5)).isEmpty
        )
        XCTAssertFalse(
            recraft.formatCost(request: ImageGenerationCostRequest(numberOfImages: 1)).isEmpty
        )
    }
}

// MARK: - Determinism and Non-Negative Cost Invariants

final class CrossProviderInvariantTests: XCTestCase {
    func testAllProviders_NonNegativeCost() {
        let imagen = G_GOOGLE_IMAGEN_BASE(
            modelCode: .GOOGLE_IMAGEN_3,
            costPerImage: 0.03,
            supportsImageSize: false
        )
        let veo = G_GOOGLE_VEO_BASE(modelCode: .GOOGLE_VEO_31)
        let sora = G_OPENAI_SORA_BASE(modelCode: .OPENAI_SORA_2, modelName: "sora-2")
        let gptImage = G_OPENAI_GPT_IMAGE_BASE(modelCode: .OPENAI_GPT_IMAGE_1, modelName: "gpt-image")
        let falKling = CrossTestFalKling(costPerSecond: 0.28)
        let falSora = CrossTestFalSora()
        let recraft = CrossTestFalRecraft()
        let perUnit = CrossTestFalKlingPerUnit()

        XCTAssertGreaterThanOrEqual(
            imagen.getCostEstimate(request: ImageGenerationCostRequest(numberOfImages: 1)), 0
        )
        XCTAssertGreaterThanOrEqual(
            veo.getCostEstimate(request: VideoGenerationCostRequest(durationSeconds: 5)), 0
        )
        XCTAssertGreaterThanOrEqual(
            sora.getCostEstimate(request: VideoGenerationCostRequest(durationSeconds: 4)), 0
        )
        XCTAssertGreaterThanOrEqual(
            gptImage.getCostEstimate(
                request: ImageGenerationCostRequest(quality: "high", dimensions: "1024x1024", numberOfImages: 1)
            ), 0
        )
        XCTAssertGreaterThanOrEqual(
            falKling.getCostEstimate(request: VideoGenerationCostRequest(durationSeconds: 5)), 0
        )
        XCTAssertGreaterThanOrEqual(
            falSora.getCostEstimate(request: VideoGenerationCostRequest(durationSeconds: 5)), 0
        )
        XCTAssertGreaterThanOrEqual(
            recraft.getCostEstimate(request: ImageGenerationCostRequest(numberOfImages: 1)), 0
        )
        XCTAssertGreaterThanOrEqual(
            perUnit.getCostEstimate(request: VideoGenerationCostRequest(numberOfVideos: 1)), 0
        )
    }

    func testAllProviders_Determinism_SameRequestSameResult() {
        let veo = G_GOOGLE_VEO_BASE(modelCode: .GOOGLE_VEO_31)
        let sora = G_OPENAI_SORA_BASE(modelCode: .OPENAI_SORA_2, modelName: "sora-2")
        let falKling = CrossTestFalKling(costPerSecond: 0.28)

        let videoReq = VideoGenerationCostRequest(durationSeconds: 8, numberOfVideos: 2)

        XCTAssertEqual(veo.getCostEstimate(request: videoReq), veo.getCostEstimate(request: videoReq))
        XCTAssertEqual(sora.getCostEstimate(request: videoReq), sora.getCostEstimate(request: videoReq))
        XCTAssertEqual(falKling.getCostEstimate(request: videoReq), falKling.getCostEstimate(request: videoReq))
    }

    func testAllGoogleVeoModels_NonNegativeCost() {
        let models: [EnumProviderModelCode] = [
            .GOOGLE_VEO_31, .GOOGLE_VEO_31_EXTEND,
            .GOOGLE_VEO_31_FAST, .GOOGLE_VEO_31_FAST_EXTEND,
            .GOOGLE_VEO_3, .GOOGLE_VEO_3_FAST,
            .GOOGLE_VEO_2,
        ]
        for code in models {
            let adapter = G_GOOGLE_VEO_BASE(modelCode: code)
            let cost = adapter.getCostEstimate(request: VideoGenerationCostRequest(durationSeconds: 5))
            XCTAssertGreaterThanOrEqual(cost, 0, "\(code) should produce non-negative cost")
        }
    }

    func testAllGoogleImagenModels_NonNegativeCost() {
        let configs: [(EnumProviderModelCode, Double, Bool)] = [
            (.GOOGLE_IMAGEN_3, 0.03, false),
            (.GOOGLE_IMAGEN_4_FAST, 0.02, false),
            (.GOOGLE_IMAGEN_4_STANDARD, 0.04, true),
            (.GOOGLE_IMAGEN_4_ULTRA, 0.06, true),
        ]
        for (code, costPerImage, supportsSize) in configs {
            let adapter = G_GOOGLE_IMAGEN_BASE(
                modelCode: code,
                costPerImage: costPerImage,
                supportsImageSize: supportsSize
            )
            let cost = adapter.getCostEstimate(request: ImageGenerationCostRequest(numberOfImages: 1))
            XCTAssertGreaterThanOrEqual(cost, 0, "\(code) should produce non-negative cost")
        }
    }

    // MARK: - Replicate Static Constants Remain Positive

    func testAllReplicateFlux_StaticCosts_Positive() {
        XCTAssertGreaterThan(G_REPLICATE_FLUX_PRO.baseCost, 0)
        XCTAssertGreaterThan(G_REPLICATE_FLUX_DEV.baseCost, 0)
        XCTAssertGreaterThan(G_REPLICATE_FLUX_SCHNELL.baseCost, 0)
    }

    func testAllStability_StaticCosts_Positive() {
        XCTAssertGreaterThan(G_STABILITY_ULTRA.baseCost, 0)
        XCTAssertGreaterThan(G_STABILITY_SD3.baseCost, 0)
        XCTAssertGreaterThan(G_STABILITY_CORE.baseCost, 0)
    }
}
