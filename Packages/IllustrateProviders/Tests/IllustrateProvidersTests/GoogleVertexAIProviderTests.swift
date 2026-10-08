import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("Google Vertex AI direct provider", .serialized)
struct GoogleVertexAIProviderTests {
    private let secret =
        #"{"access_token":"ya29.short-lived","project_id":"avgeek-media","location":"us-central1"}"# // gitleaks:allow -- synthetic fixture, not an issued token
    private let operation = "projects/avgeek-media/locations/us-central1/publishers/google/models/veo-3.1-generate-001/operations/op-123"

    @Test("Credentials construct only Google-owned project endpoints")
    func configurationAndEndpointValidation() throws {
        let configuration = try VertexAIConfiguration(secret: secret)
        let url = try configuration.modelURL(
            modelId: "gemini-3.1-flash-image",
            method: "generateContent"
        )

        #expect(url
            .absoluteString ==
            "https://us-central1-aiplatform.googleapis.com/v1/projects/avgeek-media/locations/us-central1/publishers/google/models/gemini-3.1-flash-image:generateContent")
        #expect(throws: VertexAIError.self) {
            try VertexAIConfiguration(
                secret: #"{"access_token":"token","project_id":"avgeek-media","location":"evil.example.com"}"#
            )
        }
        #expect(throws: VertexAIError.self) {
            try configuration.modelURL(modelId: "gemini/escape", method: "generateContent")
        }
    }

    @Test("Gemini image sends multimodal request and decodes inline output")
    func geminiImageFlow() async throws {
        let mock = VertexMockNetworkProvider(singleResponses: [
            .init(response: .dictionary(statusCode: 200, data: [
                "candidates": [[
                    "finishReason": "STOP",
                    "content": [
                        "parts": [
                            ["text": "Refined aircraft portrait"],
                            ["inlineData": ["mimeType": "image/png", "data": "aW1hZ2U="]],
                        ],
                    ],
                ]],
            ])),
        ])

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: VertexTestModelProvider()
        ) {
            try await G_VERTEX_GEMINI_3_1_FLASH_IMAGE().makeRequest(
                request: imageRequest(
                    source: "data:image/jpeg;base64,c291cmNl",
                    references: [.init(base64Image: "cmVm", mimeType: "image/png")]
                )
            )
        }

        #expect(mock.singleRequests.count == 1)
        let sent = try #require(mock.singleRequests.first)
        #expect(sent.method == "POST")
        #expect(sent.url.absoluteString.contains("gemini-3.1-flash-image:generateContent"))
        #expect(sent.headers?["Authorization"] == "Bearer ya29.short-lived")
        let body = try #require(sent.body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let contents = try #require(json["contents"] as? [[String: Any]])
        let parts = try #require(contents.first?["parts"] as? [[String: Any]])
        #expect(parts.count == 3)
        let config = try #require(json["generationConfig"] as? [String: Any])
        #expect(config["responseModalities"] as? [String] == ["TEXT", "IMAGE"])
        let imageConfig = try #require(config["imageConfig"] as? [String: Any])
        #expect(imageConfig["aspectRatio"] as? String == "16:9")
        #expect(imageConfig["imageSize"] as? String == "2K")

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "aW1hZ2U=")
        #expect(abs((response.cost ?? 0) - 0.1022) < 0.000_001)
        #expect(response.metadata?["vertexProjectId"] == "avgeek-media")
        #expect(response.metadata?["vertexLocation"] == "us-central1")
    }

    @Test("Gemini image fails closed on HTTP and output anomalies")
    func geminiImageFailures() async throws {
        let httpMock = VertexMockNetworkProvider(singleResponses: [
            .init(response: .dictionary(statusCode: 403, data: [
                "error": ["message": "permission denied"],
            ])),
        ])
        let httpResponse = try await withProviderDependencies(
            networkProvider: httpMock,
            modelProvider: VertexTestModelProvider()
        ) {
            try await G_VERTEX_GEMINI_3_1_FLASH_IMAGE().makeRequest(request: imageRequest())
        }
        #expect(httpMock.singleRequests.count == 1)
        #expect(httpResponse.status == .FAILED)
        #expect(httpResponse.errorMessage?.contains("permission denied") == true)

        let referenceMock = VertexMockNetworkProvider()
        let tooMany = Array(repeating: ReferenceImageData(base64Image: "cmVm"), count: 15)
        let validationResponse = try await withProviderDependencies(
            networkProvider: referenceMock,
            modelProvider: VertexTestModelProvider()
        ) {
            try await G_VERTEX_GEMINI_3_1_FLASH_IMAGE().makeRequest(
                request: imageRequest(references: tooMany)
            )
        }
        #expect(referenceMock.singleRequests.isEmpty)
        #expect(validationResponse.status == .FAILED)
    }

    @Test("Veo create polls idempotently and returns inline video")
    func veoAsyncFlow() async throws {
        let final: NetworkResponseData = .dictionary(statusCode: 200, data: [
            "name": operation,
            "done": true,
            "response": [
                "videos": [[
                    "bytesBase64Encoded": "dmlkZW8=",
                    "mimeType": "video/mp4",
                ]],
                "raiMediaFilteredCount": 0,
            ],
        ])
        let mock = VertexMockNetworkProvider(
            singleResponses: [
                .init(response: .dictionary(statusCode: 200, data: ["name": operation])),
            ],
            responses: [
                .dictionary(statusCode: 200, data: ["name": operation, "done": false]),
                final,
            ]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: VertexTestModelProvider()
        ) {
            try await G_VERTEX_VEO_3_1(
                pollingPolicy: .init(maxAttempts: 2, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest())
        }

        #expect(mock.singleRequests.count == 1)
        #expect(mock.requests.count == 2)
        #expect(mock.singleRequests[0].url.absoluteString.hasSuffix("veo-3.1-generate-001:predictLongRunning"))
        #expect(mock.requests.allSatisfy { $0.url.absoluteString.hasSuffix(":fetchPredictOperation") })
        #expect(mock.requests.allSatisfy { $0.method == "POST" })
        let pollBody = try #require(mock.requests.first?.body)
        let pollJSON = try #require(JSONSerialization.jsonObject(with: pollBody) as? [String: String])
        #expect(pollJSON["operationName"] == operation)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "dmlkZW8=")
        #expect(response.cost == 3.2)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == "op-123")
        #expect(response.metadata?["vertexOperationName"] == operation)
        #expect(response.actualDuration == 8)
        #expect(response.actualDimensions == "1080p")
    }

    @Test("Veo sends first and last frames with documented parameters")
    func veoFramePayloadAndFastPricing() throws {
        let adapter = G_VERTEX_VEO_3_1_FAST(pollingPolicy: .init(maxAttempts: 1, intervalNanoseconds: 0))
        let service = try adapter.validatedRequest(from: videoRequest(
            firstFrame: "data:image/png;base64,Zmlyc3Q=",
            lastFrame: "bGFzdA==",
            resolution: "720p",
            audio: false,
            duration: 6
        ))

        #expect(service.instances[0].image?.bytesBase64Encoded == "Zmlyc3Q=")
        #expect(service.instances[0].lastFrame?.bytesBase64Encoded == "bGFzdA==")
        #expect(service.parameters.aspectRatio == "16:9")
        #expect(service.parameters.sampleCount == 1)
        #expect(service.parameters.generateAudio == false)
        #expect(adapter.getCostEstimate(request: .init(
            durationSeconds: 6,
            numberOfVideos: 1,
            resolution: "720p",
            generateAudio: false
        )) == 0.48)
    }

    @Test("Veo rejects unsupported modes before spending credits")
    func veoValidation() async throws {
        let mock = VertexMockNetworkProvider()
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: VertexTestModelProvider()
        ) {
            try await G_VERTEX_VEO_3_1(
                pollingPolicy: .init(maxAttempts: 1, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest(duration: 5))
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("4, 6, or 8") == true)
        #expect(mock.singleRequests.isEmpty)
    }

    @Test("Veo reports provider errors and bounded polling timeout")
    func veoErrorAndTimeout() async throws {
        let failed = try VertexVeoTaskClient.classify(.dictionary(statusCode: 200, data: [
            "done": true,
            "error": ["code": 13, "message": "internal failure"],
        ]))
        #expect(failed == .failed("Vertex AI video generation failed (13): internal failure"))

        let mock = VertexMockNetworkProvider(
            singleResponses: [
                .init(response: .dictionary(statusCode: 200, data: ["name": operation])),
            ],
            responses: [
                .dictionary(statusCode: 200, data: ["name": operation, "done": false]),
            ]
        )
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: VertexTestModelProvider()
        ) {
            try await G_VERTEX_VEO_3_1(
                pollingPolicy: .init(maxAttempts: 1, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest())
        }
        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("did not finish") == true)
    }

    @Test("Catalog records current Vertex model IDs and provenance")
    func catalog() {
        let models = GoogleVertexAIModels.createModels()
        #expect(models.map(\.modelCode) == [
            .VERTEX_GEMINI_3_1_FLASH_IMAGE,
            .VERTEX_VEO_3_1,
            .VERTEX_VEO_3_1_FAST,
        ])
        #expect(models.allSatisfy { $0.providerId == EnumProviderCode.GOOGLE_VERTEX_AI.providerId })
        #expect(models.map(\.active) == [true, true, true])
        #expect(models.allSatisfy { $0.modelVerificationDate == getDateFromString("2026-07-10") })
        #expect(models.allSatisfy { $0.modelAPIDocumentationURL.hasPrefix("https://") })
        let image = models[0]
        #expect(image.modelLaunchDate == getDateFromString("2026-05-28"))
        #expect(image.modelParams.supportedImageResolutions == ["512", "1K", "2K", "4K"])
        #expect(image.pricingMetadata?.notes?.contains("GA model") == true)
        #expect(image.pricingMetadata?.notes?.contains("4K output remains Preview") == true)
    }

    private func imageRequest(
        source: String? = nil,
        references: [ReferenceImageData]? = nil
    ) -> ImageGenerationRequest {
        .init(
            modelId: EnumProviderModelCode.VERTEX_GEMINI_3_1_FLASH_IMAGE.modelId.uuidString,
            prompt: "A cinematic aircraft portrait",
            dimensions: "16:9",
            clientImage: source,
            clientReferenceImages: references,
            providerKey: providerKey,
            providerSecret: secret,
            resolution: "2K"
        )
    }

    private func videoRequest(
        firstFrame: String? = nil,
        lastFrame: String? = nil,
        resolution: String = "1080p",
        audio: Bool = true,
        duration: Int = 8
    ) -> VideoGenerationRequest {
        .init(
            modelId: EnumProviderModelCode.VERTEX_VEO_3_1.modelId.uuidString,
            prompt: "An aircraft crosses a stormy sky",
            negativePrompt: "text overlays",
            dimensions: "16:9",
            clientImage: firstFrame,
            clientLastFrame: lastFrame,
            providerKey: providerKey,
            providerSecret: secret,
            durationSeconds: duration,
            resolution: resolution,
            fps: 24,
            generateAudio: audio,
            seed: 42,
            promptEnhance: true
        )
    }

    private var providerKey: ProviderKeyInfo {
        .init(
            providerId: EnumProviderCode.GOOGLE_VERTEX_AI.providerId,
            providerCode: .GOOGLE_VERTEX_AI,
            projectId: UUID()
        )
    }
}

private final class VertexMockNetworkProvider: NetworkProvider, @unchecked Sendable {
    struct Request {
        let url: URL
        let method: String
        let body: Data?
        let headers: [String: String]?
    }

    private var singleResponses: [NetworkResponseEnvelope]
    private var responses: [NetworkResponseData]
    private(set) var singleRequests: [Request] = []
    private(set) var requests: [Request] = []

    init(
        singleResponses: [NetworkResponseEnvelope] = [],
        responses: [NetworkResponseData] = []
    ) {
        self.singleResponses = singleResponses
        self.responses = responses
    }

    func performSingleAttemptRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments _: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseEnvelope {
        try singleRequests.append(.init(
            url: url,
            method: method,
            body: body.map { try JSONEncoder().encode($0) },
            headers: headers
        ))
        guard !singleResponses.isEmpty else { throw URLError(.badServerResponse) }
        return singleResponses.removeFirst()
    }

    func performRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments _: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        try requests.append(.init(
            url: url,
            method: method,
            body: body.map { try JSONEncoder().encode($0) },
            headers: headers
        ))
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        return responses.removeFirst()
    }
}

private struct VertexTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        AllModels.createModels().first { $0.modelCode == code }
    }
}
