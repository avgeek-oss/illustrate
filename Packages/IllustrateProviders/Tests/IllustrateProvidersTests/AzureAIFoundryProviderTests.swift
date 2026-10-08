import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("Azure AI Foundry direct provider", .serialized)
struct AzureAIFoundryProviderTests {
    private let secret = #"{"endpoint":"https://avgeek-media.openai.azure.com/","api_key":"azure-secret","image_deployment":"image-prod","video_deployment":"sora-prod"}"#

    @Test("Credentials constrain requests to one Azure OpenAI resource")
    func configurationAndEndpointValidation() throws {
        let configuration = try AzureAIFoundryConfiguration(secret: secret)

        #expect(configuration.endpoint.absoluteString == "https://avgeek-media.openai.azure.com")
        #expect(try configuration.imageGenerationURL().absoluteString ==
            "https://avgeek-media.openai.azure.com/openai/v1/images/generations?api-version=preview")
        #expect(try configuration.imageEditURL().absoluteString ==
            "https://avgeek-media.openai.azure.com/openai/deployments/image-prod/images/edits?api-version=2025-04-01")
        #expect(try configuration.videoStatusURL(videoId: "video_abc-123").absoluteString ==
            "https://avgeek-media.openai.azure.com/openai/v1/videos/video_abc-123")

        #expect(throws: AzureAIFoundryError.self) {
            try AzureAIFoundryConfiguration(
                secret: #"{"endpoint":"https://avgeek.openai.azure.com.evil.example","api_key":"x","image_deployment":"image","video_deployment":"video"}"#
            )
        }
        #expect(throws: AzureAIFoundryError.self) {
            try AzureAIFoundryConfiguration(
                secret: #"{"endpoint":"https://avgeek.openai.azure.com","api_key":"x","image_deployment":"../escape","video_deployment":"video"}"#
            )
        }
        #expect(throws: AzureAIFoundryError.self) {
            try configuration.videoContentURL(videoId: "https://evil.example/video")
        }
    }

    @Test("GPT Image 2 sends one JSON generation and decodes base64 output")
    func imageGenerationFlow() async throws {
        let mock = AzureMockNetworkProvider(singleResponses: [
            .init(response: .dictionary(statusCode: 200, data: [
                "created": 1_783_680_000,
                "output_format": "png",
                "size": "2048x1152",
                "usage": ["output_tokens": 1024],
                "data": [[
                    "b64_json": "aW1hZ2U=",
                    "revised_prompt": "A refined aircraft portrait",
                ]],
            ])),
        ])

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: AzureTestModelProvider()
        ) {
            try await G_AZURE_GPT_IMAGE_2().makeRequest(request: imageRequest())
        }

        #expect(mock.singleRequests.count == 1)
        let sent = try #require(mock.singleRequests.first)
        #expect(sent.method == "POST")
        #expect(sent.url.absoluteString.hasSuffix("/openai/v1/images/generations?api-version=preview"))
        #expect(sent.headers?["api-key"] == "azure-secret")
        #expect(sent.attachments?.isEmpty != false)
        let body = try #require(sent.body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "image-prod")
        #expect(json["n"] as? Int == 1)
        #expect(json["size"] as? String == "2048x1152")
        #expect(json["quality"] as? String == "high")
        #expect(json["output_format"] as? String == "png")

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "aW1hZ2U=")
        #expect(response.modelPrompt == "A refined aircraft portrait")
        #expect(response.metadata?["azureDeployment"] == "image-prod")
        #expect(response.metadata?["azureResourceHost"] == "avgeek-media.openai.azure.com")
        #expect(response.actualDimensions == "2048x1152")
        #expect((response.cost ?? 0) > 0.211)
    }

    @Test("GPT Image 2 edit uploads source, references, and mask once")
    func imageEditFlow() async throws {
        let mock = AzureMockNetworkProvider(singleResponses: [
            .init(response: .dictionary(statusCode: 200, data: [
                "data": [["b64_json": "ZWRpdA=="]],
            ])),
        ])
        var request = imageRequest()
        request.clientImage = "data:image/jpeg;base64,c291cmNl"
        request.clientReferenceImages = [.init(base64Image: "cmVm", mimeType: "image/png")]
        request.clientMask = "bWFzaw=="
        request.inputFidelity = "high"

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: AzureTestModelProvider()
        ) {
            try await G_AZURE_GPT_IMAGE_2().makeRequest(request: request)
        }

        #expect(mock.singleRequests.count == 1)
        let sent = try #require(mock.singleRequests.first)
        #expect(sent.url.absoluteString.contains("/openai/deployments/image-prod/images/edits"))
        #expect(sent.headers?["Content-Type"] == "multipart/form-data")
        #expect(sent.attachments?.map(\.name) == ["image[]", "image[]", "mask"])
        #expect(sent.attachments?.map(\.mimeType) == ["image/jpeg", "image/png", "image/png"])
        #expect(response.status == .GENERATED)
        #expect(response.metadata?["azureOperation"] == "edit")
    }

    @Test("GPT Image 2 preserves errors and rejects invalid work before spending")
    func imageFailureSafety() async throws {
        let body = Data(#"{"error":{"code":"rate_limit","message":"quota exceeded"}}"#.utf8)
        let mock = AzureMockNetworkProvider(singleResponses: [
            .init(
                statusCode: 429,
                headers: ["x-ms-request-id": "request-123"],
                body: body,
                response: .dictionary(statusCode: 429, data: [
                    "error": ["code": "rate_limit", "message": "quota exceeded"],
                ])
            ),
        ])
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: AzureTestModelProvider()
        ) {
            try await G_AZURE_GPT_IMAGE_2().makeRequest(request: imageRequest())
        }
        #expect(mock.singleRequests.count == 1)
        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("quota exceeded") == true)
        #expect(response.rawResponse?.contains("429") == true)

        let validationMock = AzureMockNetworkProvider()
        var invalid = imageRequest()
        invalid.dimensions = "2047x1152"
        let invalidResponse = try await withProviderDependencies(
            networkProvider: validationMock,
            modelProvider: AzureTestModelProvider()
        ) {
            try await G_AZURE_GPT_IMAGE_2().makeRequest(request: invalid)
        }
        #expect(validationMock.singleRequests.isEmpty)
        #expect(invalidResponse.status == .FAILED)
    }

    @Test("Sora 2 creates once, polls safely, and downloads authenticated media")
    func videoFlow() async throws {
        let mock = AzureMockNetworkProvider(
            singleResponses: [
                .init(response: .dictionary(statusCode: 200, data: [
                    "id": "video_abc123",
                    "status": "queued",
                ])),
            ],
            responses: [
                .dictionary(statusCode: 200, data: [
                    "id": "video_abc123",
                    "status": "in_progress",
                    "progress": 50,
                ]),
                .dictionary(statusCode: 200, data: [
                    "id": "video_abc123",
                    "status": "completed",
                    "size": "1280x720",
                    "seconds": "8",
                    "expires_at": 1_783_766_400,
                ]),
            ],
            dataResponses: [
                .init(
                    statusCode: 200,
                    data: Data("video-bytes".utf8),
                    headers: ["Content-Type": "video/mp4"]
                ),
            ]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: AzureTestModelProvider()
        ) {
            try await G_AZURE_SORA_2(
                pollingPolicy: .init(maxAttempts: 2, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest())
        }

        #expect(mock.singleRequests.count == 1)
        #expect(mock.requests.count == 2)
        #expect(mock.requests.allSatisfy { $0.method == "GET" })
        #expect(mock.requests.allSatisfy { $0.url.absoluteString.hasSuffix("/openai/v1/videos/video_abc123") })
        let createBody = try #require(mock.singleRequests.first?.body)
        let createJSON = try #require(JSONSerialization.jsonObject(with: createBody) as? [String: Any])
        #expect(createJSON["model"] as? String == "sora-prod")
        #expect(createJSON["seconds"] as? Int == 8)
        #expect(createJSON["size"] as? String == "1280x720")

        let download = try #require(mock.dataRequests.first)
        #expect(download.url?.absoluteString.hasSuffix("/openai/v1/videos/video_abc123/content") == true)
        #expect(download.value(forHTTPHeaderField: "api-key") == "azure-secret")
        #expect(response.status == .GENERATED)
        #expect(response.base64 == Data("video-bytes".utf8).base64EncodedString())
        #expect(response.cost == 0.8)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == "video_abc123")
        #expect(response.actualDuration == 8)
        #expect(response.actualDimensions == "1280x720")
    }

    @Test("Sora 2 source image uses multipart and unsupported modes fail closed")
    func videoSourceAndValidation() async throws {
        let adapter = G_AZURE_SORA_2(pollingPolicy: .init(maxAttempts: 1, intervalNanoseconds: 0))
        var source = videoRequest()
        source.clientImage = "data:image/webp;base64,d2VicA=="
        let attachments = try adapter.sourceAttachments(from: source)
        #expect(attachments.map(\.name) == ["input_reference"])
        #expect(attachments.map(\.mimeType) == ["image/webp"])

        let mock = AzureMockNetworkProvider()
        var invalid = videoRequest()
        invalid.durationSeconds = 5
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: AzureTestModelProvider()
        ) {
            try await adapter.makeRequest(request: invalid)
        }
        #expect(mock.singleRequests.isEmpty)
        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("4, 8, or 12") == true)
    }

    @Test("Sora 2 classifies documented terminal states and bounds polling")
    func videoStatesAndTimeout() async throws {
        let failed = try G_AZURE_SORA_2.classify(.dictionary(statusCode: 200, data: [
            "status": "failed",
            "error": ["message": "content filtered"],
        ]))
        #expect(failed == .failed("content filtered"))
        let cancelled = try G_AZURE_SORA_2.classify(.dictionary(statusCode: 200, data: [
            "status": "cancelled",
        ]))
        #expect(cancelled == .cancelled)

        let mock = AzureMockNetworkProvider(
            singleResponses: [
                .init(response: .dictionary(statusCode: 200, data: [
                    "id": "video_timeout",
                    "status": "queued",
                ])),
            ],
            responses: [
                .dictionary(statusCode: 200, data: ["status": "queued"]),
            ]
        )
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: AzureTestModelProvider()
        ) {
            try await G_AZURE_SORA_2(
                pollingPolicy: .init(maxAttempts: 1, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest())
        }
        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("did not finish") == true)
        #expect(mock.singleRequests.count == 1)
        #expect(mock.requests.count == 1)
        #expect(mock.dataRequests.isEmpty)
    }

    @Test("Catalog records current Azure model IDs and provenance")
    func catalog() {
        let models = AzureAIFoundryModels.createModels()
        #expect(models.map(\.modelCode) == [.AZURE_GPT_IMAGE_2, .AZURE_SORA_2])
        #expect(models.allSatisfy { $0.providerId == EnumProviderCode.AZURE_AI_FOUNDRY.providerId })
        #expect(models.count == 2 && models[0].active && models[1].active)
        #expect(models.allSatisfy { $0.modelVerificationDate == getDateFromString("2026-07-10") })
        #expect(models.allSatisfy { $0.pricingMetadata?.sourceURL.contains("azure.microsoft.com") == true })
    }

    private func imageRequest() -> ImageGenerationRequest {
        .init(
            modelId: EnumProviderModelCode.AZURE_GPT_IMAGE_2.modelId.uuidString,
            prompt: "A cinematic aircraft portrait",
            quality: "high",
            dimensions: "2048x1152",
            providerKey: providerKey,
            providerSecret: secret,
            moderation: "auto"
        )
    }

    private func videoRequest() -> VideoGenerationRequest {
        .init(
            modelId: EnumProviderModelCode.AZURE_SORA_2.modelId.uuidString,
            prompt: "An aircraft crosses a stormy sky",
            dimensions: "1280x720",
            providerKey: providerKey,
            providerSecret: secret,
            durationSeconds: 8
        )
    }

    private var providerKey: ProviderKeyInfo {
        .init(
            providerId: EnumProviderCode.AZURE_AI_FOUNDRY.providerId,
            providerCode: .AZURE_AI_FOUNDRY,
            projectId: UUID()
        )
    }
}

private final class AzureMockNetworkProvider: NetworkProvider, @unchecked Sendable {
    struct Request {
        let url: URL
        let method: String
        let body: Data?
        let headers: [String: String]?
        let attachments: [NetworkRequestAttachment]?
    }

    private var singleResponses: [NetworkResponseEnvelope]
    private var responses: [NetworkResponseData]
    private var dataResponses: [NetworkDataResponse]
    private(set) var singleRequests: [Request] = []
    private(set) var requests: [Request] = []
    private(set) var dataRequests: [URLRequest] = []

    init(
        singleResponses: [NetworkResponseEnvelope] = [],
        responses: [NetworkResponseData] = [],
        dataResponses: [NetworkDataResponse] = []
    ) {
        self.singleResponses = singleResponses
        self.responses = responses
        self.dataResponses = dataResponses
    }

    func performSingleAttemptRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseEnvelope {
        try singleRequests.append(.init(
            url: url,
            method: method,
            body: body.map { try JSONEncoder().encode($0) },
            headers: headers,
            attachments: attachments
        ))
        guard !singleResponses.isEmpty else { throw URLError(.badServerResponse) }
        return singleResponses.removeFirst()
    }

    func performRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        try requests.append(.init(
            url: url,
            method: method,
            body: body.map { try JSONEncoder().encode($0) },
            headers: headers,
            attachments: attachments
        ))
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        return responses.removeFirst()
    }

    func performDataRequest(_ request: URLRequest) async throws -> NetworkDataResponse {
        dataRequests.append(request)
        guard !dataResponses.isEmpty else { throw URLError(.badServerResponse) }
        return dataResponses.removeFirst()
    }
}

private struct AzureTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        AllModels.createModels().first { $0.modelCode == code }
    }
}
