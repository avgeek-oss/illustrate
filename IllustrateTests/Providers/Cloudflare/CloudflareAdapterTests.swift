// MARK: - CloudflareAdapterTests.swift

import XCTest
@testable import IllustrateProviders

final class CloudflareAdapterTests: XCTestCase {
    private func makeRequest(
        dimensions: String = "1024x768",
        numberOfImages: Int = 1,
        steps: Int? = 12,
        seed: Int? = 12345,
        clientImage: String? = nil,
        referenceImages: [ReferenceImageData]? = nil
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: "cloudflare-test-model",
            prompt: "A glass greenhouse at sunrise",
            negativePrompt: "blurry",
            dimensions: dimensions,
            clientImage: clientImage,
            clientReferenceImages: referenceImages,
            providerKey: ProviderKeyInfo(
                providerId: UUID(),
                providerCode: .CLOUDFLARE_AI,
                projectId: UUID()
            ),
            providerSecret: #"{"account_id":"account","api_token":"token"}"#,
            numberOfImages: numberOfImages,
            steps: steps,
            guidance: 7.5,
            seed: seed
        )
    }

    func testTransformRequest_jsonUsesNumStepsAndIncludesSeed() {
        let adapter = G_CLOUDFLARE_SD_XL_BASE()
        let payload = adapter.transformRequest(request: makeRequest(clientImage: "source-image-base64"))

        XCTAssertNil(payload.steps)
        XCTAssertEqual(payload.num_steps, 12)
        XCTAssertEqual(payload.seed, 12345)
        XCTAssertEqual(payload.width, 1024)
        XCTAssertEqual(payload.height, 768)
        XCTAssertEqual(payload.negative_prompt, "blurry")
        XCTAssertNil(payload.image_b64)
    }

    func testTransformRequest_img2imgIncludesSourceImageB64() {
        let adapter = G_CLOUDFLARE_SD_15_IMG2IMG()
        let payload = adapter.transformRequest(
            request: makeRequest(clientImage: "data:image/png;base64,source-image-base64")
        )

        XCTAssertEqual(payload.num_steps, 12)
        XCTAssertEqual(payload.seed, 12345)
        XCTAssertEqual(payload.image_b64, "source-image-base64")
    }

    func testTransformRequest_multipartUsesStepsAndIncludesSeed() {
        let adapter = G_CLOUDFLARE_FLUX_2_DEV()
        let payload = adapter.transformRequest(request: makeRequest())

        XCTAssertEqual(payload.steps, 12)
        XCTAssertNil(payload.num_steps)
        XCTAssertEqual(payload.seed, 12345)
        XCTAssertEqual(payload.width, 1024)
        XCTAssertEqual(payload.height, 768)
    }

    func testTransformRequest_kleinModelsOmitFixedSteps() {
        let request = makeRequest(steps: 12)

        let klein4B = G_CLOUDFLARE_FLUX_2_KLEIN_4B().transformRequest(request: request)
        XCTAssertNil(klein4B.steps)
        XCTAssertNil(klein4B.num_steps)
        XCTAssertEqual(klein4B.seed, 12345)
        XCTAssertEqual(klein4B.width, 1024)
        XCTAssertEqual(klein4B.height, 768)

        let klein9B = G_CLOUDFLARE_FLUX_2_KLEIN_9B().transformRequest(request: request)
        XCTAssertNil(klein9B.steps)
        XCTAssertNil(klein9B.num_steps)
        XCTAssertEqual(klein9B.seed, 12345)
        XCTAssertEqual(klein9B.width, 1024)
        XCTAssertEqual(klein9B.height, 768)
    }

    func testMakeRequest_kleinMultipartReferenceImagesUseDocumentedNames() async throws {
        let mock = CloudflareMockNetworkProvider()
        let response = try await ProviderDependencies.shared.withDependencies(
            networkProvider: mock,
            modelProvider: CloudflareTestModelProvider()
        ) {
            try await G_CLOUDFLARE_FLUX_2_KLEIN_4B().makeRequest(request: makeRequest(
                clientImage: "data:image/jpeg;base64,c291cmNl",
                referenceImages: [
                    ReferenceImageData(base64Image: "cmVmMA==", mimeType: "image/png"),
                    ReferenceImageData(base64Image: "cmVmMQ==", mimeType: "image/webp"),
                    ReferenceImageData(base64Image: "cmVmMg==", mimeType: "image/png"),
                    ReferenceImageData(base64Image: "cmVmMw==", mimeType: "image/png"),
                ]
            ))
        }

        XCTAssertEqual(response.status, .GENERATED)
        XCTAssertEqual(
            mock.capturedURL?.absoluteString,
            "https://api.cloudflare.com/client/v4/accounts/account/ai/run/@cf/black-forest-labs/flux-2-klein-4b"
        )
        XCTAssertEqual(mock.capturedMethod, "POST")
        XCTAssertEqual(mock.capturedHeaders?["Authorization"], "Bearer token")
        XCTAssertEqual(mock.capturedHeaders?["Content-Type"], "multipart/form-data")

        let attachments = try XCTUnwrap(mock.capturedAttachments)
        XCTAssertEqual(attachments.map(\.name), [
            "input_image_0", "input_image_1", "input_image_2", "input_image_3",
        ])
        XCTAssertEqual(attachments.map(\.mimeType), [
            "image/jpeg", "image/png", "image/webp", "image/png",
        ])
        XCTAssertEqual(String(data: attachments[0].data, encoding: .utf8), "source")
        XCTAssertEqual(String(data: attachments[1].data, encoding: .utf8), "ref0")
        XCTAssertEqual(String(data: attachments[2].data, encoding: .utf8), "ref1")
        XCTAssertEqual(String(data: attachments[3].data, encoding: .utf8), "ref2")
    }

    func testTransformResponse_acceptsResultString() throws {
        let adapter = G_CLOUDFLARE_SD_XL_BASE()
        let response = try adapter.transformResponse(
            request: makeRequest(),
            response: .dictionary(statusCode: 200, data: ["result": "base64-image"])
        )

        XCTAssertEqual(response.status, .GENERATED)
        XCTAssertEqual(response.base64, "base64-image")
    }

    func testTransformResponse_acceptsBinaryImageResponse() throws {
        let adapter = G_CLOUDFLARE_SD_XL_BASE()
        let response = try adapter.transformResponse(
            request: makeRequest(),
            response: .image(statusCode: 200, base64: "binary-base64-image", mimeType: "image/png")
        )

        XCTAssertEqual(response.status, .GENERATED)
        XCTAssertEqual(response.base64, "binary-base64-image")
    }

    func testCloudflareModelsExposeSeedSupport() throws {
        let models = CloudflareAIModels.createModels()
        XCTAssertTrue(models.allSatisfy(\.modelParams.supportsSeed))

        let klein4B = try XCTUnwrap(models.first { $0.modelCode == .CLOUDFLARE_FLUX_2_KLEIN_4B })
        XCTAssertNil(klein4B.modelParams.supportedStepsRange)
        XCTAssertEqual(klein4B.modelParams.maxReferenceImages, 4)
        XCTAssertTrue(klein4B.modelParams.supportsSourceImage)
        XCTAssertEqual(klein4B.modelParams.maxImagePixels, 262_144)

        let klein9B = try XCTUnwrap(models.first { $0.modelCode == .CLOUDFLARE_FLUX_2_KLEIN_9B })
        XCTAssertNil(klein9B.modelParams.supportedStepsRange)
        XCTAssertEqual(klein9B.modelParams.maxReferenceImages, 4)
        XCTAssertTrue(klein9B.modelParams.supportsSourceImage)
        XCTAssertEqual(klein9B.modelParams.maxImagePixels, 262_144)

        let img2img = try XCTUnwrap(models.first { $0.modelCode == .CLOUDFLARE_SD_15_IMG2IMG })
        XCTAssertTrue(img2img.modelParams.supportsSourceImage)
    }

    func testCloudflareFlux2CostsUseDocumentedPricing() throws {
        let klein4B = G_CLOUDFLARE_FLUX_2_KLEIN_4B()
        XCTAssertEqual(
            klein4B.getCostEstimate(request: ImageGenerationCostRequest(dimensions: "1024x768")),
            0.001148,
            accuracy: 0.0000001
        )

        let klein4BResponse = try klein4B.transformResponse(
            request: makeRequest(
                dimensions: "1024x1024",
                clientImage: "c291cmNl",
                referenceImages: [ReferenceImageData(base64Image: "cmVmMA==")]
            ),
            response: .dictionary(statusCode: 200, data: ["success": true, "result": ["image": "base64-image"]])
        )
        XCTAssertEqual(klein4BResponse.cost ?? 0, 0.001266, accuracy: 0.0000001)

        let klein9B = G_CLOUDFLARE_FLUX_2_KLEIN_9B()
        XCTAssertEqual(
            klein9B.getCostEstimate(request: ImageGenerationCostRequest(dimensions: "1280x720")),
            0.015,
            accuracy: 0.0000001
        )
        XCTAssertEqual(
            klein9B.getCostEstimate(request: ImageGenerationCostRequest(dimensions: "1920x1920")),
            0.02003125,
            accuracy: 0.0000001
        )

        let flux2Dev = G_CLOUDFLARE_FLUX_2_DEV()
        XCTAssertEqual(
            flux2Dev.getCostEstimate(request: ImageGenerationCostRequest(dimensions: "1024x1024")),
            0.041,
            accuracy: 0.0000001
        )
    }
}

private final class CloudflareMockNetworkProvider: @unchecked Sendable, NetworkProvider {
    var capturedURL: URL?
    var capturedMethod: String?
    var capturedHeaders: [String: String]?
    var capturedAttachments: [NetworkRequestAttachment]?

    func performRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        capturedURL = url
        capturedMethod = method
        capturedHeaders = headers
        capturedAttachments = attachments
        return .dictionary(statusCode: 200, data: ["success": true, "result": ["image": "base64-output"]])
    }
}

private struct CloudflareTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        AllModels.createModels().first { $0.modelCode == code }
    }
}
