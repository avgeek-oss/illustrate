import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("xAI direct provider", .serialized)
struct XAIProviderTests {
    private let apiKey = "xai-test-api-key"

    @Test("Image generation is atomic and accepts raw base64")
    func imageGenerationIsAtomic() async throws {
        let imageBytes = Data("xai-image".utf8)
        let mock = XAITestNetworkProvider(singleResponses: [
            NetworkResponseEnvelope(response: .dictionary(statusCode: 200, data: [
                "data": [[
                    "b64_json": imageBytes.base64EncodedString(),
                    "mime_type": "image/png",
                    "revised_prompt": "A polished aircraft portrait",
                ]],
                "usage": ["cost_in_usd_ticks": 200_000_000],
            ])),
        ])

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_IMAGE().makeRequest(request: imageRequest(
                numberOfImages: 4,
                resolution: "2k"
            ))
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.retryableRequestCount == 0)
        let captured = try #require(mock.requests.first)
        #expect(captured.url.absoluteString == "https://api.x.ai/v1/images/generations")
        #expect(captured.method == "POST")
        #expect(captured.headers?["Authorization"] == "Bearer \(apiKey)")
        let json = try jsonObject(captured.body)
        #expect(json["model"] as? String == "grok-imagine-image")
        #expect(json["prompt"] as? String == "A cinematic aircraft portrait")
        #expect(json["n"] as? Int == 1)
        #expect(json["aspect_ratio"] as? String == "16:9")
        #expect(json["resolution"] as? String == "2k")
        #expect(json["response_format"] as? String == "b64_json")
        #expect(json["image"] == nil)
        #expect(json["images"] == nil)

        #expect(response.status == .GENERATED)
        #expect(response.base64 == imageBytes.base64EncodedString())
        #expect(response.cost == 0.02)
        #expect(response.modelPrompt == "A polished aircraft portrait")
    }

    @Test("Image edits use JSON one-image and multi-image forms")
    func imageEditForms() async throws {
        let success = NetworkResponseEnvelope(response: .dictionary(statusCode: 200, data: [
            "data": [["b64_json": "ZWRpdA=="]],
        ]))

        let single = XAITestNetworkProvider(singleResponses: [success])
        _ = try await withProviderDependencies(
            networkProvider: single,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_IMAGE_QUALITY().makeRequest(request: imageRequest(
                modelCode: .XAI_GROK_IMAGINE_IMAGE_QUALITY,
                clientImage: "aW1hZ2U=",
                resolution: "1k"
            ))
        }
        let singleJSON = try jsonObject(#require(single.requests.first?.body))
        #expect(single.requests.first?.url.absoluteString == "https://api.x.ai/v1/images/edits")
        #expect(singleJSON["image"] as? [String: String] == [
            "type": "image_url",
            "url": "data:image/png;base64,aW1hZ2U=",
        ])
        #expect(singleJSON["aspect_ratio"] == nil)
        #expect(singleJSON["images"] == nil)

        let multi = XAITestNetworkProvider(singleResponses: [success])
        _ = try await withProviderDependencies(
            networkProvider: multi,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_IMAGE().makeRequest(request: imageRequest(
                clientImage: "aW1hZ2U=",
                references: [
                    ReferenceImageData(base64Image: "cmVmMQ==", mimeType: "image/jpeg"),
                    ReferenceImageData(base64Image: "cmVmMg==", mimeType: "image/webp"),
                ]
            ))
        }
        let multiJSON = try jsonObject(#require(multi.requests.first?.body))
        let images = try #require(multiJSON["images"] as? [[String: String]])
        #expect(images.count == 3)
        #expect(images.map { $0["url"] } == [
            "data:image/png;base64,aW1hZ2U=",
            "data:image/jpeg;base64,cmVmMQ==",
            "data:image/webp;base64,cmVmMg==",
        ])
        #expect(multiJSON["aspect_ratio"] as? String == "16:9")
        #expect(multiJSON["image"] == nil)
    }

    @Test("Image URL fallback materializes without forwarding authorization")
    func imageURLFallback() async throws {
        let outputURL = "https://delivery.x.ai/result.png?expires=600"
        let bytes = Data("downloaded-image".utf8)
        let mock = XAITestNetworkProvider(
            singleResponses: [NetworkResponseEnvelope(response: .dictionary(statusCode: 200, data: [
                "data": [["url": outputURL, "mime_type": "image/png"]],
            ]))],
            dataResponses: [NetworkDataResponse(
                statusCode: 200,
                data: bytes,
                headers: ["Content-Type": "image/png"]
            )]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_IMAGE().makeRequest(request: imageRequest())
        }

        #expect(response.base64 == bytes.base64EncodedString())
        #expect(response.metadata?["xaiOutputURL"] == nil)
        let download = try #require(mock.dataRequests.first)
        #expect(download.url?.absoluteString == outputURL)
        #expect(download.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("Image validation and moderation fail closed")
    func imageValidationAndModeration() async throws {
        let excessive = XAITestNetworkProvider()
        let response = try await withProviderDependencies(
            networkProvider: excessive,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_IMAGE().makeRequest(request: imageRequest(
                clientImage: "aW1hZ2U=",
                references: (0 ..< 3).map { index in
                    ReferenceImageData(base64Image: Data("ref-\(index)".utf8).base64EncodedString())
                }
            ))
        }
        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("at most three") == true)
        #expect(excessive.requests.isEmpty)

        let longPrompt = XAITestNetworkProvider()
        let longPromptResponse = try await withProviderDependencies(
            networkProvider: longPrompt,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_IMAGE().makeRequest(request: imageRequest(
                prompt: String(repeating: "a", count: 1025)
            ))
        }
        #expect(longPromptResponse.status == .FAILED)
        #expect(longPromptResponse.errorMessage?.contains("1024") == true)
        #expect(longPrompt.requests.isEmpty)

        let moderated = try G_XAI_GROK_IMAGINE_IMAGE().transformResponse(
            request: imageRequest(),
            response: .dictionary(statusCode: 200, data: [
                "respect_moderation": false,
                "data": [["b64_json": "aW1hZ2U="]],
            ])
        )
        #expect(moderated.status == .FAILED)
        #expect(moderated.errorMessage?.contains("moderation") == true)

        let multiple = try G_XAI_GROK_IMAGINE_IMAGE().transformResponse(
            request: imageRequest(),
            response: .dictionary(statusCode: 200, data: [
                "data": [
                    ["b64_json": "aW1hZ2Ux"],
                    ["b64_json": "aW1hZ2Uy"],
                ],
            ])
        )
        #expect(multiple.status == .FAILED)
        #expect(multiple.errorMessage?.contains("atomic") == true)

        #expect(XAIClient.normalizedBase64("aW1hZ2U=") == "aW1hZ2U=")
        #expect(XAIClient.normalizedBase64("data:image/png;base64,aW1hZ2U=") == "aW1hZ2U=")
        #expect(try XAIClient.validatedImageURI("aW1h Z2U=") == "data:image/png;base64,aW1hZ2U=")
        #expect(
            try XAIClient.validatedImageURI("data:image/png;base64,aW1h Z2U=")
                == "data:image/png;base64,aW1hZ2U="
        )
    }

    @Test("Standard video polls unknown states and materializes the result")
    func standardVideoFlow() async throws {
        let requestID = "request_standard_123"
        let outputURL = "https://delivery.x.ai/video.mp4?expires=600"
        let bytes = Data("xai-video".utf8)
        let mock = XAITestNetworkProvider(
            singleResponses: [NetworkResponseEnvelope(response: .dictionary(
                statusCode: 202,
                data: ["request_id": requestID]
            ))],
            retryableResponses: [
                .dictionary(statusCode: 200, data: ["status": "warming"]),
                .dictionary(statusCode: 200, data: [
                    "status": "done",
                    "progress": 1.0,
                    "model": "grok-imagine-video",
                    "video": [
                        "url": outputURL,
                        "duration": 8,
                        "respect_moderation": true,
                    ],
                    "usage": ["cost_in_usd_ticks": 5_600_000_000],
                ]),
            ],
            dataResponses: [NetworkDataResponse(
                statusCode: 200,
                data: bytes,
                headers: ["Content-Type": "video/mp4"]
            )]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_VIDEO(
                pollingPolicy: .init(maxAttempts: 2, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest(
                numberOfVideos: 3,
                references: [
                    ReferenceImageData(base64Image: "cmVmMQ==", mimeType: "image/jpeg"),
                    ReferenceImageData(base64Image: "cmVmMg==", mimeType: "image/png"),
                ]
            ))
        }

        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.retryableRequestCount == 2)
        let create = try #require(mock.requests.first)
        let json = try jsonObject(create.body)
        #expect(create.url.absoluteString == "https://api.x.ai/v1/videos/generations")
        #expect(json["model"] as? String == "grok-imagine-video")
        #expect(json["duration"] as? Int == 8)
        #expect(json["aspect_ratio"] as? String == "16:9")
        #expect(json["resolution"] as? String == "720p")
        #expect(json["image"] == nil)
        #expect((json["reference_images"] as? [[String: String]])?.count == 2)
        #expect(json["generate_audio"] == nil)
        #expect(json["seed"] == nil)

        let statusURL = "https://api.x.ai/v1/videos/\(requestID)"
        #expect(mock.requests.dropFirst().allSatisfy { request in
            request.url.absoluteString == statusURL && request.method == "GET"
        })
        #expect(response.status == .GENERATED)
        #expect(response.base64 == bytes.base64EncodedString())
        #expect(response.cost == 0.56)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == requestID)
        #expect(response.metadata?[ProviderJobMetadataKey.statusURL] == statusURL)
        #expect(response.metadata?[ProviderJobMetadataKey.cancelURL] == nil)
        #expect(mock.dataRequests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("Video 1.5 requires an image and accepts 1080p")
    func video15Contract() async throws {
        let missing = XAITestNetworkProvider()
        let rejected = try await withProviderDependencies(
            networkProvider: missing,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_VIDEO_1_5().makeRequest(request: videoRequest(
                modelCode: .XAI_GROK_IMAGINE_VIDEO_1_5,
                resolution: "1080p"
            ))
        }
        #expect(rejected.status == .FAILED)
        #expect(rejected.errorMessage?.contains("requires a source image") == true)
        #expect(missing.requests.isEmpty)

        let outputURL = "https://delivery.x.ai/video-15.mp4"
        let mock = XAITestNetworkProvider(
            singleResponses: [NetworkResponseEnvelope(response: .dictionary(
                statusCode: 202,
                data: ["request_id": "request_15"]
            ))],
            retryableResponses: [.dictionary(statusCode: 200, data: [
                "status": "done",
                "video": ["url": outputURL, "duration": 4, "respect_moderation": true],
            ])],
            dataResponses: [NetworkDataResponse(statusCode: 200, data: Data("video-15".utf8))]
        )
        let accepted = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_VIDEO_1_5(
                pollingPolicy: .init(maxAttempts: 1, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest(
                modelCode: .XAI_GROK_IMAGINE_VIDEO_1_5,
                duration: 4,
                resolution: "1080p",
                clientImage: "aW1hZ2U="
            ))
        }

        let json = try jsonObject(#require(mock.requests.first?.body))
        #expect(json["model"] as? String == "grok-imagine-video-1.5")
        #expect(json["resolution"] as? String == "1080p")
        #expect((json["image"] as? [String: String])?["url"] == "data:image/png;base64,aW1hZ2U=")
        #expect(json["reference_images"] == nil)
        #expect(accepted.status == .GENERATED)
        #expect(accepted.cost == 1.01)
    }

    @Test("Completed video responses tolerate omitted moderation and reject explicit failures")
    func completedVideoResponseValidation() throws {
        let adapter = G_XAI_GROK_IMAGINE_VIDEO()
        let omittedModeration = try adapter.transformResponse(
            request: videoRequest(),
            response: .dictionary(statusCode: 200, data: [
                "status": "done",
                "video": ["url": "https://delivery.x.ai/video.mp4", "duration": 8],
            ])
        )
        #expect(omittedModeration.status == .GENERATED)

        for response in [
            NetworkResponseData.dictionary(statusCode: 200, data: [
                "status": "done",
                "video": [
                    "url": "https://delivery.x.ai/video.mp4",
                    "duration": 8,
                    "respect_moderation": false,
                ],
            ]),
            NetworkResponseData.dictionary(statusCode: 200, data: [
                "status": "done",
                "respect_moderation": false,
                "video": ["url": "https://delivery.x.ai/video.mp4", "duration": 8],
            ]),
        ] {
            let moderated = try adapter.transformResponse(request: videoRequest(), response: response)
            #expect(moderated.status == .FAILED)
            #expect(moderated.errorMessage?.contains("moderation") == true)
        }

        let missingDuration = try adapter.transformResponse(
            request: videoRequest(),
            response: .dictionary(statusCode: 200, data: [
                "status": "done",
                "video": ["url": "https://delivery.x.ai/video.mp4", "respect_moderation": true],
            ])
        )
        #expect(missingDuration.status == .FAILED)
        #expect(missingDuration.errorMessage?.contains("duration") == true)
    }

    @Test("Video modes reject unsupported combinations before billing")
    func videoModeValidation() async throws {
        let combined = XAITestNetworkProvider()
        let combinedResponse = try await withProviderDependencies(
            networkProvider: combined,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_VIDEO().makeRequest(request: videoRequest(
                clientImage: "aW1hZ2U=",
                references: [ReferenceImageData(base64Image: "cmVm")]
            ))
        }
        #expect(combinedResponse.status == .FAILED)
        #expect(combinedResponse.errorMessage?.contains("cannot combine") == true)
        #expect(combined.requests.isEmpty)

        let standard1080 = XAITestNetworkProvider()
        let standard1080Response = try await withProviderDependencies(
            networkProvider: standard1080,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_VIDEO().makeRequest(request: videoRequest(resolution: "1080p"))
        }
        #expect(standard1080Response.status == .FAILED)
        #expect(standard1080Response.errorMessage?.contains("resolution") == true)
        #expect(standard1080.requests.isEmpty)

        let references15 = XAITestNetworkProvider()
        let references15Response = try await withProviderDependencies(
            networkProvider: references15,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_VIDEO_1_5().makeRequest(request: videoRequest(
                modelCode: .XAI_GROK_IMAGINE_VIDEO_1_5,
                resolution: "1080p",
                clientImage: "aW1hZ2U=",
                references: [ReferenceImageData(base64Image: "cmVm")]
            ))
        }
        #expect(references15Response.status == .FAILED)
        #expect(references15.requests.isEmpty)

        let tooManyReferences = XAITestNetworkProvider()
        let tooManyResponse = try await withProviderDependencies(
            networkProvider: tooManyReferences,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_VIDEO().makeRequest(request: videoRequest(
                references: (0 ..< 8).map { index in
                    ReferenceImageData(base64Image: Data("ref-\(index)".utf8).base64EncodedString())
                }
            ))
        }
        #expect(tooManyResponse.status == .FAILED)
        #expect(tooManyResponse.errorMessage?.contains("seven") == true)
        #expect(tooManyReferences.requests.isEmpty)

        let longReferenceVideo = XAITestNetworkProvider()
        let longReferenceResponse = try await withProviderDependencies(
            networkProvider: longReferenceVideo,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_VIDEO().makeRequest(request: videoRequest(
                duration: 11,
                references: [ReferenceImageData(base64Image: "cmVm")]
            ))
        }
        #expect(longReferenceResponse.status == .FAILED)
        #expect(longReferenceResponse.errorMessage?.contains("10 seconds") == true)
        #expect(longReferenceVideo.requests.isEmpty)

        let emptyReferencePrompt = XAITestNetworkProvider()
        let emptyReferenceResponse = try await withProviderDependencies(
            networkProvider: emptyReferencePrompt,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_VIDEO().makeRequest(request: videoRequest(
                prompt: "   ",
                references: [ReferenceImageData(base64Image: "cmVm")]
            ))
        }
        #expect(emptyReferenceResponse.status == .FAILED)
        #expect(emptyReferenceResponse.errorMessage?.contains("non-empty prompt") == true)
        #expect(emptyReferencePrompt.requests.isEmpty)
    }

    @Test("Paid creates preserve provider errors and are never retried")
    func paidCreateFailureIsSingleAttempt() async throws {
        for statusCode in [429, 503, 504] {
            let body = statusCode == 429
                ? Data(#"{"error":{"code":"rate_limit","message":"Slow down"}}"#.utf8)
                : Data("temporary upstream failure".utf8)
            let parsed: NetworkResponseData? = statusCode == 429
                ? .dictionary(statusCode: statusCode, data: [
                    "error": ["code": "rate_limit", "message": "Slow down"],
                ])
                : nil
            let mock = XAITestNetworkProvider(singleResponses: [NetworkResponseEnvelope(
                statusCode: statusCode,
                headers: ["Retry-After": "10"],
                body: body,
                response: parsed
            )])

            let response = try await withProviderDependencies(
                networkProvider: mock,
                modelProvider: XAITestModelProvider()
            ) {
                try await G_XAI_GROK_IMAGINE_IMAGE().makeRequest(request: imageRequest())
            }

            #expect(mock.singleAttemptRequestCount == 1)
            #expect(mock.requests.count == 1)
            #expect(response.status == .FAILED)
            if statusCode == 429 {
                #expect(response.errorMessage?.contains("rate_limit: Slow down") == true)
                #expect(response.rawResponse?.contains("Slow down") == true)
            } else {
                #expect(response.errorMessage?.contains("temporary upstream failure") == true)
                #expect(response.rawResponse == "temporary upstream failure")
            }
        }
    }

    @Test("Unknown video states time out with resumable metadata")
    func unknownVideoStatusTimesOut() async throws {
        let requestID = "request_timeout"
        let mock = XAITestNetworkProvider(
            singleResponses: [NetworkResponseEnvelope(response: .dictionary(
                statusCode: 202,
                data: ["request_id": requestID]
            ))],
            retryableResponses: [
                .dictionary(statusCode: 200, data: ["status": "warming"]),
                .dictionary(statusCode: 200, data: ["status": "warming"]),
            ]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: XAITestModelProvider()
        ) {
            try await G_XAI_GROK_IMAGINE_VIDEO(
                pollingPolicy: .init(maxAttempts: 2, intervalNanoseconds: 0)
            ).makeRequest(request: videoRequest())
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("did not finish after 2 status checks") == true)
        #expect(response.metadata?[ProviderJobMetadataKey.jobId] == requestID)
        #expect(response
            .metadata?[ProviderJobMetadataKey.statusURL] == "https://api.x.ai/v1/videos/\(requestID)")
        #expect(response.metadata?[ProviderJobMetadataKey.cancelURL] == nil)
        #expect(mock.singleAttemptRequestCount == 1)
        #expect(mock.retryableRequestCount == 2)
    }

    @Test("Video classifiers surface terminals while unknown states remain bounded")
    func videoStatusClassification() throws {
        #expect(try G_XAI_GROK_IMAGINE_VIDEO_BASE.classify(
            .dictionary(statusCode: 200, data: ["status": "new_future_state"])
        ) == .pending)
        #expect(try G_XAI_GROK_IMAGINE_VIDEO_BASE.classify(
            .dictionary(statusCode: 200, data: [
                "status": "failed",
                "error": ["code": "invalid_argument", "message": "Bad image"],
            ])
        ) == .failed("xAI video generation failed: invalid_argument: Bad image"))
        #expect(try G_XAI_GROK_IMAGINE_VIDEO_BASE.classify(
            .dictionary(statusCode: 200, data: ["status": "expired"])
        ) == .failed("xAI video request expired before completion."))
    }

    @Test("Catalog and estimates use canonical current models")
    func catalogAndPricing() {
        let models = XAIModels.createModels()
        #expect(models.map(\.modelCode) == [
            .XAI_GROK_IMAGINE_IMAGE,
            .XAI_GROK_IMAGINE_IMAGE_QUALITY,
            .XAI_GROK_IMAGINE_VIDEO,
            .XAI_GROK_IMAGINE_VIDEO_1_5,
        ])
        #expect(models.allSatisfy { $0.providerId == EnumProviderCode.XAI.providerId })
        #expect(models.filter { !$0.active }.isEmpty)
        #expect(models.allSatisfy { $0.modelVerificationDate == getDateFromString("2026-07-10") })
        #expect(models.allSatisfy { $0.pricingMetadata?.sourceURL == "https://docs.x.ai/developers/pricing" })
        #expect(models.map(\.modelName).allSatisfy { !$0.contains("latest") && !$0.contains("preview") })
        #expect(models[0].modelParams.maxPromptLength == 1024)
        #expect(models[1].modelParams.maxPromptLength == 1024)
        #expect(models[2].modelParams.maxReferenceImages == 7)

        let standardImage = G_XAI_GROK_IMAGINE_IMAGE().getCostEstimate(request: .init(
            resolution: "2k",
            numberOfImages: 3,
            hasSourceImage: true,
            referenceImageCount: 1
        ))
        #expect(abs(standardImage - 0.072) < 0.000_001)
        let qualityImage = G_XAI_GROK_IMAGINE_IMAGE_QUALITY().getCostEstimate(request: .init(
            resolution: "2k",
            numberOfImages: 2,
            hasSourceImage: true
        ))
        #expect(abs(qualityImage - 0.16) < 0.000_001)

        let standardVideo = G_XAI_GROK_IMAGINE_VIDEO().getCostEstimate(request: .init(
            durationSeconds: 5,
            numberOfVideos: 2,
            resolution: "720p",
            hasReferenceImages: true,
            referenceImageCount: 2
        ))
        #expect(abs(standardVideo - 0.708) < 0.000_001)
        let video15 = G_XAI_GROK_IMAGINE_VIDEO_1_5().getCostEstimate(request: .init(
            durationSeconds: 4,
            resolution: "1080p",
            hasSourceImage: true
        ))
        #expect(abs(video15 - 1.01) < 0.000_001)
    }

    private func imageRequest(
        modelCode: EnumProviderModelCode = .XAI_GROK_IMAGINE_IMAGE,
        prompt: String = "A cinematic aircraft portrait",
        numberOfImages: Int = 1,
        clientImage: String? = nil,
        references: [ReferenceImageData]? = nil,
        resolution: String = "1k"
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: modelCode.modelId.uuidString,
            prompt: prompt,
            dimensions: "16:9",
            clientImage: clientImage,
            clientReferenceImages: references,
            providerKey: providerKey,
            providerSecret: apiKey,
            numberOfImages: numberOfImages,
            resolution: resolution
        )
    }

    private func videoRequest(
        modelCode: EnumProviderModelCode = .XAI_GROK_IMAGINE_VIDEO,
        prompt: String = "An aircraft taxis through rain",
        numberOfVideos: Int = 1,
        duration: Int = 8,
        resolution: String = "720p",
        clientImage: String? = nil,
        references: [ReferenceImageData]? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: modelCode.modelId.uuidString,
            prompt: prompt,
            dimensions: "16:9",
            clientImage: clientImage,
            clientReferenceImages: references,
            providerKey: providerKey,
            providerSecret: apiKey,
            numberOfVideos: numberOfVideos,
            durationSeconds: duration,
            resolution: resolution
        )
    }

    private var providerKey: ProviderKeyInfo {
        ProviderKeyInfo(
            providerId: EnumProviderCode.XAI.providerId,
            providerCode: .XAI,
            projectId: UUID(uuidString: "43DB9159-E305-44F2-B0B8-188B71C94F41")!
        )
    }

    private func jsonObject(_ data: Data?) throws -> [String: Any] {
        let body = try #require(data)
        return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}

private final class XAITestNetworkProvider: @unchecked Sendable, NetworkProvider {
    struct CapturedRequest {
        let url: URL
        let method: String
        let headers: [String: String]?
        let body: Data?
    }

    var requests: [CapturedRequest] = []
    var dataRequests: [URLRequest] = []
    var singleAttemptRequestCount = 0
    var retryableRequestCount = 0
    private var singleResponses: [NetworkResponseEnvelope]
    private var retryableResponses: [NetworkResponseData]
    private var dataResponses: [NetworkDataResponse]

    init(
        singleResponses: [NetworkResponseEnvelope] = [],
        retryableResponses: [NetworkResponseData] = [],
        dataResponses: [NetworkDataResponse] = []
    ) {
        self.singleResponses = singleResponses
        self.retryableResponses = retryableResponses
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
        try requests.append(CapturedRequest(
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
        try requests.append(CapturedRequest(
            url: url,
            method: method,
            headers: headers,
            body: body.map { try JSONEncoder().encode($0) }
        ))
        guard !singleResponses.isEmpty else { throw URLError(.badServerResponse) }
        return singleResponses.removeFirst()
    }

    func performDataRequest(_ request: URLRequest) async throws -> NetworkDataResponse {
        dataRequests.append(request)
        guard !dataResponses.isEmpty else { throw URLError(.badServerResponse) }
        return dataResponses.removeFirst()
    }
}

private struct XAITestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        XAIModels.createModels().first { $0.modelCode == code }
    }
}
