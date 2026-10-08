import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("PixVerse direct provider", .serialized)
struct PixVerseProviderTests {
    private let apiKey = "pixverse-test-api-key"
    private let videoId = 98765

    @Test("V6 uses a unique create trace and documented polling workflow")
    func v6Flow() async throws {
        let outputURL = "https://media.pixverse.example/video.mp4?expires=600"
        let mock = PixVerseMockNetworkProvider(
            responses: [
                envelope(resp: ["video_id": videoId]),
                envelope(resp: ["status": 5]),
                envelope(resp: ["status": 1, "url": outputURL]),
            ],
            dataResponses: [.init(statusCode: 200, data: Data("pixverse-video".utf8))]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: PixVerseTestModelProvider()
        ) {
            try await G_PIXVERSE_V6(
                pollingPolicy: .init(maxAttempts: 2, intervalNanoseconds: 0)
            ).makeRequest(request: request(
                modelCode: .PIXVERSE_V6,
                duration: 8,
                resolution: "720p",
                audio: true,
                seed: 123
            ))
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests.count == 3)
        #expect(mock.requests[0].url.absoluteString ==
            "https://app-api.pixverse.ai/openapi/v2/video/text/generate")
        #expect(mock.requests.dropFirst().allSatisfy {
            $0.url.absoluteString == "https://app-api.pixverse.ai/openapi/v2/video/result/\(videoId)"
        })
        #expect(mock.requests.allSatisfy { $0.headers?["API-KEY"] == apiKey })
        let traces = try mock.requests.map {
            let trace = try #require($0.headers?["Ai-trace-id"])
            return try #require(UUID(uuidString: trace))
        }
        #expect(Set(traces).count == traces.count)
        #expect(mock.requests[1].headers?["Content-Type"] == nil)

        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "v6")
        #expect(json["prompt"] as? String == "A dramatic aircraft departure")
        #expect(json["duration"] as? Int == 8)
        #expect(json["aspect_ratio"] as? String == "21:9")
        #expect(json["quality"] as? String == "720p")
        #expect(json["generate_audio_switch"] as? Bool == true)
        #expect(json["seed"] as? Int == 123)

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "cGl4dmVyc2UtdmlkZW8=")
        #expect(response.cost == 96)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == String(videoId))
        #expect(UUID(uuidString: response.metadata?["pixVerseTraceId"] ?? "") != nil)
    }

    @Test("Pricing is resolution and audio aware")
    func pricing() {
        #expect(G_PIXVERSE_C1().getCostEstimate(request: .init(
            durationSeconds: 10,
            numberOfVideos: 2,
            resolution: "1080p",
            generateAudio: true
        )) == 480)
        #expect(G_PIXVERSE_V6().getCostEstimate(request: .init(
            durationSeconds: 5,
            numberOfVideos: 1,
            resolution: "720p",
            generateAudio: false
        )) == 45)
        #expect(G_PIXVERSE_V6().formatCost(request: .init(
            durationSeconds: 5,
            resolution: "720p",
            generateAudio: false
        )) == "45 credits")
    }

    @Test("Classifies every documented status and provider envelope errors")
    func states() throws {
        #expect(try PixVerseTaskClient.classify(envelope(resp: ["status": 5])) == .pending)
        #expect(try PixVerseTaskClient.classify(envelope(resp: ["status": 1])) == .succeeded)
        #expect(try PixVerseTaskClient.classify(envelope(resp: ["status": 7])) ==
            .failed("PixVerse content moderation failed."))
        #expect(try PixVerseTaskClient.classify(envelope(resp: ["status": 8])) ==
            .failed("PixVerse generation failed."))
        #expect(try PixVerseTaskClient.classify(.dictionary(statusCode: 200, data: [
            "ErrCode": 10005,
            "ErrMsg": "Insufficient credits",
        ])) == .failed("PixVerse status failed (10005): Insufficient credits."))
    }

    @Test("Rejects unsupported input before spending credits")
    func validation() async throws {
        let mock = PixVerseMockNetworkProvider()
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: PixVerseTestModelProvider()
        ) {
            var value = request(
                modelCode: .PIXVERSE_C1,
                duration: 16,
                resolution: "4k",
                audio: false
            )
            value.clientImage = "aW1hZ2U="
            return try await G_PIXVERSE_C1().makeRequest(request: value)
        }
        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("source media") == true)
        #expect(mock.requests.isEmpty)
    }

    @Test("Registers current model dates capabilities and pricing provenance")
    func catalog() {
        let models = PixVerseModels.createModels()
        #expect(models.map(\.modelCode) == [.PIXVERSE_C1, .PIXVERSE_V6])
        #expect(models.allSatisfy { $0.providerId == EnumProviderCode.PIXVERSE.providerId })
        #expect(models.map(\.modelParams.supportsAudio) == [true, true])
        #expect(models[0].modelLaunchDate == getDateFromString("2026-04-07"))
        #expect(models[1].modelLaunchDate == getDateFromString("2026-03-29"))
        #expect(models.allSatisfy { $0.pricingMetadata?.currency == "PixVerse credits" })
        #expect(AllModels.createModels().filter { $0.providerId == EnumProviderCode.PIXVERSE.providerId }.count == 2)
    }

    private func envelope(resp: [String: Any]) -> NetworkResponseData {
        .dictionary(statusCode: 200, data: ["ErrCode": 0, "ErrMsg": "success", "Resp": resp])
    }

    private func request(
        modelCode: EnumProviderModelCode,
        duration: Int,
        resolution: String,
        audio: Bool,
        seed: Int? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: modelCode.modelId.uuidString,
            prompt: "A dramatic aircraft departure",
            dimensions: "21:9",
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.PIXVERSE.providerId,
                providerCode: .PIXVERSE,
                projectId: UUID()
            ),
            providerSecret: apiKey,
            durationSeconds: duration,
            resolution: resolution,
            generateAudio: audio,
            seed: seed
        )
    }
}

private final class PixVerseMockNetworkProvider: @unchecked Sendable, NetworkProvider {
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

private struct PixVerseTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        PixVerseModels.createModels().first { $0.modelCode == code }
    }
}
