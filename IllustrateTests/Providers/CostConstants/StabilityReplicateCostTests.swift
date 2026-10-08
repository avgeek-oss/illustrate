// MARK: - StabilityReplicateCostTests.swift

// Cost constant and static method tests for Stability AI and Replicate adapters.
//
// Tests verify cost constants, static methods, adapter cost estimates, and
// cost relationships without making provider network calls.
//
// Tests cover:
// - Stability AI: baseCost constants for Ultra, SD3, Core
// - Replicate Flux: baseCost constants for Pro, Dev, Schnell
// - Replicate Wan: costPerSecond, costForResolution(), audio premiums
// - Cross-provider cost ordering and pricing model workflows

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

// MARK: - Stability AI Cost Constants

final class StabilityAICostConstantTests: XCTestCase {
    // MARK: - baseCost Verification

    func testStabilityUltra_BaseCost_Is8() {
        XCTAssertEqual(G_STABILITY_ULTRA.baseCost, 8.0)
    }

    func testStabilitySD3_BaseCost_Is65() {
        XCTAssertEqual(G_STABILITY_SD3.baseCost, 6.5)
    }

    func testStabilitySD35_PerModelBaseCosts() {
        XCTAssertEqual(G_STABILITY_SD3.baseCost(for: .STABILITY_SD35_LARGE), 6.5)
        XCTAssertEqual(G_STABILITY_SD3.baseCost(for: .STABILITY_SD35_LARGE_TURBO), 4.0)
        XCTAssertEqual(G_STABILITY_SD3.baseCost(for: .STABILITY_SD35_MEDIUM), 3.5)
        XCTAssertEqual(G_STABILITY_SD3.baseCost(for: .STABILITY_SD35_FLASH), 2.5)
    }

    func testStabilityCore_BaseCost_Is3() {
        XCTAssertEqual(G_STABILITY_CORE.baseCost, 3.0)
    }

    // MARK: - Cost Ordering

    func testStability_CostOrdering_UltraMoreThanSD3MoreThanCore() {
        XCTAssertGreaterThan(G_STABILITY_ULTRA.baseCost, G_STABILITY_SD3.baseCost)
        XCTAssertGreaterThan(G_STABILITY_SD3.baseCost, G_STABILITY_CORE.baseCost)
    }

    // MARK: - Cost Calculations (formula verification)

    func testStabilityUltra_MultiImage_CostFormula() {
        // Formula: baseCost * numberOfImages
        let baseCost = G_STABILITY_ULTRA.baseCost
        XCTAssertEqual(baseCost * 1, 8.0)
        XCTAssertEqual(baseCost * 3, 24.0)
        XCTAssertEqual(baseCost * 5, 40.0)
    }

    func testStabilitySD3_MultiImage_CostFormula() {
        let baseCost = G_STABILITY_SD3.baseCost
        XCTAssertEqual(baseCost * 1, 6.5)
        XCTAssertEqual(baseCost * 2, 13.0)
    }

    func testStabilitySD35_PerModelCostEstimateUsesModelId() {
        let adapter = G_STABILITY_SD3()

        XCTAssertEqual(
            adapter.getCostEstimate(request: ImageGenerationCostRequest(
                modelId: EnumProviderModelCode.STABILITY_SD35_LARGE.rawValue,
                numberOfImages: 2
            )),
            13.0
        )
        XCTAssertEqual(
            adapter.getCostEstimate(request: ImageGenerationCostRequest(
                modelId: EnumProviderModelCode.STABILITY_SD35_LARGE_TURBO.rawValue,
                numberOfImages: 2
            )),
            8.0
        )
        XCTAssertEqual(
            adapter.getCostEstimate(request: ImageGenerationCostRequest(
                modelId: EnumProviderModelCode.STABILITY_SD35_MEDIUM.rawValue,
                numberOfImages: 2
            )),
            7.0
        )
        XCTAssertEqual(
            adapter.getCostEstimate(request: ImageGenerationCostRequest(
                modelId: EnumProviderModelCode.STABILITY_SD35_FLASH.rawValue,
                numberOfImages: 2
            )),
            5.0
        )
    }

    func testStabilitySD35_FactoryAdaptersCarryVariantCostsAndCreditFormatting() {
        let costRequest = ImageGenerationCostRequest(numberOfImages: 1)

        XCTAssertEqual(
            getImageGenerationAdapter(modelCode: .STABILITY_SD35_LARGE)?.getCostEstimate(request: costRequest),
            6.5
        )
        XCTAssertEqual(
            getImageGenerationAdapter(modelCode: .STABILITY_SD35_LARGE_TURBO)?.getCostEstimate(request: costRequest),
            4.0
        )
        XCTAssertEqual(
            getImageGenerationAdapter(modelCode: .STABILITY_SD35_MEDIUM)?.getCostEstimate(request: costRequest),
            3.5
        )
        XCTAssertEqual(
            getImageGenerationAdapter(modelCode: .STABILITY_SD35_FLASH)?.getCostEstimate(request: costRequest),
            2.5
        )

        XCTAssertEqual(
            getImageGenerationAdapter(modelCode: .STABILITY_SD35_LARGE)?.formatCost(request: costRequest),
            "6.5 credits"
        )
        XCTAssertEqual(
            getImageGenerationAdapter(modelCode: .STABILITY_SD35_LARGE_TURBO)?.formatCost(request: costRequest),
            "4 credits"
        )
        XCTAssertEqual(
            getImageGenerationAdapter(modelCode: .STABILITY_SD35_MEDIUM)?.formatCost(request: costRequest),
            "3.5 credits"
        )
        XCTAssertEqual(
            getImageGenerationAdapter(modelCode: .STABILITY_SD35_FLASH)?.formatCost(request: costRequest),
            "2.5 credits"
        )
    }

    func testStabilityCore_MultiImage_CostFormula() {
        let baseCost = G_STABILITY_CORE.baseCost
        XCTAssertEqual(baseCost * 1, 3.0)
        XCTAssertEqual(baseCost * 4, 12.0)
    }

    // MARK: - All Constants Positive

    func testStability_AllBaseCosts_Positive() {
        XCTAssertGreaterThan(G_STABILITY_ULTRA.baseCost, 0)
        XCTAssertGreaterThan(G_STABILITY_SD3.baseCost, 0)
        XCTAssertGreaterThan(G_STABILITY_CORE.baseCost, 0)
    }
}

// MARK: - Replicate Flux Cost Constants

final class ReplicateFluxCostConstantTests: XCTestCase {
    // MARK: - baseCost Verification

    func testFluxPro_BaseCost_Is0055() {
        XCTAssertEqual(G_REPLICATE_FLUX_PRO.baseCost, 0.055, accuracy: 0.0001)
    }

    func testFluxDev_BaseCost_Is003() {
        XCTAssertEqual(G_REPLICATE_FLUX_DEV.baseCost, 0.03, accuracy: 0.0001)
    }

    func testFluxSchnell_BaseCost_Is0003() {
        XCTAssertEqual(G_REPLICATE_FLUX_SCHNELL.baseCost, 0.003, accuracy: 0.0001)
    }

    // MARK: - Cost Ordering

    func testFlux_CostOrdering_ProMoreThanDevMoreThanSchnell() {
        XCTAssertGreaterThan(G_REPLICATE_FLUX_PRO.baseCost, G_REPLICATE_FLUX_DEV.baseCost)
        XCTAssertGreaterThan(G_REPLICATE_FLUX_DEV.baseCost, G_REPLICATE_FLUX_SCHNELL.baseCost)
    }

    // MARK: - Cost Ratio

    func testFlux_Schnell_MuchCheaperThanPro() {
        let ratio = G_REPLICATE_FLUX_PRO.baseCost / G_REPLICATE_FLUX_SCHNELL.baseCost
        // Pro is ~18.3× more expensive than Schnell
        XCTAssertGreaterThan(ratio, 18)
        XCTAssertLessThan(ratio, 19)
    }

    // MARK: - Multi-Image Formula

    func testFluxPro_MultiImage_CostFormula() {
        let baseCost = G_REPLICATE_FLUX_PRO.baseCost
        XCTAssertEqual(baseCost * 3, 0.165, accuracy: 0.0001)
    }

    // MARK: - All Constants Positive

    func testFlux_AllBaseCosts_Positive() {
        XCTAssertGreaterThan(G_REPLICATE_FLUX_PRO.baseCost, 0)
        XCTAssertGreaterThan(G_REPLICATE_FLUX_DEV.baseCost, 0)
        XCTAssertGreaterThan(G_REPLICATE_FLUX_SCHNELL.baseCost, 0)
    }
}

// MARK: - Replicate Wan Cost Constants

final class ReplicateWanCostConstantTests: XCTestCase {
    // MARK: - Wan 2.6 Per-Second Constants

    func testWan26I2V_CostNoAudio_Is010() {
        XCTAssertEqual(G_REPLICATE_WAN_2_6_I2V.costPerSecondNoAudio, 0.10, accuracy: 0.001)
    }

    func testWan26I2V_CostWithAudio_Is015() {
        XCTAssertEqual(G_REPLICATE_WAN_2_6_I2V.costPerSecondWithAudio, 0.15, accuracy: 0.001)
    }

    func testWan26T2V_CostNoAudio_Is010() {
        XCTAssertEqual(G_REPLICATE_WAN_2_6_T2V.costPerSecondNoAudio, 0.10, accuracy: 0.001)
    }

    func testWan26T2V_CostWithAudio_Is015() {
        XCTAssertEqual(G_REPLICATE_WAN_2_6_T2V.costPerSecondWithAudio, 0.15, accuracy: 0.001)
    }

    // MARK: - Wan 2.6 Audio Premium

    func testWan26_AudioPremium_Is50Percent() {
        let noAudio = G_REPLICATE_WAN_2_6_I2V.costPerSecondNoAudio
        let withAudio = G_REPLICATE_WAN_2_6_I2V.costPerSecondWithAudio
        XCTAssertEqual(withAudio / noAudio, 1.5, accuracy: 0.01)
    }

    func testWan26_I2VAndT2V_SamePricing() {
        XCTAssertEqual(G_REPLICATE_WAN_2_6_I2V.costPerSecondNoAudio, G_REPLICATE_WAN_2_6_T2V.costPerSecondNoAudio)
        XCTAssertEqual(G_REPLICATE_WAN_2_6_I2V.costPerSecondWithAudio, G_REPLICATE_WAN_2_6_T2V.costPerSecondWithAudio)
    }

    // MARK: - Wan 2.5 Resolution-Based Pricing

    func testWan25I2V_480p_Returns005() {
        XCTAssertEqual(G_REPLICATE_WAN_2_5_I2V.costForResolution("480p"), 0.05, accuracy: 0.001)
    }

    func testWan25I2V_720p_Default_Returns010() {
        XCTAssertEqual(G_REPLICATE_WAN_2_5_I2V.costForResolution("720p"), 0.10, accuracy: 0.001)
    }

    func testWan25I2V_1080p_Returns015() {
        XCTAssertEqual(G_REPLICATE_WAN_2_5_I2V.costForResolution("1080p"), 0.15, accuracy: 0.001)
    }

    func testWan25I2V_Nil_DefaultsTo720p() {
        XCTAssertEqual(G_REPLICATE_WAN_2_5_I2V.costForResolution(nil), 0.10, accuracy: 0.001)
    }

    func testWan25T2V_480p_Returns005() {
        XCTAssertEqual(G_REPLICATE_WAN_2_5_T2V.costForResolution("480p"), 0.05, accuracy: 0.001)
    }

    func testWan25T2V_1080p_Returns015() {
        XCTAssertEqual(G_REPLICATE_WAN_2_5_T2V.costForResolution("1080p"), 0.15, accuracy: 0.001)
    }

    // MARK: - Wan 2.5 Resolution Ordering

    func testWan25_ResolutionScaling_480pCheaperThan720pCheaperThan1080p() {
        let cost480 = G_REPLICATE_WAN_2_5_I2V.costForResolution("480p")
        let cost720 = G_REPLICATE_WAN_2_5_I2V.costForResolution("720p")
        let cost1080 = G_REPLICATE_WAN_2_5_I2V.costForResolution("1080p")
        XCTAssertLessThan(cost480, cost720)
        XCTAssertLessThan(cost720, cost1080)
    }

    // MARK: - Wan 2.5 Fast Audio-Based Pricing

    func testWan25FastI2V_CostNoAudio_Is0068() {
        XCTAssertEqual(G_REPLICATE_WAN_2_5_I2V_FAST.costNoAudio, 0.068, accuracy: 0.001)
    }

    func testWan25FastI2V_CostWithAudio_Is0102() {
        XCTAssertEqual(G_REPLICATE_WAN_2_5_I2V_FAST.costWithAudio, 0.102, accuracy: 0.001)
    }

    func testWan25FastT2V_CostNoAudio_Is0068() {
        XCTAssertEqual(G_REPLICATE_WAN_2_5_T2V_FAST.costNoAudio, 0.068, accuracy: 0.001)
    }

    func testWan25FastT2V_CostWithAudio_Is0102() {
        XCTAssertEqual(G_REPLICATE_WAN_2_5_T2V_FAST.costWithAudio, 0.102, accuracy: 0.001)
    }

    // MARK: - Wan 2.5 Fast vs Standard

    func testWan25Fast_CheaperThanStandard_At720p() {
        let fastCost = G_REPLICATE_WAN_2_5_I2V_FAST.costNoAudio
        let standardCost = G_REPLICATE_WAN_2_5_I2V.costForResolution("720p")
        XCTAssertLessThan(fastCost, standardCost)
    }

    // MARK: - All Constants Positive

    func testWan_AllCostConstants_Positive() {
        XCTAssertGreaterThan(G_REPLICATE_WAN_2_6_I2V.costPerSecondNoAudio, 0)
        XCTAssertGreaterThan(G_REPLICATE_WAN_2_6_I2V.costPerSecondWithAudio, 0)
        XCTAssertGreaterThan(G_REPLICATE_WAN_2_5_I2V.costForResolution("480p"), 0)
        XCTAssertGreaterThan(G_REPLICATE_WAN_2_5_I2V.costForResolution("720p"), 0)
        XCTAssertGreaterThan(G_REPLICATE_WAN_2_5_I2V.costForResolution("1080p"), 0)
        XCTAssertGreaterThan(G_REPLICATE_WAN_2_5_I2V_FAST.costNoAudio, 0)
        XCTAssertGreaterThan(G_REPLICATE_WAN_2_5_I2V_FAST.costWithAudio, 0)
    }
}
