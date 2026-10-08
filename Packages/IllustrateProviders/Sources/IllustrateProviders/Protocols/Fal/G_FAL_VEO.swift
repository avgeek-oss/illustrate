// MARK: - G_FAL_VEO.swift

// Google Veo video generation models via Fal.ai
//
// Supported models:
// - Veo 2: Text-to-video and image-to-video (no audio)
// - Veo 3/3.1: Text-to-video and image-to-video with audio
// - Veo 3.1 Reference-to-Video: Subject consistency
// - Veo 3.1 First-Last Frame: Keyframe interpolation
//
// Pricing (per video second):
// - Fast variants: $0.15/sec
// - Standard variants: $0.40/sec
// - Veo 2: $0.50/sec

import Foundation

// MARK: - Request Structs

struct FalVeoTextToVideoRequest: Codable {
    let prompt: String
    let aspect_ratio: String
    let duration: String
    let resolution: String
    let generate_audio: Bool?
    let negative_prompt: String?
    let seed: Int?
    let auto_fix: Bool?
}

struct FalVeoImageToVideoRequest: Codable {
    let prompt: String
    let image_url: String
    let aspect_ratio: String
    let duration: String
    let resolution: String
    let generate_audio: Bool?
    let seed: Int?
    let auto_fix: Bool?
}

struct FalVeoFirstLastFrameRequest: Codable {
    let prompt: String
    let first_frame_url: String
    let last_frame_url: String
    let aspect_ratio: String
    let duration: String
    let resolution: String
    let generate_audio: Bool?
    let negative_prompt: String?
    let seed: Int?
    let auto_fix: Bool?
}

struct FalVeo31LiteTextToVideoRequest: Codable {
    let prompt: String
    let aspect_ratio: String
    let duration: String
    let resolution: String
    let generate_audio: Bool?
    let negative_prompt: String?
    let seed: Int?
    let auto_fix: Bool?
    let safety_tolerance: String?
}

struct FalVeo31LiteImageToVideoRequest: Codable {
    let prompt: String
    let image_url: String
    let aspect_ratio: String
    let duration: String
    let resolution: String
    let generate_audio: Bool?
    let negative_prompt: String?
    let seed: Int?
    let auto_fix: Bool?
    let safety_tolerance: String?
}

struct FalVeo31LiteFirstLastFrameRequest: Codable {
    let prompt: String
    let first_frame_url: String
    let last_frame_url: String
    let aspect_ratio: String
    let duration: String
    let resolution: String
    let generate_audio: Bool?
    let negative_prompt: String?
    let seed: Int?
    let auto_fix: Bool?
    let safety_tolerance: String?
}

struct FalVeo31ExtendVideoRequest: Codable {
    let prompt: String
    let video_url: String
    let aspect_ratio: String
    let duration: String
    let resolution: String
    let generate_audio: Bool?
    let negative_prompt: String?
    let seed: Int?
    let auto_fix: Bool?
    let safety_tolerance: String?
}

struct FalVeoReferenceToVideoRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let aspect_ratio: String
    let duration: String
    let resolution: String
    let generate_audio: Bool?
    let auto_fix: Bool?
}

struct FalVeo2TextToVideoRequest: Codable {
    let prompt: String
    let aspect_ratio: String
    let duration: String
    let negative_prompt: String?
    let seed: Int?
    let enhance_prompt: Bool?
}

struct FalVeo2ImageToVideoRequest: Codable {
    let prompt: String
    let image_url: String
    let aspect_ratio: String
    let duration: String
}

// MARK: - Base Class

public class FalVeoBase: VideoGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var costPerSecond: Double {
        fatalError("Subclass must override")
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    var defaultDuration: Int {
        model.modelParams.supportedVideoDurations.last ?? 8
    }

    /// Required by protocol - placeholder
    public struct ServiceRequest: Codable, Sendable {
        let placeholder: Bool
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        ServiceRequest(placeholder: true)
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let durationSeconds = request.durationSeconds ?? defaultDuration
        let numberOfVideos = request.numberOfVideos ?? 1
        return costPerSecond * Double(durationSeconds) * Double(numberOfVideos)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    /// Converts base64 to data URI for Fal
    func toDataUri(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:image/png;base64,\(base64)"
    }

    /// Converts base64 video to a data URI for Fal video-to-video endpoints.
    func toVideoDataUri(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:video/mp4;base64,\(base64)"
    }

    /// Convert dimensions to aspect ratio for Fal Veo
    func getAspectRatio(_ dimensions: String) -> String {
        if dimensions == "auto" {
            return "auto"
        }
        if dimensions.contains(":") {
            return dimensions
        }
        let parts = dimensions.lowercased().split(separator: "x")
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1])
        else {
            return "16:9"
        }
        return width > height ? "16:9" : "9:16"
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            // Handle video output
            if let video = data["video"] as? [String: Any],
               let urlStr = video["url"] as? String
            {
                return try downloadAndReturnVideo(urlStr: urlStr, request: request)
            }

            // Handle errors
            if let detail = data["detail"] as? String {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: detail
                )
            }
            if let errorObj = data["error"] as? [String: Any],
               let message = errorObj["message"] as? String
            {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: message
                )
            }
        default:
            break
        }
        return createInvalidVideoResponseError(response: response, modelCode: modelCode)
    }

    private func downloadAndReturnVideo(
        urlStr: String,
        request: VideoGenerationRequest
    ) throws -> VideoGenerationResponse {
        if urlStr.hasPrefix("data:video"), let commaIndex = urlStr.firstIndex(of: ",") {
            let encoded = String(urlStr[urlStr.index(after: commaIndex)...])
            guard Data(base64Encoded: encoded) != nil else {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Invalid video data URI"
                )
            }
            return VideoGenerationResponse(
                status: .GENERATED,
                base64: encoded,
                cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
            )
        }

        guard let url = URL(string: urlStr) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid video URL"
            )
        }

        let videoData = try Data(contentsOf: url)
        let base64 = videoData.base64EncodedString()

        return VideoGenerationResponse(
            status: .GENERATED,
            base64: base64,
            cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
        )
    }

    func performVeoRequest(
        request: VideoGenerationRequest,
        body: some Codable & Sendable
    ) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let headers = [
            "Authorization": "Key \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        do {
            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: body,
                headers: headers,
                attachments: nil
            )
            return try transformResponse(request: request, response: response)
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        fatalError("Subclass must override makeRequest")
    }
}

public class FalVeo31LiteBase: FalVeoBase {
    override var costPerSecond: Double {
        0.05
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let durationSeconds = request.durationSeconds ?? defaultDuration
        let numberOfVideos = request.numberOfVideos ?? 1
        return liteCostPerSecond(
            resolution: request.resolution,
            generateAudio: request.generateAudio
        ) * Double(durationSeconds) * Double(numberOfVideos)
    }

    func liteCostPerSecond(resolution: String?, generateAudio: Bool?) -> Double {
        let hasAudio = generateAudio ?? true
        switch resolution?.lowercased() {
        case "1080p":
            return hasAudio ? 0.08 : 0.05
        default:
            return hasAudio ? 0.05 : 0.03
        }
    }

    func safetyTolerance(_ request: VideoGenerationRequest) -> String? {
        request.safetyTolerance.map(String.init)
    }
}

public class FalVeo31ExtendBase: FalVeoBase {
    var audioCostPerSecond: Double {
        fatalError("Subclass must override")
    }

    var silentCostPerSecond: Double {
        fatalError("Subclass must override")
    }

    override var costPerSecond: Double {
        audioCostPerSecond
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let durationSeconds = request.durationSeconds ?? defaultDuration
        let numberOfVideos = request.numberOfVideos ?? 1
        let hasAudio = request.generateAudio ?? true
        let perSecond = hasAudio ? audioCostPerSecond : silentCostPerSecond
        return perSecond * Double(durationSeconds) * Double(numberOfVideos)
    }

    func safetyTolerance(_ request: VideoGenerationRequest) -> String? {
        request.safetyTolerance.map(String.init)
    }

    func makeExtendRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientVideo = request.clientVideo, !clientVideo.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input video"
            )
        }

        let body = FalVeo31ExtendVideoRequest(
            prompt: request.prompt ?? "",
            video_url: toVideoDataUri(clientVideo),
            aspect_ratio: getAspectRatio(request.dimensions),
            duration: "7s",
            resolution: "720p",
            generate_audio: request.generateAudio ?? true,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            auto_fix: false,
            safety_tolerance: safetyTolerance(request)
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

// MARK: - Veo 3 Models

public final class G_FAL_VEO_3_FAST: FalVeoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_3_FAST
    }

    override var costPerSecond: Double {
        0.15
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalVeoTextToVideoRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: getAspectRatio(request.dimensions),
            duration: "\(request.durationSeconds ?? defaultDuration)s",
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            auto_fix: true
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_3: FalVeoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_3
    }

    override var costPerSecond: Double {
        0.40
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalVeoTextToVideoRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: getAspectRatio(request.dimensions),
            duration: "\(request.durationSeconds ?? defaultDuration)s",
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            auto_fix: true
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_3_I2V: FalVeoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_3_I2V
    }

    override var costPerSecond: Double {
        0.40
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalVeoImageToVideoRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            aspect_ratio: "auto",
            duration: "\(request.durationSeconds ?? defaultDuration)s",
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            seed: request.seed,
            auto_fix: false
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_3_FAST_I2V: FalVeoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_3_FAST_I2V
    }

    override var costPerSecond: Double {
        0.15
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalVeoImageToVideoRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            aspect_ratio: "auto",
            duration: "\(request.durationSeconds ?? defaultDuration)s",
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            seed: request.seed,
            auto_fix: false
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

// MARK: - Veo 3.1 Models

public final class G_FAL_VEO_31_FAST: FalVeoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_31_FAST
    }

    override var costPerSecond: Double {
        0.15
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalVeoTextToVideoRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: getAspectRatio(request.dimensions),
            duration: "\(request.durationSeconds ?? defaultDuration)s",
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            auto_fix: true
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_31: FalVeoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_31
    }

    override var costPerSecond: Double {
        0.40
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalVeoTextToVideoRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: getAspectRatio(request.dimensions),
            duration: "\(request.durationSeconds ?? defaultDuration)s",
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            auto_fix: true
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_31_LITE: FalVeo31LiteBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_31_LITE
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalVeo31LiteTextToVideoRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: getAspectRatio(request.dimensions),
            duration: "\(request.durationSeconds ?? defaultDuration)s",
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            auto_fix: true,
            safety_tolerance: safetyTolerance(request)
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_31_I2V: FalVeoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_31_I2V
    }

    override var costPerSecond: Double {
        0.40
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalVeoImageToVideoRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            aspect_ratio: "auto",
            duration: "\(request.durationSeconds ?? defaultDuration)s",
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            seed: request.seed,
            auto_fix: false
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_31_FAST_I2V: FalVeoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_31_FAST_I2V
    }

    override var costPerSecond: Double {
        0.15
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalVeoImageToVideoRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            aspect_ratio: "auto",
            duration: "\(request.durationSeconds ?? defaultDuration)s",
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            seed: request.seed,
            auto_fix: false
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_31_LITE_I2V: FalVeo31LiteBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_31_LITE_I2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalVeo31LiteImageToVideoRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            aspect_ratio: getAspectRatio(request.dimensions),
            duration: "\(request.durationSeconds ?? defaultDuration)s",
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            auto_fix: false,
            safety_tolerance: safetyTolerance(request)
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_31_REF_TO_VIDEO: FalVeoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_31_REF_TO_VIDEO
    }

    override var costPerSecond: Double {
        0.40
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let referenceImages = request.clientReferenceImages, !referenceImages.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires reference images"
            )
        }
        let imageUrls = referenceImages.map { toDataUri($0.base64Image) }
        let body = FalVeoReferenceToVideoRequest(
            prompt: request.prompt ?? "",
            image_urls: imageUrls,
            aspect_ratio: getAspectRatio(request.dimensions),
            duration: "8s", // Fixed duration for reference-to-video
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            auto_fix: false
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_31_FAST_REF_TO_VIDEO: FalVeoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_31_FAST_REF_TO_VIDEO
    }

    override var costPerSecond: Double {
        0.15
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let referenceImages = request.clientReferenceImages, !referenceImages.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires reference images"
            )
        }
        let imageUrls = referenceImages.map { toDataUri($0.base64Image) }
        let body = FalVeoReferenceToVideoRequest(
            prompt: request.prompt ?? "",
            image_urls: imageUrls,
            aspect_ratio: getAspectRatio(request.dimensions),
            duration: "8s",
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            auto_fix: false
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_31_FIRST_LAST_FRAME: FalVeoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_31_FIRST_LAST_FRAME
    }

    override var costPerSecond: Double {
        0.40
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a first frame image"
            )
        }
        guard let clientLastFrame = request.clientLastFrame else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a last frame image"
            )
        }
        let body = FalVeoFirstLastFrameRequest(
            prompt: request.prompt ?? "",
            first_frame_url: toDataUri(clientImage),
            last_frame_url: toDataUri(clientLastFrame),
            aspect_ratio: "auto",
            duration: "\(request.durationSeconds ?? defaultDuration)s",
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            auto_fix: false
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_31_FAST_FIRST_LAST_FRAME: FalVeoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_31_FAST_FIRST_LAST_FRAME
    }

    override var costPerSecond: Double {
        0.15
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a first frame image"
            )
        }
        guard let clientLastFrame = request.clientLastFrame else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a last frame image"
            )
        }
        let body = FalVeoFirstLastFrameRequest(
            prompt: request.prompt ?? "",
            first_frame_url: toDataUri(clientImage),
            last_frame_url: toDataUri(clientLastFrame),
            aspect_ratio: "auto",
            duration: "\(request.durationSeconds ?? defaultDuration)s",
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            auto_fix: false
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_31_LITE_FIRST_LAST_FRAME: FalVeo31LiteBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_31_LITE_FIRST_LAST_FRAME
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a first frame image"
            )
        }
        guard let clientLastFrame = request.clientLastFrame else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a last frame image"
            )
        }
        let body = FalVeo31LiteFirstLastFrameRequest(
            prompt: request.prompt ?? "",
            first_frame_url: toDataUri(clientImage),
            last_frame_url: toDataUri(clientLastFrame),
            aspect_ratio: getAspectRatio(request.dimensions),
            duration: "8s",
            resolution: request.resolution ?? "720p",
            generate_audio: request.generateAudio ?? true,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            auto_fix: false,
            safety_tolerance: safetyTolerance(request)
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_31_EXTEND: FalVeo31ExtendBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_31_EXTEND
    }

    override var audioCostPerSecond: Double {
        0.40
    }

    override var silentCostPerSecond: Double {
        0.20
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        try await makeExtendRequest(request: request)
    }
}

public final class G_FAL_VEO_31_FAST_EXTEND: FalVeo31ExtendBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_31_FAST_EXTEND
    }

    override var audioCostPerSecond: Double {
        0.15
    }

    override var silentCostPerSecond: Double {
        0.10
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        try await makeExtendRequest(request: request)
    }
}

// MARK: - Veo 2 Models

public final class G_FAL_VEO_2: FalVeoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_2
    }

    override var costPerSecond: Double {
        0.50
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalVeo2TextToVideoRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: getAspectRatio(request.dimensions),
            duration: "\(request.durationSeconds ?? 5)s",
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            enhance_prompt: request.promptEnhance ?? true
        )
        return try await performVeoRequest(request: request, body: body)
    }
}

public final class G_FAL_VEO_2_I2V: FalVeoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_VEO_2_I2V
    }

    override var costPerSecond: Double {
        0.50
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalVeo2ImageToVideoRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            aspect_ratio: "auto",
            duration: "\(request.durationSeconds ?? 5)s"
        )
        return try await performVeoRequest(request: request, body: body)
    }
}
