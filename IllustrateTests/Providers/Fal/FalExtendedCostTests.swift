// MARK: - FalExtendedCostTests.swift

// Cost estimation tests for Fal adapter base classes: Kling, Sora, Recraft.
//
// These base classes use abstract properties (fatalError) that require test
// subclasses to provide safe overrides. Tests verify:
// - FalKlingBase: costPerSecond × durationSeconds × numberOfVideos
// - FalKlingPerUnitBase: costPerUnit × numberOfVideos (duration-independent)
// - FalSoraBase: costPerSecond × durationSeconds × numberOfVideos ($0.10/sec)
// - FalRecraftBase: baseCost × numberOfImages ($0.04/image)
// - formatCost() output and "Free" for zero cost
// - Scaling linearity and cross-model cost relationships

import XCTest
@testable import IllustrateProviders

// MARK: - Test Subclasses

/// FalKlingBase subclass with configurable costPerSecond for testing
private class TestFalKlingPerSecond: FalKlingBase {
    private let _costPerSecond: Double
    private let _modelCode: EnumProviderModelCode

    init(costPerSecond: Double, modelCode: EnumProviderModelCode = .FAL_KLING_V21_MASTER_T2V) {
        _costPerSecond = costPerSecond
        _modelCode = modelCode
    }

    override var modelCode: EnumProviderModelCode {
        _modelCode
    }

    override var costPerSecond: Double {
        _costPerSecond
    }
}

/// FalKlingPerUnitBase subclass for testing flat per-unit pricing
private class TestFalKlingPerUnit: FalKlingPerUnitBase {
    private let _costPerUnit: Double

    init(costPerUnit: Double = 0.014) {
        _costPerUnit = costPerUnit
    }

    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_LIPSYNC_A2V
    }

    override var costPerSecond: Double {
        0
    } // Not used in per-unit mode
    override var costPerUnit: Double {
        _costPerUnit
    }
}

/// FalSoraBase subclass for testing
private class TestFalSora: FalSoraBase {
    override var modelCode: EnumProviderModelCode {
        .FAL_SORA_2_PRO_T2V
    }
}

/// FalRecraftBase subclass for testing
private class TestFalRecraft: FalRecraftBase {
    override var modelCode: EnumProviderModelCode {
        .FAL_RECRAFT_V3
    }
}

/// FalRecraftBase subclass with custom baseCost for testing
private class TestFalRecraftCustomCost: FalRecraftBase {
    private let _baseCost: Double

    init(baseCost: Double) {
        _baseCost = baseCost
    }

    override var modelCode: EnumProviderModelCode {
        .FAL_RECRAFT_V3
    }

    override var baseCost: Double {
        _baseCost
    }
}

// MARK: - FalKlingBase Per-Second Cost Tests

final class FalKlingPerSecondCostTests: XCTestCase {
    // MARK: - Helpers

    private func costRequest(
        durationSeconds: Int? = nil,
        numberOfVideos: Int? = nil
    ) -> VideoGenerationCostRequest {
        VideoGenerationCostRequest(
            durationSeconds: durationSeconds,
            numberOfVideos: numberOfVideos
        )
    }

    // MARK: - Basic Cost Calculation

    func testKling_V21Master_5Sec_Returns140() {
        let adapter = TestFalKlingPerSecond(costPerSecond: 0.28)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 5))
        XCTAssertEqual(cost, 1.40, accuracy: 0.001)
    }

    func testKling_V21Master_10Sec_Returns280() {
        let adapter = TestFalKlingPerSecond(costPerSecond: 0.28)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 10))
        XCTAssertEqual(cost, 2.80, accuracy: 0.001)
    }

    func testKling_V26Pro_5Sec_Returns035() {
        let adapter = TestFalKlingPerSecond(costPerSecond: 0.07)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 5))
        XCTAssertEqual(cost, 0.35, accuracy: 0.001)
    }

    func testKling_V25TurboPro_10Sec_Returns070() {
        let adapter = TestFalKlingPerSecond(costPerSecond: 0.07)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 10))
        XCTAssertEqual(cost, 0.70, accuracy: 0.001)
    }

    func testKling_V21Standard_5Sec_Returns025() {
        let adapter = TestFalKlingPerSecond(costPerSecond: 0.05)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 5))
        XCTAssertEqual(cost, 0.25, accuracy: 0.001)
    }

    // MARK: - Multi-Video Scaling

    func testKling_2Videos_5Sec_DoublesCost() {
        let adapter = TestFalKlingPerSecond(costPerSecond: 0.28)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 5, numberOfVideos: 2))
        XCTAssertEqual(cost, 2.80, accuracy: 0.001)
    }

    func testKling_3Videos_5Sec_TriplesCost() {
        let adapter = TestFalKlingPerSecond(costPerSecond: 0.28)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 5, numberOfVideos: 3))
        XCTAssertEqual(cost, 4.20, accuracy: 0.001)
    }

    func testKling_NilNumberOfVideos_DefaultsToOne() {
        let adapter = TestFalKlingPerSecond(costPerSecond: 0.28)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 5, numberOfVideos: nil))
        XCTAssertEqual(cost, 1.40, accuracy: 0.001)
    }

    // MARK: - Edge Cases

    func testKling_ZeroDuration_ReturnsZero() {
        let adapter = TestFalKlingPerSecond(costPerSecond: 0.28)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 0))
        XCTAssertEqual(cost, 0.0, accuracy: 0.001)
    }

    func testKling_1SecondVideo_ReturnsCostPerSecond() {
        let adapter = TestFalKlingPerSecond(costPerSecond: 0.28)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 1))
        XCTAssertEqual(cost, 0.28, accuracy: 0.001)
    }

    // MARK: - formatCost

    func testKling_FormatCost_140_FormatsCorrectly() {
        let adapter = TestFalKlingPerSecond(costPerSecond: 0.28)
        let formatted = adapter.formatCost(request: costRequest(durationSeconds: 5))
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("$"))
    }

    func testKling_FormatCost_Zero_ReturnsFree() {
        let adapter = TestFalKlingPerSecond(costPerSecond: 0.28)
        let formatted = adapter.formatCost(request: costRequest(durationSeconds: 0))
        XCTAssertEqual(formatted, "Free")
    }

    // MARK: - Cost Tier Ordering

    func testKling_MasterMoreExpensiveThanPro() {
        let master = TestFalKlingPerSecond(costPerSecond: 0.28)
        let pro = TestFalKlingPerSecond(costPerSecond: 0.09)
        let req = costRequest(durationSeconds: 5)
        XCTAssertGreaterThan(
            master.getCostEstimate(request: req),
            pro.getCostEstimate(request: req)
        )
    }

    func testKling_ProMoreExpensiveThanStandard() {
        let pro = TestFalKlingPerSecond(costPerSecond: 0.09)
        let standard = TestFalKlingPerSecond(costPerSecond: 0.05)
        let req = costRequest(durationSeconds: 5)
        XCTAssertGreaterThan(
            pro.getCostEstimate(request: req),
            standard.getCostEstimate(request: req)
        )
    }

    func testKling_DoublingDuration_DoublesCost() {
        let adapter = TestFalKlingPerSecond(costPerSecond: 0.28)
        let cost5 = adapter.getCostEstimate(request: costRequest(durationSeconds: 5))
        let cost10 = adapter.getCostEstimate(request: costRequest(durationSeconds: 10))
        XCTAssertEqual(cost10, cost5 * 2, accuracy: 0.001)
    }

    func testKling_Determinism_SameRequestSameResult() {
        let adapter = TestFalKlingPerSecond(costPerSecond: 0.28)
        let req = costRequest(durationSeconds: 5, numberOfVideos: 2)
        let cost1 = adapter.getCostEstimate(request: req)
        let cost2 = adapter.getCostEstimate(request: req)
        XCTAssertEqual(cost1, cost2)
    }
}

// MARK: - FalKlingPerUnitBase Flat Cost Tests

final class FalKlingPerUnitCostTests: XCTestCase {
    private func costRequest(
        durationSeconds: Int? = nil,
        numberOfVideos: Int? = nil
    ) -> VideoGenerationCostRequest {
        VideoGenerationCostRequest(
            durationSeconds: durationSeconds,
            numberOfVideos: numberOfVideos
        )
    }

    func testPerUnit_1Video_Returns0014() {
        let adapter = TestFalKlingPerUnit()
        let cost = adapter.getCostEstimate(request: costRequest(numberOfVideos: 1))
        XCTAssertEqual(cost, 0.014, accuracy: 0.0001)
    }

    func testPerUnit_3Videos_Returns0042() {
        let adapter = TestFalKlingPerUnit()
        let cost = adapter.getCostEstimate(request: costRequest(numberOfVideos: 3))
        XCTAssertEqual(cost, 0.042, accuracy: 0.0001)
    }

    func testPerUnit_NilNumberOfVideos_DefaultsToOne() {
        let adapter = TestFalKlingPerUnit()
        let cost = adapter.getCostEstimate(request: costRequest(numberOfVideos: nil))
        XCTAssertEqual(cost, 0.014, accuracy: 0.0001)
    }

    func testPerUnit_DurationIgnored() {
        // Per-unit pricing doesn't depend on duration
        let adapter = TestFalKlingPerUnit()
        let cost5 = adapter.getCostEstimate(request: costRequest(durationSeconds: 5, numberOfVideos: 1))
        let cost10 = adapter.getCostEstimate(request: costRequest(durationSeconds: 10, numberOfVideos: 1))
        XCTAssertEqual(cost5, cost10, "Per-unit cost should ignore duration")
    }

    func testPerUnit_5Videos_Returns0070() {
        let adapter = TestFalKlingPerUnit()
        let cost = adapter.getCostEstimate(request: costRequest(numberOfVideos: 5))
        XCTAssertEqual(cost, 0.070, accuracy: 0.0001)
    }

    func testPerUnit_CustomCostPerUnit() {
        let adapter = TestFalKlingPerUnit(costPerUnit: 0.05)
        let cost = adapter.getCostEstimate(request: costRequest(numberOfVideos: 3))
        XCTAssertEqual(cost, 0.15, accuracy: 0.001)
    }

    func testPerUnit_FormatCost_NonEmpty() {
        let adapter = TestFalKlingPerUnit()
        let formatted = adapter.formatCost(request: costRequest(numberOfVideos: 1))
        XCTAssertFalse(formatted.isEmpty)
    }
}

// MARK: - FalSoraBase Per-Second Cost Tests

final class FalSoraCostTests: XCTestCase {
    private func costRequest(
        durationSeconds: Int? = nil,
        numberOfVideos: Int? = nil
    ) -> VideoGenerationCostRequest {
        VideoGenerationCostRequest(
            durationSeconds: durationSeconds,
            numberOfVideos: numberOfVideos
        )
    }

    func testSora_5Sec_Returns050() {
        let adapter = TestFalSora()
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 5))
        XCTAssertEqual(cost, 0.50, accuracy: 0.001)
    }

    func testSora_10Sec_Returns100() {
        let adapter = TestFalSora()
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 10))
        XCTAssertEqual(cost, 1.00, accuracy: 0.001)
    }

    func testSora_4Sec_Returns040() {
        let adapter = TestFalSora()
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 4))
        XCTAssertEqual(cost, 0.40, accuracy: 0.001)
    }

    func testSora_2Videos_5Sec_Returns100() {
        let adapter = TestFalSora()
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 5, numberOfVideos: 2))
        XCTAssertEqual(cost, 1.00, accuracy: 0.001)
    }

    func testSora_NilNumberOfVideos_DefaultsToOne() {
        let adapter = TestFalSora()
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 5, numberOfVideos: nil))
        XCTAssertEqual(cost, 0.50, accuracy: 0.001)
    }

    func testSora_ZeroDuration_ReturnsZero() {
        let adapter = TestFalSora()
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 0))
        XCTAssertEqual(cost, 0.0, accuracy: 0.001)
    }

    func testSora_CostPerSecond_Is010() {
        let adapter = TestFalSora()
        XCTAssertEqual(adapter.costPerSecond, 0.10, accuracy: 0.001)
    }

    func testSora_DurationScaling_Linear() {
        let adapter = TestFalSora()
        let cost4 = adapter.getCostEstimate(request: costRequest(durationSeconds: 4))
        let cost8 = adapter.getCostEstimate(request: costRequest(durationSeconds: 8))
        let cost12 = adapter.getCostEstimate(request: costRequest(durationSeconds: 12))
        XCTAssertEqual(cost8, cost4 * 2, accuracy: 0.001)
        XCTAssertEqual(cost12, cost4 * 3, accuracy: 0.001)
    }

    func testSora_FormatCost_ProducesDollarString() {
        let adapter = TestFalSora()
        let formatted = adapter.formatCost(request: costRequest(durationSeconds: 5))
        XCTAssertTrue(formatted.contains("$"), "Expected dollar sign in formatted cost: \(formatted)")
    }

    func testSora_FormatCost_Zero_ReturnsFree() {
        let adapter = TestFalSora()
        let formatted = adapter.formatCost(request: costRequest(durationSeconds: 0))
        XCTAssertEqual(formatted, "Free")
    }
}

// MARK: - FalRecraftBase Flat Cost Tests

final class FalRecraftCostTests: XCTestCase {
    private func costRequest(numberOfImages: Int? = nil) -> ImageGenerationCostRequest {
        ImageGenerationCostRequest(numberOfImages: numberOfImages)
    }

    func testRecraft_1Image_Returns004() {
        let adapter = TestFalRecraft()
        let cost = adapter.getCostEstimate(request: costRequest(numberOfImages: 1))
        XCTAssertEqual(cost, 0.04, accuracy: 0.001)
    }

    func testRecraft_5Images_Returns020() {
        let adapter = TestFalRecraft()
        let cost = adapter.getCostEstimate(request: costRequest(numberOfImages: 5))
        XCTAssertEqual(cost, 0.20, accuracy: 0.001)
    }

    func testRecraft_NilNumberOfImages_DefaultsToOne() {
        let adapter = TestFalRecraft()
        let cost = adapter.getCostEstimate(request: costRequest(numberOfImages: nil))
        XCTAssertEqual(cost, 0.04, accuracy: 0.001)
    }

    func testRecraft_3Images_Returns012() {
        let adapter = TestFalRecraft()
        let cost = adapter.getCostEstimate(request: costRequest(numberOfImages: 3))
        XCTAssertEqual(cost, 0.12, accuracy: 0.001)
    }

    func testRecraft_BaseCost_Is004() {
        let adapter = TestFalRecraft()
        XCTAssertEqual(adapter.baseCost, 0.04, accuracy: 0.001)
    }

    func testRecraft_FormatCost_ProducesDollarString() {
        let adapter = TestFalRecraft()
        let formatted = adapter.formatCost(request: costRequest(numberOfImages: 1))
        XCTAssertTrue(formatted.contains("$"), "Expected dollar sign: \(formatted)")
    }

    func testRecraft_FormatCost_Zero_NotFree() {
        // Recraft always has baseCost > 0, so 1 image is always non-free
        let adapter = TestFalRecraft()
        let formatted = adapter.formatCost(request: costRequest(numberOfImages: 1))
        XCTAssertNotEqual(formatted, "Free")
    }

    // MARK: - Custom baseCost Override

    func testRecraft_CustomBaseCost_OverridesDefault() {
        let adapter = TestFalRecraftCustomCost(baseCost: 0.08)
        let cost = adapter.getCostEstimate(request: costRequest(numberOfImages: 1))
        XCTAssertEqual(cost, 0.08, accuracy: 0.001)
    }

    func testRecraft_CustomBaseCost_3Images() {
        let adapter = TestFalRecraftCustomCost(baseCost: 0.08)
        let cost = adapter.getCostEstimate(request: costRequest(numberOfImages: 3))
        XCTAssertEqual(cost, 0.24, accuracy: 0.001)
    }

    func testRecraft_Determinism_SameRequestSameResult() {
        let adapter = TestFalRecraft()
        let req = costRequest(numberOfImages: 3)
        let cost1 = adapter.getCostEstimate(request: req)
        let cost2 = adapter.getCostEstimate(request: req)
        XCTAssertEqual(cost1, cost2)
    }
}

// MARK: - Cross-Fal Adapter Cost Comparisons

final class FalCrossAdapterCostTests: XCTestCase {
    func testKlingPerSecond_MoreExpensiveThanPerUnit_AtTypicalDuration() {
        // Kling per-second at 5 sec, $0.28/sec = $1.40
        // Kling per-unit at any duration = $0.014
        let perSecond = TestFalKlingPerSecond(costPerSecond: 0.28)
        let perUnit = TestFalKlingPerUnit()
        let req = VideoGenerationCostRequest(durationSeconds: 5, numberOfVideos: 1)
        XCTAssertGreaterThan(
            perSecond.getCostEstimate(request: req),
            perUnit.getCostEstimate(request: req)
        )
    }

    func testFalSora_CheaperThanKlingMaster_SameDuration() {
        // Sora: $0.10/sec, Kling Master: $0.28/sec
        let sora = TestFalSora()
        let klingMaster = TestFalKlingPerSecond(costPerSecond: 0.28)
        let req = VideoGenerationCostRequest(durationSeconds: 5, numberOfVideos: 1)
        XCTAssertLessThan(
            sora.getCostEstimate(request: req),
            klingMaster.getCostEstimate(request: req)
        )
    }

    func testFalSora_MoreExpensiveThanKlingStandard_SameDuration() {
        // Sora: $0.10/sec, Kling Standard: $0.05/sec
        let sora = TestFalSora()
        let klingStandard = TestFalKlingPerSecond(costPerSecond: 0.05)
        let req = VideoGenerationCostRequest(durationSeconds: 5, numberOfVideos: 1)
        XCTAssertGreaterThan(
            sora.getCostEstimate(request: req),
            klingStandard.getCostEstimate(request: req)
        )
    }

    func testAllFalAdapters_NonNegativeCost() {
        let perSecond = TestFalKlingPerSecond(costPerSecond: 0.28)
        let perUnit = TestFalKlingPerUnit()
        let sora = TestFalSora()
        let recraft = TestFalRecraft()

        let videoReq = VideoGenerationCostRequest(durationSeconds: 5, numberOfVideos: 1)
        let imageReq = ImageGenerationCostRequest(numberOfImages: 1)

        XCTAssertGreaterThanOrEqual(perSecond.getCostEstimate(request: videoReq), 0)
        XCTAssertGreaterThanOrEqual(perUnit.getCostEstimate(request: videoReq), 0)
        XCTAssertGreaterThanOrEqual(sora.getCostEstimate(request: videoReq), 0)
        XCTAssertGreaterThanOrEqual(recraft.getCostEstimate(request: imageReq), 0)
    }
}
