import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("Black Forest Labs direct provider", .serialized)
struct BlackForestLabsProviderTests {
    @Test("Uses returned polling URL and materializes expiring output")
    func usesOpaquePollingURL() async throws {
        let pollURL = "https://api.us.bfl.ai/v1/get_result?id=job_123&cluster=opaque"
        let mock = BFLMockNetworkProvider(
            responses: [
                .dictionary(statusCode: 200, data: ["id": "job_123", "polling_url": pollURL]),
                .dictionary(statusCode: 200, data: ["id": "job_123", "status": "Pending", "progress": 0.4]),
                .dictionary(statusCode: 200, data: [
                    "id": "job_123",
                    "status": "Ready",
                    "progress": 1.0,
                    "result": ["sample": "https://delivery.eu.bfl.ai/result.png?expires=600"],
                ]),
            ],
            rawResponses: [.image(statusCode: 200, base64: "YmZsLWltYWdl", mimeType: "image/png")]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BFLTestModelProvider()
        ) {
            try await G_BFL_FLUX_2_PRO(
                pollingPolicy: ProviderPollingPolicy(maxAttempts: 3, intervalNanoseconds: 0)
            ).makeRequest(request: request())
        }

        #expect(mock.requests.count == 3)
        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests[0].url.absoluteString == "https://api.bfl.ai/v1/flux-2-pro")
        #expect(mock.requests[0].headers?["x-key"] == "bfl-test-key")
        #expect(mock.requests[1].url.absoluteString == pollURL)
        #expect(mock.requests[2].url.absoluteString == pollURL)
        #expect(mock.rawRequests.first?.url?.absoluteString == "https://delivery.eu.bfl.ai/result.png?expires=600")
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "YmZsLWltYWdl")
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == "job_123")
        #expect(response.metadata?[ProviderJobMetadataKey.statusURL] == pollURL)
    }

    @Test("Rejects untrusted polling URLs without forwarding the API key")
    func rejectsUntrustedPollingURL() async throws {
        let mock = BFLMockNetworkProvider(responses: [
            .dictionary(statusCode: 200, data: [
                "id": "job_hostile",
                "polling_url": "https://api.attacker.bfl.ai/status/job_hostile",
            ]),
        ])

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BFLTestModelProvider()
        ) {
            try await G_BFL_FLUX_2_PRO(
                pollingPolicy: ProviderPollingPolicy(maxAttempts: 1, intervalNanoseconds: 0)
            ).makeRequest(request: request())
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("untrusted polling URL") == true)
        #expect(mock.requests.count == 1)
        #expect(mock.requests[0].url.host == "api.bfl.ai")
        #expect(mock.requests[0].headers?["x-key"] == "bfl-test-key")
    }

    @Test("Posts documented dimensions editing input and controls")
    func postsDocumentedPayload() async throws {
        let mock = BFLMockNetworkProvider(responses: [
            .dictionary(statusCode: 400, data: ["error": "fixture stop"]),
        ])
        _ = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BFLTestModelProvider()
        ) {
            try await G_BFL_FLUX_2_MAX(
                pollingPolicy: ProviderPollingPolicy(maxAttempts: 1, intervalNanoseconds: 0)
            ).makeRequest(request: request(clientImage: "aW1hZ2U=", seed: 42, safetyTolerance: 3, promptEnhance: true))
        }

        let body = try #require(mock.requests.first?.body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["prompt"] as? String == "A cinematic aircraft portrait")
        #expect(json["width"] as? Int == 1280)
        #expect(json["height"] as? Int == 720)
        #expect(json["input_image"] as? String == "data:image/png;base64,aW1hZ2U=")
        #expect(json["seed"] as? Int == 42)
        #expect(json["safety_tolerance"] as? Int == 3)
        #expect(json["prompt_upsampling"] as? Bool == true)
        #expect(json["output_format"] as? String == "png")
    }

    @Test("Classifies moderation failure unknown state and timeout")
    func classifiesFailuresAndTimeout() async throws {
        let moderated = try G_BFL_FLUX_2.classify(.dictionary(statusCode: 200, data: [
            "status": "Content Moderated",
            "details": ["message": "Prompt blocked"],
        ]))
        #expect(moderated == .failed("Prompt blocked"))

        let unknown = try G_BFL_FLUX_2.classify(.dictionary(statusCode: 200, data: ["status": "Mystery"]))
        #expect(unknown == .failed("Unknown Black Forest Labs status: Mystery"))

        let mock = BFLMockNetworkProvider(responses: [
            .dictionary(statusCode: 200, data: [
                "id": "job_timeout",
                "polling_url": "https://api.bfl.ai/v1/get_result?id=job_timeout",
            ]),
            .dictionary(statusCode: 200, data: ["status": "Pending"]),
            .dictionary(statusCode: 200, data: ["status": "Pending"]),
        ])
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BFLTestModelProvider()
        ) {
            try await G_BFL_FLUX_2_PRO(
                pollingPolicy: ProviderPollingPolicy(maxAttempts: 2, intervalNanoseconds: 0)
            ).makeRequest(request: request())
        }
        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("did not finish after 2 status checks") == true)
    }

    @Test("Registers fixed endpoints and megapixel pricing provenance")
    func registersSourceBackedModels() {
        let models = BlackForestLabsModels.createModels()
        #expect(models.map(\.modelCode) == [.BFL_FLUX_2_PRO, .BFL_FLUX_2_MAX])
        #expect(models.allSatisfy { !$0.modelGenerateBaseURL.contains("preview") })
        #expect(models.allSatisfy { $0.modelVerificationDate == getDateFromString("2026-07-10") })
        #expect(models.allSatisfy { $0.pricingMetadata?.unit == .megapixel })
        let pro = G_BFL_FLUX_2_PRO()
        let text = pro.getCostEstimate(request: .init(dimensions: "1024x1024", numberOfImages: 1))
        let edit = pro.getCostEstimate(request: .init(
            dimensions: "1024x1024",
            numberOfImages: 1,
            hasSourceImage: true
        ))
        #expect(abs(text - 0.03145728) < 0.000001)
        #expect(abs(edit - 0.04718592) < 0.000001)
    }

    private func request(
        clientImage: String? = nil,
        seed: Int? = nil,
        safetyTolerance: Int? = nil,
        promptEnhance: Bool? = nil
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: EnumProviderModelCode.BFL_FLUX_2_PRO.modelId.uuidString,
            prompt: "A cinematic aircraft portrait",
            dimensions: "1280x720",
            clientImage: clientImage,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.BLACK_FOREST_LABS.providerId,
                providerCode: .BLACK_FOREST_LABS,
                projectId: UUID()
            ),
            providerSecret: "bfl-test-key",
            seed: seed,
            safetyTolerance: safetyTolerance,
            promptEnhance: promptEnhance
        )
    }
}

private final class BFLMockNetworkProvider: @unchecked Sendable, NetworkProvider {
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

private struct BFLTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        BlackForestLabsModels.createModels().first { $0.modelCode == code }
    }
}
