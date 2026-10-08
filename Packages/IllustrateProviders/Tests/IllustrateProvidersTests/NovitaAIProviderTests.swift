import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("Novita AI direct provider", .serialized)
struct NovitaAIProviderTests {
    private let apiKey = "novita-test-api-key"
    private let taskId = "0cdee604-7168-4ff4-9b2a-9793c0cc6cdf"

    @Test("Qwen-Image creates once, polls documented states, and materializes output")
    func qwenImageFlow() async throws {
        let outputURL = "https://faas-output-image.s3.ap-southeast-1.amazonaws.com/output.jpeg?expires=3600"
        let mock = NovitaAIMockNetworkProvider(
            responses: [
                .dictionary(statusCode: 200, data: ["task_id": taskId]),
                status("TASK_STATUS_QUEUED"),
                status("TASK_STATUS_PROCESSING", progress: 60),
                status("TASK_STATUS_SUCCEED", images: [[
                    "image_url": outputURL,
                    "image_url_ttl": "3600",
                    "image_type": "jpeg",
                    "nsfw_detection_result": NSNull(),
                ]]),
            ],
            dataResponses: [.init(statusCode: 200, data: Data("novita-image".utf8))]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: NovitaAITestModelProvider()
        ) {
            try await G_NOVITA_QWEN_IMAGE(
                pollingPolicy: .init(maxAttempts: 3, intervalNanoseconds: 0)
            ).makeRequest(request: request(numberOfImages: 4))
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests.count == 4)
        #expect(mock.requests[0].url.absoluteString == "https://api.novita.ai/v3/async/qwen-image-txt2img")
        #expect(mock.requests.dropFirst().allSatisfy {
            $0.url.absoluteString == "https://api.novita.ai/v3/async/task-result?task_id=\(taskId)"
        })
        #expect(mock.requests.allSatisfy { $0.headers?["Authorization"] == "Bearer \(apiKey)" })
        #expect(mock.requests[1].headers?["Content-Type"] == nil)

        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["prompt"] as? String == "A typographic aircraft poster")
        #expect(json["size"] as? String == "1344*768")
        #expect(json.count == 2)

        #expect(mock.dataRequests.count == 1)
        #expect(mock.dataRequests[0].url?.absoluteString == outputURL)
        #expect(mock.dataRequests[0].value(forHTTPHeaderField: "Authorization") == nil)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "bm92aXRhLWltYWdl")
        #expect(response.cost == 0.02)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == taskId)
        #expect(response.metadata?["novitaImageURLTTL"] == "3600")
    }

    @Test("Classifies the official SDK task state enum and fails closed")
    func states() throws {
        #expect(try G_NOVITA_QWEN_IMAGE.classify(status("TASK_STATUS_QUEUED")) == .pending)
        #expect(try G_NOVITA_QWEN_IMAGE.classify(status("TASK_STATUS_PROCESSING")) == .pending)
        #expect(try G_NOVITA_QWEN_IMAGE.classify(status("TASK_STATUS_SUCCEED")) == .succeeded)
        #expect(try G_NOVITA_QWEN_IMAGE.classify(status(
            "TASK_STATUS_FAILED",
            reason: "Generation rejected"
        )) == .failed("Generation rejected"))
        #expect(try G_NOVITA_QWEN_IMAGE.classify(status("TASK_STATUS_UNKNOWN")) ==
            .failed("Novita AI returned an unknown task state."))
        #expect(try G_NOVITA_QWEN_IMAGE.classify(status("WAITING_FOR_GPU")) ==
            .failed("Unknown Novita AI task status: WAITING_FOR_GPU"))
    }

    @Test("Surfaces create failures, NSFW output, and bounded timeouts")
    func failureCases() async throws {
        let createFailure = NovitaAIMockNetworkProvider(responses: [
            .dictionary(statusCode: 429, data: ["message": "Insufficient balance"]),
        ])
        let failedCreate = try await withProviderDependencies(
            networkProvider: createFailure,
            modelProvider: NovitaAITestModelProvider()
        ) {
            try await G_NOVITA_QWEN_IMAGE().makeRequest(request: request())
        }
        #expect(failedCreate.status == .FAILED)
        #expect(failedCreate.errorMessage == "Insufficient balance")
        #expect(createFailure.singleAttemptRequestCount == 1)

        let nsfw = NovitaAIMockNetworkProvider(responses: [
            .dictionary(statusCode: 200, data: ["task_id": taskId]),
            status(
                "TASK_STATUS_SUCCEED",
                images: [[
                    "image_url": "https://cdn.example/blocked.jpeg",
                    "image_url_ttl": 3600,
                    "image_type": "jpeg",
                    "nsfw_detection_result": true,
                ]]
            ),
        ])
        let blocked = try await withProviderDependencies(
            networkProvider: nsfw,
            modelProvider: NovitaAITestModelProvider()
        ) {
            try await G_NOVITA_QWEN_IMAGE(
                pollingPolicy: .init(maxAttempts: 1, intervalNanoseconds: 0)
            ).makeRequest(request: request())
        }
        #expect(blocked.status == .FAILED)
        #expect(blocked.errorMessage?.contains("NSFW") == true)
        #expect(nsfw.dataRequests.isEmpty)

        let timeout = NovitaAIMockNetworkProvider(responses: [
            .dictionary(statusCode: 200, data: ["task_id": taskId]),
            status("TASK_STATUS_PROCESSING"),
        ])
        let timedOut = try await withProviderDependencies(
            networkProvider: timeout,
            modelProvider: NovitaAITestModelProvider()
        ) {
            try await G_NOVITA_QWEN_IMAGE(
                pollingPolicy: .init(maxAttempts: 1, intervalNanoseconds: 0)
            ).makeRequest(request: request())
        }
        #expect(timedOut.status == .FAILED)
        #expect(timedOut.errorMessage?.contains("did not finish after 1 status checks") == true)
    }

    @Test("Rejects unsupported media, dimensions, and credentials before spending")
    func validation() async throws {
        let mock = NovitaAIMockNetworkProvider()

        let dimensions = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: NovitaAITestModelProvider()
        ) {
            try await G_NOVITA_QWEN_IMAGE().makeRequest(request: request(dimensions: "2048x2048"))
        }
        #expect(dimensions.status == .FAILED)
        #expect(dimensions.errorMessage?.contains("between 256 and 1536") == true)

        let source = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: NovitaAITestModelProvider()
        ) {
            var value = request()
            value.clientReferenceImages = [.init(base64Image: "aW1hZ2U=")]
            return try await G_NOVITA_QWEN_IMAGE().makeRequest(request: value)
        }
        #expect(source.status == .FAILED)
        #expect(source.errorMessage?.contains("text-to-image only") == true)

        let credentials = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: NovitaAITestModelProvider()
        ) {
            try await G_NOVITA_QWEN_IMAGE().makeRequest(request: request(secret: " "))
        }
        #expect(credentials.status == .FAILED)
        #expect(credentials.errorMessage?.contains("credentials are empty") == true)
        #expect(mock.requests.isEmpty)
    }

    @Test("Registers source-backed Qwen-Image capability and price")
    func catalog() throws {
        let model = try #require(NovitaAIModels.createModels().first)
        #expect(model.modelCode == .NOVITA_QWEN_IMAGE)
        #expect(model.providerId == EnumProviderCode.NOVITA_AI.providerId)
        #expect(model.modelLaunchDate == getDateFromString("2025-08-06"))
        #expect(model.modelVerificationDate == getDateFromString("2026-07-10"))
        #expect(model.modelStatusBaseURL == "https://api.novita.ai/v3/async/task-result")
        #expect(model.pricingMetadata?.unit == .image)
        #expect(model.pricingMetadata?.sourceURL == "https://novita.ai/pricing")
        #expect(G_NOVITA_QWEN_IMAGE().getCostEstimate(request: .init(numberOfImages: 8)) == 0.02)
        #expect(AllModels.createModels().filter { $0.providerId == EnumProviderCode.NOVITA_AI.providerId }.count == 1)
    }

    private func status(
        _ value: String,
        progress: Int = 0,
        reason: String = "",
        images: [[String: Any]] = []
    ) -> NetworkResponseData {
        .dictionary(statusCode: 200, data: [
            "extra": ["has_nsfw_contents": []],
            "task": [
                "task_id": taskId,
                "task_type": "QWEN_IMAGE_TEXT_TO_IMAGE",
                "status": value,
                "reason": reason,
                "eta": 0,
                "progress_percent": progress,
            ],
            "images": images,
            "videos": [],
            "audios": [],
        ])
    }

    private func request(
        secret: String = "novita-test-api-key",
        dimensions: String = "1344x768",
        numberOfImages: Int = 1
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: EnumProviderModelCode.NOVITA_QWEN_IMAGE.modelId.uuidString,
            prompt: "A typographic aircraft poster",
            dimensions: dimensions,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.NOVITA_AI.providerId,
                providerCode: .NOVITA_AI,
                projectId: UUID()
            ),
            providerSecret: secret,
            numberOfImages: numberOfImages
        )
    }
}

private final class NovitaAIMockNetworkProvider: @unchecked Sendable, NetworkProvider {
    struct CapturedRequest {
        let url: URL
        let method: String
        let headers: [String: String]?
        let body: Data?
    }

    var requests: [CapturedRequest] = []
    var singleAttemptRequestCount = 0
    var dataRequests: [URLRequest] = []
    private var responses: [NetworkResponseData]
    private var dataResponses: [NetworkDataResponse]

    init(
        responses: [NetworkResponseData] = [],
        dataResponses: [NetworkDataResponse] = []
    ) {
        self.responses = responses
        self.dataResponses = dataResponses
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
            headers: headers,
            body: body.map { try JSONEncoder().encode($0) }
        ))
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
        return try await NetworkResponseEnvelope(response: performRequest(
            url: url,
            method: method,
            body: body,
            headers: headers,
            attachments: attachments
        ))
    }

    func performDataRequest(_ request: URLRequest) async throws -> NetworkDataResponse {
        dataRequests.append(request)
        guard !dataResponses.isEmpty else { throw URLError(.badServerResponse) }
        return dataResponses.removeFirst()
    }
}

private struct NovitaAITestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        NovitaAIModels.createModels().first { $0.modelCode == code }
    }
}
