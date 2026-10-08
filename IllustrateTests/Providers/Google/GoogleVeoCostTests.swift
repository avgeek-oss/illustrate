// MARK: - GoogleVeoCostTests.swift

// Cost estimation tests for Google Veo video generation models.
//
// Tests cover:
// - getCostEstimate(): model variants with resolution-aware per-second pricing
// - Model-tier cost differentiation (Standard, Fast, Lite, and deprecated Veo 2)
// - formatCost(): USD formatting
// - Duration and resolution constraints before API submission
// - Duration and video count scaling workflows
// - Cross-model cost ordering invariants

import XCTest
@testable import IllustrateProviders

final class GoogleVeoCostTests: XCTestCase {
    // MARK: - Helpers

    private func makeVeo(_ modelCode: EnumProviderModelCode) -> G_GOOGLE_VEO_BASE {
        G_GOOGLE_VEO_BASE(modelCode: modelCode)
    }

    private func costRequest(
        durationSeconds: Int? = nil,
        numberOfVideos: Int? = nil,
        dimensions: String? = nil,
        resolution: String? = nil,
        hasReferenceImages: Bool = false
    ) -> VideoGenerationCostRequest {
        VideoGenerationCostRequest(
            dimensions: dimensions,
            durationSeconds: durationSeconds,
            numberOfVideos: numberOfVideos,
            resolution: resolution,
            hasReferenceImages: hasReferenceImages
        )
    }

    private func videoRequest(
        modelCode: EnumProviderModelCode = .GOOGLE_VEO_31,
        dimensions: String = "16:9",
        durationSeconds: Int? = 8,
        resolution: String? = "720p",
        clientReferenceImages: [ReferenceImageData]? = nil,
        sourceMetadata: [String: String]? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: modelCode.rawValue,
            prompt: "A cinematic aircraft hangar reveal.",
            dimensions: dimensions,
            clientReferenceImages: clientReferenceImages,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                providerCode: .GOOGLE_CLOUD,
                projectId: UUID()
            ),
            providerSecret: "AIza-test",
            durationSeconds: durationSeconds,
            resolution: resolution,
            sourceMetadata: sourceMetadata
        )
    }

    // MARK: - Veo 3.1 / Veo 3 Standard ($0.40/sec)

    func testVeo31_8Sec_Returns320() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 8))
        XCTAssertEqual(cost, 3.20, accuracy: 0.001)
    }

    func testVeo3_5Sec_Returns200() {
        let adapter = makeVeo(.GOOGLE_VEO_3)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 5))
        XCTAssertEqual(cost, 2.00, accuracy: 0.001)
    }

    func testVeo31Extend_4Sec_UsesEightSecondMinimum() {
        let adapter = makeVeo(.GOOGLE_VEO_31_EXTEND)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 4))
        XCTAssertEqual(cost, 3.20, accuracy: 0.001)
    }

    func testVeo31_2Videos_8Sec_Returns640() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 8, numberOfVideos: 2))
        XCTAssertEqual(cost, 6.40, accuracy: 0.001)
    }

    func testVeo31_4K_8Sec_Returns480() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "4K"))
        XCTAssertEqual(cost, 4.80, accuracy: 0.001)
    }

    func testVeo31_1080p4Sec_UsesEightSecondMinimum() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 4, resolution: "1080p"))
        XCTAssertEqual(cost, 3.20, accuracy: 0.001)
    }

    func testVeo31_720pReferenceImage4Sec_UsesEightSecondMinimum() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let cost = adapter.getCostEstimate(
            request: costRequest(durationSeconds: 4, resolution: "720p", hasReferenceImages: true)
        )
        XCTAssertEqual(cost, 3.20, accuracy: 0.001)
    }

    func testVeo31_ReferenceImageVideoRequest_UsesEightSecondMinimum() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let request = VideoGenerationCostRequest(
            from: videoRequest(
                durationSeconds: 4,
                resolution: "720p",
                clientReferenceImages: [
                    ReferenceImageData(base64Image: "data:image/png;base64,AAAA", referenceType: "asset"),
                ]
            )
        )

        XCTAssertTrue(request.hasReferenceImages)
        XCTAssertEqual(adapter.getCostEstimate(request: request), 3.20, accuracy: 0.001)
    }

    // MARK: - Veo 3.1 Fast / Veo 3 Fast (resolution-aware)

    func testVeo31Fast_720p8Sec_Returns080() {
        let adapter = makeVeo(.GOOGLE_VEO_31_FAST)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 8))
        XCTAssertEqual(cost, 0.80, accuracy: 0.001)
    }

    func testVeo31Fast_1080p8Sec_Returns096() {
        let adapter = makeVeo(.GOOGLE_VEO_31_FAST)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "1080p"))
        XCTAssertEqual(cost, 0.96, accuracy: 0.001)
    }

    func testVeo31Fast_4K8Sec_Returns240() {
        let adapter = makeVeo(.GOOGLE_VEO_31_FAST)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "4k"))
        XCTAssertEqual(cost, 2.40, accuracy: 0.001)
    }

    func testVeo31Fast_720pReferenceImage4Sec_UsesEightSecondMinimum() {
        let adapter = makeVeo(.GOOGLE_VEO_31_FAST)
        let cost = adapter.getCostEstimate(
            request: costRequest(durationSeconds: 4, resolution: "720p", hasReferenceImages: true)
        )
        XCTAssertEqual(cost, 0.80, accuracy: 0.001)
    }

    func testVeo3Fast_10Sec_Returns100() {
        let adapter = makeVeo(.GOOGLE_VEO_3_FAST)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 10))
        XCTAssertEqual(cost, 1.00, accuracy: 0.001)
    }

    func testVeo31FastExtend_4Sec_UsesEightSecondMinimum() {
        let adapter = makeVeo(.GOOGLE_VEO_31_FAST_EXTEND)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 4))
        XCTAssertEqual(cost, 0.80, accuracy: 0.001)
    }

    // MARK: - Veo 3.1 Lite

    func testVeo31Lite_720p8Sec_Returns040() {
        let adapter = makeVeo(.GOOGLE_VEO_31_LITE)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "720p"))
        XCTAssertEqual(cost, 0.40, accuracy: 0.001)
    }

    func testVeo31Lite_1080p8Sec_Returns064() {
        let adapter = makeVeo(.GOOGLE_VEO_31_LITE)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "1080p"))
        XCTAssertEqual(cost, 0.64, accuracy: 0.001)
    }

    func testVeo31Lite_4KRequestFallsBackTo720pCost() {
        let adapter = makeVeo(.GOOGLE_VEO_31_LITE)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "4k"))
        XCTAssertEqual(cost, 0.40, accuracy: 0.001)
    }

    // MARK: - Veo 2 ($0.35/sec)

    func testVeo2_8Sec_Returns280() {
        let adapter = makeVeo(.GOOGLE_VEO_2)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 8))
        XCTAssertEqual(cost, 2.80, accuracy: 0.001)
    }

    func testVeo2_4Sec_Returns140() {
        let adapter = makeVeo(.GOOGLE_VEO_2)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 4))
        XCTAssertEqual(cost, 1.40, accuracy: 0.001)
    }

    // MARK: - Default Fallback ($0.40/sec)

    func testDefaultModelCode_FallsBackTo040PerSec() {
        // Use a non-Veo model code to trigger default branch
        let adapter = makeVeo(.OPENAI_DALLE3)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 10))
        XCTAssertEqual(cost, 4.00, accuracy: 0.001)
    }

    // MARK: - Edge Cases

    func testNilNumberOfVideos_DefaultsToOne() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 8, numberOfVideos: nil))
        XCTAssertEqual(cost, 3.20, accuracy: 0.001)
    }

    func testZeroDuration_ReturnsZero() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 0))
        XCTAssertEqual(cost, 0.0, accuracy: 0.001)
    }

    func testOneSecondVideo_ReturnsPerSecondRate() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 1))
        XCTAssertEqual(cost, 0.40, accuracy: 0.001)
    }

    func testOneSecondVideo_Fast_ReturnsPerSecondRate() {
        let adapter = makeVeo(.GOOGLE_VEO_31_FAST)
        let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 1))
        XCTAssertEqual(cost, 0.10, accuracy: 0.001)
    }

    // MARK: - formatCost Tests

    func testFormatCost_320_FormatsCorrectly() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let formatted = adapter.formatCost(request: costRequest(durationSeconds: 8))
        XCTAssertEqual(formatted, "$3.2")
    }

    func testFormatCost_080_FormatsCorrectly() {
        let adapter = makeVeo(.GOOGLE_VEO_31_FAST_EXTEND)
        let formatted = adapter.formatCost(request: costRequest(durationSeconds: 4))
        XCTAssertEqual(formatted, "$0.8")
    }

    func testFormatCost_Zero_ReturnsFree() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let formatted = adapter.formatCost(request: costRequest(durationSeconds: 0))
        XCTAssertEqual(formatted, "Free")
    }

    // MARK: - Cost Ordering Workflows

    func testWorkflow_FastCheaperThanStandard_SameDuration() {
        let standard = makeVeo(.GOOGLE_VEO_31)
        let fast = makeVeo(.GOOGLE_VEO_31_FAST)
        let req = costRequest(durationSeconds: 8)
        XCTAssertLessThan(
            fast.getCostEstimate(request: req),
            standard.getCostEstimate(request: req)
        )
    }

    func testWorkflow_Veo2_BetweenFastAndStandard() {
        let fast = makeVeo(.GOOGLE_VEO_31_FAST)
        let veo2 = makeVeo(.GOOGLE_VEO_2)
        let standard = makeVeo(.GOOGLE_VEO_31)
        let req = costRequest(durationSeconds: 8)

        let fastCost = fast.getCostEstimate(request: req)
        let veo2Cost = veo2.getCostEstimate(request: req)
        let standardCost = standard.getCostEstimate(request: req)

        XCTAssertLessThan(fastCost, veo2Cost)
        XCTAssertLessThan(veo2Cost, standardCost)
    }

    func testWorkflow_DoublingDuration_DoublesCost() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let cost4 = adapter.getCostEstimate(request: costRequest(durationSeconds: 4))
        let cost8 = adapter.getCostEstimate(request: costRequest(durationSeconds: 8))
        XCTAssertEqual(cost8, cost4 * 2, accuracy: 0.001)
    }

    func testWorkflow_TriplingVideos_TriplesCost() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let cost1 = adapter.getCostEstimate(request: costRequest(durationSeconds: 8, numberOfVideos: 1))
        let cost3 = adapter.getCostEstimate(request: costRequest(durationSeconds: 8, numberOfVideos: 3))
        XCTAssertEqual(cost3, cost1 * 3, accuracy: 0.001)
    }

    func testWorkflow_AllModelCodes_CostOrdering_SameDuration() {
        // At 8 seconds, each model should use its documented 720p/default per-second rate.
        let modelCosts: [(EnumProviderModelCode, Double)] = [
            (.GOOGLE_VEO_31_FAST, 0.10),
            (.GOOGLE_VEO_3_FAST, 0.10),
            (.GOOGLE_VEO_31_FAST_EXTEND, 0.10),
            (.GOOGLE_VEO_31_LITE, 0.05),
            (.GOOGLE_VEO_2, 0.35),
            (.GOOGLE_VEO_31, 0.40),
            (.GOOGLE_VEO_3, 0.40),
            (.GOOGLE_VEO_31_EXTEND, 0.40),
        ]

        let req = costRequest(durationSeconds: 8)
        for (code, expectedRate) in modelCosts {
            let adapter = makeVeo(code)
            let cost = adapter.getCostEstimate(request: req)
            XCTAssertEqual(cost, expectedRate * 8, accuracy: 0.001, "\(code) should cost \(expectedRate)/sec")
        }
    }

    func testWorkflow_AllModels_NonNegativeCost() {
        let models: [EnumProviderModelCode] = [
            .GOOGLE_VEO_31, .GOOGLE_VEO_31_EXTEND,
            .GOOGLE_VEO_31_FAST, .GOOGLE_VEO_31_FAST_EXTEND,
            .GOOGLE_VEO_31_LITE,
            .GOOGLE_VEO_3, .GOOGLE_VEO_3_FAST,
            .GOOGLE_VEO_2,
        ]
        for code in models {
            let adapter = makeVeo(code)
            let cost = adapter.getCostEstimate(request: costRequest(durationSeconds: 5))
            XCTAssertGreaterThanOrEqual(cost, 0, "\(code) should produce non-negative cost")
        }
    }

    func testWorkflow_Determinism_SameRequestSameResult() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let req = costRequest(durationSeconds: 8, numberOfVideos: 2)
        let cost1 = adapter.getCostEstimate(request: req)
        let cost2 = adapter.getCostEstimate(request: req)
        XCTAssertEqual(cost1, cost2)
    }

    // MARK: - Request Constraints

    func testTransformRequest_4KForcesEightSeconds() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let request = videoRequest(durationSeconds: 4, resolution: "4K")
        let transformed = adapter.transformRequest(request: request)

        XCTAssertEqual(transformed.parameters?.resolution, "4k")
        XCTAssertEqual(transformed.parameters?.durationSeconds, 8)
    }

    func testTransformRequest_LiteRejects4KByFallingBackTo720p() {
        let adapter = makeVeo(.GOOGLE_VEO_31_LITE)
        let request = videoRequest(modelCode: .GOOGLE_VEO_31_LITE, durationSeconds: 8, resolution: "4k")
        let transformed = adapter.transformRequest(request: request)

        XCTAssertEqual(transformed.parameters?.resolution, "720p")
        XCTAssertEqual(transformed.parameters?.durationSeconds, 8)
    }

    func testTransformRequest_ExtendForces720pAndEightSeconds() {
        let adapter = makeVeo(.GOOGLE_VEO_31_EXTEND)
        let request = videoRequest(
            modelCode: .GOOGLE_VEO_31_EXTEND,
            durationSeconds: 4,
            resolution: "4k",
            sourceMetadata: [G_GOOGLE_VEO_BASE.veoGeneratedUriKey: "https://example.com/video.mp4"]
        )
        let transformed = adapter.transformRequest(request: request)

        XCTAssertEqual(transformed.parameters?.resolution, "720p")
        XCTAssertEqual(transformed.parameters?.durationSeconds, 8)
        XCTAssertEqual(transformed.instances.first?.video?.uri, "https://example.com/video.mp4")
    }

    func testTransformRequest_ReferenceImagesForceEightSeconds() {
        let adapter = makeVeo(.GOOGLE_VEO_31)
        let request = videoRequest(
            durationSeconds: 4,
            resolution: "720p",
            clientReferenceImages: [
                ReferenceImageData(base64Image: "data:image/png;base64,AAAA", referenceType: "asset"),
            ]
        )
        let transformed = adapter.transformRequest(request: request)

        XCTAssertEqual(transformed.parameters?.durationSeconds, 8)
    }
}
