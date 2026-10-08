import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("Kling AI direct provider", .serialized)
struct KlingAIProviderTests {
    private let taskId = "kling-task-123"
    private let apiKey = "kling-direct-api-key"

    @Test("Credentials use one raw key and the fixed Singapore host")
    func strictCredentials() throws {
        let credentials = try KlingAIClient.credentials(from: "  \(apiKey)  ")
        #expect(credentials.apiKey == apiKey)
        #expect(credentials.baseURL.absoluteString == "https://api-singapore.klingai.com")

        #expect(throws: KlingAIError.self) {
            try KlingAIClient.credentials(from: "")
        }
        #expect(throws: KlingAIError.self) {
            try KlingAIClient.credentials(from: #"{"access_key":"ak","secret_key":"sk"}"#)
        }
    }

    @Test("Classic image create is exact once and output download omits bearer auth")
    func classicImageAsyncFlow() async throws {
        let outputURL = "https://kling-output.example/image.png?expires=300"
        let mock = KlingMockNetworkProvider(
            responses: [
                createFixture(),
                statusFixture("processing"),
                successFixture(kind: "images", outputURL: outputURL),
            ],
            dataResponses: [
                NetworkDataResponse(
                    statusCode: 200,
                    data: Data("kling-image".utf8),
                    headers: ["Content-Type": "image/png"]
                ),
            ]
        )

        let response = try await withProviderDependencies(networkProvider: mock) {
            try await G_KLING_IMAGE_3_0(
                pollingPolicy: .init(maxAttempts: 3, intervalNanoseconds: 0)
            ).makeRequest(request: imageRequest(
                modelCode: .KLING_IMAGE_3_0,
                dimensions: "16:9",
                resolution: "2K",
                negativePrompt: "no text"
            ))
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests.count == 3)
        #expect(mock.requests[0].url.absoluteString ==
            "https://api-singapore.klingai.com/v1/images/generations")
        #expect(mock.requests[1].url.absoluteString ==
            "https://api-singapore.klingai.com/v1/images/generations/\(taskId)")
        #expect(mock.requests[0].headers?["Authorization"] == "Bearer \(apiKey)")
        #expect(mock.requests[1].headers?["Content-Type"] == nil)

        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model_name"] as? String == "kling-v3")
        #expect(json["prompt"] as? String == "A polished aircraft portrait")
        #expect(json["negative_prompt"] as? String == "no text")
        #expect(json["image"] == nil)
        #expect(json["resolution"] as? String == "2k")
        #expect(json["n"] as? Int == 1)
        #expect(json["aspect_ratio"] as? String == "16:9")
        #expect(json["watermark"] as? Bool == false)

        let download = try #require(mock.dataRequests.first)
        #expect(download.url?.absoluteString == outputURL)
        #expect(download.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "a2xpbmctaW1hZ2U=")
        #expect(response.cost == 0.028)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == taskId)
        #expect(response.metadata?[ProviderJobMetadataKey.cancelURL] == nil)
    }

    @Test("Omni image binds up to ten inputs with indexed prompt markers")
    func omniImageContract() throws {
        let request = imageRequest(
            modelCode: .KLING_IMAGE_3_0_OMNI,
            dimensions: "auto",
            resolution: "4K",
            clientImage: "aW1hZ2U=",
            references: [
                ReferenceImageData(
                    base64Image: "https://assets.example/reference.webp",
                    referenceType: "subject",
                    mimeType: "image/webp"
                ),
            ]
        )

        let transformed = try G_KLING_IMAGE_3_0_OMNI().validatedServiceRequest(from: request)
        #expect(transformed.model_name == "kling-v3-omni")
        #expect(transformed.prompt ==
            "<<<image_1>>> <<<image_2>>> A polished aircraft portrait")
        #expect(transformed.image_list?.map(\.image) == [
            "aW1hZ2U=",
            "https://assets.example/reference.webp",
        ])
        #expect(transformed.resolution == "4k")
        #expect(transformed.result_type == "single")
        #expect(transformed.aspect_ratio == "auto")
        #expect(try KlingAIClient.imagePrice(omni: true, resolution: "4K") == 0.056)
    }

    @Test("Text-to-video sends sound mode duration and exact pricing controls")
    func textToVideoAsyncFlow() async throws {
        let outputURL = "https://kling-output.example/video.mp4"
        let mock = KlingMockNetworkProvider(
            responses: [
                createFixture(),
                successFixture(kind: "videos", outputURL: outputURL),
            ],
            dataResponses: [
                NetworkDataResponse(
                    statusCode: 200,
                    data: Data("kling-video".utf8),
                    headers: ["Content-Type": "video/mp4"]
                ),
            ]
        )

        let response = try await withProviderDependencies(networkProvider: mock) {
            try await G_KLING_VIDEO_3_0_T2V(
                pollingPolicy: .init(maxAttempts: 2, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest(
                modelCode: .KLING_VIDEO_3_0_T2V,
                dimensions: "9:16",
                duration: 5,
                resolution: "4K",
                generateAudio: true,
                negativePrompt: "no text"
            ))
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests[0].url.path == "/v1/videos/text2video")
        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model_name"] as? String == "kling-v3")
        #expect(json["sound"] as? String == "on")
        #expect(json["mode"] as? String == "4k")
        #expect(json["aspect_ratio"] as? String == "9:16")
        #expect(json["duration"] as? String == "5")
        #expect(json["negative_prompt"] as? String == "no text")
        #expect(json["image"] == nil)
        #expect(json["image_tail"] == nil)

        #expect(mock.dataRequests.first?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "a2xpbmctdmlkZW8=")
        #expect(abs((response.cost ?? 0) - 2.1) < 0.000_001)
        #expect(response.actualDuration == 5)
    }

    @Test("Image-to-video accepts initial final or both frames")
    func imageToVideoFrameContract() throws {
        let adapter = G_KLING_VIDEO_3_0_I2V()
        let request = videoRequest(
            modelCode: .KLING_VIDEO_3_0_I2V,
            dimensions: "16:9",
            duration: 8,
            resolution: "1080p",
            generateAudio: false,
            clientImage: "data:image/png;base64,aW1hZ2U=",
            clientLastFrame: "https://assets.example/final.webp"
        )
        let transformed = try adapter.validatedServiceRequest(from: request)
        #expect(transformed.image == "aW1hZ2U=")
        #expect(transformed.image_tail == "https://assets.example/final.webp")
        #expect(transformed.mode == "pro")
        #expect(transformed.sound == "off")

        var tailOnly = request
        tailOnly.clientImage = nil
        #expect(try adapter.validatedServiceRequest(from: tailOnly).image_tail != nil)

        tailOnly.clientLastFrame = nil
        #expect(throws: KlingAIError.self) {
            try adapter.validatedServiceRequest(from: tailOnly)
        }
    }

    @Test("Concurrency code returns manual retry failure after one create")
    func concurrencyFailureNeverRetriesCreate() async throws {
        let mock = KlingMockNetworkProvider(responses: [
            .dictionary(statusCode: 429, data: [
                "code": 1303,
                "message": "parallel task limit reached",
                "request_id": "request-limit",
            ]),
        ])

        let response = try await withProviderDependencies(networkProvider: mock) {
            try await G_KLING_IMAGE_3_0().makeRequest(request: imageRequest(
                modelCode: .KLING_IMAGE_3_0,
                dimensions: "1:1",
                resolution: "1K"
            ))
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests.count == 1)
        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("retry manually") == true)
    }

    @Test("Task states and body errors are explicit")
    func taskStateClassification() throws {
        #expect(try KlingAIClient.classify(statusFixture("submitted")) == .pending)
        #expect(try KlingAIClient.classify(statusFixture("processing")) == .pending)
        #expect(try KlingAIClient.classify(statusFixture("succeed")) == .succeeded)
        #expect(try KlingAIClient.classify(.dictionary(statusCode: 200, data: [
            "code": 0,
            "message": "SUCCEED",
            "data": [
                "task_id": taskId,
                "task_status": "failed",
                "task_status_msg": "content rejected",
            ],
        ])) == .failed("content rejected"))
        #expect(try KlingAIClient.classify(statusFixture("mystery")) ==
            .failed("Unknown Kling task status: mystery"))
        #expect(try KlingAIClient.classify(.dictionary(statusCode: 200, data: [
            "code": 1303,
            "message": "busy",
        ])) == .failed(
            "Kling concurrency limit reached; retry manually after capacity is available."
        ))
    }

    @Test("Capability and pricing matrices fail closed")
    func validationAndPricingMatrix() throws {
        let classic = G_KLING_IMAGE_3_0()
        var sourceWithNegative = imageRequest(
            modelCode: .KLING_IMAGE_3_0,
            dimensions: "1:1",
            resolution: "1K",
            negativePrompt: "no text",
            clientImage: "aW1hZ2U="
        )
        #expect(throws: KlingAIError.self) {
            try classic.validatedServiceRequest(from: sourceWithNegative)
        }
        sourceWithNegative.negativePrompt = nil
        #expect(try classic.validatedServiceRequest(from: sourceWithNegative).image == "aW1hZ2U=")

        #expect(throws: KlingAIError.self) {
            try KlingAIClient.imagePrice(omni: false, resolution: "4K")
        }
        #expect(try KlingAIClient.imagePrice(omni: false, resolution: "2K") == 0.028)
        #expect(try KlingAIClient.videoPricePerSecond(resolution: "720P", audio: false) == 0.084)
        #expect(try KlingAIClient.videoPricePerSecond(resolution: "720P", audio: true) == 0.126)
        #expect(try KlingAIClient.videoPricePerSecond(resolution: "1080P", audio: false) == 0.112)
        #expect(try KlingAIClient.videoPricePerSecond(resolution: "1080P", audio: true) == 0.168)
        #expect(try KlingAIClient.videoPricePerSecond(resolution: "4K", audio: true) == 0.42)

        var invalidDuration = videoRequest(
            modelCode: .KLING_VIDEO_3_0_T2V,
            dimensions: "16:9",
            duration: 16,
            resolution: "720p",
            generateAudio: false
        )
        let video = G_KLING_VIDEO_3_0_T2V()
        #expect(throws: KlingAIError.self) {
            try video.validatedServiceRequest(from: invalidDuration)
        }
        invalidDuration.durationSeconds = 5
        invalidDuration.clientImage = "aW1hZ2U="
        #expect(throws: KlingAIError.self) {
            try video.validatedServiceRequest(from: invalidDuration)
        }
    }

    @Test("Catalog is exactly classic and Omni image plus classic video")
    func catalogBoundary() {
        let models = KlingAIModels.createModels()

        #expect(models.map(\.modelCode) == [
            .KLING_IMAGE_3_0,
            .KLING_IMAGE_3_0_OMNI,
            .KLING_VIDEO_3_0_T2V,
            .KLING_VIDEO_3_0_I2V,
        ])
        #expect(!models.contains { !$0.active })
        #expect(!models.contains { $0.modelName.contains("Turbo") })
        #expect(!models.contains { $0.modelName.contains("O1") })
        #expect(!models.contains { $0.modelName.contains("2.") })
        #expect(!models.filter { $0.modelSetType == .VIDEO_GENERATE }
            .contains { $0.modelName.contains("Omni") })
        #expect(models.allSatisfy {
            $0.providerId == EnumProviderCode.KLING_AI.providerId
                && $0.modelVerificationDate == getDateFromString("2026-07-10")
                && $0.pricingMetadata?.sourceURL.contains("productBilling") == true
        })
    }

    private func createFixture() -> NetworkResponseData {
        .dictionary(statusCode: 200, data: [
            "code": 0,
            "message": "SUCCEED",
            "request_id": "request-create",
            "data": ["task_id": taskId, "task_status": "submitted"],
        ])
    }

    private func statusFixture(_ status: String) -> NetworkResponseData {
        .dictionary(statusCode: 200, data: [
            "code": 0,
            "message": "SUCCEED",
            "request_id": "request-status",
            "data": ["task_id": taskId, "task_status": status],
        ])
    }

    private func successFixture(kind: String, outputURL: String) -> NetworkResponseData {
        .dictionary(statusCode: 200, data: [
            "code": 0,
            "message": "SUCCEED",
            "request_id": "request-success",
            "data": [
                "task_id": taskId,
                "task_status": "succeed",
                "task_result": [kind: [["url": outputURL]]],
            ],
        ])
    }

    private func imageRequest(
        modelCode: EnumProviderModelCode,
        dimensions: String,
        resolution: String,
        negativePrompt: String? = nil,
        clientImage: String? = nil,
        references: [ReferenceImageData]? = nil
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: modelCode.modelId.uuidString,
            prompt: "A polished aircraft portrait",
            negativePrompt: negativePrompt,
            dimensions: dimensions,
            clientImage: clientImage,
            clientReferenceImages: references,
            providerKey: providerKey,
            providerSecret: apiKey,
            resolution: resolution
        )
    }

    private func videoRequest(
        modelCode: EnumProviderModelCode,
        dimensions: String,
        duration: Int,
        resolution: String,
        generateAudio: Bool,
        negativePrompt: String? = nil,
        clientImage: String? = nil,
        clientLastFrame: String? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: modelCode.modelId.uuidString,
            prompt: "An aircraft taxis through rain",
            negativePrompt: negativePrompt,
            dimensions: dimensions,
            clientImage: clientImage,
            clientLastFrame: clientLastFrame,
            providerKey: providerKey,
            providerSecret: apiKey,
            durationSeconds: duration,
            resolution: resolution,
            generateAudio: generateAudio
        )
    }

    private var providerKey: ProviderKeyInfo {
        ProviderKeyInfo(
            providerId: EnumProviderCode.KLING_AI.providerId,
            providerCode: .KLING_AI,
            projectId: UUID()
        )
    }
}

private final class KlingMockNetworkProvider: @unchecked Sendable, NetworkProvider {
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
