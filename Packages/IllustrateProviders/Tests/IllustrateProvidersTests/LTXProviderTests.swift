import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("LTX direct provider", .serialized)
struct LTXProviderTests {
    private let apiKey = "ltx-test-api-key"
    private let projectId = UUID(uuidString: "43DB9159-E305-44F2-B0B8-188B71C94F41")!

    @Test("Fast text-to-video follows v2 endpoint-family polling and materializes output")
    func fastTextToVideoFlow() async throws {
        let jobId = "job_fast_123"
        let outputURL = "https://outputs.ltx.video/jobs/job_fast_123/video.mp4?expires=600"
        let mock = LTXMockNetworkProvider(
            responses: [
                .dictionary(statusCode: 202, data: [
                    "id": jobId,
                    "created_at": "2026-07-10T01:02:03Z",
                ]),
                .dictionary(statusCode: 200, data: [
                    "status": "pending",
                    "id": jobId,
                    "created_at": "2026-07-10T01:02:03Z",
                ]),
                .dictionary(statusCode: 200, data: [
                    "status": "processing",
                    "id": jobId,
                    "created_at": "2026-07-10T01:02:03Z",
                ]),
                .dictionary(statusCode: 200, data: [
                    "status": "completed",
                    "id": jobId,
                    "created_at": "2026-07-10T01:02:03Z",
                    "completed_at": "2026-07-10T01:04:05Z",
                    "result": ["video_url": outputURL],
                ]),
            ],
            dataResponses: [
                NetworkDataResponse(
                    statusCode: 200,
                    data: Data("ltx-fast-video".utf8),
                    headers: ["Content-Type": "video/mp4"]
                ),
            ]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: LTXTestModelProvider()
        ) {
            try await G_LTX_2_3_FAST(
                pollingPolicy: .init(maxAttempts: 3, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest(
                modelCode: .LTX_2_3_FAST,
                dimensions: "16:9",
                resolution: "1080p",
                duration: 20,
                fps: 24,
                generateAudio: true
            ))
        }

        #expect(mock.requests.count == 4)
        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests[0].url.absoluteString == "https://api.ltx.video/v2/text-to-video")
        #expect(mock.requests.dropFirst().allSatisfy {
            $0.url.absoluteString == "https://api.ltx.video/v2/text-to-video/\(jobId)"
                && $0.method == "GET"
        })
        assertHeaders(mock.requests[0].headers, includesJSONBody: true)
        assertHeaders(mock.requests[1].headers, includesJSONBody: false)

        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "ltx-2-3-fast")
        #expect(json["prompt"] as? String == "An aircraft climbs through monsoon clouds")
        #expect(json["duration"] as? Int == 20)
        #expect(json["fps"] as? Int == 24)
        #expect(json["resolution"] as? String == "1920x1080")
        #expect(json["generate_audio"] as? Bool == true)
        #expect(json["image_uri"] == nil)
        #expect(json["last_frame_uri"] == nil)

        #expect(mock.dataRequests.first?.url?.absoluteString == outputURL)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == Data("ltx-fast-video".utf8).base64EncodedString())
        #expect(response.videoUrl == outputURL)
        #expect(response.cost == 1.2)
        #expect(response.actualDimensions == "1920x1080")
        #expect(response.actualDuration == 20)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == jobId)
        #expect(response
            .metadata?[ProviderJobMetadataKey.statusURL] == "https://api.ltx.video/v2/text-to-video/\(jobId)")
        #expect(response.metadata?[ProviderJobMetadataKey.cancelURL] == nil)
        #expect(response.metadata?["ltxEndpointFamily"] == "text-to-video")
        #expect(response.metadata?["ltxCreatedAt"] == "2026-07-10T01:02:03Z")
        #expect(response.metadata?["ltxCompletedAt"] == "2026-07-10T01:04:05Z")
        #expect(response.metadata?["ltxOutputURL"] == outputURL)
        #expect(response.metadata?["ltxModelId"] == "ltx-2-3-fast")
        #expect(response.metadata?["ltxResolution"] == "1920x1080")
        #expect(response.metadata?["ltxFPS"] == "24")
        #expect(response.metadata?["ltxDurationSeconds"] == "20")
        #expect(response.metadata?["ltxGenerateAudio"] == "true")
        #expect(response.rawResponse?.contains("completed_at") == true)
    }

    @Test("Pro image-to-video posts source last frame and audio controls")
    func proImageToVideoFlow() async throws {
        let jobId = "job_pro_456"
        let outputURL = "https://outputs.ltx.video/jobs/job_pro_456/video.mp4"
        let mock = LTXMockNetworkProvider(
            responses: [
                .dictionary(statusCode: 202, data: [
                    "id": jobId,
                    "created_at": "2026-07-10T02:00:00Z",
                ]),
                .dictionary(statusCode: 200, data: [
                    "status": "completed",
                    "id": jobId,
                    "created_at": "2026-07-10T02:00:00Z",
                    "completed_at": "2026-07-10T02:03:00Z",
                    "result": ["video_url": outputURL],
                ]),
            ],
            dataResponses: [
                NetworkDataResponse(statusCode: 200, data: Data("ltx-pro-video".utf8)),
            ]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: LTXTestModelProvider()
        ) {
            try await G_LTX_2_3_PRO(
                pollingPolicy: .init(maxAttempts: 1, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest(
                modelCode: .LTX_2_3_PRO,
                dimensions: "9:16",
                resolution: "1440p",
                duration: 10,
                fps: 50,
                generateAudio: false,
                clientImage: "c291cmNl",
                clientLastFrame: "data:image/webp;base64,bGFzdA=="
            ))
        }

        #expect(mock.requests.count == 2)
        #expect(mock.requests[0].url.absoluteString == "https://api.ltx.video/v2/image-to-video")
        #expect(mock.requests[1].url.absoluteString == "https://api.ltx.video/v2/image-to-video/\(jobId)")
        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "ltx-2-3-pro")
        #expect(json["resolution"] as? String == "1440x2560")
        #expect(json["fps"] as? Int == 50)
        #expect(json["duration"] as? Int == 10)
        #expect(json["generate_audio"] as? Bool == false)
        #expect(json["image_uri"] as? String == "data:image/png;base64,c291cmNl")
        #expect(json["last_frame_uri"] as? String == "data:image/webp;base64,bGFzdA==")

        #expect(response.status == .GENERATED)
        #expect(response.base64 == Data("ltx-pro-video".utf8).base64EncodedString())
        #expect(response.cost == 1.6)
        #expect(response.actualDimensions == "1440x2560")
        #expect(response.metadata?["ltxEndpointFamily"] == "image-to-video")
        #expect(response.metadata?["ltxModelId"] == "ltx-2-3-pro")
        #expect(response.metadata?["ltxResolution"] == "1440x2560")
        #expect(response.metadata?["ltxFPS"] == "50")
        #expect(response.metadata?["ltxDurationSeconds"] == "10")
        #expect(response.metadata?["ltxGenerateAudio"] == "false")
    }

    @Test("Validates the conditional LTX model matrix")
    func conditionalModelMatrix() throws {
        let fast = G_LTX_2_3_FAST()
        let pro = G_LTX_2_3_PRO()

        #expect(try fast.validatedServiceRequest(from: videoRequest(
            modelCode: .LTX_2_3_FAST,
            resolution: "1080p",
            duration: 20,
            fps: 25
        )).resolution == "1920x1080")
        #expect(try fast.validatedServiceRequest(from: videoRequest(
            modelCode: .LTX_2_3_FAST,
            dimensions: "9:16",
            resolution: "1080p",
            duration: 10,
            fps: 48
        )).resolution == "1080x1920")
        #expect(try fast.validatedServiceRequest(from: videoRequest(
            modelCode: .LTX_2_3_FAST,
            resolution: "1440p",
            duration: 10,
            fps: 50
        )).resolution == "2560x1440")
        #expect(try fast.validatedServiceRequest(from: videoRequest(
            modelCode: .LTX_2_3_FAST,
            resolution: "4K",
            duration: 10,
            fps: 24
        )).resolution == "3840x2160")
        #expect(try pro.validatedServiceRequest(from: videoRequest(
            modelCode: .LTX_2_3_PRO,
            resolution: "4K",
            duration: 10,
            fps: 50
        )).duration == 10)

        #expect(validationMessage {
            try fast.validatedServiceRequest(from: videoRequest(
                modelCode: .LTX_2_3_FAST,
                resolution: "1080p",
                duration: 12,
                fps: 48
            ))
        }.contains("6, 8, 10"))
        #expect(validationMessage {
            try fast.validatedServiceRequest(from: videoRequest(
                modelCode: .LTX_2_3_FAST,
                resolution: "1440p",
                duration: 12,
                fps: 24
            ))
        }.contains("6, 8, 10"))
        #expect(validationMessage {
            try pro.validatedServiceRequest(from: videoRequest(
                modelCode: .LTX_2_3_PRO,
                resolution: "1080p",
                duration: 12,
                fps: 24
            ))
        }.contains("6, 8, 10"))
        #expect(validationMessage {
            try fast.validatedServiceRequest(from: videoRequest(
                modelCode: .LTX_2_3_FAST,
                resolution: "1080p",
                duration: 6,
                fps: 30
            ))
        }.contains("24, 25, 48, or 50"))
        #expect(validationMessage {
            try fast.validatedServiceRequest(from: videoRequest(
                modelCode: .LTX_2_3_FAST,
                dimensions: "9:16",
                resolution: "1920x1080",
                duration: 6,
                fps: 24
            ))
        }.contains("portrait orientation"))
    }

    @Test("Accepts documented upload HTTPS and Data URI inputs with a decimal 7 MB cap")
    func imageURIValidation() throws {
        #expect(try LTXJobClient.validatedImageURI("cG5n") == "data:image/png;base64,cG5n")
        #expect(try LTXJobClient
            .validatedImageURI("data:image/jpeg;base64,anBlZw==") == "data:image/jpeg;base64,anBlZw==")
        #expect(try LTXJobClient
            .validatedImageURI("data:image/webp;base64,d2VicA==") == "data:image/webp;base64,d2VicA==")
        #expect(try LTXJobClient
            .validatedImageURI("https://assets.example.com/frame.png?token=signed") ==
            "https://assets.example.com/frame.png?token=signed")
        #expect(try LTXJobClient.validatedImageURI("ltx://uploads/abc-123") == "ltx://uploads/abc-123")

        #expect(validationMessage { try LTXJobClient.validatedImageURI("http://assets.example.com/frame.png") }
            .contains("must be an LTX upload URI"))
        #expect(validationMessage { try LTXJobClient.validatedImageURI("https://127.0.0.1/frame.png") }
            .contains("public domain name"))
        #expect(validationMessage { try LTXJobClient.validatedImageURI("https://localhost/frame.png") }
            .contains("public domain name"))
        #expect(validationMessage { try LTXJobClient.validatedImageURI("ltx://other/abc-123") }
            .contains("malformed"))
        #expect(validationMessage { try LTXJobClient.validatedImageURI("ltx://uploads/../secret") }
            .contains("malformed"))
        #expect(validationMessage { try LTXJobClient.validatedImageURI("data:image/jpg;base64,anBlZw==") }
            .contains("JPEG, PNG, or WebP"))
        #expect(validationMessage { try LTXJobClient.validatedImageURI("data:image/png;base64,not-base64") }
            .contains("invalid base64"))

        let oversized = "data:image/png;base64," + String(repeating: "A", count: LTXJobClient.maxImageDataURIBytes)
        #expect(oversized.utf8.count > 7_000_000)
        #expect(validationMessage { try LTXJobClient.validatedImageURI(oversized) }.contains("7 MB"))
        #expect(LTXJobClient.maxImageDataURIBytes == 7_000_000)
    }

    @Test("Requires source image for last frame and rejects unsupported unified inputs")
    func sourceAndUnsupportedInputValidation() {
        let adapter = G_LTX_2_3_FAST()

        #expect(validationMessage {
            try adapter.validatedServiceRequest(from: videoRequest(
                modelCode: .LTX_2_3_FAST,
                clientLastFrame: "bGFzdA=="
            ))
        }.contains("requires a source image"))
        #expect(validationMessage {
            var request = videoRequest(modelCode: .LTX_2_3_FAST)
            request.numberOfVideos = 2
            return try adapter.validatedServiceRequest(from: request)
        }.contains("one video"))
        #expect(validationMessage {
            var request = videoRequest(modelCode: .LTX_2_3_FAST)
            request.clientVideo = "dmlkZW8="
            return try adapter.validatedServiceRequest(from: request)
        }.contains("source video"))
        #expect(validationMessage {
            var request = videoRequest(modelCode: .LTX_2_3_FAST)
            request.clientReferenceImages = [ReferenceImageData(base64Image: "cmVm")]
            return try adapter.validatedServiceRequest(from: request)
        }.contains("one source image"))
    }

    @Test("Classifies every documented job state and provider errors")
    func classifiesJobStates() throws {
        for status in ["pending", "processing"] {
            #expect(try LTXJobClient.classify(.dictionary(
                statusCode: 200,
                data: ["status": status]
            )) == .pending)
        }
        #expect(try LTXJobClient.classify(.dictionary(
            statusCode: 200,
            data: ["status": "completed"]
        )) == .succeeded)
        #expect(try LTXJobClient.classify(.dictionary(statusCode: 200, data: [
            "status": "failed",
            "error": [
                "type": "content_filtered_error",
                "message": "Prompt rejected",
            ],
        ])) == .failed("LTX generation failed (content_filtered_error): Prompt rejected"))
        #expect(try LTXJobClient.classify(.dictionary(
            statusCode: 200,
            data: ["status": "cancelled"]
        )) == .failed("Unknown LTX job status: cancelled"))
        let authenticationState = try LTXJobClient.classify(.dictionary(statusCode: 401, data: [
            "type": "error",
            "error": ["type": "authentication_error", "message": "Invalid API key"],
        ]))
        #expect(authenticationState == .failed("LTX status request failed with HTTP 401: Invalid API key."))
    }

    @Test("Bounds polling without cancelling the remote job and keeps resumable metadata")
    func pollingTimeout() async throws {
        let jobId = "job_timeout_789"
        let mock = LTXMockNetworkProvider(responses: [
            .dictionary(statusCode: 202, data: [
                "id": jobId,
                "created_at": "2026-07-10T03:00:00Z",
            ]),
            .dictionary(statusCode: 200, data: ["status": "pending"]),
            .dictionary(statusCode: 200, data: ["status": "processing"]),
        ])

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: LTXTestModelProvider()
        ) {
            try await G_LTX_2_3_FAST(
                pollingPolicy: .init(maxAttempts: 2, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest(modelCode: .LTX_2_3_FAST))
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("did not finish after 2 status checks") == true)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == jobId)
        #expect(response
            .metadata?[ProviderJobMetadataKey.statusURL] == "https://api.ltx.video/v2/text-to-video/\(jobId)")
        #expect(response.metadata?[ProviderJobMetadataKey.cancelURL] == nil)
        #expect(mock.requests.count == 3)
        #expect(mock.rawRequests.isEmpty)
        #expect(mock.dataRequests.isEmpty)
    }

    @Test("Surfaces submit failures and rejects missing or insecure completed output")
    func failureContracts() async throws {
        let submitMock = LTXMockNetworkProvider(responses: [
            .dictionary(statusCode: 402, data: [
                "type": "error",
                "error": [
                    "type": "insufficient_funds_error",
                    "message": "Insufficient credits",
                ],
            ]),
        ])
        let submit = try await withProviderDependencies(
            networkProvider: submitMock,
            modelProvider: LTXTestModelProvider()
        ) {
            try await G_LTX_2_3_FAST().makeRequest(request: videoRequest(modelCode: .LTX_2_3_FAST))
        }
        #expect(submit.status == .FAILED)
        #expect(submit.errorMessage?.contains("HTTP 402: Insufficient credits") == true)
        #expect(submitMock.requests.count == 1)

        let outputMock = LTXMockNetworkProvider(responses: [
            .dictionary(statusCode: 202, data: [
                "id": "job_bad_output",
                "created_at": "2026-07-10T04:00:00Z",
            ]),
            .dictionary(statusCode: 200, data: [
                "status": "completed",
                "id": "job_bad_output",
                "created_at": "2026-07-10T04:00:00Z",
                "completed_at": "2026-07-10T04:01:00Z",
                "result": ["video_url": "http://outputs.example.com/video.mp4"],
            ]),
        ])
        let output = try await withProviderDependencies(
            networkProvider: outputMock,
            modelProvider: LTXTestModelProvider()
        ) {
            try await G_LTX_2_3_PRO(
                pollingPolicy: .init(maxAttempts: 1, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest(modelCode: .LTX_2_3_PRO))
        }
        #expect(output.status == .FAILED)
        #expect(output.errorMessage?.contains("valid HTTPS result.video_url") == true)
        #expect(output.metadata?[ProviderJobMetadataKey.jobId] == "job_bad_output")
        #expect(outputMock.dataRequests.isEmpty)
    }

    @Test("Registers current LTX models capabilities lifecycle and source-backed pricing")
    func catalogAndPricing() {
        let models = LTXModels.createModels()
        #expect(models.map(\.modelCode) == [.LTX_2_3_FAST, .LTX_2_3_PRO])
        #expect(models.allSatisfy { $0.providerId == EnumProviderCode.LTX.providerId })
        #expect(models.allSatisfy { $0.modelLaunchDate == getDateFromString("2026-02-23") })
        #expect(models.allSatisfy { $0.modelVerificationDate == getDateFromString("2026-07-10") })
        #expect(models.allSatisfy { $0.modelGenerateBaseURL == "https://api.ltx.video/v2/text-to-video" })
        #expect(models.allSatisfy { $0.modelStatusBaseURL == "https://api.ltx.video/v2" })
        #expect(models.allSatisfy { !$0.modelGenerateBaseURL.contains("/v1/") })
        #expect(models.allSatisfy { $0.pricingMetadata?.unit == .second })
        #expect(models.allSatisfy { $0.pricingMetadata?.sourceURL == "https://docs.ltx.video/pricing" })
        #expect(models.map(\.modelParams.supportsAudio) == [true, true])
        #expect(models.map(\.modelParams.supportsSourceImage) == [true, true])
        #expect(models.map(\.modelParams.supportsLastFrame) == [true, true])
        #expect(models.allSatisfy { $0.modelParams.maxImageSizeBytes == 7_000_000 })
        #expect(models.allSatisfy { $0.modelParams.supportedDimensions == ["16:9", "9:16"] })
        #expect(models.allSatisfy { $0.modelParams.supportedVideoFPS == [24, 25, 48, 50] })
        #expect(models.allSatisfy { $0.modelParams.supportedVideoResolutions == ["4K", "1440p", "1080p"] })
        #expect(models[0].modelParams.supportedVideoDurations == [6, 8, 10, 12, 14, 16, 18, 20])
        #expect(models[1].modelParams.supportedVideoDurations == [6, 8, 10])
        #expect(AllModels.createModels().filter { $0.providerId == EnumProviderCode.LTX.providerId }.count == 2)
        #expect(LTXJobClient.defaultPollingPolicy == .init(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        ))

        let fast = G_LTX_2_3_FAST()
        #expect(fast.getCostEstimate(request: .init(
            dimensions: "1920x1080",
            durationSeconds: 10,
            numberOfVideos: nil
        )) == 0.6)
        #expect(fast.getCostEstimate(request: .init(
            durationSeconds: 10,
            numberOfVideos: 2,
            resolution: "1440p"
        )) == 2.4)
        #expect(fast.getCostEstimate(request: .init(
            dimensions: "2160x3840",
            durationSeconds: 10,
            generateAudio: false
        )) == 2.4)

        let pro = G_LTX_2_3_PRO()
        #expect(pro.getCostEstimate(request: .init(
            durationSeconds: 10,
            resolution: "1080p",
            generateAudio: true
        )) == 0.8)
        #expect(pro.getCostEstimate(request: .init(
            durationSeconds: 10,
            resolution: "1440p"
        )) == 1.6)
        #expect(pro.getCostEstimate(request: .init(
            durationSeconds: 10,
            resolution: "4K"
        )) == 3.2)
    }

    private func videoRequest(
        modelCode: EnumProviderModelCode,
        dimensions: String = "16:9",
        resolution: String? = "1080p",
        duration: Int = 6,
        fps: Int = 24,
        generateAudio: Bool? = nil,
        clientImage: String? = nil,
        clientLastFrame: String? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: modelCode.modelId.uuidString,
            prompt: "An aircraft climbs through monsoon clouds",
            dimensions: dimensions,
            clientImage: clientImage,
            clientLastFrame: clientLastFrame,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.LTX.providerId,
                providerCode: .LTX,
                projectId: projectId
            ),
            providerSecret: apiKey,
            durationSeconds: duration,
            resolution: resolution,
            fps: fps,
            generateAudio: generateAudio
        )
    }

    private func validationMessage(_ operation: () throws -> some Any) -> String {
        do {
            _ = try operation()
            return ""
        } catch {
            return error.localizedDescription
        }
    }

    private func assertHeaders(_ headers: [String: String]?, includesJSONBody: Bool) {
        #expect(headers?["Authorization"] == "Bearer \(apiKey)")
        #expect(headers?["Accept"] == "application/json")
        #expect((headers?["Content-Type"] != nil) == includesJSONBody)
    }
}

private final class LTXMockNetworkProvider: @unchecked Sendable, NetworkProvider {
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

private struct LTXTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        LTXModels.createModels().first { $0.modelCode == code }
    }
}
