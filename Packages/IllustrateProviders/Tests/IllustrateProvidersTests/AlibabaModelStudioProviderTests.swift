import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("Alibaba Model Studio direct provider", .serialized)
struct AlibabaModelStudioProviderTests {
    private let taskId = "wan-task-123"
    private let secret = #"{"api_key":"alibaba-key","workspace_id":"workspace-7","region":"singapore"}"#

    @Test("Credentials construct only documented regional workspace hosts")
    func strictRegionalHosts() throws {
        let singapore = try AlibabaModelStudioClient.credentials(from: secret)
        #expect(singapore.baseURL.absoluteString == "https://workspace-7.ap-southeast-1.maas.aliyuncs.com")
        #expect(singapore.region == .singapore)

        let beijing = try AlibabaModelStudioClient.credentials(
            from: #"{"api_key":"key","workspace_id":"cn-workspace","region":"beijing"}"#
        )
        #expect(beijing.baseURL.absoluteString == "https://cn-workspace.cn-beijing.maas.aliyuncs.com")
        #expect(beijing.region == .beijing)

        #expect(throws: AlibabaModelStudioError.self) {
            try AlibabaModelStudioClient.credentials(
                from: #"{"api_key":"key","workspace_id":"workspace","region":"us"}"#
            )
        }
        #expect(throws: AlibabaModelStudioError.self) {
            try AlibabaModelStudioClient.credentials(
                from: #"{"api_key":"key","workspace_id":"evil.example.com","region":"singapore"}"#
            )
        }
    }

    @Test("Image create is exact once and output download omits bearer auth")
    func imageAsyncFlow() async throws {
        let outputURL = "https://dashscope-result.example/wan.png?expires=300"
        let mock = AlibabaMockNetworkProvider(
            responses: [
                createFixture(),
                statusFixture("RUNNING"),
                .dictionary(statusCode: 200, data: [
                    "request_id": "request-2",
                    "output": [
                        "task_id": taskId,
                        "task_status": "SUCCEEDED",
                        "choices": [[
                            "message": [
                                "content": [["type": "image", "image": outputURL]],
                            ],
                        ]],
                    ],
                    "usage": ["width": 2048, "height": 2048],
                ]),
            ],
            dataResponses: [
                NetworkDataResponse(
                    statusCode: 200,
                    data: Data("alibaba-image".utf8),
                    headers: ["Content-Type": "image/png"]
                ),
            ]
        )

        let response = try await withProviderDependencies(networkProvider: mock) {
            try await G_ALIBABA_WAN_2_7_IMAGE_PRO(
                pollingPolicy: .init(maxAttempts: 3, intervalNanoseconds: 0)
            ).makeRequest(request: imageRequest(resolution: "2K", seed: 42))
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests.count == 3)
        #expect(mock.requests[0].url.absoluteString ==
            "https://workspace-7.ap-southeast-1.maas.aliyuncs.com/api/v1/services/aigc/image-generation/generation")
        #expect(mock.requests[1].url.absoluteString ==
            "https://workspace-7.ap-southeast-1.maas.aliyuncs.com/api/v1/tasks/\(taskId)")
        #expect(mock.requests[0].headers?["Authorization"] == "Bearer alibaba-key")
        #expect(mock.requests[0].headers?["X-DashScope-Async"] == "enable")
        #expect(mock.requests[1].headers?["X-DashScope-Async"] == nil)

        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "wan2.7-image-pro")
        let parameters = try #require(json["parameters"] as? [String: Any])
        #expect(parameters["size"] as? String == "2K")
        #expect(parameters["n"] as? Int == 1)
        #expect(parameters["seed"] as? Int == 42)

        let download = try #require(mock.dataRequests.first)
        #expect(download.url?.absoluteString == outputURL)
        #expect(download.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "YWxpYmFiYS1pbWFnZQ==")
        #expect(response.cost == 0.075)
        #expect(response.actualDimensions == "2048x2048")
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == taskId)
        #expect(response.metadata?[ProviderJobMetadataKey.cancelURL] == nil)
    }

    @Test("Video sends documented controls and materializes the succeeded task")
    func textToVideoAsyncFlow() async throws {
        let outputURL = "https://dashscope-result.example/wan.mp4"
        let mock = AlibabaMockNetworkProvider(
            responses: [
                createFixture(),
                .dictionary(statusCode: 200, data: [
                    "output": [
                        "task_id": taskId,
                        "task_status": "SUCCEEDED",
                        "video_url": outputURL,
                    ],
                ]),
            ],
            dataResponses: [
                NetworkDataResponse(
                    statusCode: 200,
                    data: Data("alibaba-video".utf8),
                    headers: ["Content-Type": "video/mp4"]
                ),
            ]
        )

        let response = try await withProviderDependencies(networkProvider: mock) {
            try await G_ALIBABA_WAN_2_7_T2V(
                pollingPolicy: .init(maxAttempts: 2, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest(
                modelCode: .ALIBABA_WAN_2_7_T2V,
                dimensions: "9:16",
                duration: 6,
                resolution: "720p",
                negativePrompt: "no text",
                seed: 7
            ))
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests[0].url.path == "/api/v1/services/aigc/video-generation/video-synthesis")
        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "wan2.7-t2v")
        let input = try #require(json["input"] as? [String: Any])
        #expect(input["prompt"] as? String == "An aircraft taxis through rain")
        #expect(input["negative_prompt"] as? String == "no text")
        #expect(input["media"] == nil)
        let parameters = try #require(json["parameters"] as? [String: Any])
        #expect(parameters["resolution"] as? String == "720P")
        #expect(parameters["ratio"] as? String == "9:16")
        #expect(parameters["duration"] as? Int == 6)
        #expect(parameters["seed"] as? Int == 7)

        #expect(mock.dataRequests.first?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "YWxpYmFiYS12aWRlbw==")
        #expect(abs((response.cost ?? 0) - 0.6) < 0.000_001)
        #expect(response.actualDuration == 6)
    }

    @Test("Image-to-video accepts one first input and optional final frame")
    func imageToVideoMediaContract() throws {
        let adapter = G_ALIBABA_WAN_2_7_I2V()
        let request = videoRequest(
            modelCode: .ALIBABA_WAN_2_7_I2V,
            dimensions: "16:9",
            duration: 5,
            resolution: "1080P",
            clientImage: "aW1hZ2U=",
            clientLastFrame: "https://assets.example/final.webp"
        )

        let transformed = try adapter.validatedServiceRequest(from: request)
        #expect(transformed.model == "wan2.7-i2v")
        #expect(transformed.input.media?.map(\.type) == ["first_frame", "last_frame"])
        #expect(transformed.input.media?.first?.url == "data:image/png;base64,aW1hZ2U=")
        #expect(transformed.input.media?.last?.url == "https://assets.example/final.webp")
        #expect(transformed.parameters.ratio == nil)

        var conflicting = request
        conflicting.clientVideo = "https://assets.example/input.mp4"
        #expect(throws: AlibabaModelStudioError.self) {
            try adapter.validatedServiceRequest(from: conflicting)
        }
    }

    @Test("Body errors fail without repeating a paid create")
    func bodyErrorDoesNotRetryCreate() async throws {
        let mock = AlibabaMockNetworkProvider(responses: [
            .dictionary(statusCode: 200, data: [
                "code": "InvalidParameter",
                "message": "unsupported input",
                "request_id": "request-error",
            ]),
        ])

        let response = try await withProviderDependencies(networkProvider: mock) {
            try await G_ALIBABA_WAN_2_7_IMAGE().makeRequest(
                request: imageRequest(modelCode: .ALIBABA_WAN_2_7_IMAGE, resolution: "1K")
            )
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests.count == 1)
        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("InvalidParameter") == true)
    }

    @Test("All documented task states are bounded and explicit")
    func taskStateClassification() throws {
        #expect(try AlibabaModelStudioClient.classify(statusFixture("PENDING")) == .pending)
        #expect(try AlibabaModelStudioClient.classify(statusFixture("RUNNING")) == .pending)
        #expect(try AlibabaModelStudioClient.classify(statusFixture("SUCCEEDED")) == .succeeded)
        #expect(try AlibabaModelStudioClient.classify(statusFixture("CANCELED")) == .cancelled)
        #expect(try AlibabaModelStudioClient.classify(statusFixture("UNKNOWN")) ==
            .failed("Alibaba task is unknown or its 24-hour query window expired."))
        #expect(try AlibabaModelStudioClient.classify(.dictionary(statusCode: 200, data: [
            "output": [
                "task_status": "FAILED",
                "code": "DataInspectionFailed",
                "message": "content rejected",
            ],
        ])) == .failed("Alibaba generation failed (DataInspectionFailed): content rejected"))
    }

    @Test("Validation rejects unsupported capability and pricing combinations")
    func validationAndPricingMatrix() throws {
        let beijingSecret = #"{"api_key":"key","workspace_id":"cn-workspace","region":"beijing"}"#
        let imagePro = G_ALIBABA_WAN_2_7_IMAGE_PRO()
        var editing4K = imageRequest(resolution: "4K", clientImage: "aW1hZ2U=")
        #expect(throws: AlibabaModelStudioError.self) {
            try imagePro.validatedServiceRequest(from: editing4K)
        }
        editing4K.clientImage = nil
        #expect(try imagePro.validatedServiceRequest(from: editing4K).parameters.size == "4K")

        let standard = G_ALIBABA_WAN_2_7_IMAGE()
        #expect(throws: AlibabaModelStudioError.self) {
            try standard.validatedServiceRequest(from: imageRequest(
                modelCode: .ALIBABA_WAN_2_7_IMAGE,
                resolution: "4K"
            ))
        }

        let t2v = G_ALIBABA_WAN_2_7_T2V()
        var invalidVideo = videoRequest(
            modelCode: .ALIBABA_WAN_2_7_T2V,
            dimensions: "16:9",
            duration: 16,
            resolution: "1080p"
        )
        #expect(throws: AlibabaModelStudioError.self) {
            try t2v.validatedServiceRequest(from: invalidVideo)
        }
        invalidVideo.durationSeconds = 5
        invalidVideo.generateAudio = false
        #expect(throws: AlibabaModelStudioError.self) {
            try t2v.validatedServiceRequest(from: invalidVideo)
        }

        #expect(AlibabaModelStudioClient.pricePerImage(
            modelCode: .ALIBABA_WAN_2_7_IMAGE_PRO,
            region: .singapore
        ) == 0.075)
        #expect(AlibabaModelStudioClient.pricePerImage(
            modelCode: .ALIBABA_WAN_2_7_IMAGE,
            region: .beijing
        ) == 0.028671)
        #expect(AlibabaModelStudioClient.pricePerVideoSecond(
            resolution: "1080P",
            region: .beijing
        ) == 0.143353)
        #expect(imagePro.getCostEstimate(request: .init(
            numberOfImages: 1,
            providerSecret: beijingSecret
        )) == 0.068761)
        #expect(abs(G_ALIBABA_WAN_2_7_T2V().getCostEstimate(request: .init(
            durationSeconds: 5,
            numberOfVideos: 1,
            resolution: "1080P",
            providerSecret: beijingSecret
        )) - 0.716765) < 0.000_001)
    }

    @Test("Catalog is the four documented Wan 2.7 model choices")
    func catalogBoundary() {
        let models = AlibabaModelStudioModels.createModels()

        #expect(models.map(\.modelCode) == [
            .ALIBABA_WAN_2_7_IMAGE_PRO,
            .ALIBABA_WAN_2_7_IMAGE,
            .ALIBABA_WAN_2_7_T2V,
            .ALIBABA_WAN_2_7_I2V,
        ])
        #expect(!models.contains { !$0.active })
        #expect(models.allSatisfy {
            $0.providerId == EnumProviderCode.ALIBABA_MODEL_STUDIO.providerId
                && $0.modelVerificationDate == getDateFromString("2026-07-10")
                && $0.pricingMetadata?.sourceURL.contains("model-pricing") == true
        })
        #expect(models.filter { $0.modelSetType == .IMAGE_GENERATE }.count == 2)
        #expect(models.filter { $0.modelSetType == .VIDEO_GENERATE }.count == 2)
    }

    private func createFixture() -> NetworkResponseData {
        .dictionary(statusCode: 200, data: [
            "request_id": "request-1",
            "output": ["task_id": taskId, "task_status": "PENDING"],
        ])
    }

    private func statusFixture(_ status: String) -> NetworkResponseData {
        .dictionary(statusCode: 200, data: [
            "request_id": "request-status",
            "output": ["task_id": taskId, "task_status": status],
        ])
    }

    private func imageRequest(
        modelCode: EnumProviderModelCode = .ALIBABA_WAN_2_7_IMAGE_PRO,
        resolution: String,
        clientImage: String? = nil,
        seed: Int? = nil
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: modelCode.modelId.uuidString,
            prompt: "A polished aircraft portrait",
            dimensions: "1:1",
            clientImage: clientImage,
            providerKey: providerKey,
            providerSecret: secret,
            resolution: resolution,
            seed: seed
        )
    }

    private func videoRequest(
        modelCode: EnumProviderModelCode,
        dimensions: String,
        duration: Int,
        resolution: String,
        negativePrompt: String? = nil,
        clientImage: String? = nil,
        clientLastFrame: String? = nil,
        seed: Int? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: modelCode.modelId.uuidString,
            prompt: "An aircraft taxis through rain",
            negativePrompt: negativePrompt,
            dimensions: dimensions,
            clientImage: clientImage,
            clientLastFrame: clientLastFrame,
            providerKey: providerKey,
            providerSecret: secret,
            durationSeconds: duration,
            resolution: resolution,
            seed: seed
        )
    }

    private var providerKey: ProviderKeyInfo {
        ProviderKeyInfo(
            providerId: EnumProviderCode.ALIBABA_MODEL_STUDIO.providerId,
            providerCode: .ALIBABA_MODEL_STUDIO,
            projectId: UUID()
        )
    }
}

private final class AlibabaMockNetworkProvider: @unchecked Sendable, NetworkProvider {
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
