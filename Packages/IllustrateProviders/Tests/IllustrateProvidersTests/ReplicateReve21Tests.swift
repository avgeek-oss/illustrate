import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Replicate Reve 2.1 adapter", .serialized)
struct ReplicateReve21Tests {
    @Test("Posts documented Replicate request envelope")
    func postsDocumentedRequest() async throws {
        let mock = ReplicateReve21MockNetworkProvider()
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: ReplicateReve21TestModelProvider()
        ) {
            try await G_REPLICATE_REVE_2_1().makeRequest(
                request: imageRequest(dimensions: "3:1")
            )
        }

        let body = try #require(mock.capturedBodyData)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let input = try #require(json["input"] as? [String: Any])

        #expect(mock.capturedURL?
            .absoluteString == "https://api.replicate.com/v1/models/reve/reve-2.1/predictions")
        #expect(mock.capturedMethod == "POST")
        #expect(mock.capturedHeaders?["Authorization"] == "Bearer replicate-test")
        #expect(input["prompt"] as? String == "A typographic airline poster.")
        #expect(input["reference_images"] == nil)
        #expect(input["aspect_ratio"] as? String == "3:1")
        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "stubbed replicate response")
    }

    @Test("Builds documented text-to-image payload")
    func buildsTextPayload() {
        let input = G_REPLICATE_REVE_2_1().buildInput(
            request: imageRequest(dimensions: "1920x1080"),
            sourceImageURL: nil,
            maskURL: nil,
            referenceImageURLs: []
        )

        #expect(input.prompt == "A typographic airline poster.")
        #expect(input.reference_images == nil)
        #expect(input.aspect_ratio == "16:9")
    }

    @Test("Builds ordered edit payload at eight-image combined limit")
    func buildsReferencePayload() {
        let references = (0 ..< 7).map { "https://files.example/reference-\($0).png" }
        let input = G_REPLICATE_REVE_2_1().buildInput(
            request: imageRequest(dimensions: "4:1"),
            sourceImageURL: "https://files.example/source.png",
            maskURL: nil,
            referenceImageURLs: references
        )

        #expect(input.reference_images?.count == 8)
        #expect(input.reference_images?.first == "https://files.example/source.png")
        #expect(input.reference_images?.last == "https://files.example/reference-6.png")
        #expect(input.aspect_ratio == "4:1")
    }

    @Test("Estimates documented per-image price")
    func estimatesCost() {
        let adapter = G_REPLICATE_REVE_2_1()

        #expect(abs(adapter.getCostEstimate(
            request: ImageGenerationCostRequest(numberOfImages: 3)
        ) - 0.60) < 0.0001)
        #expect(adapter.formatCost(
            request: ImageGenerationCostRequest(numberOfImages: 3)
        ) == "$0.6")
    }

    @Test("Parses single-image data URI output")
    func parsesDataURIOutput() throws {
        let response = try G_REPLICATE_REVE_2_1().transformResponse(
            request: imageRequest(),
            response: .dictionary(statusCode: 200, data: [
                "status": "succeeded",
                "output": "data:image/png;base64,aW1hZ2U=",
            ])
        )

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "aW1hZ2U=")
        #expect(abs((response.cost ?? 0) - 0.20) < 0.0001)
    }

    @Test("Maps provider errors")
    func mapsProviderError() throws {
        let response = try G_REPLICATE_REVE_2_1().transformResponse(
            request: imageRequest(),
            response: .dictionary(statusCode: 200, data: [
                "status": "failed",
                "error": "reference image rejected",
            ])
        )

        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "reference image rejected")
    }

    @Test("Registers verified model metadata")
    func registersMetadata() throws {
        let model = try #require(
            ReplicateModels.createModels().first { $0.modelCode == .REPLICATE_REVE_2_1 }
        )

        #expect(model.modelName == "Reve 2.1")
        #expect(model.modelGenerateBaseURL == "https://api.replicate.com/v1/models/reve/reve-2.1/predictions")
        #expect(model.modelStatusBaseURL == "https://api.replicate.com/v1/predictions")
        #expect(model.modelAPIDocumentationURL == "https://replicate.com/reve/reve-2.1/api")
        #expect(model.modelParams.maxGenerations == 1)
        #expect(model.modelParams.maxReferenceImages == 8)
        #expect(model.modelParams.supportedDimensions.contains("auto"))
        #expect(model.modelParams.supportedDimensions.contains("1:4"))
        #expect(model.modelParams.supportsSourceImage)
        #expect(model.modelLaunchDate == getDateFromString("2026-07-09"))
        #expect(model.modelVerificationDate == getDateFromString("2026-07-28"))
        #expect(model.pricingMetadata?.unit == .image)
        #expect(model.pricingMetadata?.notes == "$0.20 per output image.")
        #expect(model.active)
    }

    private func imageRequest(
        dimensions: String = "1:1",
        numberOfImages: Int = 1
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: EnumProviderModelCode.REPLICATE_REVE_2_1.modelId.uuidString,
            prompt: "A typographic airline poster.",
            dimensions: dimensions,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.REPLICATE.providerId,
                providerCode: .REPLICATE,
                projectId: UUID()
            ),
            providerSecret: "replicate-test",
            numberOfImages: numberOfImages
        )
    }
}

private final class ReplicateReve21MockNetworkProvider: @unchecked Sendable, NetworkProvider {
    var capturedURL: URL?
    var capturedMethod: String?
    var capturedBodyData: Data?
    var capturedHeaders: [String: String]?

    func performRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments _: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        capturedURL = url
        capturedMethod = method
        capturedHeaders = headers
        if let body {
            capturedBodyData = try JSONEncoder().encode(body)
        }
        return .dictionary(statusCode: 400, data: ["error": "stubbed replicate response"])
    }
}

private struct ReplicateReve21TestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        ReplicateModels.createModels().first { $0.modelCode == code }
    }
}
