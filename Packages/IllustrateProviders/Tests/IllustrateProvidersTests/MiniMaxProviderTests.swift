import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("MiniMax direct provider", .serialized)
struct MiniMaxProviderTests {
    private let taskId = "minimax-task-123"
    private let secret = #"{"api_key":"minimax-key","region":"global"}"#

    @Test("Credentials select only the documented regional hosts")
    func strictRegionalHosts() throws {
        let global = try MiniMaxClient.credentials(from: secret)
        #expect(global.baseURL.absoluteString == "https://api.minimax.io")
        #expect(global.region == .global)

        let mainland = try MiniMaxClient.credentials(
            from: #"{"api_key":"key","region":"mainland"}"#
        )
        #expect(mainland.baseURL.absoluteString == "https://api.minimaxi.com")
        #expect(mainland.region == .mainland)

        #expect(throws: MiniMaxError.self) {
            try MiniMaxClient.credentials(from: #"{"api_key":"key","region":"custom"}"#)
        }
        #expect(throws: ProviderCredentialError.self) {
            try MiniMaxClient.credentials(from: #"{"region":"global"}"#)
        }
    }

    @Test("Image-01 sends one paid request and decodes body-level success")
    func imageGenerationFlow() async throws {
        let imageData = Data("minimax-image".utf8).base64EncodedString()
        let mock = MiniMaxMockNetworkProvider(responses: [
            .dictionary(statusCode: 200, data: [
                "data": [
                    "image_base64": [imageData],
                ],
                "metadata": ["success_count": "1", "failed_count": "0"],
                "base_resp": successBaseResponse,
            ]),
        ])

        let response = try await withProviderDependencies(networkProvider: mock) {
            try await G_MINIMAX_IMAGE_01().makeRequest(request: imageRequest(seed: 42))
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests.count == 1)
        #expect(mock.requests[0].url.absoluteString == "https://api.minimax.io/v1/image_generation")
        #expect(mock.requests[0].headers?["Authorization"] == "Bearer minimax-key")
        #expect(mock.requests[0].headers?["Content-Type"] == "application/json")
        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "image-01")
        #expect(json["prompt"] as? String == "A polished aircraft portrait")
        #expect(json["aspect_ratio"] as? String == "16:9")
        #expect(json["response_format"] as? String == "base64")
        #expect(json["seed"] as? Int == 42)
        #expect(json["n"] as? Int == 1)
        #expect(json["prompt_optimizer"] as? Bool == true)

        #expect(response.status == .GENERATED)
        #expect(response.base64 == imageData)
        #expect(response.cost == 0.0035)
        #expect(response.metadata?["minimaxSuccessCount"] == "1")
        #expect(response.metadata?["minimaxFailedCount"] == "0")
    }

    @Test("Video follows create query file and unauthenticated download chain")
    func videoGenerationFlow() async throws {
        let outputURL = "https://cdn.minimax.example/output.mp4?expires=300"
        let mock = MiniMaxMockNetworkProvider(
            responses: [
                .dictionary(statusCode: 200, data: [
                    "task_id": taskId,
                    "base_resp": successBaseResponse,
                ]),
                statusFixture("Processing"),
                .dictionary(statusCode: 200, data: [
                    "status": "Success",
                    "file_id": "file-456",
                    "base_resp": successBaseResponse,
                ]),
                .dictionary(statusCode: 200, data: [
                    "file": ["download_url": outputURL],
                    "base_resp": successBaseResponse,
                ]),
            ],
            dataResponses: [
                NetworkDataResponse(
                    statusCode: 200,
                    data: Data("minimax-video".utf8),
                    headers: ["Content-Type": "video/mp4"]
                ),
            ]
        )

        let response = try await withProviderDependencies(networkProvider: mock) {
            try await G_MINIMAX_HAILUO_2_3_I2V(
                pollingPolicy: .init(maxAttempts: 3, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest(
                modelCode: .MINIMAX_HAILUO_2_3_I2V,
                duration: 10,
                resolution: "768p",
                clientImage: "aW1hZ2U="
            ))
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests.count == 4)
        #expect(mock.requests[0].url.absoluteString == "https://api.minimax.io/v1/video_generation")
        #expect(mock.requests[1].url.path == "/v1/query/video_generation")
        #expect(URLComponents(url: mock.requests[1].url, resolvingAgainstBaseURL: false)?
            .queryItems?.first == URLQueryItem(name: "task_id", value: taskId))
        #expect(mock.requests[3].url.path == "/v1/files/retrieve")
        #expect(URLComponents(url: mock.requests[3].url, resolvingAgainstBaseURL: false)?
            .queryItems?.first == URLQueryItem(name: "file_id", value: "file-456"))
        #expect(mock.requests.allSatisfy {
            $0.headers?["Authorization"] == "Bearer minimax-key"
        })

        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "MiniMax-Hailuo-2.3")
        #expect(json["duration"] as? Int == 10)
        #expect(json["resolution"] as? String == "768P")
        #expect(json["first_frame_image"] as? String == "data:image/png;base64,aW1hZ2U=")
        #expect(json["prompt_optimizer"] as? Bool == true)
        #expect(json["fast_pretreatment"] as? Bool == false)

        let download = try #require(mock.dataRequests.first)
        #expect(download.url?.absoluteString == outputURL)
        #expect(download.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "bWluaW1heC12aWRlbw==")
        #expect(response.videoUrl == outputURL)
        #expect(response.cost == 0.56)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == taskId)
        #expect(response.metadata?[ProviderJobMetadataKey.cancelURL] == nil)
        #expect(response.metadata?["minimaxFileId"] == "file-456")
    }

    @Test("Body-level errors fail without repeating paid creates")
    func bodyErrorDoesNotRetryCreate() async throws {
        let mock = MiniMaxMockNetworkProvider(responses: [
            .dictionary(statusCode: 200, data: [
                "base_resp": ["status_code": 1004, "status_msg": "invalid parameter"],
            ]),
        ])

        let response = try await withProviderDependencies(networkProvider: mock) {
            try await G_MINIMAX_IMAGE_01().makeRequest(request: imageRequest())
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests.count == 1)
        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("1004") == true)
        #expect(response.errorMessage?.contains("invalid parameter") == true)
    }

    @Test("Task states are bounded and body errors remain failures")
    func statusClassification() throws {
        #expect(try MiniMaxClient.classify(statusFixture("Preparing")) == .pending)
        #expect(try MiniMaxClient.classify(statusFixture("Queueing")) == .pending)
        #expect(try MiniMaxClient.classify(statusFixture("Processing")) == .pending)
        #expect(try MiniMaxClient.classify(statusFixture("Success")) == .succeeded)
        #expect(try MiniMaxClient.classify(.dictionary(statusCode: 200, data: [
            "status": "Fail",
            "error_message": "generation rejected",
            "base_resp": successBaseResponse,
        ])) == .failed("generation rejected"))
        #expect(try MiniMaxClient.classify(.dictionary(statusCode: 200, data: [
            "status": "Processing",
            "base_resp": ["status_code": 1008, "status_msg": "insufficient balance"],
        ])) == .failed("MiniMax status failed (1008): insufficient balance"))
        #expect(try MiniMaxClient.classify(statusFixture("Mystery")) ==
            .failed("Unknown MiniMax task status: Mystery"))
    }

    @Test("Capabilities and the exact price matrix fail closed")
    func validationAndPricingMatrix() throws {
        let image = G_MINIMAX_IMAGE_01()
        var unsupportedImage = imageRequest()
        unsupportedImage.clientImage = "aW1hZ2U="
        #expect(throws: MiniMaxError.self) {
            try image.validatedServiceRequest(from: unsupportedImage)
        }

        let t2v = G_MINIMAX_HAILUO_2_3_T2V()
        var textRequest = videoRequest(
            modelCode: .MINIMAX_HAILUO_2_3_T2V,
            duration: 6,
            resolution: "1080P"
        )
        #expect(try t2v.validatedServiceRequest(from: textRequest).first_frame_image == nil)
        textRequest.clientImage = "aW1hZ2U="
        #expect(throws: MiniMaxError.self) {
            try t2v.validatedServiceRequest(from: textRequest)
        }

        let i2v = G_MINIMAX_HAILUO_2_3_I2V()
        #expect(throws: MiniMaxError.self) {
            try i2v.validatedServiceRequest(from: videoRequest(
                modelCode: .MINIMAX_HAILUO_2_3_I2V,
                duration: 6,
                resolution: "768P"
            ))
        }
        #expect(throws: MiniMaxError.self) {
            try MiniMaxClient.price(mode: .standard, resolution: "1080P", duration: 10)
        }

        #expect(try MiniMaxClient.price(mode: .standard, resolution: "768P", duration: 6) == 0.28)
        #expect(try MiniMaxClient.price(mode: .standard, resolution: "768P", duration: 10) == 0.56)
        #expect(try MiniMaxClient.price(mode: .standard, resolution: "1080P", duration: 6) == 0.49)
        #expect(try MiniMaxClient.price(mode: .fast, resolution: "768P", duration: 6) == 0.19)
        #expect(try MiniMaxClient.price(mode: .fast, resolution: "768P", duration: 10) == 0.32)
        #expect(try MiniMaxClient.price(mode: .fast, resolution: "1080P", duration: 6) == 0.33)
    }

    @Test("Fast Hailuo uses its dedicated upstream model")
    func fastModelRequest() throws {
        let request = videoRequest(
            modelCode: .MINIMAX_HAILUO_2_3_FAST_I2V,
            duration: 6,
            resolution: "1080P",
            clientImage: "https://assets.example/frame.webp"
        )
        let transformed = try G_MINIMAX_HAILUO_2_3_FAST_I2V()
            .validatedServiceRequest(from: request)

        #expect(transformed.model == "MiniMax-Hailuo-2.3-Fast")
        #expect(transformed.first_frame_image == "https://assets.example/frame.webp")
        #expect(transformed.duration == 6)
        #expect(transformed.resolution == "1080P")
    }

    @Test("Catalog contains only Image-01 and the three Hailuo choices")
    func catalogBoundary() {
        let models = MiniMaxModels.createModels()

        #expect(models.map(\.modelCode) == [
            .MINIMAX_IMAGE_01,
            .MINIMAX_HAILUO_2_3_T2V,
            .MINIMAX_HAILUO_2_3_I2V,
            .MINIMAX_HAILUO_2_3_FAST_I2V,
        ])
        #expect(!models.contains { !$0.active })
        #expect(!models.contains { $0.modelName.lowercased().contains("live") })
        #expect(!models.contains { $0.modelName.contains("Hailuo 02") })
        #expect(models.allSatisfy {
            $0.providerId == EnumProviderCode.MINIMAX.providerId
                && $0.modelVerificationDate == getDateFromString("2026-07-10")
                && $0.pricingMetadata?.sourceURL.contains("pricing") == true
        })
    }

    private var successBaseResponse: [String: Any] {
        ["status_code": 0, "status_msg": "success"]
    }

    private func statusFixture(_ status: String) -> NetworkResponseData {
        .dictionary(statusCode: 200, data: [
            "status": status,
            "base_resp": successBaseResponse,
        ])
    }

    private func imageRequest(seed: Int? = nil) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: EnumProviderModelCode.MINIMAX_IMAGE_01.modelId.uuidString,
            prompt: "A polished aircraft portrait",
            dimensions: "16:9",
            providerKey: providerKey,
            providerSecret: secret,
            seed: seed
        )
    }

    private func videoRequest(
        modelCode: EnumProviderModelCode,
        duration: Int,
        resolution: String,
        clientImage: String? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: modelCode.modelId.uuidString,
            prompt: "An aircraft taxis through rain",
            dimensions: "",
            clientImage: clientImage,
            providerKey: providerKey,
            providerSecret: secret,
            durationSeconds: duration,
            resolution: resolution
        )
    }

    private var providerKey: ProviderKeyInfo {
        ProviderKeyInfo(
            providerId: EnumProviderCode.MINIMAX.providerId,
            providerCode: .MINIMAX,
            projectId: UUID()
        )
    }
}

private final class MiniMaxMockNetworkProvider: @unchecked Sendable, NetworkProvider {
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

    func performDataRequest(_ request: URLRequest) async throws -> NetworkDataResponse {
        dataRequests.append(request)
        guard !dataResponses.isEmpty else { throw URLError(.badServerResponse) }
        return dataResponses.removeFirst()
    }
}
