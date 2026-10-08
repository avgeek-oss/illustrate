import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("Vidu direct provider", .serialized)
struct ViduProviderTests {
    private let apiKey = "vidu-test-api-key"
    private let taskId = "task_20260710_abc"

    @Test("Q3 Pro follows the documented async workflow")
    func q3ProFlow() async throws {
        let outputURL = "https://cdn.vidu.example/generated.mp4?expires=86400"
        let mock = ViduMockNetworkProvider(
            responses: [
                .dictionary(statusCode: 200, data: ["task_id": taskId, "state": "created"]),
                .dictionary(statusCode: 200, data: ["state": "queueing"]),
                .dictionary(statusCode: 200, data: ["state": "success", "creations": [["url": outputURL]]]),
            ],
            dataResponses: [.init(statusCode: 200, data: Data("vidu-video".utf8))]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: ViduTestModelProvider()
        ) {
            try await G_VIDU_Q3_PRO(
                pollingPolicy: .init(maxAttempts: 2, intervalNanoseconds: 0)
            ).makeRequest(request: request(
                modelCode: .VIDU_Q3_PRO,
                duration: 10,
                resolution: "720p",
                seed: 42
            ))
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests.count == 3)
        #expect(mock.requests[0].url.absoluteString == "https://api.vidu.com/ent/v2/text2video")
        #expect(mock.requests.dropFirst().allSatisfy {
            $0.url.absoluteString == "https://api.vidu.com/ent/v2/tasks/\(taskId)/creations"
        })
        #expect(mock.requests[0].headers?["Authorization"] == "Token \(apiKey)")
        #expect(mock.requests[1].headers?["Content-Type"] == nil)

        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "viduq3-pro")
        #expect(json["prompt"] as? String == "An airliner lifts through morning fog")
        #expect(json["duration"] as? Int == 10)
        #expect(json["aspect_ratio"] as? String == "16:9")
        #expect(json["resolution"] as? String == "720p")
        #expect(json["audio"] as? Bool == true)
        #expect(json["seed"] as? Int == 42)
        #expect(json["off_peak"] == nil)

        #expect(mock.dataRequests.first?.url?.absoluteString == outputURL)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "dmlkdS12aWRlbw==")
        #expect(response.cost == 1.0)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == taskId)
    }

    @Test("Pricing follows model and resolution tables")
    func pricing() {
        #expect(G_VIDU_Q3_PRO().getCostEstimate(request: .init(
            durationSeconds: 8,
            numberOfVideos: 2,
            resolution: "1080p"
        )) == 1.92)
        #expect(G_VIDU_Q3_TURBO().getCostEstimate(request: .init(
            durationSeconds: 10,
            numberOfVideos: 1,
            resolution: "720p"
        )) == 0.55)
    }

    @Test("Rejects undocumented request shapes before network activity")
    func validation() async throws {
        let mock = ViduMockNetworkProvider()
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: ViduTestModelProvider()
        ) {
            var value = request(modelCode: .VIDU_Q3_PRO, duration: 17, resolution: "4k")
            value.clientImage = "aW1hZ2U="
            return try await G_VIDU_Q3_PRO().makeRequest(request: value)
        }
        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("source media") == true)
        #expect(mock.requests.isEmpty)
    }

    @Test("Classifies all documented states")
    func states() throws {
        for state in ["created", "queueing", "processing"] {
            #expect(try ViduTaskClient.classify(
                .dictionary(statusCode: 200, data: ["state": state])
            ) == .pending)
        }
        #expect(try ViduTaskClient.classify(
            .dictionary(statusCode: 200, data: ["state": "success"])
        ) == .succeeded)
        #expect(try ViduTaskClient.classify(
            .dictionary(statusCode: 200, data: ["state": "failed", "err_code": "SAFETY_BLOCK"])
        ) == .failed("Vidu generation failed (SAFETY_BLOCK)."))
    }

    @Test("Uses the documented cancellation endpoint")
    func cancellation() async throws {
        let mock = ViduMockNetworkProvider(rawResponses: [.dictionary(statusCode: 200, data: [:])])
        try await ViduTaskClient.cancel(jobId: taskId, apiKey: apiKey, network: mock)
        let request = try #require(mock.rawRequests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.vidu.com/ent/v2/tasks/\(taskId)/cancel")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Token \(apiKey)")
        #expect(request.httpBody == Data("{}".utf8))

        await #expect(throws: ViduAdapterError.self) {
            try await ViduTaskClient.cancel(jobId: "../unsafe", apiKey: apiKey, network: mock)
        }
        #expect(mock.rawRequests.count == 1)
    }

    @Test("Registers source-backed catalog metadata")
    func catalog() {
        let models = ViduModels.createModels()
        #expect(models.map(\.modelCode) == [.VIDU_Q3_PRO, .VIDU_Q3_TURBO])
        #expect(models.allSatisfy { $0.providerId == EnumProviderCode.VIDU.providerId })
        #expect(models.allSatisfy { $0.modelParams.supportedVideoDurations == Array(1 ... 16) })
        #expect(models.map(\.modelParams.supportsAudio) == [true, true])
        #expect(models[0].modelLaunchDate == getDateFromString("2026-01-27"))
        #expect(models[1].modelLaunchDate == getDateFromString("2026-02-11"))
        #expect(AllModels.createModels().filter { $0.providerId == EnumProviderCode.VIDU.providerId }.count == 2)
    }

    private func request(
        modelCode: EnumProviderModelCode,
        duration: Int,
        resolution: String,
        seed: Int? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: modelCode.modelId.uuidString,
            prompt: "An airliner lifts through morning fog",
            dimensions: "16:9",
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.VIDU.providerId,
                providerCode: .VIDU,
                projectId: UUID()
            ),
            providerSecret: apiKey,
            durationSeconds: duration,
            resolution: resolution,
            generateAudio: true,
            seed: seed
        )
    }
}

private final class ViduMockNetworkProvider: @unchecked Sendable, NetworkProvider {
    struct CapturedRequest {
        let url: URL
        let method: String
        let headers: [String: String]?
        let body: Data?
    }

    var requests: [CapturedRequest] = []
    var singleAttemptRequestCount = 0
    var rawRequests: [URLRequest] = []
    var dataRequests: [URLRequest] = []
    private var responses: [NetworkResponseData]
    private var rawResponses: [NetworkResponseData]
    private var dataResponses: [NetworkDataResponse]

    init(
        responses: [NetworkResponseData] = [],
        rawResponses: [NetworkResponseData] = [],
        dataResponses: [NetworkDataResponse] = []
    ) {
        self.responses = responses
        self.rawResponses = rawResponses
        self.dataResponses = dataResponses
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
        return try await NetworkResponseEnvelope(response: performRequest(
            url: url,
            method: method,
            body: body,
            headers: headers,
            attachments: attachments
        ))
    }

    func performRawRequest(_ request: URLRequest) async throws -> NetworkResponseData {
        rawRequests.append(request)
        guard !rawResponses.isEmpty else { throw URLError(.badServerResponse) }
        return rawResponses.removeFirst()
    }

    func performDataRequest(_ request: URLRequest) async throws -> NetworkDataResponse {
        dataRequests.append(request)
        guard !dataResponses.isEmpty else { throw URLError(.badServerResponse) }
        return dataResponses.removeFirst()
    }
}

private struct ViduTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        ViduModels.createModels().first { $0.modelCode == code }
    }
}
