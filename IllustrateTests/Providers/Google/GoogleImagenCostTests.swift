// MARK: - GoogleImagenCostTests.swift

// Cost estimation and request transformation tests for Google Imagen models.
//
// Tests cover:
// - getCostEstimate(): 4 model variants with quality-tier branching
// - formatCost(): USD formatting with $X.XX pattern
// - transformRequest(): aspect ratio conversion, imageSize quality mapping
// - Cross-model cost ordering and scaling workflows

import XCTest
@testable import IllustrateProviders

final class GoogleImagenCostTests: XCTestCase {
    // MARK: - Helpers

    private func makeImagen(
        _ modelCode: EnumProviderModelCode,
        costPerImage: Double = 0.03,
        supportsImageSize: Bool = false
    ) -> G_GOOGLE_IMAGEN_BASE {
        G_GOOGLE_IMAGEN_BASE(
            modelCode: modelCode,
            costPerImage: costPerImage,
            supportsImageSize: supportsImageSize
        )
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

    // MARK: - Imagen 3 Cost Tests ($0.03/image, ignores quality)

    func testImagen3_SingleImage_Returns003() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_3)
        let cost = adapter.getCostEstimate(request: costRequest(numberOfImages: 1))
        XCTAssertEqual(cost, 0.03, accuracy: 0.0001)
    }

    func testImagen3_ThreeImages_Returns009() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_3)
        let cost = adapter.getCostEstimate(request: costRequest(numberOfImages: 3))
        XCTAssertEqual(cost, 0.09, accuracy: 0.0001)
    }

    func testImagen3_NilNumberOfImages_DefaultsToOne() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_3)
        let cost = adapter.getCostEstimate(request: costRequest())
        XCTAssertEqual(cost, 0.03, accuracy: 0.0001)
    }

    func testImagen3_Quality2K_StillReturns003() {
        // Imagen 3 has no quality tier — "2K" is irrelevant
        let adapter = makeImagen(.GOOGLE_IMAGEN_3)
        let cost = adapter.getCostEstimate(request: costRequest(quality: "2K", numberOfImages: 1))
        XCTAssertEqual(cost, 0.03, accuracy: 0.0001)
    }

    // MARK: - Imagen 4 Fast Cost Tests ($0.02/image)

    func testImagen4Fast_SingleImage_Returns002() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_FAST, costPerImage: 0.02)
        let cost = adapter.getCostEstimate(request: costRequest(numberOfImages: 1))
        XCTAssertEqual(cost, 0.02, accuracy: 0.0001)
    }

    func testImagen4Fast_FiveImages_Returns010() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_FAST, costPerImage: 0.02)
        let cost = adapter.getCostEstimate(request: costRequest(numberOfImages: 5))
        XCTAssertEqual(cost, 0.10, accuracy: 0.0001)
    }

    // MARK: - Imagen 4 Standard Cost Tests ($0.04 standard, $0.08 2K)

    func testImagen4Standard_StandardQuality_Returns004() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_STANDARD, costPerImage: 0.04, supportsImageSize: true)
        let cost = adapter.getCostEstimate(request: costRequest(quality: "standard", numberOfImages: 1))
        XCTAssertEqual(cost, 0.04, accuracy: 0.0001)
    }

    func testImagen4Standard_2KQuality_Returns008() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_STANDARD, costPerImage: 0.04, supportsImageSize: true)
        let cost = adapter.getCostEstimate(request: costRequest(quality: "2K", numberOfImages: 1))
        XCTAssertEqual(cost, 0.08, accuracy: 0.0001)
    }

    func testImagen4Standard_2KQuality_ThreeImages_Returns024() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_STANDARD, costPerImage: 0.04, supportsImageSize: true)
        let cost = adapter.getCostEstimate(request: costRequest(quality: "2K", numberOfImages: 3))
        XCTAssertEqual(cost, 0.24, accuracy: 0.0001)
    }

    func testImagen4Standard_NilQuality_DefaultsToStandard() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_STANDARD, costPerImage: 0.04, supportsImageSize: true)
        let cost = adapter.getCostEstimate(request: costRequest(numberOfImages: 1))
        XCTAssertEqual(cost, 0.04, accuracy: 0.0001)
    }

    func testImagen4Standard_Lowercase2k_UppercasedComparison() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_STANDARD, costPerImage: 0.04, supportsImageSize: true)
        let cost = adapter.getCostEstimate(request: costRequest(quality: "2k", numberOfImages: 1))
        XCTAssertEqual(cost, 0.08, accuracy: 0.0001)
    }

    // MARK: - Imagen 4 Ultra Cost Tests ($0.06 standard, $0.12 2K)

    func testImagen4Ultra_StandardQuality_Returns006() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_ULTRA, costPerImage: 0.06, supportsImageSize: true)
        let cost = adapter.getCostEstimate(request: costRequest(quality: "standard", numberOfImages: 1))
        XCTAssertEqual(cost, 0.06, accuracy: 0.0001)
    }

    func testImagen4Ultra_2KQuality_Returns012() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_ULTRA, costPerImage: 0.06, supportsImageSize: true)
        let cost = adapter.getCostEstimate(request: costRequest(quality: "2K", numberOfImages: 1))
        XCTAssertEqual(cost, 0.12, accuracy: 0.0001)
    }

    func testImagen4Ultra_2KQuality_TwoImages_Returns024() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_ULTRA, costPerImage: 0.06, supportsImageSize: true)
        let cost = adapter.getCostEstimate(request: costRequest(quality: "2K", numberOfImages: 2))
        XCTAssertEqual(cost, 0.24, accuracy: 0.0001)
    }

    func testImagen4Ultra_NilQuality_DefaultsToStandard() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_ULTRA, costPerImage: 0.06, supportsImageSize: true)
        let cost = adapter.getCostEstimate(request: costRequest(numberOfImages: 1))
        XCTAssertEqual(cost, 0.06, accuracy: 0.0001)
    }

    // MARK: - Default Model Code Fallback

    func testDefaultModelCode_FallsBackTo003() {
        // Use a model code that doesn't match any Imagen case
        let adapter = makeImagen(.OPENAI_DALLE3)
        let cost = adapter.getCostEstimate(request: costRequest(numberOfImages: 1))
        XCTAssertEqual(cost, 0.03, accuracy: 0.0001)
    }

    // MARK: - formatCost Tests

    func testFormatCost_Imagen3_SingleImage() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_3)
        let formatted = adapter.formatCost(request: costRequest(numberOfImages: 1))
        XCTAssertEqual(formatted, "$0.03")
    }

    func testFormatCost_Imagen4Ultra_2K() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_ULTRA, costPerImage: 0.06, supportsImageSize: true)
        let formatted = adapter.formatCost(request: costRequest(quality: "2K", numberOfImages: 1))
        XCTAssertEqual(formatted, "$0.12")
    }

    func testFormatCost_Imagen4Standard_ThreeImages() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_STANDARD, costPerImage: 0.04, supportsImageSize: true)
        let formatted = adapter.formatCost(request: costRequest(quality: "2K", numberOfImages: 3))
        XCTAssertEqual(formatted, "$0.24")
    }

    func testFormatCost_AllModels_ProducesNonEmptyString() {
        let models: [(EnumProviderModelCode, Double)] = [
            (.GOOGLE_IMAGEN_3, 0.03),
            (.GOOGLE_IMAGEN_4_FAST, 0.02),
            (.GOOGLE_IMAGEN_4_STANDARD, 0.04),
            (.GOOGLE_IMAGEN_4_ULTRA, 0.06),
        ]
        for (code, cost) in models {
            let adapter = makeImagen(code, costPerImage: cost)
            let formatted = adapter.formatCost(request: costRequest(numberOfImages: 1))
            XCTAssertFalse(formatted.isEmpty, "\(code) should produce non-empty format")
            XCTAssertTrue(formatted.hasPrefix("$"), "\(code) should use dollar format")
        }
    }

    // MARK: - transformRequest Tests

    func testTransformRequest_NoImageSize_AspectRatioOnly() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_3, supportsImageSize: false)
        let request = ImageGenerationRequest(
            modelId: "test",
            prompt: "a sunset",
            dimensions: "1920x1080",
            providerKey: ProviderKeyInfo(providerId: UUID(), providerCode: .GOOGLE_CLOUD, projectId: UUID()),
            providerSecret: "test"
        )
        let serviceReq = adapter.transformRequest(request: request)
        XCTAssertEqual(serviceReq.instances.count, 1)
        XCTAssertEqual(serviceReq.instances.first?.prompt, "a sunset")
        XCTAssertEqual(serviceReq.parameters?.aspectRatio, "16:9")
        XCTAssertNil(serviceReq.parameters?.imageSize)
    }

    func testTransformRequest_SupportsImageSize_2KQuality() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_STANDARD, costPerImage: 0.04, supportsImageSize: true)
        let request = ImageGenerationRequest(
            modelId: "test",
            prompt: "test",
            quality: "2K",
            dimensions: "1024x1024",
            providerKey: ProviderKeyInfo(providerId: UUID(), providerCode: .GOOGLE_CLOUD, projectId: UUID()),
            providerSecret: "test"
        )
        let serviceReq = adapter.transformRequest(request: request)
        XCTAssertEqual(serviceReq.parameters?.imageSize, "2K")
    }

    func testTransformRequest_SupportsImageSize_StandardQuality() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_STANDARD, costPerImage: 0.04, supportsImageSize: true)
        let request = ImageGenerationRequest(
            modelId: "test",
            prompt: "test",
            quality: "standard",
            dimensions: "1024x1024",
            providerKey: ProviderKeyInfo(providerId: UUID(), providerCode: .GOOGLE_CLOUD, projectId: UUID()),
            providerSecret: "test"
        )
        let serviceReq = adapter.transformRequest(request: request)
        XCTAssertEqual(serviceReq.parameters?.imageSize, "1K")
    }

    func testTransformRequest_SquareDimensions() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_3, supportsImageSize: false)
        let request = ImageGenerationRequest(
            modelId: "test",
            prompt: "test",
            dimensions: "1024x1024",
            providerKey: ProviderKeyInfo(providerId: UUID(), providerCode: .GOOGLE_CLOUD, projectId: UUID()),
            providerSecret: "test"
        )
        let serviceReq = adapter.transformRequest(request: request)
        XCTAssertEqual(serviceReq.parameters?.aspectRatio, "1:1")
    }

    func testTransformRequest_PersonGeneration_PassesThrough() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_3, supportsImageSize: false)
        let request = ImageGenerationRequest(
            modelId: "test",
            prompt: "test",
            dimensions: "1024x1024",
            providerKey: ProviderKeyInfo(providerId: UUID(), providerCode: .GOOGLE_CLOUD, projectId: UUID()),
            providerSecret: "test",
            personGeneration: "allow_adult"
        )
        let serviceReq = adapter.transformRequest(request: request)
        XCTAssertEqual(serviceReq.parameters?.personGeneration, "allow_adult")
    }

    func testTransformRequest_Seed_PassesThrough() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_3, supportsImageSize: false)
        let request = ImageGenerationRequest(
            modelId: "test",
            prompt: "test",
            dimensions: "1024x1024",
            providerKey: ProviderKeyInfo(providerId: UUID(), providerCode: .GOOGLE_CLOUD, projectId: UUID()),
            providerSecret: "test",
            seed: 42
        )
        let serviceReq = adapter.transformRequest(request: request)
        XCTAssertEqual(serviceReq.parameters?.seed, 42)
    }

    // MARK: - Cost Ordering & Scaling Workflows

    func testWorkflow_QualityUpgrade_DoublesCostForImagen4Standard() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_STANDARD, costPerImage: 0.04, supportsImageSize: true)
        let standardCost = adapter.getCostEstimate(request: costRequest(quality: "standard", numberOfImages: 1))
        let twokCost = adapter.getCostEstimate(request: costRequest(quality: "2K", numberOfImages: 1))
        XCTAssertEqual(twokCost, standardCost * 2, accuracy: 0.0001)
    }

    func testWorkflow_Ultra_MoreExpensiveThanStandard_SameQuality() {
        let standard = makeImagen(.GOOGLE_IMAGEN_4_STANDARD, costPerImage: 0.04, supportsImageSize: true)
        let ultra = makeImagen(.GOOGLE_IMAGEN_4_ULTRA, costPerImage: 0.06, supportsImageSize: true)

        let standardCost = standard.getCostEstimate(request: costRequest(quality: "standard", numberOfImages: 1))
        let ultraCost = ultra.getCostEstimate(request: costRequest(quality: "standard", numberOfImages: 1))
        XCTAssertGreaterThan(ultraCost, standardCost)

        let standard2K = standard.getCostEstimate(request: costRequest(quality: "2K", numberOfImages: 1))
        let ultra2K = ultra.getCostEstimate(request: costRequest(quality: "2K", numberOfImages: 1))
        XCTAssertGreaterThan(ultra2K, standard2K)
    }

    func testWorkflow_FastIsCheapest_GoogleImagenFamily() {
        let fast = makeImagen(.GOOGLE_IMAGEN_4_FAST, costPerImage: 0.02)
        let imagen3 = makeImagen(.GOOGLE_IMAGEN_3, costPerImage: 0.03)
        let standard = makeImagen(.GOOGLE_IMAGEN_4_STANDARD, costPerImage: 0.04, supportsImageSize: true)
        let ultra = makeImagen(.GOOGLE_IMAGEN_4_ULTRA, costPerImage: 0.06, supportsImageSize: true)

        let req = costRequest(numberOfImages: 1)
        let fastCost = fast.getCostEstimate(request: req)
        let imagen3Cost = imagen3.getCostEstimate(request: req)
        let standardCost = standard.getCostEstimate(request: req)
        let ultraCost = ultra.getCostEstimate(request: req)

        XCTAssertLessThan(fastCost, imagen3Cost)
        XCTAssertLessThan(imagen3Cost, standardCost)
        XCTAssertLessThan(standardCost, ultraCost)
    }

    func testWorkflow_ImageCountScaling_Linear() {
        let adapter = makeImagen(.GOOGLE_IMAGEN_4_STANDARD, costPerImage: 0.04, supportsImageSize: true)
        let cost1 = adapter.getCostEstimate(request: costRequest(numberOfImages: 1))
        let cost3 = adapter.getCostEstimate(request: costRequest(numberOfImages: 3))
        XCTAssertEqual(cost3, cost1 * 3, accuracy: 0.0001)
    }
}
