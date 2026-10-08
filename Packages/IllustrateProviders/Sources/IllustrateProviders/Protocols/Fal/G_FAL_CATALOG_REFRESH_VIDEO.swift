// MARK: - G_FAL_CATALOG_REFRESH_VIDEO.swift

// Direct Fal video endpoints added by the provider catalog audit.

import Foundation

private struct FalBerniniTextToVideoRequest: Codable {
    let prompt: String
    let max_image_size: Int
    let frames_per_second: Int
    let negative_prompt: String?
    let seed: Int?
    let num_frames: Int
    let enable_prompt_expansion: Bool
    let num_inference_steps: Int
    let acceleration: String
    let aspect_ratio: String
}

private struct FalBerniniReferenceToVideoRequest: Codable {
    let prompt: String
    let reference_image_urls: [String]
    let max_image_size: Int
    let frames_per_second: Int
    let negative_prompt: String?
    let seed: Int?
    let num_frames: Int
    let enable_prompt_expansion: Bool
    let num_inference_steps: Int
    let acceleration: String
    let aspect_ratio: String
}

private struct FalBerniniEditVideoRequest: Codable {
    let prompt: String
    let video_url: String
    let max_image_size: Int
    let frames_per_second: Int
    let negative_prompt: String?
    let seed: Int?
    let num_frames: Int
    let enable_prompt_expansion: Bool
    let num_inference_steps: Int
    let acceleration: String
}

private struct FalBerniniReferenceEditVideoRequest: Codable {
    let prompt: String
    let video_url: String
    let reference_image_urls: [String]
    let max_image_size: Int
    let frames_per_second: Int
    let negative_prompt: String?
    let seed: Int?
    let num_frames: Int
    let enable_prompt_expansion: Bool
    let num_inference_steps: Int
    let acceleration: String
}

private struct FalDreamActorRequest: Codable {
    let image_url: String
    let video_url: String
    let trim_first_second: Bool
}

private struct FalByteDanceVideoUpscaleRequest: Codable {
    let video_url: String
    let target_fps: String
    let target_resolution: String
    let enhancement_tier: String
    let fidelity: String
    let enhancement_preset: String
}

private struct FalOmniHumanRequest: Codable {
    let prompt: String?
    let image_url: String
    let mask_url: String?
    let audio_url: String
    let turbo_mode: Bool
    let resolution: String
}

private struct FalLtxImageSize: Codable {
    let width: Int
    let height: Int
}

private struct FalLtxExtendRequest: Codable {
    let prompt: String
    let video_url: String
    let match_input_fps: Bool
    let frames_per_second: Double
    let end_image_url: String?
    let negative_prompt: String?
    let num_frames: Int
    let num_context_frames: Int
    let generate_audio: Bool
    let enable_prompt_expansion: Bool
    let seed: Int?
    let resolution: FalLtxImageSize
    let extend_direction: String
}

public class FalCatalogRefreshVideoBase: VideoGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var costPerSecond: Double {
        fatalError("Subclass must override")
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public struct ServiceRequest: Codable, Sendable {
        let placeholder: Bool
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        ServiceRequest(placeholder: true)
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        let count = Double(request.numberOfVideos ?? 1)
        return costPerSecond * duration * count
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        guard case let .dictionary(_, data) = response else {
            return createInvalidVideoResponseError(response: response, modelCode: modelCode)
        }

        if let video = data["video"] as? [String: Any],
           let url = video["url"] as? String
        {
            return try videoResponse(
                url: url,
                data: data,
                rawResponse: response.rawResponseString,
                request: request
            )
        }

        if let detail = data["detail"] as? String {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: detail,
                rawResponse: response.rawResponseString
            )
        }
        if let error = data["error"] as? [String: Any],
           let message = error["message"] as? String
        {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: message,
                rawResponse: response.rawResponseString
            )
        }

        return createInvalidVideoResponseError(response: response, modelCode: modelCode)
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        fatalError("Subclass must override")
    }

    func performRequest(
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

        do {
            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: body,
                headers: [
                    "Authorization": "Key \(request.providerSecret)",
                    "Content-Type": "application/json",
                ],
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

    func imageDataURI(_ base64: String, mimeType: String = "image/png") -> String {
        base64.hasPrefix("data:") ? base64 : "data:\(mimeType);base64,\(base64)"
    }

    func videoDataURI(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:video/mp4;base64,\(base64)"
    }

    private func videoResponse(
        url: String,
        data: [String: Any],
        rawResponse: String?,
        request: VideoGenerationRequest
    ) throws -> VideoGenerationResponse {
        let actualDuration = (data["duration"] as? NSNumber)?.intValue

        if url.hasPrefix("data:"), let comma = url.firstIndex(of: ",") {
            let base64 = String(url[url.index(after: comma)...])
            guard Data(base64Encoded: base64) != nil else {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Invalid video data URI"
                )
            }
            return VideoGenerationResponse(
                status: .GENERATED,
                base64: base64,
                cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
                modelPrompt: request.prompt,
                rawResponse: rawResponse,
                actualDuration: actualDuration
            )
        }

        guard let remoteURL = URL(string: url) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid video URL"
            )
        }
        let video = try Data(contentsOf: remoteURL)
        return VideoGenerationResponse(
            status: .GENERATED,
            base64: video.base64EncodedString(),
            cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
            modelPrompt: request.prompt,
            rawResponse: rawResponse,
            actualDuration: actualDuration
        )
    }
}

public class FalBerniniVideoBase: FalCatalogRefreshVideoBase {
    override var costPerSecond: Double {
        0.08
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let generatedSeconds = Double(frameCount(duration: request.durationSeconds)) / 16
        let count = Double(request.numberOfVideos ?? 1)
        return costPerSecond * generatedSeconds * count * resolutionMultiplier(request.resolution)
    }

    func maxImageSize(_ resolution: String?) -> Int {
        switch resolution?.lowercased() {
        case "576p": 576
        case "1280p": 1280
        default: 848
        }
    }

    func frameCount(duration: Int?, fps: Int = 16) -> Int {
        let desired = max(1, (duration ?? 5) * fps)
        return min(121, ((desired - 1 + 3) / 4) * 4 + 1)
    }

    func aspectRatio(_ dimensions: String) -> String {
        if ["16:9", "9:16", "1:1"].contains(dimensions) {
            return dimensions
        }
        let sides = dimensions.lowercased().split(separator: "x").compactMap { Double($0) }
        guard sides.count == 2 else { return "16:9" }
        if abs(sides[0] - sides[1]) < 0.01 { return "1:1" }
        return sides[0] > sides[1] ? "16:9" : "9:16"
    }

    private func resolutionMultiplier(_ resolution: String?) -> Double {
        switch resolution?.lowercased() {
        case "576p": 0.5
        case "1280p": 2
        default: 1
        }
    }
}

public final class G_FAL_BYTEDANCE_BERNINI_R_T2V: FalBerniniVideoBase {
    override public init() {}

    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_BERNINI_R_T2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let fps = request.fps ?? 16
        let body = FalBerniniTextToVideoRequest(
            prompt: request.prompt ?? "",
            max_image_size: maxImageSize(request.resolution),
            frames_per_second: fps,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            num_frames: frameCount(duration: request.durationSeconds, fps: fps),
            enable_prompt_expansion: request.promptEnhance ?? false,
            num_inference_steps: min(50, max(1, request.steps ?? 30)),
            acceleration: "none",
            aspect_ratio: aspectRatio(request.dimensions)
        )
        return try await performRequest(request: request, body: body)
    }
}

public final class G_FAL_BYTEDANCE_BERNINI_R_REF2V: FalBerniniVideoBase {
    override public init() {}

    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_BERNINI_R_REF2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let references = Array((request.clientReferenceImages ?? []).prefix(5))
        guard !references.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires reference images"
            )
        }

        let fps = request.fps ?? 16
        let body = FalBerniniReferenceToVideoRequest(
            prompt: request.prompt ?? "",
            reference_image_urls: references.map { imageDataURI($0.base64Image, mimeType: $0.mimeType) },
            max_image_size: maxImageSize(request.resolution),
            frames_per_second: fps,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            num_frames: frameCount(duration: request.durationSeconds, fps: fps),
            enable_prompt_expansion: request.promptEnhance ?? false,
            num_inference_steps: min(50, max(1, request.steps ?? 30)),
            acceleration: "none",
            aspect_ratio: aspectRatio(request.dimensions)
        )
        return try await performRequest(request: request, body: body)
    }
}

public final class G_FAL_BYTEDANCE_BERNINI_R_EDIT_VIDEO: FalBerniniVideoBase {
    override public init() {}

    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_BERNINI_R_EDIT_VIDEO
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let video = request.clientVideo, !video.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input video"
            )
        }

        let fps = request.fps ?? 16
        let body = FalBerniniEditVideoRequest(
            prompt: request.prompt ?? "",
            video_url: videoDataURI(video),
            max_image_size: maxImageSize(request.resolution),
            frames_per_second: fps,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            num_frames: frameCount(duration: request.durationSeconds, fps: fps),
            enable_prompt_expansion: request.promptEnhance ?? false,
            num_inference_steps: min(50, max(1, request.steps ?? 30)),
            acceleration: "none"
        )
        return try await performRequest(request: request, body: body)
    }
}

public final class G_FAL_BYTEDANCE_BERNINI_R_REFERENCE_EDIT_VIDEO: FalBerniniVideoBase {
    override public init() {}

    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_BERNINI_R_REFERENCE_EDIT_VIDEO
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let video = request.clientVideo, !video.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input video"
            )
        }
        let references = Array((request.clientReferenceImages ?? []).prefix(5))
        guard !references.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires reference images"
            )
        }

        let fps = request.fps ?? 16
        let body = FalBerniniReferenceEditVideoRequest(
            prompt: request.prompt ?? "",
            video_url: videoDataURI(video),
            reference_image_urls: references.map { imageDataURI($0.base64Image, mimeType: $0.mimeType) },
            max_image_size: maxImageSize(request.resolution),
            frames_per_second: fps,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            num_frames: frameCount(duration: request.durationSeconds, fps: fps),
            enable_prompt_expansion: request.promptEnhance ?? false,
            num_inference_steps: min(50, max(1, request.steps ?? 30)),
            acceleration: "none"
        )
        return try await performRequest(request: request, body: body)
    }
}

public final class G_FAL_BYTEDANCE_DREAMACTOR_V2: FalCatalogRefreshVideoBase {
    override public init() {}

    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_DREAMACTOR_V2
    }

    override var costPerSecond: Double {
        0.05
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let image = request.clientImage, !image.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        guard let video = request.clientVideo, !video.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input video"
            )
        }

        let body = FalDreamActorRequest(
            image_url: imageDataURI(image),
            video_url: videoDataURI(video),
            trim_first_second: true
        )
        return try await performRequest(request: request, body: body)
    }
}

public final class G_FAL_BYTEDANCE_VIDEO_UPSCALER: FalCatalogRefreshVideoBase {
    override public init() {}

    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_VIDEO_UPSCALER
    }

    override var costPerSecond: Double {
        0.0072
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let multiplier: Double = switch request.resolution?.lowercased() {
        case "2k": 2
        case "4k": 4
        default: 1
        }
        return super.getCostEstimate(request: request) * multiplier
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let video = request.clientVideo, !video.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input video"
            )
        }

        let resolution = switch request.resolution?.lowercased() {
        case "2k": "2k"
        case "4k": "4k"
        default: "1080p"
        }
        let body = FalByteDanceVideoUpscaleRequest(
            video_url: videoDataURI(video),
            target_fps: "30fps",
            target_resolution: resolution,
            enhancement_tier: "standard",
            fidelity: "high",
            enhancement_preset: "general"
        )
        return try await performRequest(request: request, body: body)
    }
}

public final class G_FAL_BYTEDANCE_OMNIHUMAN_V15: FalCatalogRefreshVideoBase {
    override public init() {}

    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_OMNIHUMAN_V15
    }

    override var costPerSecond: Double {
        0.16
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let image = request.clientImage, !image.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        guard let audioURL = request.sourceMetadata?["audio_url"], !audioURL.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires audio_url metadata"
            )
        }

        let body = FalOmniHumanRequest(
            prompt: request.prompt,
            image_url: imageDataURI(image),
            mask_url: request.clientMask.map { imageDataURI($0) },
            audio_url: audioURL,
            turbo_mode: false,
            resolution: request.resolution?.lowercased() == "720p" ? "720p" : "1080p"
        )
        return try await performRequest(request: request, body: body)
    }
}

public final class G_FAL_LTX_23_EXTEND: FalCatalogRefreshVideoBase {
    override public init() {}

    override var modelCode: EnumProviderModelCode {
        .FAL_LTX_23_EXTEND
    }

    override var costPerSecond: Double {
        0
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let size = outputSize(resolution: request.resolution, dimensions: request.dimensions ?? "16:9")
        let frames = frameCount(duration: request.durationSeconds)
        let megapixelFrames = ceil(Double(size.width * size.height * frames) / 1_000_000)
        return 0.0024075 * megapixelFrames * Double(request.numberOfVideos ?? 1)
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let video = request.clientVideo, !video.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input video"
            )
        }

        let direction = request.sourceMetadata?["extend_direction"] == "backward" ? "backward" : "forward"
        let body = FalLtxExtendRequest(
            prompt: request.prompt ?? "",
            video_url: videoDataURI(video),
            match_input_fps: true,
            frames_per_second: 24,
            end_image_url: request.clientLastFrame.map { imageDataURI($0) },
            negative_prompt: request.negativePrompt,
            num_frames: frameCount(duration: request.durationSeconds),
            num_context_frames: 25,
            generate_audio: request.generateAudio ?? true,
            enable_prompt_expansion: request.promptEnhance ?? true,
            seed: request.seed,
            resolution: outputSize(resolution: request.resolution, dimensions: request.dimensions),
            extend_direction: direction
        )
        return try await performRequest(request: request, body: body)
    }

    private func frameCount(duration: Int?) -> Int {
        let desired = max(1, (duration ?? 5) * 24 + 25)
        return ((desired - 1 + 7) / 8) * 8 + 1
    }

    private func outputSize(resolution: String?, dimensions: String) -> FalLtxImageSize {
        let normalized = dimensions.lowercased()
        let portrait = normalized == "9:16" || normalized.hasPrefix("9:") || normalized.hasPrefix("1080x1920")
        let square = normalized == "1:1" || normalized.hasPrefix("1024x1024")

        if square {
            let side = switch resolution?.lowercased() {
            case "480p": 480
            case "1080p": 1056
            default: 704
            }
            return FalLtxImageSize(width: side, height: side)
        }

        let landscapeSize = switch resolution?.lowercased() {
        case "480p": (832, 480)
        case "1080p": (1888, 1056)
        default: (1280, 704)
        }
        return portrait
            ? FalLtxImageSize(width: landscapeSize.1, height: landscapeSize.0)
            : FalLtxImageSize(width: landscapeSize.0, height: landscapeSize.1)
    }
}
