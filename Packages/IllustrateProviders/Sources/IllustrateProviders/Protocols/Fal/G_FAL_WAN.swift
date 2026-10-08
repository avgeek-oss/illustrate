// MARK: - G_FAL_WAN.swift

// Wan video generation models via Fal.ai
//
// Supported models:
// - Wan 2.2 A14B: High quality text/image-to-video
// - Wan 2.2 A14B Turbo: Fast generation
// - Wan 2.2 5B: Lightweight text/image-to-video
// - Wan 2.1: Standard text/image-to-video
// - Wan 2.1 FLF2V: First-last-frame-to-video
// - Wan Pro: Premium 1080p generation
// - Pika Scenes: Scene composition from reference images
//
// Pricing:
// - Wan 2.2 A14B: $0.08/sec
// - Wan 2.2 Turbo: $0.10/video
// - Wan 2.2 5B: $0.15/video
// - Wan 2.1: $0.40/video
// - Wan Pro: $0.80/video
// - Pika Scenes: $0.20/video

import Foundation

// MARK: - Request Structs

struct FalWan22T2VRequest: Codable {
    let prompt: String
    let negative_prompt: String?
    let num_frames: Int?
    let frames_per_second: Int?
    let seed: Int?
    let resolution: String
    let aspect_ratio: String
    let num_inference_steps: Int?
    let enable_safety_checker: Bool
    let enable_prompt_expansion: Bool?
    let guidance_scale: Double?
    let guidance_scale_2: Double?
    let interpolator_model: String?
    let num_interpolated_frames: Int?
    let video_quality: String?
}

struct FalWan22I2VRequest: Codable {
    let image_url: String
    let prompt: String
    let negative_prompt: String?
    let num_frames: Int?
    let frames_per_second: Int?
    let seed: Int?
    let resolution: String
    let aspect_ratio: String
    let num_inference_steps: Int?
    let enable_safety_checker: Bool
    let enable_prompt_expansion: Bool?
    let guidance_scale: Double?
    let guidance_scale_2: Double?
    let interpolator_model: String?
    let num_interpolated_frames: Int?
    let video_quality: String?
    let end_image_url: String?
}

struct FalWan22TurboT2VRequest: Codable {
    let prompt: String
    let seed: Int?
    let resolution: String
    let aspect_ratio: String
    let enable_safety_checker: Bool
    let enable_prompt_expansion: Bool?
    let video_quality: String?
}

struct FalWan22TurboI2VRequest: Codable {
    let image_url: String
    let prompt: String
    let seed: Int?
    let resolution: String
    let aspect_ratio: String
    let enable_safety_checker: Bool
    let enable_prompt_expansion: Bool?
    let video_quality: String?
}

struct FalWan21T2VRequest: Codable {
    let prompt: String
    let negative_prompt: String?
    let num_frames: Int?
    let frames_per_second: Int?
    let seed: Int?
    let resolution: String
    let aspect_ratio: String
    let num_inference_steps: Int?
    let enable_safety_checker: Bool
    let enable_prompt_expansion: Bool?
    let turbo_mode: Bool?
}

struct FalWan21I2VRequest: Codable {
    let image_url: String
    let prompt: String
    let negative_prompt: String?
    let num_frames: Int?
    let frames_per_second: Int?
    let seed: Int?
    let resolution: String
    let aspect_ratio: String
    let num_inference_steps: Int?
    let guide_scale: Double?
    let shift: Double?
    let enable_safety_checker: Bool
    let enable_prompt_expansion: Bool?
}

struct FalWan21FLF2VRequest: Codable {
    let prompt: String
    let negative_prompt: String?
    let start_image_url: String
    let end_image_url: String
    let num_frames: Int?
    let frames_per_second: Int?
    let seed: Int?
    let resolution: String
    let num_inference_steps: Int?
    let guide_scale: Double?
    let shift: Double?
    let enable_safety_checker: Bool
    let enable_prompt_expansion: Bool?
    let aspect_ratio: String
}

struct FalWanProT2VRequest: Codable {
    let prompt: String
    let seed: Int?
    let enable_safety_checker: Bool
}

struct FalWanProI2VRequest: Codable {
    let prompt: String
    let image_url: String
    let seed: Int?
    let enable_safety_checker: Bool
}

struct FalPikaScenesRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let seed: Int?
}

struct FalWan27T2VRequest: Codable {
    let prompt: String
    let aspect_ratio: String
    let resolution: String
    let duration: Int
    let negative_prompt: String?
    let enable_prompt_expansion: Bool?
    let seed: Int?
    let enable_safety_checker: Bool
}

struct FalWan27I2VRequest: Codable {
    let prompt: String?
    let image_url: String
    let end_image_url: String?
    let resolution: String
    let duration: Int
    let negative_prompt: String?
    let enable_prompt_expansion: Bool?
    let seed: Int?
    let enable_safety_checker: Bool
}

// MARK: - Base Class

public class FalWanBase: VideoGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var costPerVideo: Double {
        fatalError("Subclass must override")
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    var defaultDuration: Int {
        model.modelParams.supportedVideoDurations.first ?? 5
    }

    /// Required by protocol - placeholder
    public struct ServiceRequest: Codable, Sendable {
        let placeholder: Bool
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        ServiceRequest(placeholder: true)
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let numberOfVideos = request.numberOfVideos ?? 1
        return costPerVideo * Double(numberOfVideos)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    /// Converts base64 to data URI for Fal
    func toDataUri(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:image/png;base64,\(base64)"
    }

    /// Convert dimensions to aspect ratio
    func getAspectRatio(_ dimensions: String) -> String {
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
        let ratio = Double(width) / Double(height)
        if ratio > 1.5 { return "16:9" }
        if ratio > 0.8 { return "1:1" }
        return "9:16"
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
                return try downloadAndReturnVideo(urlStr: urlStr, request: request, responseData: data)
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
        request: VideoGenerationRequest,
        responseData: [String: Any]
    ) throws -> VideoGenerationResponse {
        let responseMetadata = wanResponseMetadata(responseData)
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
                size: responseMetadata.size,
                cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
                modelPrompt: responseMetadata.actualPrompt,
                metadata: responseMetadata.metadata.isEmpty ? nil : responseMetadata.metadata,
                actualDimensions: responseMetadata.actualDimensions,
                actualDuration: responseMetadata.actualDuration
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
            size: responseMetadata.size,
            cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
            modelPrompt: responseMetadata.actualPrompt,
            metadata: responseMetadata.metadata.isEmpty ? nil : responseMetadata.metadata,
            actualDimensions: responseMetadata.actualDimensions,
            actualDuration: responseMetadata.actualDuration
        )
    }

    private func wanResponseMetadata(_ data: [String: Any]) -> (
        metadata: [String: String],
        actualPrompt: String?,
        actualDimensions: String?,
        actualDuration: Int?,
        size: Int?
    ) {
        var metadata: [String: String] = [:]
        if let seed = data["seed"] as? Int {
            metadata["seed"] = String(seed)
        }
        let actualPrompt = data["actual_prompt"] as? String
        if let actualPrompt {
            metadata["actual_prompt"] = actualPrompt
        }

        guard let video = data["video"] as? [String: Any] else {
            return (metadata, actualPrompt, nil, nil, nil)
        }

        let actualDimensions: String? = {
            guard let width = video["width"] as? Int,
                  let height = video["height"] as? Int
            else { return nil }
            return "\(width)x\(height)"
        }()

        let actualDuration: Int? = {
            if let duration = video["duration"] as? Double {
                return Int(duration.rounded())
            }
            return video["duration"] as? Int
        }()

        return (
            metadata,
            actualPrompt,
            actualDimensions,
            actualDuration,
            video["file_size"] as? Int
        )
    }

    func performWanRequest(
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

// MARK: - Per-Second Pricing Base

public class FalWanPerSecondBase: FalWanBase {
    var costPerSecond: Double {
        0.08
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        // Calculate duration from num_frames and fps (default 81 frames at 16fps = ~5s)
        let durationSeconds = Double(request.durationSeconds ?? 5)
        let numberOfVideos = request.numberOfVideos ?? 1
        return costPerSecond * durationSeconds * Double(numberOfVideos)
    }
}

// MARK: - Wan 2.7 Models

public class FalWan27Base: FalWanPerSecondBase {
    override var costPerVideo: Double {
        0.50
    }

    override var costPerSecond: Double {
        0.10
    }

    override var defaultDuration: Int {
        5
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let durationSeconds = Double(request.durationSeconds ?? defaultDuration)
        let numberOfVideos = request.numberOfVideos ?? 1
        let perSecond = request.resolution?.lowercased() == "1080p" ? 0.15 : 0.10
        return perSecond * durationSeconds * Double(numberOfVideos)
    }

    func wan27Duration(_ request: VideoGenerationRequest) -> Int {
        min(max(request.durationSeconds ?? defaultDuration, 2), 15)
    }

    func wan27PromptExpansion(_ request: VideoGenerationRequest) -> Bool {
        request.promptEnhance ?? true
    }

    func wan27SafetyChecker(_ request: VideoGenerationRequest) -> Bool {
        guard let safetyTolerance = request.safetyTolerance else {
            return true
        }
        return safetyTolerance > 0
    }
}

public final class G_FAL_WAN_27_T2V: FalWan27Base {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_27_T2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalWan27T2VRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: getAspectRatio(request.dimensions),
            resolution: request.resolution ?? "1080p",
            duration: wan27Duration(request),
            negative_prompt: request.negativePrompt,
            enable_prompt_expansion: wan27PromptExpansion(request),
            seed: request.seed,
            enable_safety_checker: wan27SafetyChecker(request)
        )
        return try await performWanRequest(request: request, body: body)
    }
}

public final class G_FAL_WAN_27_I2V: FalWan27Base {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_27_I2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalWan27I2VRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            end_image_url: request.clientLastFrame.map { toDataUri($0) },
            resolution: request.resolution ?? "1080p",
            duration: wan27Duration(request),
            negative_prompt: request.negativePrompt,
            enable_prompt_expansion: wan27PromptExpansion(request),
            seed: request.seed,
            enable_safety_checker: wan27SafetyChecker(request)
        )
        return try await performWanRequest(request: request, body: body)
    }
}

// MARK: - Wan 2.2 A14B Models

public final class G_FAL_WAN_22_A14B_T2V: FalWanPerSecondBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_22_A14B_T2V
    }

    override var costPerVideo: Double {
        0.40
    } // Fallback
    override var costPerSecond: Double {
        0.08
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalWan22T2VRequest(
            prompt: request.prompt ?? "",
            negative_prompt: request.negativePrompt,
            num_frames: 81,
            frames_per_second: request.fps ?? 16,
            seed: request.seed,
            resolution: request.resolution ?? "720p",
            aspect_ratio: getAspectRatio(request.dimensions),
            num_inference_steps: request.steps ?? 27,
            enable_safety_checker: false,
            enable_prompt_expansion: request.promptEnhance,
            guidance_scale: request.guidance ?? 3.5,
            guidance_scale_2: 4.0,
            interpolator_model: "film",
            num_interpolated_frames: 1,
            video_quality: "high"
        )
        return try await performWanRequest(request: request, body: body)
    }
}

public final class G_FAL_WAN_22_A14B_I2V: FalWanPerSecondBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_22_A14B_I2V
    }

    override var costPerVideo: Double {
        0.40
    }

    override var costPerSecond: Double {
        0.08
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalWan22I2VRequest(
            image_url: toDataUri(clientImage),
            prompt: request.prompt ?? "",
            negative_prompt: request.negativePrompt,
            num_frames: 81,
            frames_per_second: request.fps ?? 16,
            seed: request.seed,
            resolution: request.resolution ?? "720p",
            aspect_ratio: "auto",
            num_inference_steps: request.steps ?? 27,
            enable_safety_checker: false,
            enable_prompt_expansion: request.promptEnhance,
            guidance_scale: request.guidance ?? 3.5,
            guidance_scale_2: 3.5,
            interpolator_model: "film",
            num_interpolated_frames: 1,
            video_quality: "high",
            end_image_url: request.clientLastFrame.map { toDataUri($0) }
        )
        return try await performWanRequest(request: request, body: body)
    }
}

// MARK: - Wan 2.2 A14B Turbo Models

public final class G_FAL_WAN_22_A14B_TURBO_T2V: FalWanBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_22_A14B_TURBO_T2V
    }

    override var costPerVideo: Double {
        0.10
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalWan22TurboT2VRequest(
            prompt: request.prompt ?? "",
            seed: request.seed,
            resolution: request.resolution ?? "720p",
            aspect_ratio: getAspectRatio(request.dimensions),
            enable_safety_checker: false,
            enable_prompt_expansion: request.promptEnhance,
            video_quality: "high"
        )
        return try await performWanRequest(request: request, body: body)
    }
}

public final class G_FAL_WAN_22_A14B_TURBO_I2V: FalWanBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_22_A14B_TURBO_I2V
    }

    override var costPerVideo: Double {
        0.10
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalWan22TurboI2VRequest(
            image_url: toDataUri(clientImage),
            prompt: request.prompt ?? "",
            seed: request.seed,
            resolution: request.resolution ?? "720p",
            aspect_ratio: "auto",
            enable_safety_checker: false,
            enable_prompt_expansion: request.promptEnhance,
            video_quality: "high"
        )
        return try await performWanRequest(request: request, body: body)
    }
}

// MARK: - Wan 2.2 5B Models

public final class G_FAL_WAN_22_5B_T2V: FalWanBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_22_5B_T2V
    }

    override var costPerVideo: Double {
        0.15
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalWan22T2VRequest(
            prompt: request.prompt ?? "",
            negative_prompt: request.negativePrompt,
            num_frames: 81,
            frames_per_second: request.fps ?? 24,
            seed: request.seed,
            resolution: request.resolution ?? "720p",
            aspect_ratio: getAspectRatio(request.dimensions),
            num_inference_steps: request.steps ?? 27,
            enable_safety_checker: false,
            enable_prompt_expansion: request.promptEnhance,
            guidance_scale: request.guidance ?? 3.5,
            guidance_scale_2: 4.0,
            interpolator_model: "film",
            num_interpolated_frames: 1,
            video_quality: "high"
        )
        return try await performWanRequest(request: request, body: body)
    }
}

public final class G_FAL_WAN_22_5B_I2V: FalWanBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_22_5B_I2V
    }

    override var costPerVideo: Double {
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
        let body = FalWan22I2VRequest(
            image_url: toDataUri(clientImage),
            prompt: request.prompt ?? "",
            negative_prompt: request.negativePrompt,
            num_frames: 81,
            frames_per_second: request.fps ?? 24,
            seed: request.seed,
            resolution: request.resolution ?? "720p",
            aspect_ratio: "auto",
            num_inference_steps: request.steps ?? 27,
            enable_safety_checker: false,
            enable_prompt_expansion: request.promptEnhance,
            guidance_scale: request.guidance ?? 3.5,
            guidance_scale_2: 3.5,
            interpolator_model: "film",
            num_interpolated_frames: 1,
            video_quality: "high",
            end_image_url: nil
        )
        return try await performWanRequest(request: request, body: body)
    }
}

// MARK: - Wan 2.1 Models

public final class G_FAL_WAN_21_T2V: FalWanBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_21_T2V
    }

    override var costPerVideo: Double {
        0.40
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalWan21T2VRequest(
            prompt: request.prompt ?? "",
            negative_prompt: request.negativePrompt,
            num_frames: 81,
            frames_per_second: request.fps ?? 16,
            seed: request.seed,
            resolution: request.resolution ?? "720p",
            aspect_ratio: getAspectRatio(request.dimensions),
            num_inference_steps: request.steps ?? 30,
            enable_safety_checker: false,
            enable_prompt_expansion: request.promptEnhance,
            turbo_mode: false
        )
        return try await performWanRequest(request: request, body: body)
    }
}

public final class G_FAL_WAN_21_I2V: FalWanBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_21_I2V
    }

    override var costPerVideo: Double {
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
        let body = FalWan21I2VRequest(
            image_url: toDataUri(clientImage),
            prompt: request.prompt ?? "",
            negative_prompt: request.negativePrompt,
            num_frames: 81,
            frames_per_second: request.fps ?? 16,
            seed: request.seed,
            resolution: request.resolution ?? "720p",
            aspect_ratio: "auto",
            num_inference_steps: request.steps ?? 30,
            guide_scale: request.guidance ?? 5.0,
            shift: 5.0,
            enable_safety_checker: false,
            enable_prompt_expansion: request.promptEnhance
        )
        return try await performWanRequest(request: request, body: body)
    }
}

public final class G_FAL_WAN_21_FLF2V: FalWanBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_21_FLF2V
    }

    override var costPerVideo: Double {
        0.40
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a start image"
            )
        }
        guard let clientLastFrame = request.clientLastFrame else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an end image"
            )
        }
        let body = FalWan21FLF2VRequest(
            prompt: request.prompt ?? "",
            negative_prompt: request.negativePrompt,
            start_image_url: toDataUri(clientImage),
            end_image_url: toDataUri(clientLastFrame),
            num_frames: 81,
            frames_per_second: request.fps ?? 16,
            seed: request.seed,
            resolution: request.resolution ?? "720p",
            num_inference_steps: request.steps ?? 30,
            guide_scale: request.guidance ?? 5.0,
            shift: 5.0,
            enable_safety_checker: false,
            enable_prompt_expansion: request.promptEnhance,
            aspect_ratio: "auto"
        )
        return try await performWanRequest(request: request, body: body)
    }
}

// MARK: - Wan Pro Models

public final class G_FAL_WAN_PRO_T2V: FalWanBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_PRO_T2V
    }

    override var costPerVideo: Double {
        0.80
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalWanProT2VRequest(
            prompt: request.prompt ?? "",
            seed: request.seed,
            enable_safety_checker: true
        )
        return try await performWanRequest(request: request, body: body)
    }
}

public final class G_FAL_WAN_PRO_I2V: FalWanBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_PRO_I2V
    }

    override var costPerVideo: Double {
        0.80
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalWanProI2VRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            seed: request.seed,
            enable_safety_checker: true
        )
        return try await performWanRequest(request: request, body: body)
    }
}

// MARK: - Pika Scenes

public final class G_FAL_PIKA_SCENES: FalWanBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_PIKA_SCENES
    }

    override var costPerVideo: Double {
        0.20
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        var imageUrls: [String] = []

        // Collect reference images
        if let clientImage = request.clientImage {
            imageUrls.append(toDataUri(clientImage))
        }
        if let referenceImages = request.clientReferenceImages {
            imageUrls.append(contentsOf: referenceImages.map { toDataUri($0.base64Image) })
        }

        guard !imageUrls.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires at least one reference image"
            )
        }

        let body = FalPikaScenesRequest(
            prompt: request.prompt ?? "",
            image_urls: imageUrls,
            seed: request.seed
        )
        return try await performWanRequest(request: request, body: body)
    }
}
