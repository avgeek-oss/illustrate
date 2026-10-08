import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Fal video variant adapters", .serialized)
struct FalVideoVariantTests {
    @Test("Seedance 2 Mini T2V posts documented payload and resolution-aware estimate")
    func seedanceMiniT2VPostsDocumentedPayload() async throws {
        let mock = FalMockNetworkProvider()
        let adapter = try await withFalDependencies(mock) {
            let adapter = G_FAL_SEEDANCE_V2_MINI_T2V()
            _ = try await adapter.makeRequest(request: videoRequest(
                dimensions: "9:16",
                durationSeconds: 8,
                resolution: "480p",
                generateAudio: false,
                seed: 123
            ))
            return adapter
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/bytedance/seedance-2.0/mini/text-to-video")
        #expect(mock.capturedHeaders?["Authorization"] == "Key fal-test")
        #expect(json["prompt"] as? String == "A crane camera move over a neon city.")
        #expect(json["resolution"] as? String == "480p")
        #expect(json["duration"] as? String == "8")
        #expect(json["aspect_ratio"] as? String == "9:16")
        #expect(json["generate_audio"] as? Bool == false)
        #expect(json["seed"] == nil)

        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "480p")) - 0.5768) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "720p")) - 1.2376) <
            0.0001)
    }

    @Test("Seedance 2 Mini I2V includes source image and optional last frame")
    func seedanceMiniI2VPostsImagePayload() async throws {
        let mock = FalMockNetworkProvider()
        try await withFalDependencies(mock) {
            let adapter = G_FAL_SEEDANCE_V2_MINI_I2V()
            _ = try await adapter.makeRequest(request: videoRequest(
                clientImage: "source-image",
                clientLastFrame: "last-frame",
                durationSeconds: nil,
                resolution: "720p",
                seed: 99
            ))
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/bytedance/seedance-2.0/mini/image-to-video")
        #expect(json["image_url"] as? String == "data:image/png;base64,source-image")
        #expect(json["end_image_url"] as? String == "data:image/png;base64,last-frame")
        #expect(json["duration"] as? String == "auto")
        #expect(json["generate_audio"] as? Bool == true)
        #expect(json["seed"] == nil)
    }

    @Test("Seedance 2 Mini Ref2V uses image_urls for reference images")
    func seedanceMiniRef2VPostsImageURLs() async throws {
        let mock = FalMockNetworkProvider()
        try await withFalDependencies(mock) {
            let adapter = G_FAL_SEEDANCE_V2_MINI_REF2V()
            _ = try await adapter.makeRequest(request: videoRequest(
                clientReferenceImages: [
                    ReferenceImageData(base64Image: "reference-one"),
                    ReferenceImageData(base64Image: "data:image/jpeg;base64,reference-two", mimeType: "image/jpeg"),
                ],
                durationSeconds: 6,
                resolution: "720p"
            ))
        }

        let json = try capturedJSON(mock)
        let imageURLs = try #require(json["image_urls"] as? [String])
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/bytedance/seedance-2.0/mini/reference-to-video")
        #expect(imageURLs == [
            "data:image/png;base64,reference-one",
            "data:image/jpeg;base64,reference-two",
        ])
        #expect(json["reference_image_urls"] == nil)
        #expect(json["duration"] as? String == "6")
    }

    @Test("PixVerse V6 T2V posts prompt fields and audio-aware estimate")
    func pixverseV6T2VPostsDocumentedPayload() async throws {
        let mock = FalMockNetworkProvider()
        let adapter = try await withFalDependencies(mock) {
            let adapter = G_FAL_PIXVERSE_V6_T2V()
            _ = try await adapter.makeRequest(request: videoRequest(
                negativePrompt: "low quality",
                dimensions: "21:9",
                durationSeconds: 4,
                resolution: "1080p",
                generateAudio: true,
                seed: 77
            ))
            return adapter
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/fal-ai/pixverse/v6/text-to-video")
        #expect(json["aspect_ratio"] as? String == "21:9")
        #expect(json["resolution"] as? String == "1080p")
        #expect(json["duration"] as? Int == 4)
        #expect(json["negative_prompt"] as? String == "low quality")
        #expect(json["seed"] as? Int == 77)
        #expect(json["generate_audio_switch"] as? Bool == true)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 4,
            resolution: "1080p",
            generateAudio: true
        )) - 0.46) < 0.0001)
    }

    @Test("Happy Horse 1.1 I2V omits unsupported aspect ratio")
    func happyHorseV11I2VOmitsAspectRatio() async throws {
        let mock = FalMockNetworkProvider()
        let adapter = try await withFalDependencies(mock) {
            let adapter = G_FAL_HAPPY_HORSE_V11_I2V()
            _ = try await adapter.makeRequest(request: videoRequest(
                dimensions: "9:16",
                clientImage: "horse-source",
                durationSeconds: 10,
                resolution: "720p",
                seed: 5
            ))
            return adapter
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/alibaba/happy-horse/v1.1/image-to-video")
        #expect(json["image_url"] as? String == "data:image/png;base64,horse-source")
        #expect(json["prompt"] as? String == "A crane camera move over a neon city.")
        #expect(json["resolution"] as? String == "720p")
        #expect(json["duration"] as? Int == 10)
        #expect(json["seed"] as? Int == 5)
        #expect(json["enable_safety_checker"] as? Bool == true)
        #expect(json["aspect_ratio"] == nil)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 10, resolution: "720p")) - 1.4) <
            0.0001)
    }

    @Test("Happy Horse 1.1 Ref2V uses image_urls and aspect ratio")
    func happyHorseV11Ref2VPostsImageURLs() async throws {
        let mock = FalMockNetworkProvider()
        let adapter = try await withFalDependencies(mock) {
            let adapter = G_FAL_HAPPY_HORSE_V11_REF2V()
            _ = try await adapter.makeRequest(request: videoRequest(
                dimensions: "21:9",
                clientReferenceImages: [
                    ReferenceImageData(base64Image: "character-one"),
                    ReferenceImageData(base64Image: "character-two"),
                ],
                durationSeconds: 5,
                resolution: "1080p"
            ))
            return adapter
        }

        let json = try capturedJSON(mock)
        let imageURLs = try #require(json["image_urls"] as? [String])
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/alibaba/happy-horse/v1.1/reference-to-video")
        #expect(imageURLs == [
            "data:image/png;base64,character-one",
            "data:image/png;base64,character-two",
        ])
        #expect(json["aspect_ratio"] as? String == "21:9")
        #expect(json["reference_image_urls"] == nil)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "1080p")) - 0.9) <
            0.0001)
    }

    @Test("Wan 2.7 T2V posts documented payload and resolution-aware estimate")
    func wan27T2VPostsDocumentedPayload() async throws {
        let mock = FalMockNetworkProvider()
        let adapter = try await withFalDependencies(mock) {
            let adapter = G_FAL_WAN_27_T2V()
            _ = try await adapter.makeRequest(request: videoRequest(
                negativePrompt: "low quality",
                dimensions: "4:3",
                durationSeconds: 10,
                resolution: "1080p",
                seed: 123,
                promptEnhance: false
            ))
            return adapter
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/fal-ai/wan/v2.7/text-to-video")
        #expect(mock.capturedHeaders?["Authorization"] == "Key fal-test")
        #expect(json["prompt"] as? String == "A crane camera move over a neon city.")
        #expect(json["aspect_ratio"] as? String == "4:3")
        #expect(json["resolution"] as? String == "1080p")
        #expect(json["duration"] as? Int == 10)
        #expect(json["negative_prompt"] as? String == "low quality")
        #expect(json["enable_prompt_expansion"] as? Bool == false)
        #expect(json["seed"] as? Int == 123)
        #expect(json["enable_safety_checker"] as? Bool == true)
        #expect(json["audio_url"] == nil)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 10, resolution: "720p")) - 1.0) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 10, resolution: "1080p")) - 1.5) <
            0.0001)
    }

    @Test("Wan 2.7 I2V posts source image and optional end image")
    func wan27I2VPostsImagePayload() async throws {
        let mock = FalMockNetworkProvider()
        try await withFalDependencies(mock) {
            let adapter = G_FAL_WAN_27_I2V()
            _ = try await adapter.makeRequest(request: videoRequest(
                negativePrompt: "blur",
                clientImage: "source-image",
                clientLastFrame: "last-frame",
                durationSeconds: 5,
                resolution: "720p",
                seed: 77,
                promptEnhance: true
            ))
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/fal-ai/wan/v2.7/image-to-video")
        #expect(json["prompt"] as? String == "A crane camera move over a neon city.")
        #expect(json["image_url"] as? String == "data:image/png;base64,source-image")
        #expect(json["end_image_url"] as? String == "data:image/png;base64,last-frame")
        #expect(json["resolution"] as? String == "720p")
        #expect(json["duration"] as? Int == 5)
        #expect(json["negative_prompt"] as? String == "blur")
        #expect(json["enable_prompt_expansion"] as? Bool == true)
        #expect(json["seed"] as? Int == 77)
        #expect(json["enable_safety_checker"] as? Bool == true)
        #expect(json["video_url"] == nil)
        #expect(json["audio_url"] == nil)
    }

    @Test("Wan 2.7 I2V validates source image")
    func wan27I2VValidatesSourceImage() async throws {
        let mock = FalMockNetworkProvider()
        let response = try await withFalDependencies(mock) {
            try await G_FAL_WAN_27_I2V().makeRequest(request: videoRequest(clientImage: nil))
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "This model requires an input image")
        #expect(mock.capturedURL == nil)
    }

    @Test("Wan 2.7 parses video URL metadata and rejects malformed responses")
    func wan27ParsesVideoURLMetadataAndRejectsMalformedResponses() async throws {
        let mock = FalMockNetworkProvider(response: .dictionary(
            statusCode: 200,
            data: [
                "seed": 1_478_415_556,
                "actual_prompt": "Expanded crane camera move.",
                "video": [
                    "url": "data:video/mp4;base64,dmlkZW8=",
                    "width": 1920,
                    "height": 1080,
                    "duration": 5.038005,
                    "file_size": 1234,
                ],
            ]
        ))

        let (adapter, response) = try await withFalDependencies(mock) {
            let adapter = G_FAL_WAN_27_T2V()
            let response = try await adapter.makeRequest(request: videoRequest(
                durationSeconds: 5,
                resolution: "720p"
            ))
            return (adapter, response)
        }

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "dmlkZW8=")
        #expect(response.modelPrompt == "Expanded crane camera move.")
        #expect(response.metadata?["seed"] == "1478415556")
        #expect(response.metadata?["actual_prompt"] == "Expanded crane camera move.")
        #expect(response.actualDimensions == "1920x1080")
        #expect(response.actualDuration == 5)
        #expect(response.size == 1234)
        #expect(abs((response.cost ?? 0) - 0.5) < 0.0001)

        let missingURL = try adapter.transformResponse(
            request: videoRequest(),
            response: .dictionary(statusCode: 200, data: ["video": [:]])
        )
        #expect(missingURL.status == .FAILED)

        let malformedDataURI = try adapter.transformResponse(
            request: videoRequest(),
            response: .dictionary(statusCode: 200, data: ["video": ["url": "data:video/mp4;base64,not-base64"]])
        )
        #expect(malformedDataURI.status == .FAILED)
        #expect(malformedDataURI.errorMessage == "Invalid video data URI")
    }

    @Test("Wan 2.7 Fal model metadata is registered")
    func wan27ModelMetadataIsRegistered() throws {
        let models = FALModels.createModels()

        let t2v = try #require(models.first { $0.modelCode == .FAL_WAN_27_T2V })
        #expect(t2v.modelGenerateBaseURL == "https://fal.run/fal-ai/wan/v2.7/text-to-video")
        #expect(t2v.modelParams.maxPromptLength == 5000)
        #expect(t2v.modelParams.supportedDimensions == ["16:9", "9:16", "1:1", "4:3", "3:4"])
        #expect(t2v.modelParams.supportedVideoDurations == [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
        #expect(t2v.modelParams.supportedVideoResolutions == ["720p", "1080p"])
        #expect(t2v.modelParams.supportsNegativePrompt)
        #expect(t2v.modelParams.supportsPromptEnhance)
        #expect(t2v.modelParams.supportsSeed)

        let i2v = try #require(models.first { $0.modelCode == .FAL_WAN_27_I2V })
        #expect(i2v.modelGenerateBaseURL == "https://fal.run/fal-ai/wan/v2.7/image-to-video")
        #expect(i2v.modelParams.supportsSourceImage)
        #expect(i2v.modelParams.supportsLastFrame)
        #expect(i2v.modelParams.supportedVideoResolutions == ["720p", "1080p"])
    }

    @Test("Veo 3.1 Lite T2V posts documented payload and audio-aware estimate")
    func veo31LiteT2VPostsDocumentedPayload() async throws {
        let mock = FalMockNetworkProvider()
        let adapter = try await withFalDependencies(mock) {
            let adapter = G_FAL_VEO_31_LITE()
            _ = try await adapter.makeRequest(request: videoRequest(
                negativePrompt: "low quality",
                dimensions: "9:16",
                durationSeconds: 8,
                resolution: "1080p",
                generateAudio: false,
                seed: 123,
                safetyTolerance: 5
            ))
            return adapter
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/fal-ai/veo3.1/lite")
        #expect(mock.capturedHeaders?["Authorization"] == "Key fal-test")
        #expect(json["prompt"] as? String == "A crane camera move over a neon city.")
        #expect(json["aspect_ratio"] as? String == "9:16")
        #expect(json["duration"] as? String == "8s")
        #expect(json["resolution"] as? String == "1080p")
        #expect(json["generate_audio"] as? Bool == false)
        #expect(json["negative_prompt"] as? String == "low quality")
        #expect(json["seed"] as? Int == 123)
        #expect(json["auto_fix"] as? Bool == true)
        #expect(json["safety_tolerance"] as? String == "5")
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 4,
            resolution: "720p",
            generateAudio: true
        )) - 0.20) < 0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 4,
            resolution: "720p",
            generateAudio: false
        )) - 0.12) < 0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 8,
            resolution: "1080p",
            generateAudio: false
        )) - 0.40) < 0.0001)
    }

    @Test("Veo 3.1 Lite I2V posts source image payload")
    func veo31LiteI2VPostsImagePayload() async throws {
        let mock = FalMockNetworkProvider()
        try await withFalDependencies(mock) {
            let adapter = G_FAL_VEO_31_LITE_I2V()
            _ = try await adapter.makeRequest(request: videoRequest(
                dimensions: "auto",
                clientImage: "source-image",
                durationSeconds: 6,
                resolution: "720p",
                generateAudio: true,
                seed: 77,
                safetyTolerance: 4
            ))
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/fal-ai/veo3.1/lite/image-to-video")
        #expect(json["image_url"] as? String == "data:image/png;base64,source-image")
        #expect(json["aspect_ratio"] as? String == "auto")
        #expect(json["duration"] as? String == "6s")
        #expect(json["resolution"] as? String == "720p")
        #expect(json["generate_audio"] as? Bool == true)
        #expect(json["auto_fix"] as? Bool == false)
        #expect(json["safety_tolerance"] as? String == "4")
    }

    @Test("Veo 3.1 Lite first-last-frame posts first and last frames")
    func veo31LiteFirstLastFramePostsKeyframes() async throws {
        let mock = FalMockNetworkProvider()
        try await withFalDependencies(mock) {
            let adapter = G_FAL_VEO_31_LITE_FIRST_LAST_FRAME()
            _ = try await adapter.makeRequest(request: videoRequest(
                negativePrompt: "flicker",
                dimensions: "auto",
                clientImage: "first-frame",
                clientLastFrame: "last-frame",
                durationSeconds: 4,
                resolution: "1080p",
                generateAudio: false,
                seed: 88,
                safetyTolerance: 6
            ))
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/fal-ai/veo3.1/lite/first-last-frame-to-video")
        #expect(json["first_frame_url"] as? String == "data:image/png;base64,first-frame")
        #expect(json["last_frame_url"] as? String == "data:image/png;base64,last-frame")
        #expect(json["aspect_ratio"] as? String == "auto")
        #expect(json["duration"] as? String == "8s")
        #expect(json["resolution"] as? String == "1080p")
        #expect(json["generate_audio"] as? Bool == false)
        #expect(json["negative_prompt"] as? String == "flicker")
        #expect(json["seed"] as? Int == 88)
        #expect(json["safety_tolerance"] as? String == "6")
    }

    @Test("Veo 3.1 Extend posts source video and audio-aware estimates")
    func veo31ExtendPostsVideoPayload() async throws {
        let mock = FalMockNetworkProvider()
        let adapter = try await withFalDependencies(mock) {
            let adapter = G_FAL_VEO_31_EXTEND()
            _ = try await adapter.makeRequest(request: videoRequest(
                negativePrompt: "scene cut",
                dimensions: "16:9",
                clientVideo: "source-video",
                durationSeconds: 7,
                resolution: "1080p",
                generateAudio: false,
                seed: 99,
                safetyTolerance: 3
            ))
            return adapter
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/fal-ai/veo3.1/extend-video")
        #expect(json["video_url"] as? String == "data:video/mp4;base64,source-video")
        #expect(json["aspect_ratio"] as? String == "16:9")
        #expect(json["duration"] as? String == "7s")
        #expect(json["resolution"] as? String == "720p")
        #expect(json["generate_audio"] as? Bool == false)
        #expect(json["negative_prompt"] as? String == "scene cut")
        #expect(json["seed"] as? Int == 99)
        #expect(json["auto_fix"] as? Bool == false)
        #expect(json["safety_tolerance"] as? String == "3")
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 7,
            resolution: "720p",
            generateAudio: false
        )) - 1.40) < 0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 7,
            resolution: "720p",
            generateAudio: true
        )) - 2.80) < 0.0001)
    }

    @Test("Veo 3.1 Fast Extend posts source video and validates input")
    func veo31FastExtendPostsVideoPayloadAndValidatesInput() async throws {
        let mock = FalMockNetworkProvider()
        let adapter = try await withFalDependencies(mock) {
            let adapter = G_FAL_VEO_31_FAST_EXTEND()
            _ = try await adapter.makeRequest(request: videoRequest(
                dimensions: "auto",
                clientVideo: "data:video/webm;base64,existing-data-uri",
                durationSeconds: 7,
                generateAudio: true
            ))
            return adapter
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/fal-ai/veo3.1/fast/extend-video")
        #expect(json["video_url"] as? String == "data:video/webm;base64,existing-data-uri")
        #expect(json["aspect_ratio"] as? String == "auto")
        #expect(json["duration"] as? String == "7s")
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 7,
            resolution: "720p",
            generateAudio: true
        )) - 1.05) < 0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 7,
            resolution: "720p",
            generateAudio: false
        )) - 0.70) < 0.0001)

        let missingInputMock = FalMockNetworkProvider()
        let missingInputResponse = try await withFalDependencies(missingInputMock) {
            try await adapter.makeRequest(request: videoRequest(clientVideo: nil))
        }
        #expect(missingInputResponse.status == .FAILED)
        #expect(missingInputResponse.errorMessage == "This model requires an input video")
        #expect(missingInputMock.capturedURL == nil)
    }

    @Test("Veo 3.1 Lite parses video URL and rejects malformed responses")
    func veo31LiteParsesVideoURLAndRejectsMalformedResponses() async throws {
        let mock = FalMockNetworkProvider(response: .dictionary(
            statusCode: 200,
            data: ["video": ["url": "data:video/mp4;base64,dmlkZW8="]]
        ))

        let (adapter, response) = try await withFalDependencies(mock) {
            let adapter = G_FAL_VEO_31_LITE()
            let response = try await adapter.makeRequest(request: videoRequest(
                durationSeconds: 4,
                resolution: "720p",
                generateAudio: true
            ))
            return (adapter, response)
        }

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "dmlkZW8=")
        #expect(abs((response.cost ?? 0) - 0.20) < 0.0001)

        let missingURL = try adapter.transformResponse(
            request: videoRequest(),
            response: .dictionary(statusCode: 200, data: ["video": [:]])
        )
        #expect(missingURL.status == .FAILED)

        let malformedDataURI = try adapter.transformResponse(
            request: videoRequest(),
            response: .dictionary(statusCode: 200, data: ["video": ["url": "data:video/mp4;base64,not-base64"]])
        )
        #expect(malformedDataURI.status == .FAILED)
        #expect(malformedDataURI.errorMessage == "Invalid video data URI")
    }

    @Test("Veo 3.1 Lite and Extend Fal model metadata is registered")
    func veo31LiteAndExtendModelMetadataIsRegistered() throws {
        let models = FALModels.createModels()

        let lite = try #require(models.first { $0.modelCode == .FAL_VEO_31_LITE })
        #expect(lite.modelGenerateBaseURL == "https://fal.run/fal-ai/veo3.1/lite")
        #expect(lite.modelParams.supportedVideoDurations == [4, 6, 8])
        #expect(lite.modelParams.supportedVideoResolutions == ["720p", "1080p"])
        #expect(lite.modelParams.supportedSafetyRange == IntRange(1, 6))
        #expect(lite.modelParams.supportsAudio)
        #expect(lite.modelParams.supportsNegativePrompt)
        #expect(lite.modelParams.supportsSeed)

        let i2v = try #require(models.first { $0.modelCode == .FAL_VEO_31_LITE_I2V })
        #expect(i2v.modelGenerateBaseURL == "https://fal.run/fal-ai/veo3.1/lite/image-to-video")
        #expect(i2v.modelParams.supportsSourceImage)
        #expect(i2v.modelParams.supportedDimensions == ["auto", "16:9", "9:16"])

        let firstLastFrame = try #require(models.first { $0.modelCode == .FAL_VEO_31_LITE_FIRST_LAST_FRAME })
        #expect(firstLastFrame.modelGenerateBaseURL == "https://fal.run/fal-ai/veo3.1/lite/first-last-frame-to-video")
        #expect(firstLastFrame.modelParams.supportedVideoDurations == [8])
        #expect(firstLastFrame.modelParams.supportsLastFrame)
        #expect(firstLastFrame.modelParams.supportsSourceImage)

        let extend = try #require(models.first { $0.modelCode == .FAL_VEO_31_EXTEND })
        #expect(extend.modelSetType == .VIDEO_EXTEND)
        #expect(extend.modelGenerateBaseURL == "https://fal.run/fal-ai/veo3.1/extend-video")
        #expect(extend.modelParams.supportedVideoDurations == [7])
        #expect(extend.modelParams.supportedVideoResolutions == ["720p"])
        #expect(extend.modelParams.supportsVideoUpload)

        let fastExtend = try #require(models.first { $0.modelCode == .FAL_VEO_31_FAST_EXTEND })
        #expect(fastExtend.modelSetType == .VIDEO_EXTEND)
        #expect(fastExtend.modelGenerateBaseURL == "https://fal.run/fal-ai/veo3.1/fast/extend-video")
        #expect(fastExtend.modelParams.supportsVideoUpload)
    }

    @Test("Gemini Omni Flash I2V posts documented payload and clamps duration")
    func geminiOmniFlashI2VPostsDocumentedPayload() async throws {
        let mock = FalMockNetworkProvider()
        let adapter = try await withFalDependencies(mock) {
            let adapter = G_FAL_GOOGLE_GEMINI_OMNI_FLASH_I2V()
            _ = try await adapter.makeRequest(request: videoRequest(
                dimensions: "9:16",
                clientImage: "source-image",
                durationSeconds: 12,
                resolution: "1080p",
                generateAudio: true,
                seed: 123
            ))
            return adapter
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/google/gemini-omni-flash/image-to-video")
        #expect(mock.capturedHeaders?["Authorization"] == "Key fal-test")
        #expect(json["prompt"] as? String == "A crane camera move over a neon city.")
        #expect(json["image_url"] as? String == "data:image/png;base64,source-image")
        #expect(json["aspect_ratio"] as? String == "9:16")
        #expect(json["duration"] as? Int == 10)
        #expect(json["resolution"] == nil)
        #expect(json["generate_audio"] == nil)
        #expect(json["seed"] == nil)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "720p")) - 1.04) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: VideoGenerationCostRequest(numberOfVideos: 2)) - 2.08) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 12, resolution: "720p")) - 1.3) <
            0.0001)
        #expect(adapter.formatCost(request: costRequest(durationSeconds: 8, resolution: "720p")).hasSuffix("+"))
    }

    @Test("Gemini Omni Flash Ref2V posts image_urls and parses video data URI")
    func geminiOmniFlashRef2VPostsImageURLsAndParsesResponse() async throws {
        let mock = FalMockNetworkProvider(response: .dictionary(
            statusCode: 200,
            data: ["video": ["url": "data:video/mp4;base64,dmlkZW8="]]
        ))

        let response = try await withFalDependencies(mock) {
            let adapter = G_FAL_GOOGLE_GEMINI_OMNI_FLASH_REF2V()
            return try await adapter.makeRequest(request: videoRequest(
                dimensions: "1920x1080",
                clientReferenceImages: [
                    ReferenceImageData(base64Image: "reference-one"),
                    ReferenceImageData(base64Image: "data:image/jpeg;base64,reference-two", mimeType: "image/jpeg"),
                ],
                durationSeconds: nil,
                resolution: "1080p",
                generateAudio: true
            ))
        }

        let json = try capturedJSON(mock)
        let imageURLs = try #require(json["image_urls"] as? [String])
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/google/gemini-omni-flash/reference-to-video")
        #expect(imageURLs == [
            "data:image/png;base64,reference-one",
            "data:image/jpeg;base64,reference-two",
        ])
        #expect(json["aspect_ratio"] as? String == "16:9")
        #expect(json["duration"] as? Int == 8)
        #expect(json["resolution"] == nil)
        #expect(json["generate_audio"] == nil)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "dmlkZW8=")
        #expect(abs((response.cost ?? 0) - 1.04) < 0.0001)
    }

    @Test("Gemini Omni Flash video endpoints validate required image inputs")
    func geminiOmniFlashVideoEndpointsValidateRequiredInputs() async throws {
        let mock = FalMockNetworkProvider()
        try await withFalDependencies(mock) {
            let i2vResponse = try await G_FAL_GOOGLE_GEMINI_OMNI_FLASH_I2V().makeRequest(request: videoRequest(
                clientImage: nil
            ))
            #expect(i2vResponse.status == .FAILED)
            #expect(i2vResponse.errorMessage == "This model requires an input image")

            let ref2vResponse = try await G_FAL_GOOGLE_GEMINI_OMNI_FLASH_REF2V().makeRequest(request: videoRequest(
                clientReferenceImages: []
            ))
            #expect(ref2vResponse.status == .FAILED)
            #expect(ref2vResponse.errorMessage == "This model requires reference images")
        }
        #expect(mock.capturedURL == nil)
    }

    @Test("Gemini Omni Flash Fal model metadata is registered")
    func geminiOmniFlashModelMetadataIsRegistered() throws {
        let models = FALModels.createModels()

        let i2v = try #require(models.first { $0.modelCode == .FAL_GOOGLE_GEMINI_OMNI_FLASH_I2V })
        #expect(i2v.modelGenerateBaseURL == "https://fal.run/google/gemini-omni-flash/image-to-video")
        #expect(i2v.modelParams.supportsSourceImage)
        #expect(i2v.modelParams.supportedDimensions == ["16:9", "9:16"])
        #expect(i2v.modelParams.supportedVideoDurations == [3, 4, 5, 6, 7, 8, 9, 10])
        #expect(i2v.modelParams.supportedVideoResolutions.isEmpty)
        #expect(i2v.modelParams.supportsAudio == false)

        let ref2v = try #require(models.first { $0.modelCode == .FAL_GOOGLE_GEMINI_OMNI_FLASH_REF2V })
        #expect(ref2v.modelGenerateBaseURL == "https://fal.run/google/gemini-omni-flash/reference-to-video")
        #expect(ref2v.modelParams.maxReferenceImages == 10)
        #expect(ref2v.modelParams.supportsReferenceImages)
        #expect(ref2v.modelParams.supportedVideoResolutions.isEmpty)
        #expect(ref2v.modelParams.supportsAudio == false)
    }

    private func configureFal(_ mock: FalMockNetworkProvider) {
        ProviderDependencies.shared.configure(
            networkProvider: mock,
            modelProvider: FalTestModelProvider()
        )
    }

    private func withFalDependencies<Result>(
        _ mock: FalMockNetworkProvider,
        operation: () async throws -> Result
    ) async rethrows -> Result {
        try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: FalTestModelProvider(),
            operation: operation
        )
    }

    private func capturedJSON(_ mock: FalMockNetworkProvider) throws -> [String: Any] {
        let data = try #require(mock.capturedBodyData)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func videoRequest(
        prompt: String = "A crane camera move over a neon city.",
        negativePrompt: String? = nil,
        dimensions: String = "16:9",
        clientImage: String? = nil,
        clientLastFrame: String? = nil,
        clientVideo: String? = nil,
        clientReferenceImages: [ReferenceImageData]? = nil,
        durationSeconds: Int? = 5,
        resolution: String? = nil,
        generateAudio: Bool? = nil,
        seed: Int? = nil,
        safetyTolerance: Int? = nil,
        promptEnhance: Bool? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: UUID().uuidString,
            prompt: prompt,
            negativePrompt: negativePrompt,
            dimensions: dimensions,
            clientImage: clientImage,
            clientLastFrame: clientLastFrame,
            clientVideo: clientVideo,
            clientReferenceImages: clientReferenceImages,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.FAL_AI.providerId,
                providerCode: .FAL_AI,
                projectId: UUID()
            ),
            providerSecret: "fal-test",
            durationSeconds: durationSeconds,
            resolution: resolution,
            generateAudio: generateAudio,
            seed: seed,
            safetyTolerance: safetyTolerance,
            promptEnhance: promptEnhance
        )
    }

    private func costRequest(
        durationSeconds: Int,
        resolution: String,
        generateAudio: Bool? = nil
    ) -> VideoGenerationCostRequest {
        VideoGenerationCostRequest(
            durationSeconds: durationSeconds,
            resolution: resolution,
            generateAudio: generateAudio
        )
    }
}

private final class FalMockNetworkProvider: @unchecked Sendable, NetworkProvider {
    var capturedURL: URL?
    var capturedMethod: String?
    var capturedBodyData: Data?
    var capturedHeaders: [String: String]?
    let response: NetworkResponseData

    init(response: NetworkResponseData = .dictionary(statusCode: 400, data: ["detail": "stubbed fal response"])) {
        self.response = response
    }

    func performRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        capturedURL = url
        capturedMethod = method
        capturedHeaders = headers
        if let body {
            capturedBodyData = try JSONEncoder().encode(body)
        }
        return response
    }
}

private struct FalTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        FALModels.createModels().first { $0.modelCode == code }
    }
}
