import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Luma Agents video adapters", .serialized)
struct LumaAgentsVideoTests {
    @Test("Ray 3.2 text request posts Agents video payload")
    func ray32TextRequestPostsVideoPayload() {
        let adapter = G_LUMA_RAY_3_2()

        let serviceRequest = adapter.transformRequest(request: videoRequest(
            dimensions: "3840x2160",
            durationSeconds: 10,
            resolution: "360p"
        ))

        #expect(serviceRequest.model == "ray-3.2")
        #expect(serviceRequest.type == "video")
        #expect(serviceRequest.prompt == "A cinematic aircraft hangar reveal.")
        #expect(serviceRequest.aspect_ratio == "16:9")
        #expect(serviceRequest.video.resolution == "360p")
        #expect(serviceRequest.video.duration == "10s")
        #expect(serviceRequest.video.start_frame?.data == nil)
        #expect(serviceRequest.video.end_frame?.data == nil)
        #expect(serviceRequest.video.hdr == nil)
        #expect(serviceRequest.video.exr_export == nil)
        #expect(serviceRequest.video.loop == nil)
    }

    @Test("Ray 3.2 source and last frame request posts inline image refs and 5 second duration")
    func ray32SourceAndLastFrameRequestPostsImageRefs() {
        let adapter = G_LUMA_RAY_3_2()

        let serviceRequest = adapter.transformRequest(request: videoRequest(
            dimensions: "4000x3000",
            durationSeconds: 10,
            resolution: "1080p",
            clientImage: "data:image/jpeg;base64,c3RhcnQ=",
            clientLastFrame: "ZW5k"
        ))

        #expect(serviceRequest.aspect_ratio == "4:3")
        #expect(serviceRequest.video.resolution == "1080p")
        #expect(serviceRequest.video.duration == "5s")
        #expect(serviceRequest.video.start_frame?.data == "c3RhcnQ=")
        #expect(serviceRequest.video.start_frame?.media_type == "image/jpeg")
        #expect(serviceRequest.video.end_frame?.data == "ZW5k")
        #expect(serviceRequest.video.end_frame?.media_type == "image/png")
    }

    @Test("Ray 3.2 validates unsupported dimensions, durations, and resolutions")
    func ray32RequestDefaultsUnsupportedValues() {
        let adapter = G_LUMA_RAY_3_2()

        let serviceRequest = adapter.transformRequest(request: videoRequest(
            dimensions: "not-a-size",
            durationSeconds: 7,
            resolution: "4K"
        ))

        #expect(serviceRequest.aspect_ratio == "16:9")
        #expect(serviceRequest.video.resolution == "720p")
        #expect(serviceRequest.video.duration == "5s")

        let squareRequest = adapter.transformRequest(request: videoRequest(
            dimensions: "1024x1024",
            durationSeconds: 5,
            resolution: "540p"
        ))

        #expect(squareRequest.aspect_ratio == "1:1")
        #expect(squareRequest.video.resolution == "540p")
        #expect(squareRequest.video.duration == "5s")
    }

    @Test("Ray 3.2 response parses output URL and failed state")
    func ray32ResponseParsing() throws {
        let adapter = G_LUMA_RAY_3_2()

        let generated = try adapter.transformResponse(
            request: videoRequest(durationSeconds: 10, resolution: "1080p"),
            response: .dictionary(statusCode: 200, data: [
                "id": "gen_123",
                "state": "completed",
                "output": [
                    ["type": "video", "url": "https://example.com/video.mp4"],
                    ["type": "exr", "url": "https://example.com/video.exr"],
                ],
            ])
        )

        #expect(generated.status == .GENERATED)
        #expect(generated.videoUrl == "https://example.com/video.mp4")
        #expect(generated.rawResponse == "https://example.com/video.mp4")
        #expect(generated.metadata?["lumaGenerationId"] == "gen_123")
        #expect(generated.metadata?["lumaExrUrl"] == "https://example.com/video.exr")
        #expect(generated.actualDuration == 10)
        #expect(abs((generated.cost ?? 0) - 3.60) < 0.0001)

        let failed = try adapter.transformResponse(
            request: videoRequest(),
            response: .dictionary(statusCode: 200, data: [
                "id": "gen_124",
                "state": "failed",
                "failure_reason": "Prompt rejected",
            ])
        )

        #expect(failed.status == .FAILED)
        #expect(failed.errorMessage == "Prompt rejected")
    }

    @Test("Ray 3.2 image anchored response cost uses posted 5 second duration")
    func ray32ImageAnchoredResponseCostUsesPostedDuration() throws {
        let adapter = G_LUMA_RAY_3_2()

        let response = try adapter.transformResponse(
            request: videoRequest(
                durationSeconds: 10,
                resolution: "1080p",
                clientImage: "c3RhcnQ="
            ),
            response: .dictionary(statusCode: 200, data: [
                "id": "gen_125",
                "state": "completed",
                "output": [
                    ["type": "video", "url": "https://example.com/video.mp4"],
                ],
            ])
        )

        #expect(response.status == .GENERATED)
        #expect(response.actualDuration == 5)
        #expect(abs((response.cost ?? 0) - 1.20) < 0.0001)
    }

    @Test("Ray 3.2 pricing follows official SDR grid")
    func ray32PricingFollowsSDRGrid() {
        let adapter = G_LUMA_RAY_3_2()

        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "360p")) - 0.06) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 10, resolution: "360p")) - 0.18) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 10, resolution: "540p")) - 0.45) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "720p")) - 0.30) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 10, resolution: "1080p")) - 3.60) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 5,
            resolution: "720p",
            numberOfVideos: 2
        )) - 0.60) < 0.0001)
    }

    @Test("Ray 3.2 output controls post HDR EXR and loop payload fields")
    func ray32OutputControlsPostPayloadFields() {
        let adapter = G_LUMA_RAY_3_2()

        let hdrRequest = adapter.transformRequest(request: videoRequest(
            resolution: "720p",
            lumaHDR: true,
            lumaEXRExport: true
        ))

        #expect(hdrRequest.video.hdr == true)
        #expect(hdrRequest.video.exr_export == true)
        #expect(hdrRequest.video.loop == nil)

        let loopRequest = adapter.transformRequest(request: videoRequest(lumaLoop: true))

        #expect(loopRequest.video.hdr == nil)
        #expect(loopRequest.video.exr_export == nil)
        #expect(loopRequest.video.loop == true)
    }

    @Test("Ray 3.2 HDR and EXR pricing follows official generation grid")
    func ray32HDRAndEXRPricingFollowsGenerationGrid() {
        let adapter = G_LUMA_RAY_3_2()

        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 5,
            resolution: "720p",
            lumaHDR: true
        )) - 0.60) < 0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 5,
            resolution: "1080p",
            lumaHDR: true
        )) - 2.40) < 0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 5,
            resolution: "720p",
            lumaHDR: true,
            lumaEXRExport: true
        )) - 0.90) < 0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 5,
            resolution: "1080p",
            lumaHDR: true,
            lumaEXRExport: true
        )) - 3.60) < 0.0001)
    }

    @Test("Ray 3.2 output validation rejects invalid HDR EXR and loop combinations")
    func ray32OutputValidationRejectsInvalidCombinations() async throws {
        let mock = LumaAgentsVideoMockNetworkProvider(response: .dictionary(statusCode: 200, data: [:]))
        try await withProviderDependencies(networkProvider: mock, modelProvider: LumaAgentsVideoTestModelProvider()) {
            let adapter = G_LUMA_RAY_3_2()

            let exrWithoutHDR = try await adapter.makeRequest(request: videoRequest(lumaEXRExport: true))
            #expect(exrWithoutHDR.status == .FAILED)
            #expect(exrWithoutHDR.errorMessage == "Luma EXR export requires HDR output.")

            let hdrLowResolution = try await adapter.makeRequest(request: videoRequest(
                resolution: "540p",
                lumaHDR: true
            ))
            #expect(hdrLowResolution.status == .FAILED)
            #expect(hdrLowResolution.errorMessage == "Luma HDR output requires 720p or 1080p.")

            let hdrLongDuration = try await adapter.makeRequest(request: videoRequest(
                durationSeconds: 10,
                lumaHDR: true
            ))
            #expect(hdrLongDuration.status == .FAILED)
            #expect(hdrLongDuration.errorMessage == "Luma HDR output is only supported for 5s generation.")

            let loopLongDuration = try await adapter.makeRequest(request: videoRequest(
                durationSeconds: 10,
                lumaLoop: true
            ))
            #expect(loopLongDuration.status == .FAILED)
            #expect(loopLongDuration.errorMessage == "Luma loop output is only supported for 5s generation.")

            let loopEndFrame = try await adapter.makeRequest(request: videoRequest(
                clientLastFrame: "ZW5k",
                lumaLoop: true
            ))
            #expect(loopEndFrame.status == .FAILED)
            #expect(loopEndFrame.errorMessage == "Luma loop output cannot be combined with an end frame.")

            let loopHDR = try await adapter.makeRequest(request: videoRequest(
                lumaHDR: true,
                lumaLoop: true
            ))
            #expect(loopHDR.status == .FAILED)
            #expect(loopHDR.errorMessage == "Luma loop output cannot be combined with HDR.")
        }
        #expect(mock.requestCount == 0)
    }

    @Test("Ray 3.2 multi-keyframe request posts keyframes and frame indexes")
    func ray32KeyframesRequestPostsKeyframesAndIndexes() {
        let adapter = G_LUMA_RAY_3_2_KEYFRAMES()

        let serviceRequest = adapter.transformRequest(request: videoRequest(
            dimensions: "1024x1024",
            durationSeconds: 10,
            resolution: "1080p",
            clientReferenceImages: [
                ReferenceImageData(
                    base64Image: "data:image/jpeg;base64,bWlk",
                    referenceType: "keyframe",
                    frameIndex: 120
                ),
                ReferenceImageData(
                    base64Image: "c3RhcnQ=",
                    referenceType: "keyframe",
                    frameIndex: 0
                ),
            ]
        ))

        #expect(serviceRequest.model == "ray-3.2")
        #expect(serviceRequest.type == "video")
        #expect(serviceRequest.aspect_ratio == "1:1")
        #expect(serviceRequest.video.resolution == "1080p")
        #expect(serviceRequest.video.duration == "10s")
        #expect(serviceRequest.video.start_frame == nil)
        #expect(serviceRequest.video.end_frame == nil)
        #expect(serviceRequest.video.keyframe_indexes == [0, 120])
        #expect(serviceRequest.video.keyframes?.count == 2)
        #expect(serviceRequest.video.keyframes?.first?.data == "c3RhcnQ=")
        #expect(serviceRequest.video.keyframes?.first?.media_type == "image/png")
        #expect(serviceRequest.video.keyframes?.last?.data == "bWlk")
        #expect(serviceRequest.video.keyframes?.last?.media_type == "image/jpeg")
        #expect(serviceRequest.video.hdr == nil)
        #expect(serviceRequest.video.exr_export == nil)
        #expect(serviceRequest.video.loop == nil)
    }

    @Test("Ray 3.2 multi-keyframe request posts HDR and EXR without loop")
    func ray32KeyframesRequestPostsHDRAndEXRWithoutLoop() {
        let adapter = G_LUMA_RAY_3_2_KEYFRAMES()

        let serviceRequest = adapter.transformRequest(request: videoRequest(
            durationSeconds: 5,
            resolution: "1080p",
            clientReferenceImages: [
                ReferenceImageData(base64Image: "c3RhcnQ=", frameIndex: 0),
            ],
            lumaHDR: true,
            lumaEXRExport: true,
            lumaLoop: true
        ))

        #expect(serviceRequest.video.hdr == true)
        #expect(serviceRequest.video.exr_export == true)
        #expect(serviceRequest.video.loop == nil)
    }

    @Test("Ray 3.2 multi-keyframe response cost can use 10 second generation pricing")
    func ray32KeyframesResponseCostUsesRequestedDuration() throws {
        let adapter = G_LUMA_RAY_3_2_KEYFRAMES()

        let response = try adapter.transformResponse(
            request: videoRequest(
                durationSeconds: 10,
                resolution: "720p",
                clientReferenceImages: [
                    ReferenceImageData(base64Image: "c3RhcnQ=", frameIndex: 0),
                    ReferenceImageData(base64Image: "ZW5k", frameIndex: 240),
                ]
            ),
            response: .dictionary(statusCode: 200, data: [
                "id": "gen_keyframes",
                "state": "completed",
                "output": [
                    ["type": "video", "url": "https://example.com/keyframes.mp4"],
                ],
            ])
        )

        #expect(response.status == .GENERATED)
        #expect(response.metadata?["lumaGenerationId"] == "gen_keyframes")
        #expect(response.actualDuration == 10)
        #expect(abs((response.cost ?? 0) - 0.90) < 0.0001)
    }

    @Test("Ray 3.2 multi-keyframe validates missing and invalid timeline data")
    func ray32KeyframesValidateTimelineBeforeNetworkRequest() async throws {
        let mock = LumaAgentsVideoMockNetworkProvider(response: .dictionary(statusCode: 200, data: [:]))
        try await withProviderDependencies(networkProvider: mock, modelProvider: LumaAgentsVideoTestModelProvider()) {
            let adapter = G_LUMA_RAY_3_2_KEYFRAMES()

            let missing = try await adapter.makeRequest(request: videoRequest(clientReferenceImages: []))
            #expect(missing.status == .FAILED)
            #expect(missing.errorMessage == "Luma multi-keyframe generation requires at least one keyframe image.")

            let duplicate = try await adapter.makeRequest(request: videoRequest(clientReferenceImages: [
                ReferenceImageData(base64Image: "aW1hZ2Uw", frameIndex: 0),
                ReferenceImageData(base64Image: "aW1hZ2Ux", frameIndex: 0),
            ]))
            #expect(duplicate.status == .FAILED)
            #expect(duplicate.errorMessage == "Luma keyframe frame indexes must be unique.")

            let outOfRange = try await adapter.makeRequest(request: videoRequest(
                durationSeconds: 5,
                clientReferenceImages: [
                    ReferenceImageData(base64Image: "aW1hZ2Uw", frameIndex: 121),
                ]
            ))
            #expect(outOfRange.status == .FAILED)
            #expect(outOfRange.errorMessage == "Luma keyframe frame indexes must be between 0 and 120 for a 5s clip.")

            let mixed = try await adapter.makeRequest(request: videoRequest(
                clientImage: "c3RhcnQ=",
                clientReferenceImages: [ReferenceImageData(base64Image: "aW1hZ2Uw", frameIndex: 0)]
            ))
            #expect(mixed.status == .FAILED)
            #expect(mixed
                .errorMessage == "Luma multi-keyframe generation cannot be combined with start or end frame images.")

            let loop = try await adapter.makeRequest(request: videoRequest(
                clientReferenceImages: [ReferenceImageData(base64Image: "aW1hZ2Uw", frameIndex: 0)],
                lumaLoop: true
            ))
            #expect(loop.status == .FAILED)
            #expect(loop.errorMessage == "Luma loop output is only supported for Ray 3.2 generation.")
        }

        #expect(mock.requestCount == 0)
    }

    @Test("Ray 3.2 extend request posts prior generation ID")
    func ray32ExtendRequestPostsPriorGenerationId() {
        let adapter = G_LUMA_RAY_3_2_EXTEND()

        let serviceRequest = adapter.transformRequest(request: videoRequest(
            dimensions: "1024x1024",
            durationSeconds: 10,
            resolution: "1080p",
            sourceMetadata: ["lumaGenerationId": "gen_source"]
        ))

        #expect(serviceRequest.model == "ray-3.2")
        #expect(serviceRequest.type == "video")
        #expect(serviceRequest.prompt == "A cinematic aircraft hangar reveal.")
        #expect(serviceRequest.aspect_ratio == nil)
        #expect(serviceRequest.video.resolution == "1080p")
        #expect(serviceRequest.video.duration == "5s")
        #expect(serviceRequest.video.start_frame?.generation_id == "gen_source")
        #expect(serviceRequest.video.start_frame?.data == nil)
        #expect(serviceRequest.video.start_frame?.media_type == nil)
        #expect(serviceRequest.video.end_frame == nil)
    }

    @Test("Ray 3.2 extend pricing follows official single-keyframe grid")
    func ray32ExtendPricingFollowsSingleKeyframeGrid() {
        let adapter = G_LUMA_RAY_3_2_EXTEND()

        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 10, resolution: "540p")) - 0.15) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "720p")) - 0.30) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "1080p")) - 1.20) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 5,
            resolution: "1080p",
            numberOfVideos: 2
        )) - 2.40) < 0.0001)
    }

    @Test("Ray 3.2 edit request posts source generation ID and auto controls")
    func ray32EditRequestPostsSourceGenerationIdAndAutoControls() {
        let adapter = G_LUMA_RAY_3_2_EDIT()

        let serviceRequest = adapter.transformRequest(request: videoRequest(
            dimensions: "1024x1024",
            durationSeconds: 10,
            resolution: "1080p",
            sourceMetadata: ["lumaGenerationId": "gen_source"]
        ))

        #expect(serviceRequest.model == "ray-3.2")
        #expect(serviceRequest.type == "video_edit")
        #expect(serviceRequest.prompt == "A cinematic aircraft hangar reveal.")
        #expect(serviceRequest.aspect_ratio == nil)
        #expect(serviceRequest.source?.generation_id == "gen_source")
        #expect(serviceRequest.source?.data == nil)
        #expect(serviceRequest.source?.media_type == nil)
        #expect(serviceRequest.video.resolution == "1080p")
        #expect(serviceRequest.video.duration == "10s")
        #expect(serviceRequest.video.start_frame == nil)
        #expect(serviceRequest.video.end_frame == nil)
        #expect(serviceRequest.video.edit?.auto_controls == true)
        #expect(serviceRequest.video.hdr == nil)
        #expect(serviceRequest.video.exr_export == nil)
        #expect(serviceRequest.video.loop == nil)
    }

    @Test("Ray 3.2 edit request posts HDR and EXR controls")
    func ray32EditRequestPostsHDRAndEXRControls() {
        let adapter = G_LUMA_RAY_3_2_EDIT()

        let serviceRequest = adapter.transformRequest(request: videoRequest(
            durationSeconds: 10,
            resolution: "1080p",
            sourceMetadata: ["lumaGenerationId": "gen_source"],
            lumaHDR: true,
            lumaEXRExport: true,
            lumaLoop: true
        ))

        #expect(serviceRequest.video.hdr == true)
        #expect(serviceRequest.video.exr_export == true)
        #expect(serviceRequest.video.loop == nil)
    }

    @Test("Ray 3.2 edit pricing follows official standard SDR grid")
    func ray32EditPricingFollowsStandardSDRGrid() {
        let adapter = G_LUMA_RAY_3_2_EDIT()

        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "360p")) - 0.54) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 10, resolution: "360p")) - 1.08) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 10, resolution: "540p")) - 1.44) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "720p")) - 1.08) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 10, resolution: "1080p")) - 4.32) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 5,
            resolution: "1080p",
            numberOfVideos: 2
        )) - 4.32) < 0.0001)
    }

    @Test("Ray 3.2 edit HDR and EXR pricing follows official edit grid")
    func ray32EditHDRAndEXRPricingFollowsEditGrid() {
        let adapter = G_LUMA_RAY_3_2_EDIT()

        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 10,
            resolution: "720p",
            lumaHDR: true
        )) - 4.32) < 0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 5,
            resolution: "1080p",
            lumaHDR: true
        )) - 4.32) < 0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 10,
            resolution: "720p",
            lumaHDR: true,
            lumaEXRExport: true
        )) - 6.48) < 0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 10,
            resolution: "1080p",
            lumaHDR: true,
            lumaEXRExport: true
        )) - 12.96) < 0.0001)
    }

    @Test("Ray 3.2 edit rejects unsupported HDR resolution before network request")
    func ray32EditRejectsUnsupportedHDRResolution() async throws {
        let mock = LumaAgentsVideoMockNetworkProvider(response: .dictionary(statusCode: 200, data: [:]))
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: LumaAgentsVideoTestModelProvider()
        ) {
            try await G_LUMA_RAY_3_2_EDIT().makeRequest(request: videoRequest(
                resolution: "540p",
                sourceMetadata: ["lumaGenerationId": "gen_source"],
                lumaHDR: true
            ))
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "Luma HDR output requires 720p or 1080p.")
        #expect(mock.requestCount == 0)
    }

    @Test("Ray 3.2 edit response cost keeps requested duration")
    func ray32EditResponseCostKeepsRequestedDuration() throws {
        let adapter = G_LUMA_RAY_3_2_EDIT()

        let response = try adapter.transformResponse(
            request: videoRequest(
                durationSeconds: 10,
                resolution: "1080p",
                sourceMetadata: ["lumaGenerationId": "gen_source"]
            ),
            response: .dictionary(statusCode: 200, data: [
                "id": "gen_edited",
                "state": "completed",
                "output": [
                    ["type": "video", "url": "https://example.com/edited.mp4"],
                ],
            ])
        )

        #expect(response.status == .GENERATED)
        #expect(response.videoUrl == "https://example.com/edited.mp4")
        #expect(response.metadata?["lumaGenerationId"] == "gen_edited")
        #expect(response.actualDuration == 10)
        #expect(abs((response.cost ?? 0) - 4.32) < 0.0001)
    }

    @Test("Ray 3.2 reframe request posts target aspect ratio and source generation ID")
    func ray32ReframeRequestPostsTargetAspectRatioAndSourceGenerationId() {
        let adapter = G_LUMA_RAY_3_2_REFRAME()

        let serviceRequest = adapter.transformRequest(request: videoRequest(
            dimensions: "21:9",
            durationSeconds: 10,
            resolution: "720p",
            sourceMetadata: ["lumaGenerationId": "gen_source"]
        ))

        #expect(serviceRequest.model == "ray-3.2")
        #expect(serviceRequest.type == "video_reframe")
        #expect(serviceRequest.prompt == "A cinematic aircraft hangar reveal.")
        #expect(serviceRequest.aspect_ratio == "21:9")
        #expect(serviceRequest.source?.generation_id == "gen_source")
        #expect(serviceRequest.source?.data == nil)
        #expect(serviceRequest.source?.media_type == nil)
        #expect(serviceRequest.video.resolution == "720p")
        #expect(serviceRequest.video.duration == nil)
        #expect(serviceRequest.video.start_frame == nil)
        #expect(serviceRequest.video.end_frame == nil)
        #expect(serviceRequest.video.edit == nil)
    }

    @Test("Ray 3.2 reframe pricing follows official per-second grid")
    func ray32ReframePricingFollowsPerSecondGrid() {
        let adapter = G_LUMA_RAY_3_2_REFRAME()

        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "360p")) - 0.15) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 10, resolution: "540p")) - 0.60) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 10, resolution: "720p")) - 1.20) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "1080p")) - 1.80) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 10,
            resolution: "1080p",
            numberOfVideos: 2
        )) - 7.20) < 0.0001)
    }

    @Test("Ray 3.2 reframe response cost uses source duration metadata")
    func ray32ReframeResponseCostUsesSourceDurationMetadata() throws {
        let adapter = G_LUMA_RAY_3_2_REFRAME()

        let response = try adapter.transformResponse(
            request: videoRequest(
                dimensions: "16:9",
                durationSeconds: 5,
                resolution: "720p",
                sourceMetadata: [
                    "lumaGenerationId": "gen_source",
                    "duration_seconds": "12",
                ]
            ),
            response: .dictionary(statusCode: 200, data: [
                "id": "gen_reframed",
                "state": "completed",
                "output": [
                    ["type": "video", "url": "https://example.com/reframed.mp4"],
                ],
            ])
        )

        #expect(response.status == .GENERATED)
        #expect(response.videoUrl == "https://example.com/reframed.mp4")
        #expect(response.metadata?["lumaGenerationId"] == "gen_reframed")
        #expect(response.actualDuration == 12)
        #expect(abs((response.cost ?? 0) - 1.44) < 0.0001)
    }

    @Test("Ray 3.2 extend requires Luma generation metadata")
    func ray32ExtendRequiresLumaGenerationMetadata() async throws {
        let mock = LumaAgentsVideoMockNetworkProvider(response: .dictionary(statusCode: 200, data: [:]))
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: LumaAgentsVideoTestModelProvider()
        ) {
            try await G_LUMA_RAY_3_2_EXTEND().makeRequest(request: videoRequest(sourceMetadata: [:]))
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "No Luma generation ID provided for extension")
        #expect(mock.requestCount == 0)
    }

    @Test("Ray 3.2 edit requires Luma generation metadata")
    func ray32EditRequiresLumaGenerationMetadata() async throws {
        let mock = LumaAgentsVideoMockNetworkProvider(response: .dictionary(statusCode: 200, data: [:]))
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: LumaAgentsVideoTestModelProvider()
        ) {
            try await G_LUMA_RAY_3_2_EDIT().makeRequest(request: videoRequest(sourceMetadata: [:]))
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "No Luma generation ID provided for video edit")
        #expect(mock.requestCount == 0)
    }

    @Test("Ray 3.2 reframe requires Luma generation metadata")
    func ray32ReframeRequiresLumaGenerationMetadata() async throws {
        let mock = LumaAgentsVideoMockNetworkProvider(response: .dictionary(statusCode: 200, data: [:]))
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: LumaAgentsVideoTestModelProvider()
        ) {
            try await G_LUMA_RAY_3_2_REFRAME().makeRequest(request: videoRequest(sourceMetadata: [:]))
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "No Luma generation ID provided for video reframe")
        #expect(mock.requestCount == 0)
    }

    @Test("Ray 3.2 reframe rejects vertical 1080p targets before network request")
    func ray32ReframeRejectsVertical1080pTargets() async throws {
        let mock = LumaAgentsVideoMockNetworkProvider(response: .dictionary(statusCode: 200, data: [:]))
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: LumaAgentsVideoTestModelProvider()
        ) {
            try await G_LUMA_RAY_3_2_REFRAME().makeRequest(request: videoRequest(
                dimensions: "9:16",
                resolution: "1080p",
                sourceMetadata: ["lumaGenerationId": "gen_source"]
            ))
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage ==
            "Luma reframe does not support 1080p for vertical target aspect ratios. Choose 720p or lower.")
        #expect(mock.requestCount == 0)
    }

    @Test("Initial failed response returns immediately without polling")
    func initialFailedResponseReturnsImmediately() async throws {
        let mock = LumaAgentsVideoMockNetworkProvider(response: .dictionary(statusCode: 200, data: [
            "id": "gen_failed",
            "state": "failed",
            "failure_reason": "Prompt rejected",
        ]))

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: LumaAgentsVideoTestModelProvider()
        ) {
            try await G_LUMA_RAY_3_2().makeRequest(request: videoRequest())
        }
        let body = try capturedBody(mock)
        let video = try #require(body["video"] as? [String: Any])

        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "Prompt rejected")
        #expect(mock.requestCount == 1)
        #expect(mock.capturedURL?.absoluteString == "https://agents.lumalabs.ai/v1/generations")
        #expect(mock.capturedMethod == "POST")
        #expect(mock.capturedHeaders?["Authorization"] == "Bearer luma-test")
        #expect(body["model"] as? String == "ray-3.2")
        #expect(body["type"] as? String == "video")
        #expect(video["resolution"] as? String == "720p")
        #expect(video["duration"] as? String == "5s")
    }

    @Test("Model metadata registers Ray 3.2 Agents endpoint and capabilities")
    func ray32MetadataIsRegistered() throws {
        let models = LumaAIModels.createModels()
        let ray = try #require(models.first { $0.modelCode == .LUMA_RAY_3_2 })

        #expect(ray.modelGenerateBaseURL == "https://agents.lumalabs.ai/v1/generations")
        #expect(ray.modelStatusBaseURL == "https://agents.lumalabs.ai/v1/generations")
        #expect(ray.modelParams.maxGenerations == 1)
        #expect(ray.modelParams.maxPromptLength == 6000)
        #expect(ray.modelParams.supportedDimensions == ["9:16", "3:4", "1:1", "4:3", "16:9", "21:9"])
        #expect(ray.modelParams.supportedVideoDurations == [5, 10])
        #expect(ray.modelParams.supportedVideoResolutions == ["360p", "540p", "720p", "1080p"])
        #expect(ray.modelParams.supportsSourceImage)
        #expect(ray.modelParams.supportsLastFrame)

        let keyframes = try #require(models.first { $0.modelCode == .LUMA_RAY_3_2_KEYFRAMES })
        #expect(keyframes.modelSetType == .VIDEO_GENERATE)
        #expect(keyframes.modelName == "Ray 3.2 Keyframes")
        #expect(keyframes.modelGenerateBaseURL == "https://agents.lumalabs.ai/v1/generations")
        #expect(keyframes.modelStatusBaseURL == "https://agents.lumalabs.ai/v1/generations")
        #expect(keyframes.modelParams.supportedDimensions == ["9:16", "3:4", "1:1", "4:3", "16:9", "21:9"])
        #expect(keyframes.modelParams.supportedVideoDurations == [5, 10])
        #expect(keyframes.modelParams.supportedVideoResolutions == ["360p", "540p", "720p", "1080p"])
        #expect(!keyframes.modelParams.supportsSourceImage)
        #expect(!keyframes.modelParams.supportsLastFrame)

        let extend = try #require(models.first { $0.modelCode == .LUMA_RAY_3_2_EXTEND })
        #expect(extend.modelSetType == .VIDEO_EXTEND)
        #expect(extend.modelGenerateBaseURL == "https://agents.lumalabs.ai/v1/generations")
        #expect(extend.modelStatusBaseURL == "https://agents.lumalabs.ai/v1/generations")
        #expect(extend.modelParams.requiredMetadata == ["lumaGenerationId"])
        #expect(extend.modelParams.supportedDimensions == ["9:16", "3:4", "1:1", "4:3", "16:9", "21:9"])
        #expect(extend.modelParams.supportedVideoDurations == [5])
        #expect(extend.modelParams.supportedVideoResolutions == ["540p", "720p", "1080p"])

        let edit = try #require(models.first { $0.modelCode == .LUMA_RAY_3_2_EDIT })
        #expect(edit.modelSetType == .VIDEO_EXTEND)
        #expect(edit.modelGenerateBaseURL == "https://agents.lumalabs.ai/v1/generations")
        #expect(edit.modelStatusBaseURL == "https://agents.lumalabs.ai/v1/generations")
        #expect(edit.modelParams.requiredMetadata == ["lumaGenerationId"])
        #expect(edit.modelParams.supportedDimensions == [])
        #expect(edit.modelParams.supportedVideoDurations == [5, 10])
        #expect(edit.modelParams.supportedVideoResolutions == ["360p", "540p", "720p", "1080p"])

        let reframe = try #require(models.first { $0.modelCode == .LUMA_RAY_3_2_REFRAME })
        #expect(reframe.modelSetType == .VIDEO_EXTEND)
        #expect(reframe.modelGenerateBaseURL == "https://agents.lumalabs.ai/v1/generations")
        #expect(reframe.modelStatusBaseURL == "https://agents.lumalabs.ai/v1/generations")
        #expect(reframe.modelParams.requiredMetadata == ["lumaGenerationId"])
        #expect(reframe.modelParams.supportedDimensions == ["9:16", "3:4", "1:1", "4:3", "16:9", "21:9"])
        #expect(reframe.modelParams.supportedVideoDurations == [])
        #expect(reframe.modelParams.supportedVideoResolutions == ["360p", "540p", "720p", "1080p"])
    }

    private func capturedBody(_ mock: LumaAgentsVideoMockNetworkProvider) throws -> [String: Any] {
        let data = try #require(mock.capturedBodyData)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func videoRequest(
        dimensions: String = "16:9",
        durationSeconds: Int? = 5,
        resolution: String? = "720p",
        clientImage: String? = nil,
        clientLastFrame: String? = nil,
        clientReferenceImages: [ReferenceImageData]? = nil,
        numberOfVideos: Int = 1,
        sourceMetadata: [String: String]? = nil,
        lumaHDR: Bool? = nil,
        lumaEXRExport: Bool? = nil,
        lumaLoop: Bool? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: UUID().uuidString,
            prompt: "A cinematic aircraft hangar reveal.",
            dimensions: dimensions,
            clientImage: clientImage,
            clientLastFrame: clientLastFrame,
            clientReferenceImages: clientReferenceImages,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.LUMA_AI.providerId,
                providerCode: .LUMA_AI,
                projectId: UUID()
            ),
            providerSecret: "luma-test",
            numberOfVideos: numberOfVideos,
            durationSeconds: durationSeconds,
            resolution: resolution,
            sourceMetadata: sourceMetadata,
            lumaHDR: lumaHDR,
            lumaEXRExport: lumaEXRExport,
            lumaLoop: lumaLoop
        )
    }

    private func costRequest(
        durationSeconds: Int? = nil,
        resolution: String? = nil,
        numberOfVideos: Int? = nil,
        lumaHDR: Bool? = nil,
        lumaEXRExport: Bool? = nil,
        lumaLoop: Bool? = nil
    ) -> VideoGenerationCostRequest {
        VideoGenerationCostRequest(
            durationSeconds: durationSeconds,
            numberOfVideos: numberOfVideos,
            resolution: resolution,
            lumaHDR: lumaHDR,
            lumaEXRExport: lumaEXRExport,
            lumaLoop: lumaLoop
        )
    }
}

private final class LumaAgentsVideoMockNetworkProvider: @unchecked Sendable, NetworkProvider {
    private(set) var requestCount = 0
    var capturedURL: URL?
    var capturedMethod: String?
    var capturedBodyData: Data?
    var capturedHeaders: [String: String]?
    let response: NetworkResponseData

    init(response: NetworkResponseData) {
        self.response = response
    }

    func performRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        requestCount += 1
        capturedURL = url
        capturedMethod = method
        capturedHeaders = headers
        if let body {
            capturedBodyData = try JSONEncoder().encode(body)
        }
        return response
    }
}

private struct LumaAgentsVideoTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        LumaAIModels.createModels().first { $0.modelCode == code }
    }
}
