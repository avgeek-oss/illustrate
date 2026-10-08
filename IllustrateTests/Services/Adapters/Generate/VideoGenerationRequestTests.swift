// MARK: - VideoGenerationRequestTests.swift

// Tests for VideoGenerationRequest Codable round-trip and toProviderRequest() mapping,
// and VideoSetResponse Codable.

import IllustrateProviders
import XCTest
@testable import Illustrate

final class VideoGenerationRequestTests: XCTestCase {
    // MARK: - Helpers

    private func makeProviderKeyInfo() -> ProviderKeyInfo {
        ProviderKeyInfo(
            providerId: UUID(),
            providerCode: .STABILITY_AI,
            projectId: UUID()
        )
    }

    private func makeMinimalRequest() -> Illustrate.VideoGenerationRequest {
        Illustrate.VideoGenerationRequest(
            modelId: "test-model",
            prompt: "A cat playing piano",
            dimensions: "1280x720",
            providerKey: makeProviderKeyInfo(),
            providerSecret: "test-secret"
        )
    }

    // MARK: - Codable Round-Trip Minimal

    func testCodableRoundTrip_MinimalFields() throws {
        let request = makeMinimalRequest()
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)

        XCTAssertEqual(decoded.modelId, "test-model")
        XCTAssertEqual(decoded.prompt, "A cat playing piano")
        XCTAssertEqual(decoded.dimensions, "1280x720")
        XCTAssertEqual(decoded.providerSecret, "test-secret")
    }

    // MARK: - Optional Fields Nil By Default

    func testOptionalFields_NilByDefault() {
        let request = makeMinimalRequest()
        XCTAssertNil(request.clientImage)
        XCTAssertNil(request.clientMask)
        XCTAssertNil(request.clientLastFrame)
        XCTAssertNil(request.clientVideo)
        XCTAssertNil(request.clientReferenceImages)
        XCTAssertNil(request.motion)
        XCTAssertNil(request.stickyness)
        XCTAssertNil(request.durationSeconds)
        XCTAssertNil(request.resolution)
        XCTAssertNil(request.fps)
        XCTAssertNil(request.generateAudio)
        XCTAssertNil(request.steps)
        XCTAssertNil(request.guidance)
        XCTAssertNil(request.seed)
        XCTAssertNil(request.safetyTolerance)
        XCTAssertNil(request.promptEnhance)
        XCTAssertNil(request.sourceMetadata)
        XCTAssertNil(request.lumaHDR)
        XCTAssertNil(request.lumaEXRExport)
        XCTAssertNil(request.lumaLoop)
    }

    // MARK: - NumberOfVideos Default

    func testNumberOfVideos_DefaultsToOne() {
        let request = makeMinimalRequest()
        XCTAssertEqual(request.numberOfVideos, 1)
    }

    // MARK: - CodingKeys Excludes progressCallback

    func testCodable_ProgressCallbackNotEncoded() throws {
        var request = makeMinimalRequest()
        request.progressCallback = { (_: Int) in }

        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNil(json["progressCallback"])
    }

    func testCodable_OtherFieldsSurviveDespiteProgressCallback() throws {
        var request = makeMinimalRequest()
        request.progressCallback = { (_: Int) in }
        request.durationSeconds = 10
        request.fps = 24

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)

        XCTAssertEqual(decoded.modelId, "test-model")
        XCTAssertEqual(decoded.durationSeconds, 10)
        XCTAssertEqual(decoded.fps, 24)
    }

    // MARK: - Codable Round-Trip: Video-Specific Fields

    func testCodableRoundTrip_Motion() throws {
        var request = makeMinimalRequest()
        request.motion = 127
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.motion, 127)
    }

    func testCodableRoundTrip_Stickyness() throws {
        var request = makeMinimalRequest()
        request.stickyness = 80
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.stickyness, 80)
    }

    func testCodableRoundTrip_DurationSeconds() throws {
        var request = makeMinimalRequest()
        request.durationSeconds = 10
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.durationSeconds, 10)
    }

    func testCodableRoundTrip_Resolution() throws {
        var request = makeMinimalRequest()
        request.resolution = "1080p"
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.resolution, "1080p")
    }

    func testCodableRoundTrip_FPS() throws {
        var request = makeMinimalRequest()
        request.fps = 30
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.fps, 30)
    }

    func testCodableRoundTrip_GenerateAudio() throws {
        var request = makeMinimalRequest()
        request.generateAudio = true
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.generateAudio, true)
    }

    func testCodableRoundTrip_StepsAndGuidance() throws {
        var request = makeMinimalRequest()
        request.steps = 50
        request.guidance = 7.5
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.steps, 50)
        XCTAssertEqual(decoded.guidance, 7.5)
    }

    func testCodableRoundTrip_SeedAndSafetyTolerance() throws {
        var request = makeMinimalRequest()
        request.seed = 42
        request.safetyTolerance = 3
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.seed, 42)
        XCTAssertEqual(decoded.safetyTolerance, 3)
    }

    func testCodableRoundTrip_PromptEnhance() throws {
        var request = makeMinimalRequest()
        request.promptEnhance = true
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.promptEnhance, true)
    }

    func testCodableRoundTrip_SourceMetadata() throws {
        var request = makeMinimalRequest()
        request.sourceMetadata = ["videoId": "abc-123", "format": "mp4"]
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.sourceMetadata?["videoId"], "abc-123")
        XCTAssertEqual(decoded.sourceMetadata?["format"], "mp4")
    }

    func testCodableRoundTrip_LumaOutputControls() throws {
        var request = makeMinimalRequest()
        request.lumaHDR = true
        request.lumaEXRExport = true
        request.lumaLoop = false

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)

        XCTAssertEqual(decoded.lumaHDR, true)
        XCTAssertEqual(decoded.lumaEXRExport, true)
        XCTAssertEqual(decoded.lumaLoop, false)
    }

    func testCodableRoundTrip_ClientReferenceImages() throws {
        var request = makeMinimalRequest()
        request.clientReferenceImages = [
            ReferenceImageData(base64Image: "base64data", referenceType: "style"),
        ]
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.clientReferenceImages?.count, 1)
        XCTAssertEqual(decoded.clientReferenceImages?.first?.base64Image, "base64data")
        XCTAssertEqual(decoded.clientReferenceImages?.first?.referenceType, "style")
    }

    // MARK: - Codable Round-Trip: Client Media Fields

    func testCodableRoundTrip_ClientImage() throws {
        var request = makeMinimalRequest()
        request.clientImage = "base64-image-data"
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.clientImage, "base64-image-data")
    }

    func testCodableRoundTrip_ClientMask() throws {
        var request = makeMinimalRequest()
        request.clientMask = "base64-mask-data"
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.clientMask, "base64-mask-data")
    }

    func testCodableRoundTrip_ClientLastFrame() throws {
        var request = makeMinimalRequest()
        request.clientLastFrame = "base64-last-frame"
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.clientLastFrame, "base64-last-frame")
    }

    func testCodableRoundTrip_ClientVideo() throws {
        var request = makeMinimalRequest()
        request.clientVideo = "base64-video-data"
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.clientVideo, "base64-video-data")
    }

    // MARK: - toProviderRequest() Mapping

    func testToProviderRequest_MapsBasicFields() {
        let request = makeMinimalRequest()
        let providerRequest = request.toProviderRequest()

        XCTAssertEqual(providerRequest.modelId, "test-model")
        XCTAssertEqual(providerRequest.prompt, "A cat playing piano")
        XCTAssertEqual(providerRequest.dimensions, "1280x720")
        XCTAssertEqual(providerRequest.providerSecret, "test-secret")
    }

    func testToProviderRequest_MapsNegativePrompt() {
        var request = makeMinimalRequest()
        request.negativePrompt = "blurry"
        let providerRequest = request.toProviderRequest()
        XCTAssertEqual(providerRequest.negativePrompt, "blurry")
    }

    func testToProviderRequest_MapsClientFields() {
        var request = makeMinimalRequest()
        request.clientImage = "img"
        request.clientMask = "mask"
        request.clientLastFrame = "frame"
        request.clientVideo = "video"
        let providerRequest = request.toProviderRequest()

        XCTAssertEqual(providerRequest.clientImage, "img")
        XCTAssertEqual(providerRequest.clientMask, "mask")
        XCTAssertEqual(providerRequest.clientLastFrame, "frame")
        XCTAssertEqual(providerRequest.clientVideo, "video")
    }

    func testToProviderRequest_MapsVideoSpecificFields() {
        var request = makeMinimalRequest()
        request.motion = 100
        request.stickyness = 50
        request.durationSeconds = 10
        request.resolution = "720p"
        request.fps = 24
        let providerRequest = request.toProviderRequest()

        XCTAssertEqual(providerRequest.motion, 100)
        XCTAssertEqual(providerRequest.stickyness, 50)
        XCTAssertEqual(providerRequest.durationSeconds, 10)
        XCTAssertEqual(providerRequest.resolution, "720p")
        XCTAssertEqual(providerRequest.fps, 24)
    }

    func testToProviderRequest_MapsOptionalFields() {
        var request = makeMinimalRequest()
        request.generateAudio = true
        request.steps = 30
        request.guidance = 5.0
        request.seed = 999
        request.safetyTolerance = 2
        request.promptEnhance = false
        let providerRequest = request.toProviderRequest()

        XCTAssertEqual(providerRequest.generateAudio, true)
        XCTAssertEqual(providerRequest.steps, 30)
        XCTAssertEqual(providerRequest.guidance, 5.0)
        XCTAssertEqual(providerRequest.seed, 999)
        XCTAssertEqual(providerRequest.safetyTolerance, 2)
        XCTAssertEqual(providerRequest.promptEnhance, false)
    }

    func testToProviderRequest_MapsLumaOutputControls() {
        var request = makeMinimalRequest()
        request.lumaHDR = true
        request.lumaEXRExport = true
        request.lumaLoop = true

        let providerRequest = request.toProviderRequest()

        XCTAssertEqual(providerRequest.lumaHDR, true)
        XCTAssertEqual(providerRequest.lumaEXRExport, true)
        XCTAssertEqual(providerRequest.lumaLoop, true)
    }

    func testToProviderRequest_MapsSourceMetadata() {
        var request = makeMinimalRequest()
        request.sourceMetadata = ["key1": "val1", "key2": "val2"]
        let providerRequest = request.toProviderRequest()
        XCTAssertEqual(providerRequest.sourceMetadata?["key1"], "val1")
        XCTAssertEqual(providerRequest.sourceMetadata?["key2"], "val2")
    }

    func testToProviderRequest_NilOptionals_MapAsNil() {
        let request = makeMinimalRequest()
        let providerRequest = request.toProviderRequest()

        XCTAssertNil(providerRequest.clientImage)
        XCTAssertNil(providerRequest.clientMask)
        XCTAssertNil(providerRequest.clientLastFrame)
        XCTAssertNil(providerRequest.clientVideo)
        XCTAssertNil(providerRequest.motion)
        XCTAssertNil(providerRequest.stickyness)
        XCTAssertNil(providerRequest.durationSeconds)
        XCTAssertNil(providerRequest.resolution)
        XCTAssertNil(providerRequest.fps)
        XCTAssertNil(providerRequest.generateAudio)
        XCTAssertNil(providerRequest.steps)
        XCTAssertNil(providerRequest.guidance)
        XCTAssertNil(providerRequest.seed)
        XCTAssertNil(providerRequest.safetyTolerance)
        XCTAssertNil(providerRequest.promptEnhance)
        XCTAssertNil(providerRequest.sourceMetadata)
        XCTAssertNil(providerRequest.lumaHDR)
        XCTAssertNil(providerRequest.lumaEXRExport)
        XCTAssertNil(providerRequest.lumaLoop)
    }

    // MARK: - VideoSetResponse Codable

    func testVideoSetResponse_CodableRoundTrip_GeneratedStatus() throws {
        let response = VideoSetResponse(
            status: .GENERATED,
            set: nil,
            generations: nil,
            errorCode: nil,
            errorMessage: nil,
            rawResponse: nil
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(VideoSetResponse.self, from: data)
        XCTAssertEqual(decoded.status, .GENERATED)
        XCTAssertNil(decoded.errorMessage)
    }

    func testVideoSetResponse_CodableRoundTrip_FailedWithError() throws {
        let response = VideoSetResponse(
            status: .FAILED,
            set: nil,
            generations: nil,
            errorCode: .GENERATOR_ERROR,
            errorMessage: "Internal error",
            rawResponse: "{\"error\": \"internal\"}"
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(VideoSetResponse.self, from: data)
        XCTAssertEqual(decoded.status, .FAILED)
        XCTAssertEqual(decoded.errorCode, .GENERATOR_ERROR)
        XCTAssertEqual(decoded.errorMessage, "Internal error")
        XCTAssertEqual(decoded.rawResponse, "{\"error\": \"internal\"}")
    }

    // MARK: - SearchPrompt

    func testCodableRoundTrip_SearchPrompt() throws {
        var request = makeMinimalRequest()
        request.searchPrompt = "replace background"
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.searchPrompt, "replace background")
    }

    // MARK: - NumberOfVideos Custom

    func testCodableRoundTrip_NumberOfVideos() throws {
        var request = makeMinimalRequest()
        request.numberOfVideos = 4
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(Illustrate.VideoGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.numberOfVideos, 4)
    }
}
