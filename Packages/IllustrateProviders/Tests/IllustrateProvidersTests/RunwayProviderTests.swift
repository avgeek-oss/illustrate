import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("Runway direct provider", .serialized)
struct RunwayProviderTests {
    private let jobId = "17f20503-6c24-4c16-946b-35dbbce2af2f"
    private let apiKey = "key_" + String(repeating: "a", count: 128)

    @Test("Image Turbo sends documented references and materializes output")
    func imageTurboAsyncFlow() async throws {
        let outputURL = "https://runway-output.example/image.png?expires=600"
        let mock = RunwayMockNetworkProvider(
            responses: [
                .dictionary(statusCode: 200, data: ["id": jobId]),
                .dictionary(statusCode: 200, data: [
                    "id": jobId,
                    "status": "PENDING",
                    "createdAt": "2026-07-10T00:00:00Z",
                ]),
                .dictionary(statusCode: 200, data: [
                    "id": jobId,
                    "status": "SUCCEEDED",
                    "createdAt": "2026-07-10T00:00:00Z",
                    "output": [outputURL],
                ]),
            ],
            dataResponses: [
                NetworkDataResponse(
                    statusCode: 200,
                    data: Data("runway-image".utf8),
                    headers: ["Content-Type": "image/png"]
                ),
            ]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: RunwayTestModelProvider()
        ) {
            try await G_RUNWAY_GEN_4_IMAGE_TURBO(
                pollingPolicy: .init(maxAttempts: 3, intervalNanoseconds: 0)
            ).makeRequest(request: imageRequest(
                clientImage: "aW1hZ2U=",
                references: [
                    ReferenceImageData(
                        base64Image: "cmVmZXJlbmNl",
                        referenceType: "aircraft",
                        mimeType: "image/jpeg"
                    ),
                ],
                moderation: "low",
                seed: 42
            ))
        }

        #expect(mock.requests.count == 3)
        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.requests[0].url.absoluteString == "https://api.dev.runwayml.com/v1/text_to_image")
        #expect(mock.requests.dropFirst().allSatisfy {
            $0.url.absoluteString == "https://api.dev.runwayml.com/v1/tasks/\(jobId)"
        })
        assertRunwayHeaders(mock.requests[0].headers, includesJSONBody: true)
        assertRunwayHeaders(mock.requests[1].headers, includesJSONBody: false)

        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "gen4_image_turbo")
        #expect(json["promptText"] as? String == "A cinematic aircraft portrait")
        #expect(json["ratio"] as? String == "1920:1080")
        #expect(json["seed"] as? Int == 42)
        let moderation = try #require(json["contentModeration"] as? [String: Any])
        #expect(moderation["publicFigureThreshold"] as? String == "low")
        let references = try #require(json["referenceImages"] as? [[String: Any]])
        #expect(references.count == 2)
        #expect(references[0]["uri"] as? String == "data:image/png;base64,aW1hZ2U=")
        #expect(references[0]["tag"] == nil)
        #expect(references[1]["uri"] as? String == "data:image/jpeg;base64,cmVmZXJlbmNl")
        #expect(references[1]["tag"] as? String == "aircraft")

        #expect(mock.dataRequests.first?.url?.absoluteString == outputURL)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "cnVud2F5LWltYWdl")
        #expect(response.cost == 0.02)
        #expect(response.actualDimensions == "1920:1080")
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == jobId)
        #expect(response
            .metadata?[ProviderJobMetadataKey.statusURL] == "https://api.dev.runwayml.com/v1/tasks/\(jobId)")
        #expect(response
            .metadata?[ProviderJobMetadataKey.cancelURL] == "https://api.dev.runwayml.com/v1/tasks/\(jobId)")
        #expect(response.metadata?["runwayOutputURL"] == outputURL)
        #expect(response.rawResponse?.contains("SUCCEEDED") == true)
    }

    @Test("Gen-4.5 text-to-video handles throttling and materializes video")
    func gen45TextToVideoFlow() async throws {
        let outputURL = "https://runway-output.example/video.mp4?expires=600"
        let mock = RunwayMockNetworkProvider(
            responses: [
                .dictionary(statusCode: 200, data: ["id": jobId]),
                .dictionary(statusCode: 200, data: [
                    "id": jobId,
                    "status": "THROTTLED",
                    "createdAt": "2026-07-10T00:00:00Z",
                ]),
                .dictionary(statusCode: 200, data: [
                    "id": jobId,
                    "status": "RUNNING",
                    "progress": 0.4,
                    "createdAt": "2026-07-10T00:00:00Z",
                ]),
                .dictionary(statusCode: 200, data: [
                    "id": jobId,
                    "status": "SUCCEEDED",
                    "output": [outputURL],
                    "createdAt": "2026-07-10T00:00:00Z",
                ]),
            ],
            dataResponses: [
                NetworkDataResponse(
                    statusCode: 200,
                    data: Data("runway-video".utf8),
                    headers: ["Content-Type": "video/mp4"]
                ),
            ]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: RunwayTestModelProvider()
        ) {
            try await G_RUNWAY_GEN_4_5(
                pollingPolicy: .init(maxAttempts: 4, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest(
                modelCode: .RUNWAY_GEN_4_5,
                dimensions: "1280:720",
                duration: 7,
                moderation: "auto",
                seed: 7
            ))
        }

        #expect(mock.requests.count == 4)
        #expect(mock.requests[0].url.absoluteString == "https://api.dev.runwayml.com/v1/text_to_video")
        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "gen4.5")
        #expect(json["promptText"] as? String == "An aircraft taxis through rain")
        #expect(json["ratio"] as? String == "1280:720")
        #expect(json["duration"] as? Int == 7)
        #expect(json["seed"] as? Int == 7)
        #expect(json["promptImage"] == nil)
        let moderation = try #require(json["contentModeration"] as? [String: Any])
        #expect(moderation["publicFigureThreshold"] as? String == "auto")

        #expect(mock.dataRequests.first?.url?.absoluteString == outputURL)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "cnVud2F5LXZpZGVv")
        #expect(abs((response.cost ?? 0) - 0.84) < 0.000_001)
        #expect(response.actualDuration == 7)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == jobId)
    }

    @Test("Gen-4.5 image-to-video uses its endpoint and prompt image")
    func gen45ImageToVideoFlow() async throws {
        let outputURL = "https://runway-output.example/i2v.mp4"
        let mock = RunwayMockNetworkProvider(
            responses: [
                .dictionary(statusCode: 200, data: ["id": jobId]),
                .dictionary(statusCode: 200, data: [
                    "id": jobId,
                    "status": "SUCCEEDED",
                    "output": [outputURL],
                    "createdAt": "2026-07-10T00:00:00Z",
                ]),
            ],
            dataResponses: [
                NetworkDataResponse(statusCode: 200, data: Data("i2v-video".utf8)),
            ]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: RunwayTestModelProvider()
        ) {
            try await G_RUNWAY_GEN_4_5_I2V(
                pollingPolicy: .init(maxAttempts: 1, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest(
                modelCode: .RUNWAY_GEN_4_5_I2V,
                dimensions: "960:960",
                duration: 10,
                clientImage: "aW1hZ2U="
            ))
        }

        #expect(mock.requests[0].url.absoluteString == "https://api.dev.runwayml.com/v1/image_to_video")
        let body = try #require(mock.requests[0].body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["promptImage"] as? String == "data:image/png;base64,aW1hZ2U=")
        #expect(json["ratio"] as? String == "960:960")
        #expect(json["duration"] as? Int == 10)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "aTJ2LXZpZGVv")
        #expect(response.cost == 1.2)
    }

    @Test("Rejects invalid image inputs before network activity")
    func imageValidation() async throws {
        let missingMock = RunwayMockNetworkProvider()
        let missing = try await withProviderDependencies(
            networkProvider: missingMock,
            modelProvider: RunwayTestModelProvider()
        ) {
            try await G_RUNWAY_GEN_4_IMAGE_TURBO().makeRequest(request: imageRequest())
        }
        #expect(missing.status == .FAILED)
        #expect(missing.errorMessage?.contains("one to three") == true)
        #expect(missingMock.requests.isEmpty)

        let excessiveMock = RunwayMockNetworkProvider()
        let excessive = try await withProviderDependencies(
            networkProvider: excessiveMock,
            modelProvider: RunwayTestModelProvider()
        ) {
            try await G_RUNWAY_GEN_4_IMAGE_TURBO().makeRequest(request: imageRequest(
                clientImage: "aW1hZ2U=",
                references: (0 ..< 3).map { index in
                    ReferenceImageData(base64Image: "cmVm\(index)=".data(using: .utf8)!.base64EncodedString())
                }
            ))
        }
        #expect(excessive.status == .FAILED)
        #expect(excessive.errorMessage?.contains("one to three") == true)
        #expect(excessiveMock.requests.isEmpty)

        let mimeMock = RunwayMockNetworkProvider()
        let mime = try await withProviderDependencies(
            networkProvider: mimeMock,
            modelProvider: RunwayTestModelProvider()
        ) {
            try await G_RUNWAY_GEN_4_IMAGE_TURBO().makeRequest(request: imageRequest(
                references: [ReferenceImageData(base64Image: "aW1hZ2U=", mimeType: "image/jpg")]
            ))
        }
        #expect(mime.status == .FAILED)
        #expect(mime.errorMessage?.contains("JPEG, PNG, and WebP") == true)
        #expect(mimeMock.requests.isEmpty)
    }

    @Test("Rejects prompt ratio and duration violations locally")
    func requestValidation() async throws {
        let promptMock = RunwayMockNetworkProvider()
        let prompt = try await withProviderDependencies(
            networkProvider: promptMock,
            modelProvider: RunwayTestModelProvider()
        ) {
            try await G_RUNWAY_GEN_4_IMAGE_TURBO().makeRequest(request: imageRequest(
                prompt: String(repeating: "😀", count: 501),
                clientImage: "aW1hZ2U="
            ))
        }
        #expect(prompt.status == .FAILED)
        #expect(prompt.errorMessage?.contains("UTF-16") == true)
        #expect(promptMock.requests.isEmpty)

        let videoMock = RunwayMockNetworkProvider()
        let video = try await withProviderDependencies(
            networkProvider: videoMock,
            modelProvider: RunwayTestModelProvider()
        ) {
            try await G_RUNWAY_GEN_4_5().makeRequest(request: videoRequest(
                modelCode: .RUNWAY_GEN_4_5,
                dimensions: "960:960",
                duration: 11
            ))
        }
        #expect(video.status == .FAILED)
        #expect(video.errorMessage?.contains("between 2 and 10") == true)
        #expect(videoMock.requests.isEmpty)
    }

    @Test("Requires the correct source-image mode")
    func modeValidation() async throws {
        let i2vMock = RunwayMockNetworkProvider()
        let i2v = try await withProviderDependencies(
            networkProvider: i2vMock,
            modelProvider: RunwayTestModelProvider()
        ) {
            try await G_RUNWAY_GEN_4_5_I2V().makeRequest(request: videoRequest(
                modelCode: .RUNWAY_GEN_4_5_I2V,
                dimensions: "1280:720",
                duration: 5
            ))
        }
        #expect(i2v.status == .FAILED)
        #expect(i2v.errorMessage?.contains("requires an input image") == true)
        #expect(i2vMock.requests.isEmpty)

        let t2vMock = RunwayMockNetworkProvider()
        let t2v = try await withProviderDependencies(
            networkProvider: t2vMock,
            modelProvider: RunwayTestModelProvider()
        ) {
            try await G_RUNWAY_GEN_4_5().makeRequest(request: videoRequest(
                modelCode: .RUNWAY_GEN_4_5,
                dimensions: "1280:720",
                duration: 5,
                clientImage: "aW1hZ2U="
            ))
        }
        #expect(t2v.status == .FAILED)
        #expect(t2v.errorMessage?.contains("select the image-to-video model") == true)
        #expect(t2vMock.requests.isEmpty)
    }

    @Test("Classifies all documented task states and failure codes")
    func classifiesTaskStates() throws {
        for status in ["PENDING", "THROTTLED", "RUNNING"] {
            let state = try RunwayTaskClient.classify(.dictionary(statusCode: 200, data: ["status": status]))
            #expect(state == .pending)
        }
        #expect(try RunwayTaskClient
            .classify(.dictionary(statusCode: 200, data: ["status": "SUCCEEDED"])) == .succeeded)
        #expect(try RunwayTaskClient
            .classify(.dictionary(statusCode: 200, data: ["status": "CANCELLED"])) == .cancelled)
        #expect(try RunwayTaskClient.classify(.dictionary(statusCode: 200, data: [
            "status": "FAILED",
            "failure": "Prompt rejected",
            "failureCode": "SAFETY.INPUT.TEXT",
        ])) == .failed("Runway generation failed (SAFETY.INPUT.TEXT): Prompt rejected"))
        #expect(try RunwayTaskClient
            .classify(.dictionary(statusCode: 200, data: ["status": "MYSTERY"])) ==
            .failed("Unknown Runway task status: MYSTERY"))
    }

    @Test("Bounds polling and retains job metadata on timeout")
    func pollingTimeout() async throws {
        let mock = RunwayMockNetworkProvider(responses: [
            .dictionary(statusCode: 200, data: ["id": jobId]),
            .dictionary(statusCode: 200, data: ["status": "PENDING"]),
            .dictionary(statusCode: 200, data: ["status": "PENDING"]),
        ])

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: RunwayTestModelProvider()
        ) {
            try await G_RUNWAY_GEN_4_5(
                pollingPolicy: .init(maxAttempts: 2, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest(
                modelCode: .RUNWAY_GEN_4_5,
                dimensions: "1280:720",
                duration: 5
            ))
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("did not finish after 2 status checks") == true)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == jobId)
        #expect(mock.requests.count == 3)
        #expect(mock.dataRequests.isEmpty)
    }

    @Test("Cancels tasks explicitly and treats 404 as idempotent success")
    func cancellation() async throws {
        let successful = RunwayMockNetworkProvider(rawResponses: [
            .dictionary(statusCode: 204, data: [:]),
        ])
        try await RunwayTaskClient.cancel(jobId: jobId, apiKey: apiKey, network: successful)
        let request = try #require(successful.rawRequests.first)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.absoluteString == "https://api.dev.runwayml.com/v1/tasks/\(jobId)")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(apiKey)")
        #expect(request.value(forHTTPHeaderField: "X-Runway-Version") == "2024-11-06")

        let alreadyGone = RunwayMockNetworkProvider(rawResponses: [
            .dictionary(statusCode: 404, data: ["error": "Task not found"]),
        ])
        try await RunwayTaskClient.cancel(jobId: jobId, apiKey: apiKey, network: alreadyGone)

        do {
            try await RunwayTaskClient.cancel(jobId: "../invalid", apiKey: apiKey, network: alreadyGone)
            Issue.record("Expected malformed task ID to fail")
        } catch let error as RunwayAdapterError {
            #expect(error.errorDescription?.contains("valid UUID") == true)
        }
        #expect(alreadyGone.rawRequests.count == 1)
    }

    @Test("Registers endpoints lifecycle capabilities and source-backed pricing")
    func registersCatalog() {
        let models = RunwayModels.createModels()
        #expect(models.map(\.modelCode) == [
            .RUNWAY_GEN_4_IMAGE_TURBO,
            .RUNWAY_GEN_4_5,
            .RUNWAY_GEN_4_5_I2V,
        ])
        #expect(models.allSatisfy { $0.providerId == EnumProviderCode.RUNWAY.providerId })
        #expect(models.allSatisfy { $0.modelVerificationDate == getDateFromString("2026-07-10") })
        #expect(models.allSatisfy { $0.modelStatusBaseURL == "https://api.dev.runwayml.com/v1/tasks" })
        #expect(models[0].modelGenerateBaseURL == "https://api.dev.runwayml.com/v1/text_to_image")
        #expect(models[1].modelGenerateBaseURL == "https://api.dev.runwayml.com/v1/text_to_video")
        #expect(models[2].modelGenerateBaseURL == "https://api.dev.runwayml.com/v1/image_to_video")
        #expect(models[0].modelLaunchDate == getDateFromString("2025-08-19"))
        #expect(models[1].modelLaunchDate == getDateFromString("2026-02-10"))
        #expect(models[0].pricingMetadata?.unit == .image)
        #expect(models[1].pricingMetadata?.unit == .second)
        #expect(models[0].modelParams.maxReferenceImages == 3)
        #expect(models[1].modelParams.supportsSourceImage == false)
        #expect(models[2].modelParams.supportsSourceImage)
        #expect(models[1].modelParams.supportedVideoDurations == Array(2 ... 10))
        #expect(!models[2].modelParams.supportedDimensions.contains("672:1584"))
        #expect(AllModels.createModels().filter { $0.providerId == EnumProviderCode.RUNWAY.providerId }.count == 3)
        #expect(RunwayTaskClient.defaultPollingPolicy == .init(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        ))

        #expect(G_RUNWAY_GEN_4_IMAGE_TURBO().getCostEstimate(request: .init(numberOfImages: 3)) == 0.06)
        #expect(G_RUNWAY_GEN_4_5().getCostEstimate(request: .init(
            durationSeconds: 7,
            numberOfVideos: 2
        )) == 1.68)
    }

    private func imageRequest(
        prompt: String = "A cinematic aircraft portrait",
        clientImage: String? = nil,
        references: [ReferenceImageData]? = nil,
        moderation: String? = nil,
        seed: Int? = nil
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: EnumProviderModelCode.RUNWAY_GEN_4_IMAGE_TURBO.modelId.uuidString,
            prompt: prompt,
            dimensions: "1920:1080",
            clientImage: clientImage,
            clientReferenceImages: references,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.RUNWAY.providerId,
                providerCode: .RUNWAY,
                projectId: UUID()
            ),
            providerSecret: apiKey,
            seed: seed,
            moderation: moderation
        )
    }

    private func videoRequest(
        modelCode: EnumProviderModelCode,
        dimensions: String,
        duration: Int,
        clientImage: String? = nil,
        moderation: String? = nil,
        seed: Int? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: modelCode.modelId.uuidString,
            prompt: "An aircraft taxis through rain",
            dimensions: dimensions,
            clientImage: clientImage,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.RUNWAY.providerId,
                providerCode: .RUNWAY,
                projectId: UUID()
            ),
            providerSecret: apiKey,
            durationSeconds: duration,
            seed: seed,
            moderation: moderation
        )
    }

    private func assertRunwayHeaders(
        _ headers: [String: String]?,
        includesJSONBody: Bool
    ) {
        #expect(headers?["Authorization"] == "Bearer \(apiKey)")
        #expect(headers?["X-Runway-Version"] == "2024-11-06")
        #expect(headers?["Accept"] == "application/json")
        #expect((headers?["Content-Type"] != nil) == includesJSONBody)
    }
}

private final class RunwayMockNetworkProvider: @unchecked Sendable, NetworkProvider {
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

private struct RunwayTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        RunwayModels.createModels().first { $0.modelCode == code }
    }
}
