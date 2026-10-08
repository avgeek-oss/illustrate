import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("BytePlus ModelArk direct provider", .serialized)
struct BytePlusModelArkProviderTests {
    @Test("Dola Seedream Pro sends one atomic request with combined inputs")
    func proImageAtomicRequest() async throws {
        let bytes = Data("byteplus-image".utf8)
        let mock = BytePlusTestNetworkProvider(singleResponses: [
            NetworkResponseEnvelope(response: .dictionary(statusCode: 200, data: [
                "data": [["b64_json": bytes.base64EncodedString(), "size": "2048x2048"]],
                "usage": ["generated_images": 1, "output_tokens": 16384],
            ])),
        ])
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BytePlusTestModelProvider()
        ) {
            try await G_BYTEPLUS_DOLA_SEEDREAM_5_0_PRO().makeRequest(request: imageRequest(
                modelCode: .BYTEPLUS_DOLA_SEEDREAM_5_0_PRO,
                numberOfImages: 4,
                clientImage: "c291cmNl",
                references: [
                    .init(base64Image: "cmVmMQ==", mimeType: "image/jpeg"),
                    .init(base64Image: "cmVmMg==", mimeType: "image/png"),
                ],
                resolution: "2k"
            ))
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.retryableRequestCount == 0)
        let captured = try #require(mock.requests.first)
        #expect(captured.url.absoluteString == "https://ark.ap-southeast.bytepluses.com/api/v3/images/generations")
        #expect(captured.headers?["Authorization"] == "Bearer byteplus-test-key")
        let json = try jsonObject(captured.body)
        #expect(json["model"] as? String == "dola-seedream-5-0-pro-260628")
        #expect(json["size"] as? String == "2048x2048")
        #expect(json["response_format"] as? String == "b64_json")
        #expect(json["watermark"] as? Bool == false)
        #expect(json["output_format"] as? String == "png")
        #expect(json["sequential_image_generation"] == nil)
        #expect(json["stream"] == nil)
        #expect((json["image"] as? [String])?.count == 3)
        #expect(response.base64 == bytes.base64EncodedString())
        #expect(response.actualDimensions == "2048x2048")
        #expect(abs((response.cost ?? 0) - 0.096) < 0.000_001)
    }

    @Test("Seedream Lite uses the EU allowlist and materializes URL output")
    func liteImageEUAndMaterialization() async throws {
        let outputURL = "https://ark-content.byteplus.com/image.png?signature=secret"
        let bytes = Data("downloaded-byteplus-image".utf8)
        let mock = BytePlusTestNetworkProvider(
            singleResponses: [NetworkResponseEnvelope(response: .dictionary(statusCode: 200, data: [
                "data": [["url": outputURL, "size": "1760x2368"]],
                "usage": ["generated_images": 1],
            ]))],
            dataResponses: [.init(statusCode: 200, data: bytes)]
        )
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BytePlusTestModelProvider()
        ) {
            try await G_BYTEPLUS_SEEDREAM_5_0_LITE().makeRequest(request: imageRequest(
                modelCode: .BYTEPLUS_SEEDREAM_5_0_LITE,
                secret: credentials(region: "eu-west-1"),
                clientImage: "aW1hZ2U=",
                resolution: "3k"
            ))
        }

        let captured = try #require(mock.requests.first)
        #expect(captured.url.absoluteString == "https://ark.eu-west.bytepluses.com/api/v3/images/generations")
        let json = try jsonObject(captured.body)
        #expect(json["image"] as? String == "data:image/png;base64,aW1hZ2U=")
        #expect(json["sequential_image_generation"] as? String == "disabled")
        #expect(json["stream"] as? Bool == false)
        #expect(json["output_format"] as? String == "png")
        #expect(response.base64 == bytes.base64EncodedString())
        #expect(response.metadata?["bytePlusOutputURL"] == nil)
        #expect(mock.dataRequests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("Image requests reject unsafe regions and preserve exact provider failures")
    func imageFailureContracts() async throws {
        let unavailable = BytePlusTestNetworkProvider()
        let unavailableResponse = try await withProviderDependencies(
            networkProvider: unavailable,
            modelProvider: BytePlusTestModelProvider()
        ) {
            try await G_BYTEPLUS_DOLA_SEEDREAM_5_0_PRO().makeRequest(request: imageRequest(
                modelCode: .BYTEPLUS_DOLA_SEEDREAM_5_0_PRO,
                secret: credentials(region: "eu-west-1"),
                resolution: "1k"
            ))
        }
        #expect(unavailableResponse.status == .FAILED)
        #expect(unavailableResponse.errorMessage?.contains("ap-southeast-1") == true)
        #expect(unavailable.requests.isEmpty)

        let body = Data("upstream overloaded".utf8)
        let failed = BytePlusTestNetworkProvider(singleResponses: [
            .init(statusCode: 503, body: body),
        ])
        let failedResponse = try await withProviderDependencies(
            networkProvider: failed,
            modelProvider: BytePlusTestModelProvider()
        ) {
            try await G_BYTEPLUS_SEEDREAM_4_5().makeRequest(request: imageRequest(
                modelCode: .BYTEPLUS_SEEDREAM_4_5,
                numberOfImages: 5,
                resolution: "2k"
            ))
        }
        #expect(failed.singleAttemptRequestCount == 1)
        #expect(failedResponse.errorMessage?.contains("upstream overloaded") == true)

        let partial = try G_BYTEPLUS_SEEDREAM_4_0().transformResponse(
            request: imageRequest(modelCode: .BYTEPLUS_SEEDREAM_4_0, resolution: "1k"),
            response: .dictionary(statusCode: 200, data: [
                "data": [["error": ["code": "ContentFilter", "message": "blocked"]]],
            ])
        )
        #expect(partial.status == .FAILED)
        #expect(partial.errorMessage?.contains("ContentFilter") == true)

        #expect(throws: BytePlusModelArkError.self) {
            try BytePlusModelArkClient.validatedImageURI("data:text/html;base64,PHNjcmlwdD4=")
        }

        let olderJSON = try jsonObject(JSONEncoder().encode(
            G_BYTEPLUS_SEEDREAM_4_5().transformRequest(request: imageRequest(
                modelCode: .BYTEPLUS_SEEDREAM_4_5,
                resolution: "4k"
            ))
        ))
        #expect(olderJSON["output_format"] == nil)
        #expect(olderJSON["sequential_image_generation"] as? String == "disabled")

        let defaultImageSizes: [(G_BYTEPLUS_SEEDREAM_BASE, String)] = [
            (G_BYTEPLUS_DOLA_SEEDREAM_5_0_PRO(), "1024x1024"),
            (G_BYTEPLUS_SEEDREAM_5_0_LITE(), "2048x2048"),
            (G_BYTEPLUS_SEEDREAM_4_5(), "2048x2048"),
            (G_BYTEPLUS_SEEDREAM_4_0(), "2048x2048"),
        ]
        for (adapter, expectedSize) in defaultImageSizes {
            let body = adapter.transformRequest(request: imageRequest(
                modelCode: adapter.modelCode,
                resolution: nil
            ))
            #expect(body.size == expectedSize)
        }
    }

    @Test("Seedance 2.0 creates once, polls, prices usage, and materializes without auth")
    func videoFlow() async throws {
        let jobId = "opaque_task_20260710"
        let outputURL = "https://ark-content.byteplus.com/video.mp4?signature=secret"
        let bytes = Data("byteplus-video".utf8)
        let mock = BytePlusTestNetworkProvider(
            singleResponses: [NetworkResponseEnvelope(response: .dictionary(
                statusCode: 200,
                data: ["id": jobId]
            ))],
            retryableResponses: [
                .dictionary(statusCode: 200, data: ["status": "running"]),
                .dictionary(statusCode: 200, data: [
                    "status": "succeeded",
                    "content": ["video_url": outputURL],
                    "usage": ["completion_tokens": 108_000, "total_tokens": 108_000],
                    "resolution": "720p",
                    "ratio": "16:9",
                    "duration": 5,
                    "generate_audio": true,
                ]),
            ],
            dataResponses: [.init(statusCode: 200, data: bytes)]
        )
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BytePlusTestModelProvider()
        ) {
            try await G_BYTEPLUS_DREAMINA_SEEDANCE_2_0(
                pollingPolicy: .init(maxAttempts: 2, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest(
                duration: 5,
                resolution: "720p",
                references: [
                    .init(base64Image: "cmVmMQ==", mimeType: "image/jpeg"),
                    .init(base64Image: "cmVmMg==", mimeType: "image/png"),
                ],
                generateAudio: true
            ))
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.retryableRequestCount == 2)
        let create = try #require(mock.requests.first)
        let json = try jsonObject(create.body)
        #expect(json["model"] as? String == "dreamina-seedance-2-0-260128")
        #expect(json["resolution"] as? String == "720p")
        #expect(json["ratio"] as? String == "16:9")
        #expect(json["duration"] as? Int == 5)
        #expect(json["generate_audio"] as? Bool == true)
        #expect(json["seed"] == nil)
        #expect(json["camera_fixed"] == nil)
        #expect(json["watermark"] as? Bool == false)
        #expect(json["return_last_frame"] as? Bool == false)
        #expect(json["service_tier"] == nil)
        #expect(json["execution_expires_after"] as? Int == 3600)
        let content = try #require(json["content"] as? [[String: Any]])
        #expect(content.filter { $0["role"] as? String == "reference_image" }.count == 2)
        #expect(response.base64 == bytes.base64EncodedString())
        #expect(abs((response.cost ?? 0) - 0.756) < 0.000_001)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == jobId)
        #expect(response.metadata?[ProviderJobMetadataKey.cancelURL]?.hasSuffix(jobId) == true)
        #expect(mock.dataRequests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("Seedance model variants omit unsupported fields and reject invalid modes")
    func videoVariantContracts() async throws {
        let older = G_BYTEPLUS_SEEDANCE_1_0_PRO().transformRequest(request: videoRequest(
            modelCode: .BYTEPLUS_SEEDANCE_1_0_PRO,
            duration: 4,
            resolution: "1080p",
            clientImage: "Zmlyc3Q=",
            lastFrame: "bGFzdA==",
            generateAudio: false,
            seed: 7
        ))
        let olderJSON = try jsonObject(JSONEncoder().encode(older))
        #expect(olderJSON["generate_audio"] == nil)
        #expect(olderJSON["seed"] as? Int == 7)
        #expect(olderJSON["camera_fixed"] as? Bool == false)
        let content = try #require(olderJSON["content"] as? [[String: Any]])
        #expect(content.contains { $0["role"] as? String == "first_frame" })
        #expect(content.contains { $0["role"] as? String == "last_frame" })

        for adapter in [
            G_BYTEPLUS_DREAMINA_SEEDANCE_2_0() as G_BYTEPLUS_SEEDANCE_BASE,
            G_BYTEPLUS_DREAMINA_SEEDANCE_2_0_FAST(),
            G_BYTEPLUS_DREAMINA_SEEDANCE_2_0_MINI(),
        ] {
            let body = try jsonObject(JSONEncoder().encode(adapter.validatedServiceRequest(
                from: videoRequest()
            )))
            #expect(body["service_tier"] == nil)
        }

        let default20 = try G_BYTEPLUS_DREAMINA_SEEDANCE_2_0().validatedServiceRequest(
            from: videoRequest(duration: nil, resolution: nil)
        )
        #expect(default20.resolution == "720p")
        #expect(default20.duration == 5)
        let default15 = try G_BYTEPLUS_SEEDANCE_1_5_PRO().validatedServiceRequest(
            from: videoRequest(
                modelCode: .BYTEPLUS_SEEDANCE_1_5_PRO,
                duration: nil,
                resolution: "",
                generateAudio: true
            )
        )
        #expect(default15.resolution == "720p")
        #expect(default15.duration == 5)
        let default10 = try G_BYTEPLUS_SEEDANCE_1_0_PRO().validatedServiceRequest(
            from: videoRequest(
                modelCode: .BYTEPLUS_SEEDANCE_1_0_PRO,
                duration: nil,
                resolution: nil,
                generateAudio: false
            )
        )
        #expect(default10.resolution == "1080p")
        #expect(default10.duration == 5)

        for adapter in [
            G_BYTEPLUS_DREAMINA_SEEDANCE_2_0() as G_BYTEPLUS_SEEDANCE_BASE,
            G_BYTEPLUS_SEEDANCE_1_5_PRO(),
            G_BYTEPLUS_SEEDANCE_1_0_PRO(),
        ] {
            #expect(throws: BytePlusModelArkError.self) {
                try adapter.validatedServiceRequest(from: videoRequest(
                    modelCode: adapter.modelCode,
                    dimensions: "adaptive",
                    clientImage: "Zmlyc3Q=",
                    generateAudio: adapter.modelCode == .BYTEPLUS_SEEDANCE_1_0_PRO ? false : true
                ))
            }
        }

        let invalidAudio = BytePlusTestNetworkProvider()
        let audioResponse = try await withProviderDependencies(
            networkProvider: invalidAudio,
            modelProvider: BytePlusTestModelProvider()
        ) {
            try await G_BYTEPLUS_SEEDANCE_1_0_PRO().makeRequest(request: videoRequest(
                modelCode: .BYTEPLUS_SEEDANCE_1_0_PRO,
                generateAudio: true
            ))
        }
        #expect(audioResponse.status == .FAILED)
        #expect(invalidAudio.requests.isEmpty)

        let invalidSeed = BytePlusTestNetworkProvider()
        let seedResponse = try await withProviderDependencies(
            networkProvider: invalidSeed,
            modelProvider: BytePlusTestModelProvider()
        ) {
            try await G_BYTEPLUS_DREAMINA_SEEDANCE_2_0().makeRequest(request: videoRequest(seed: 3))
        }
        #expect(seedResponse.status == .FAILED)
        #expect(invalidSeed.requests.isEmpty)

        let invalidLastFrame = BytePlusTestNetworkProvider()
        let lastFrameResponse = try await withProviderDependencies(
            networkProvider: invalidLastFrame,
            modelProvider: BytePlusTestModelProvider()
        ) {
            try await G_BYTEPLUS_SEEDANCE_1_0_PRO_FAST().makeRequest(request: videoRequest(
                modelCode: .BYTEPLUS_SEEDANCE_1_0_PRO_FAST,
                clientImage: "Zmlyc3Q=",
                lastFrame: "bGFzdA==",
                generateAudio: false
            ))
        }
        #expect(lastFrameResponse.status == .FAILED)
        #expect(invalidLastFrame.requests.isEmpty)
    }

    @Test("Video paid create is exact once, statuses fail closed, and queued jobs cancel")
    func videoLifecycleContracts() async throws {
        let overload = BytePlusTestNetworkProvider(singleResponses: [
            .init(statusCode: 504, body: Data("gateway timeout".utf8)),
        ])
        let response = try await withProviderDependencies(
            networkProvider: overload,
            modelProvider: BytePlusTestModelProvider()
        ) {
            try await G_BYTEPLUS_DREAMINA_SEEDANCE_2_0().makeRequest(request: videoRequest())
        }
        #expect(overload.singleAttemptRequestCount == 1)
        #expect(response.errorMessage?.contains("gateway timeout") == true)

        #expect(try BytePlusModelArkClient.classify(.dictionary(
            statusCode: 200,
            data: ["status": "queued"]
        )) == .pending)
        #expect(try BytePlusModelArkClient.classify(.dictionary(
            statusCode: 200,
            data: ["status": "succeeded"]
        )) == .succeeded)
        if case let .failed(message) = try BytePlusModelArkClient.classify(.dictionary(
            statusCode: 200,
            data: ["status": "future_state"]
        )) {
            #expect(message.contains("Unknown"))
        } else {
            Issue.record("Unknown BytePlus status must fail closed")
        }

        let cancel = BytePlusTestNetworkProvider(singleResponses: [
            .init(statusCode: 204),
            .init(statusCode: 404),
        ])
        try await withProviderDependencies(
            networkProvider: cancel,
            modelProvider: BytePlusTestModelProvider()
        ) {
            try await G_BYTEPLUS_DREAMINA_SEEDANCE_2_0().cancel(
                jobId: "cgt-20260710-cancel",
                providerSecret: credentials()
            )
            try await G_BYTEPLUS_DREAMINA_SEEDANCE_2_0().cancel(
                jobId: "cgt-20260710-already-cancelled",
                providerSecret: credentials()
            )
        }
        let cancelRequest = try #require(cancel.requests.first)
        #expect(cancelRequest.method == "DELETE")
        #expect(cancelRequest.url.absoluteString.hasSuffix("/cgt-20260710-cancel") == true)
        #expect(cancelRequest.headers?["Authorization"] == "Bearer byteplus-test-key")
        #expect(cancel.singleAttemptRequestCount == 2)
    }

    @Test("Catalog locks the safe image ratio, region contract, and token estimates")
    func catalogAndPricing() throws {
        let models = BytePlusModelArkModels.createModels()
        #expect(models.map(\.modelCode) == [
            .BYTEPLUS_DOLA_SEEDREAM_5_0_PRO,
            .BYTEPLUS_SEEDREAM_5_0_LITE,
            .BYTEPLUS_SEEDREAM_4_5,
            .BYTEPLUS_SEEDREAM_4_0,
            .BYTEPLUS_DREAMINA_SEEDANCE_2_0,
            .BYTEPLUS_DREAMINA_SEEDANCE_2_0_FAST,
            .BYTEPLUS_DREAMINA_SEEDANCE_2_0_MINI,
            .BYTEPLUS_SEEDANCE_1_5_PRO,
            .BYTEPLUS_SEEDANCE_1_0_PRO,
            .BYTEPLUS_SEEDANCE_1_0_PRO_FAST,
        ])
        #expect(models.prefix(4).allSatisfy { $0.modelParams.supportedDimensions == ["1:1"] })
        #expect(models.allSatisfy { $0.providerId == EnumProviderCode.BYTEPLUS_MODELARK.providerId })
        #expect(models.allSatisfy { $0.modelVerificationDate == getDateFromString("2026-07-10") })
        #expect(models.allSatisfy { $0.modelDescription.split(separator: " ").count <= 9 })
        #expect(models[4].modelParams.supportedVideoResolutions.contains("4k"))
        #expect(models[6].modelParams.supportedVideoDurations == Array(4 ... 15))
        #expect(models.suffix(6).allSatisfy { !$0.modelParams.supportedDimensions.contains("adaptive") })
        #expect(models.allSatisfy {
            $0.pricingMetadata?.sourceURL == "https://docs.byteplus.com/en/docs/ModelArk/1544106"
        })

        let credentials = try BytePlusModelArkClient.credentials(from: credentials(region: "eu-west-1"))
        #expect(credentials.region == .europe)
        #expect(credentials.region.baseURL.absoluteString == "https://ark.eu-west.bytepluses.com/api/v3")
        try BytePlusModelArkClient.validateAvailability(
            modelCode: .BYTEPLUS_SEEDREAM_5_0_LITE,
            region: credentials.region
        )

        let standard = G_BYTEPLUS_DREAMINA_SEEDANCE_2_0().getCostEstimate(request: .init(
            dimensions: "16:9",
            durationSeconds: 5,
            resolution: "720p",
            generateAudio: true
        ))
        #expect(abs(standard - 0.756) < 0.000_001)
        let standardFourThree = G_BYTEPLUS_DREAMINA_SEEDANCE_2_0().getCostEstimate(request: .init(
            dimensions: "4:3",
            durationSeconds: 5,
            resolution: "720p",
            generateAudio: true
        ))
        let expectedFourThree = Double(1112 * 834 * 24 * 5) / 1024.0 / 1_000_000.0 * 7.0
        #expect(abs(standardFourThree - expectedFourThree) < 0.000_001)
        let audio15 = G_BYTEPLUS_SEEDANCE_1_5_PRO().getCostEstimate(request: .init(
            dimensions: "16:9",
            durationSeconds: 4,
            resolution: "720p",
            generateAudio: true
        ))
        #expect(abs(audio15 - 0.20736) < 0.000_001)
    }

    private func imageRequest(
        modelCode: EnumProviderModelCode,
        secret: String? = nil,
        numberOfImages: Int = 1,
        clientImage: String? = nil,
        references: [ReferenceImageData]? = nil,
        resolution: String?
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: modelCode.modelId.uuidString,
            prompt: "A premium aircraft campaign image",
            dimensions: "1:1",
            clientImage: clientImage,
            clientReferenceImages: references,
            providerKey: providerKey,
            providerSecret: secret ?? credentials(),
            numberOfImages: numberOfImages,
            resolution: resolution
        )
    }

    private func videoRequest(
        modelCode: EnumProviderModelCode = .BYTEPLUS_DREAMINA_SEEDANCE_2_0,
        duration: Int? = 5,
        resolution: String? = "720p",
        dimensions: String = "16:9",
        clientImage: String? = nil,
        lastFrame: String? = nil,
        references: [ReferenceImageData]? = nil,
        generateAudio: Bool? = true,
        seed: Int? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: modelCode.modelId.uuidString,
            prompt: "An aircraft taxis through monsoon rain",
            dimensions: dimensions,
            clientImage: clientImage,
            clientLastFrame: lastFrame,
            clientReferenceImages: references,
            providerKey: providerKey,
            providerSecret: credentials(),
            numberOfVideos: 3,
            durationSeconds: duration,
            resolution: resolution,
            fps: 24,
            generateAudio: generateAudio,
            seed: seed
        )
    }

    private var providerKey: ProviderKeyInfo {
        ProviderKeyInfo(
            providerId: EnumProviderCode.BYTEPLUS_MODELARK.providerId,
            providerCode: .BYTEPLUS_MODELARK,
            projectId: UUID(uuidString: "F9229038-C01A-4082-B777-D40D924BB396")!
        )
    }

    private func credentials(region: String = "ap-southeast-1") -> String {
        "{\"api_key\":\"byteplus-test-key\",\"region\":\"\(region)\"}"
    }

    private func jsonObject(_ data: Data?) throws -> [String: Any] {
        let data = try #require(data)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class BytePlusTestNetworkProvider: @unchecked Sendable, NetworkProvider {
    struct CapturedRequest {
        let url: URL
        let method: String
        let headers: [String: String]?
        let body: Data?
    }

    var requests: [CapturedRequest] = []
    var rawRequests: [URLRequest] = []
    var dataRequests: [URLRequest] = []
    var singleAttemptRequestCount = 0
    var retryableRequestCount = 0
    private var singleResponses: [NetworkResponseEnvelope]
    private var retryableResponses: [NetworkResponseData]
    private var rawResponses: [NetworkResponseData]
    private var dataResponses: [NetworkDataResponse]

    init(
        singleResponses: [NetworkResponseEnvelope] = [],
        retryableResponses: [NetworkResponseData] = [],
        rawResponses: [NetworkResponseData] = [],
        dataResponses: [NetworkDataResponse] = []
    ) {
        self.singleResponses = singleResponses
        self.retryableResponses = retryableResponses
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
        retryableRequestCount += 1
        try requests.append(.init(
            url: url,
            method: method,
            headers: headers,
            body: body.map { try JSONEncoder().encode($0) }
        ))
        guard !retryableResponses.isEmpty else { throw URLError(.badServerResponse) }
        return retryableResponses.removeFirst()
    }

    func performSingleAttemptRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments _: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseEnvelope {
        singleAttemptRequestCount += 1
        try requests.append(.init(
            url: url,
            method: method,
            headers: headers,
            body: body.map { try JSONEncoder().encode($0) }
        ))
        guard !singleResponses.isEmpty else { throw URLError(.badServerResponse) }
        return singleResponses.removeFirst()
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

private struct BytePlusTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        BytePlusModelArkModels.createModels().first { $0.modelCode == code }
    }
}
