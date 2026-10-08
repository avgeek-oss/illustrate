import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("Bria direct provider", .serialized)
struct BriaProviderTests {
    @Test("Runs documented async flow and materializes the output URL")
    func runsAsyncFlow() async throws {
        let statusURL = "https://engine.prod.bria-api.com/v2/status/request_123?region=opaque"
        let outputURL = "https://bria-output.example/fibo.png?expires=600"
        let mock = BriaMockNetworkProvider(
            responses: [
                .dictionary(statusCode: 202, data: [
                    "request_id": "request_123",
                    "status_url": statusURL,
                ]),
                .dictionary(statusCode: 200, data: [
                    "request_id": "request_123",
                    "status": "IN_PROGRESS",
                ]),
                .dictionary(statusCode: 200, data: [
                    "request_id": "request_123",
                    "status": "COMPLETED",
                    "result": [
                        "image_url": outputURL,
                        "seed": 42,
                        "structured_prompt": "{\"short_description\":\"aircraft\"}",
                    ],
                ]),
            ],
            rawResponses: [
                .image(statusCode: 200, base64: "YnJpYS1maWJv", mimeType: "image/png"),
            ]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BriaTestModelProvider()
        ) {
            try await G_BRIA_FIBO(
                pollingPolicy: ProviderPollingPolicy(maxAttempts: 3, intervalNanoseconds: 0)
            ).makeRequest(request: request(
                clientImage: "data:image/png;base64,aW1hZ2U=",
                negativePrompt: "blurry",
                resolution: "4MP",
                steps: 42,
                seed: 7,
                numberOfImages: 8
            ))
        }

        #expect(mock.requests.count == 3)
        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests[0].url.absoluteString == "https://engine.prod.bria-api.com/v2/image/generate")
        #expect(mock.requests[0].method == "POST")
        #expect(mock.requests[0].headers?["api_token"] == "bria-test-token")
        #expect(mock.requests[1].url.absoluteString == statusURL)
        #expect(mock.requests[2].url.absoluteString == statusURL)
        #expect(mock.requests.dropFirst().allSatisfy { $0.headers?["api_token"] == "bria-test-token" })

        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["prompt"] as? String == "A cinematic aircraft portrait")
        #expect(json["images"] as? [String] == ["aW1hZ2U="])
        #expect(json["negative_prompt"] as? String == "blurry")
        #expect(json["resolution"] as? String == "4MP")
        #expect(json["model_version"] as? String == "FIBO")
        #expect(json["aspect_ratio"] as? String == "16:9")
        #expect(json["steps_num"] as? Int == 42)
        #expect(json["seed"] as? Int == 7)
        #expect(json["sync"] as? Bool == false)
        #expect(json["output_type"] as? String == "png")
        #expect(json["number_of_images"] == nil)

        #expect(mock.rawRequests.first?.url?.absoluteString == outputURL)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "YnJpYS1maWJv")
        #expect(response.cost == 0.03)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == "request_123")
        #expect(response.metadata?[ProviderJobMetadataKey.statusURL] == statusURL)
        #expect(response.metadata?["briaOutputURL"] == outputURL)
        #expect(response.metadata?["briaSeed"] == "42")
        #expect(response.rawResponse?.contains("COMPLETED") == true)
    }

    @Test("Rejects untrusted status URLs without forwarding the API token")
    func rejectsUntrustedStatusURL() async throws {
        let mock = BriaMockNetworkProvider(responses: [
            .dictionary(statusCode: 202, data: [
                "request_id": "request_hostile",
                "status_url": "https://attacker.example/status/request_hostile",
            ]),
        ])

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BriaTestModelProvider()
        ) {
            try await G_BRIA_FIBO(
                pollingPolicy: ProviderPollingPolicy(maxAttempts: 1, intervalNanoseconds: 0)
            ).makeRequest(request: request())
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("untrusted status URL") == true)
        #expect(mock.requests.count == 1)
        #expect(mock.requests[0].url.host == "engine.prod.bria-api.com")
        #expect(mock.requests[0].headers?["api_token"] == "bria-test-token")
    }

    @Test("Rejects simultaneous source and reference images before creating a paid job")
    func rejectsSourcePlusReference() async throws {
        let mock = BriaMockNetworkProvider(responses: [])
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BriaTestModelProvider()
        ) {
            try await G_BRIA_FIBO().makeRequest(request: request(
                clientImage: "c291cmNl",
                clientReferenceImages: [.init(base64Image: "cmVmZXJlbmNl")]
            ))
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("one source or reference image") == true)
        #expect(mock.requests.isEmpty)
        #expect(mock.singleAttemptRequestCount == 0)
    }

    @Test("Treats an HTTP 200 ERROR job body as failure")
    func treatsBodyErrorAsFailure() async throws {
        let mock = BriaMockNetworkProvider(responses: [
            .dictionary(statusCode: 202, data: [
                "request_id": "request_error",
                "status_url": "https://engine.prod.bria-api.com/v2/status/request_error",
            ]),
            .dictionary(statusCode: 200, data: [
                "request_id": "request_error",
                "status": "ERROR",
                "error": ["message": "Prompt was rejected"],
            ]),
        ])

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BriaTestModelProvider()
        ) {
            try await G_BRIA_FIBO(
                pollingPolicy: ProviderPollingPolicy(maxAttempts: 2, intervalNanoseconds: 0)
            ).makeRequest(request: request())
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("Prompt was rejected") == true)
        #expect(mock.rawRequests.isEmpty)
    }

    @Test("Classifies UNKNOWN expired jobs and rate limiting as failures")
    func classifiesFailureFixtures() throws {
        let unknown = try G_BRIA_FIBO.classify(.dictionary(statusCode: 200, data: [
            "status": "UNKNOWN",
        ]))
        #expect(unknown == .failed("Bria returned an UNKNOWN job state."))

        let expired = try G_BRIA_FIBO.classify(.dictionary(statusCode: 404, data: [
            "status": "NOT_FOUND",
        ]))
        guard case let .failed(expiredMessage) = expired else {
            Issue.record("Expected expired status request to fail")
            return
        }
        #expect(expiredMessage.contains("HTTP 404"))

        let limited = try G_BRIA_FIBO.classify(.dictionary(statusCode: 429, data: [
            "error": ["message": "Too many requests"],
        ]))
        guard case let .failed(limitedMessage) = limited else {
            Issue.record("Expected rate-limited status request to fail")
            return
        }
        #expect(limitedMessage.contains("HTTP 429"))
        #expect(limitedMessage.contains("Too many requests"))
    }

    @Test("Surfaces a rate-limited create response without polling")
    func handlesCreateRateLimit() async throws {
        let mock = BriaMockNetworkProvider(responses: [
            .dictionary(statusCode: 429, data: [
                "error": ["message": "Rate limit exceeded"],
            ]),
        ])

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BriaTestModelProvider()
        ) {
            try await G_BRIA_FIBO().makeRequest(request: request())
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("HTTP 429") == true)
        #expect(response.errorMessage?.contains("Rate limit exceeded") == true)
        #expect(mock.requests.count == 1)
        #expect(mock.rawRequests.isEmpty)
    }

    @Test("Accepts documented and defensive result URL shapes")
    func acceptsResultURLShapes() throws {
        let adapter = G_BRIA_FIBO()
        let direct = try adapter.transformResponse(
            request: request(),
            response: .dictionary(statusCode: 200, data: [
                "result_url": "https://output.example/direct.png",
            ])
        )
        let nested = try adapter.transformResponse(
            request: request(),
            response: .dictionary(statusCode: 200, data: [
                "result": ["result": ["image_url": "https://output.example/nested.png"]],
            ])
        )

        #expect(direct.status == .GENERATED)
        #expect(direct.rawResponse == "https://output.example/direct.png")
        #expect(nested.status == .GENERATED)
        #expect(nested.rawResponse == "https://output.example/nested.png")
    }

    @Test("Registers the current FIBO contract and atomic pricing")
    func registersCurrentContract() throws {
        let model = try #require(BriaModels.createModels().only)
        #expect(model.providerId == EnumProviderCode.BRIA.providerId)
        #expect(model.modelCode == .BRIA_FIBO)
        #expect(model.modelGenerateBaseURL == "https://engine.prod.bria-api.com/v2/image/generate")
        #expect(model.modelStatusBaseURL == "https://engine.prod.bria-api.com/v2/status")
        #expect(model.modelVerificationDate == getDateFromString("2026-07-10"))
        #expect(model.pricingMetadata?.unit == .image)
        #expect(model.pricingMetadata?.sourceURL == "https://bria.ai/pricing")
        #expect(model.modelParams.maxGenerations == 1)
        #expect(AllModels.createModels().contains { $0.modelCode == .BRIA_FIBO })

        let adapter = G_BRIA_FIBO()
        #expect(adapter.getCostEstimate(request: .init(numberOfImages: 1)) == 0.03)
        #expect(adapter.getCostEstimate(request: .init(numberOfImages: 12)) == 0.03)
        #expect(G_BRIA_FIBO.aspectRatio(for: "1280x720") == "16:9")
        #expect(G_BRIA_FIBO.imageInput("data:image/webp;base64,Zmlicmlh") == "Zmlicmlh")
        #expect(G_BRIA_FIBO.imageInput("https://input.example/image.png") == "https://input.example/image.png")
    }

    private func request(
        clientImage: String? = nil,
        clientReferenceImages: [ReferenceImageData]? = nil,
        negativePrompt: String? = nil,
        resolution: String? = nil,
        steps: Int? = nil,
        seed: Int? = nil,
        numberOfImages: Int = 1
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: EnumProviderModelCode.BRIA_FIBO.modelId.uuidString,
            prompt: "A cinematic aircraft portrait",
            negativePrompt: negativePrompt,
            dimensions: "1280x720",
            clientImage: clientImage,
            clientReferenceImages: clientReferenceImages,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.BRIA.providerId,
                providerCode: .BRIA,
                projectId: UUID()
            ),
            providerSecret: "bria-test-token",
            numberOfImages: numberOfImages,
            resolution: resolution,
            steps: steps,
            seed: seed
        )
    }
}

private final class BriaMockNetworkProvider: @unchecked Sendable, NetworkProvider {
    struct CapturedRequest {
        let url: URL
        let method: String
        let headers: [String: String]?
        let body: Data?
    }

    var requests: [CapturedRequest] = []
    var singleAttemptRequestCount = 0
    var rawRequests: [URLRequest] = []
    private var responses: [NetworkResponseData]
    private var rawResponses: [NetworkResponseData]

    init(responses: [NetworkResponseData], rawResponses: [NetworkResponseData] = []) {
        self.responses = responses
        self.rawResponses = rawResponses
    }

    func performRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments _: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        let encoded = try body.map { try JSONEncoder().encode($0) }
        requests.append(.init(url: url, method: method, headers: headers, body: encoded))
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        return responses.removeFirst()
    }

    func performSingleAttemptRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseEnvelope {
        singleAttemptRequestCount += 1
        let response = try await performRequest(
            url: url,
            method: method,
            body: body,
            headers: headers,
            attachments: attachments
        )
        return NetworkResponseEnvelope(response: response)
    }

    func performRawRequest(_ request: URLRequest) async throws -> NetworkResponseData {
        rawRequests.append(request)
        guard !rawResponses.isEmpty else { throw URLError(.badServerResponse) }
        return rawResponses.removeFirst()
    }
}

private struct BriaTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        BriaModels.createModels().first { $0.modelCode == code }
    }
}

private extension Collection {
    var only: Element? {
        count == 1 ? first : nil
    }
}
