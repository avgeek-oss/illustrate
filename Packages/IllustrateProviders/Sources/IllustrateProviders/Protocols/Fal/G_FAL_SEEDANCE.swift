// MARK: - G_FAL_SEEDANCE.swift

// ByteDance Seedance video generation models via Fal.ai
//
// Supported models:
// - Seedance v1 Pro: High quality text-to-video and image-to-video
// - Seedance v1 Pro Fast: Fast generation with minimal cost
// - Seedance v1 Lite: Lightweight text/image/reference-to-video
// - Seedance v1.5 Pro: With audio generation
// - Seedance v2: SOTA with native audio and cinematic control
// - Lynx: Subject consistent video generation
//
// Pricing (token-based, estimated per 5s video):
// - Pro: ~$0.10
// - Pro Fast: ~$0.04
// - Lite: ~$0.07
// - v1.5 Pro: ~$0.05

import Foundation

// MARK: - Request Structs

struct FalSeedanceTextToVideoRequest: Codable {
    let prompt: String
    let aspect_ratio: String
    let resolution: String
    let duration: String
    let camera_fixed: Bool?
    let seed: Int?
    let enable_safety_checker: Bool
    let generate_audio: Bool?
}

struct FalSeedanceImageToVideoRequest: Codable {
    let prompt: String
    let image_url: String
    let aspect_ratio: String
    let resolution: String
    let duration: String
    let camera_fixed: Bool?
    let seed: Int?
    let enable_safety_checker: Bool
    let end_image_url: String?
    let generate_audio: Bool?
}

struct FalSeedanceReferenceToVideoRequest: Codable {
    let prompt: String
    let reference_image_urls: [String]
    let aspect_ratio: String
    let resolution: String
    let duration: String
    let camera_fixed: Bool?
    let seed: Int?
    let enable_safety_checker: Bool
}

struct FalLynxRequest: Codable {
    let image_url: String
    let prompt: String
    let negative_prompt: String?
    let num_inference_steps: Int?
    let seed: Int?
    let resolution: String
    let aspect_ratio: String
    let ip_scale: Double?
    let strength: Double?
    let frames_per_second: Int?
    let guidance_scale: Double?
    let num_frames: Int?
}

// MARK: - Base Class

public class FalSeedanceBase: VideoGenerationProtocol {
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
        if ratio > 2.0 { return "21:9" }
        if ratio > 1.5 { return "16:9" }
        if ratio > 1.2 { return "4:3" }
        if ratio > 0.8 { return "1:1" }
        if ratio > 0.6 { return "3:4" }
        return "9:16"
    }

    func getAutoDuration(_ durationSeconds: Int?) -> String {
        guard let durationSeconds else { return "auto" }
        return "\(durationSeconds)"
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

    func performSeedanceRequest(
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

// MARK: - Seedance v1 Pro Models

public final class G_FAL_SEEDANCE_V1_PRO_T2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V1_PRO_T2V
    }

    override var costPerSecond: Double {
        0.02
    } // ~$0.10/5s

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalSeedanceTextToVideoRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: getAspectRatio(request.dimensions),
            resolution: request.resolution ?? "1080p",
            duration: "\(request.durationSeconds ?? defaultDuration)",
            camera_fixed: nil,
            seed: request.seed,
            enable_safety_checker: true,
            generate_audio: nil
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

public final class G_FAL_SEEDANCE_V1_PRO_I2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V1_PRO_I2V
    }

    override var costPerSecond: Double {
        0.02
    } // ~$0.10/5s

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalSeedanceImageToVideoRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            aspect_ratio: "auto",
            resolution: request.resolution ?? "1080p",
            duration: "\(request.durationSeconds ?? defaultDuration)",
            camera_fixed: nil,
            seed: request.seed,
            enable_safety_checker: true,
            end_image_url: request.clientLastFrame.map { toDataUri($0) },
            generate_audio: nil
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

// MARK: - Seedance v1 Pro Fast Models

public final class G_FAL_SEEDANCE_V1_PRO_FAST_T2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V1_PRO_FAST_T2V
    }

    override var costPerSecond: Double {
        0.008
    } // ~$0.04/5s

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalSeedanceTextToVideoRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: getAspectRatio(request.dimensions),
            resolution: request.resolution ?? "1080p",
            duration: "\(request.durationSeconds ?? defaultDuration)",
            camera_fixed: nil,
            seed: request.seed,
            enable_safety_checker: true,
            generate_audio: nil
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

public final class G_FAL_SEEDANCE_V1_PRO_FAST_I2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V1_PRO_FAST_I2V
    }

    override var costPerSecond: Double {
        0.008
    } // ~$0.04/5s

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalSeedanceImageToVideoRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            aspect_ratio: "auto",
            resolution: request.resolution ?? "1080p",
            duration: "\(request.durationSeconds ?? defaultDuration)",
            camera_fixed: nil,
            seed: request.seed,
            enable_safety_checker: true,
            end_image_url: nil,
            generate_audio: nil
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

// MARK: - Seedance v1 Lite Models

public final class G_FAL_SEEDANCE_V1_LITE_T2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V1_LITE_T2V
    }

    override var costPerSecond: Double {
        0.014
    } // ~$0.07/5s

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalSeedanceTextToVideoRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: getAspectRatio(request.dimensions),
            resolution: request.resolution ?? "720p",
            duration: "\(request.durationSeconds ?? defaultDuration)",
            camera_fixed: nil,
            seed: request.seed,
            enable_safety_checker: true,
            generate_audio: nil
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

public final class G_FAL_SEEDANCE_V1_LITE_I2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V1_LITE_I2V
    }

    override var costPerSecond: Double {
        0.014
    } // ~$0.07/5s

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalSeedanceImageToVideoRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            aspect_ratio: "auto",
            resolution: request.resolution ?? "720p",
            duration: "\(request.durationSeconds ?? defaultDuration)",
            camera_fixed: nil,
            seed: request.seed,
            enable_safety_checker: true,
            end_image_url: request.clientLastFrame.map { toDataUri($0) },
            generate_audio: nil
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

public final class G_FAL_SEEDANCE_V1_LITE_REF2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V1_LITE_REF2V
    }

    override var costPerSecond: Double {
        0.014
    } // ~$0.07/5s

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let referenceImages = request.clientReferenceImages, !referenceImages.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires reference images"
            )
        }
        let imageUrls = referenceImages.map { toDataUri($0.base64Image) }
        let body = FalSeedanceReferenceToVideoRequest(
            prompt: request.prompt ?? "",
            reference_image_urls: imageUrls,
            aspect_ratio: "auto",
            resolution: request.resolution ?? "720p",
            duration: "\(request.durationSeconds ?? defaultDuration)",
            camera_fixed: nil,
            seed: request.seed,
            enable_safety_checker: true
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

// MARK: - Seedance v1.5 Pro Models (with audio)

public final class G_FAL_SEEDANCE_V15_PRO_T2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V15_PRO_T2V
    }

    override var costPerSecond: Double {
        0.01
    } // ~$0.05/5s

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalSeedanceTextToVideoRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: getAspectRatio(request.dimensions),
            resolution: request.resolution ?? "720p",
            duration: "\(request.durationSeconds ?? defaultDuration)",
            camera_fixed: nil,
            seed: request.seed,
            enable_safety_checker: true,
            generate_audio: request.generateAudio ?? true
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

public final class G_FAL_SEEDANCE_V15_PRO_I2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V15_PRO_I2V
    }

    override var costPerSecond: Double {
        0.01
    } // ~$0.05/5s

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalSeedanceImageToVideoRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            aspect_ratio: getAspectRatio(request.dimensions),
            resolution: request.resolution ?? "720p",
            duration: "\(request.durationSeconds ?? defaultDuration)",
            camera_fixed: nil,
            seed: request.seed,
            enable_safety_checker: true,
            end_image_url: request.clientLastFrame.map { toDataUri($0) },
            generate_audio: request.generateAudio ?? true
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

// MARK: - Seedance v2 Models (SOTA with native audio)

struct FalSeedance2TextToVideoRequest: Codable {
    let prompt: String
    let resolution: String?
    let duration: String?
    let aspect_ratio: String?
    let generate_audio: Bool?
    let seed: Int?
}

struct FalSeedance2ImageToVideoRequest: Codable {
    let prompt: String
    let image_url: String
    let end_image_url: String?
    let resolution: String?
    let duration: String?
    let aspect_ratio: String?
    let generate_audio: Bool?
    let seed: Int?
}

struct FalSeedance2MiniTextToVideoRequest: Codable {
    let prompt: String
    let resolution: String?
    let duration: String?
    let aspect_ratio: String?
    let generate_audio: Bool?
}

struct FalSeedance2MiniImageToVideoRequest: Codable {
    let prompt: String
    let image_url: String
    let end_image_url: String?
    let resolution: String?
    let duration: String?
    let aspect_ratio: String?
    let generate_audio: Bool?
}

struct FalSeedance2MiniReferenceToVideoRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let resolution: String?
    let duration: String?
    let aspect_ratio: String?
    let generate_audio: Bool?
}

public final class G_FAL_SEEDANCE_V2_T2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V2_T2V
    }

    override var costPerSecond: Double {
        0.03
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let duration = if let dur = request.durationSeconds {
            "\(dur)"
        } else {
            "auto"
        }

        let body = FalSeedance2TextToVideoRequest(
            prompt: request.prompt ?? "",
            resolution: request.resolution ?? "720p",
            duration: duration,
            aspect_ratio: getAspectRatio(request.dimensions),
            generate_audio: request.generateAudio ?? true,
            seed: request.seed
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

public final class G_FAL_SEEDANCE_V2_I2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V2_I2V
    }

    override var costPerSecond: Double {
        0.03
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let duration = if let dur = request.durationSeconds {
            "\(dur)"
        } else {
            "auto"
        }

        let body = FalSeedance2ImageToVideoRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            end_image_url: request.clientLastFrame.map { toDataUri($0) },
            resolution: request.resolution ?? "720p",
            duration: duration,
            aspect_ratio: getAspectRatio(request.dimensions),
            generate_audio: request.generateAudio ?? true,
            seed: request.seed
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

// MARK: - Seedance v2 Ref2V

struct FalSeedance2Ref2VRequest: Codable {
    let prompt: String
    let reference_image_urls: [String]
    let resolution: String?
    let duration: String?
    let aspect_ratio: String?
    let generate_audio: Bool?
    let seed: Int?
}

public final class G_FAL_SEEDANCE_V2_REF2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V2_REF2V
    }

    override var costPerSecond: Double {
        0.03
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
        let duration = if let dur = request.durationSeconds {
            "\(dur)"
        } else {
            "auto"
        }
        let body = FalSeedance2Ref2VRequest(
            prompt: request.prompt ?? "",
            reference_image_urls: imageUrls,
            resolution: request.resolution ?? "720p",
            duration: duration,
            aspect_ratio: getAspectRatio(request.dimensions),
            generate_audio: request.generateAudio ?? true,
            seed: request.seed
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

// MARK: - Seedance v2 Fast Models

public final class G_FAL_SEEDANCE_V2_FAST_T2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V2_FAST_T2V
    }

    override var costPerSecond: Double {
        0.015
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let duration = if let dur = request.durationSeconds {
            "\(dur)"
        } else {
            "auto"
        }

        let body = FalSeedance2TextToVideoRequest(
            prompt: request.prompt ?? "",
            resolution: request.resolution ?? "720p",
            duration: duration,
            aspect_ratio: getAspectRatio(request.dimensions),
            generate_audio: request.generateAudio ?? true,
            seed: request.seed
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

public final class G_FAL_SEEDANCE_V2_FAST_I2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V2_FAST_I2V
    }

    override var costPerSecond: Double {
        0.015
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let duration = if let dur = request.durationSeconds {
            "\(dur)"
        } else {
            "auto"
        }

        let body = FalSeedance2ImageToVideoRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            end_image_url: request.clientLastFrame.map { toDataUri($0) },
            resolution: request.resolution ?? "720p",
            duration: duration,
            aspect_ratio: getAspectRatio(request.dimensions),
            generate_audio: request.generateAudio ?? true,
            seed: request.seed
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

public final class G_FAL_SEEDANCE_V2_FAST_REF2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V2_FAST_REF2V
    }

    override var costPerSecond: Double {
        0.015
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
        let duration = if let dur = request.durationSeconds {
            "\(dur)"
        } else {
            "auto"
        }
        let body = FalSeedance2Ref2VRequest(
            prompt: request.prompt ?? "",
            reference_image_urls: imageUrls,
            resolution: request.resolution ?? "720p",
            duration: duration,
            aspect_ratio: getAspectRatio(request.dimensions),
            generate_audio: request.generateAudio ?? true,
            seed: request.seed
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

// MARK: - Seedance v2 Mini Models

public class FalSeedanceMiniBase: FalSeedanceBase {
    override var costPerSecond: Double {
        0.1547
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let durationSeconds = request.durationSeconds ?? defaultDuration
        let numberOfVideos = request.numberOfVideos ?? 1
        let perSecond = request.resolution == "480p" ? 0.0721 : 0.1547
        return perSecond * Double(durationSeconds) * Double(numberOfVideos)
    }
}

public final class G_FAL_SEEDANCE_V2_MINI_T2V: FalSeedanceMiniBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V2_MINI_T2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalSeedance2MiniTextToVideoRequest(
            prompt: request.prompt ?? "",
            resolution: request.resolution ?? "720p",
            duration: getAutoDuration(request.durationSeconds),
            aspect_ratio: getAspectRatio(request.dimensions),
            generate_audio: request.generateAudio ?? true
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

public final class G_FAL_SEEDANCE_V2_MINI_I2V: FalSeedanceMiniBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V2_MINI_I2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = FalSeedance2MiniImageToVideoRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            end_image_url: request.clientLastFrame.map { toDataUri($0) },
            resolution: request.resolution ?? "720p",
            duration: getAutoDuration(request.durationSeconds),
            aspect_ratio: getAspectRatio(request.dimensions),
            generate_audio: request.generateAudio ?? true
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

public final class G_FAL_SEEDANCE_V2_MINI_REF2V: FalSeedanceMiniBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SEEDANCE_V2_MINI_REF2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let referenceImages = request.clientReferenceImages, !referenceImages.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires reference images"
            )
        }

        let body = FalSeedance2MiniReferenceToVideoRequest(
            prompt: request.prompt ?? "",
            image_urls: referenceImages.map { toDataUri($0.base64Image) },
            resolution: request.resolution ?? "720p",
            duration: getAutoDuration(request.durationSeconds),
            aspect_ratio: getAspectRatio(request.dimensions),
            generate_audio: request.generateAudio ?? true
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

// MARK: - Lynx Model

public final class G_FAL_LYNX: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_LYNX
    }

    override var costPerSecond: Double {
        0.02
    } // Estimated ~$0.10/5s based on compute seconds

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a subject image"
            )
        }
        let body = FalLynxRequest(
            image_url: toDataUri(clientImage),
            prompt: request.prompt ?? "",
            negative_prompt: request.negativePrompt,
            num_inference_steps: request.steps ?? 50,
            seed: request.seed,
            resolution: request.resolution ?? "720p",
            aspect_ratio: getAspectRatio(request.dimensions),
            ip_scale: nil,
            strength: nil,
            frames_per_second: request.fps ?? 16,
            guidance_scale: request.guidance,
            num_frames: nil
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

// MARK: - PixVerse V6

struct PixverseV6I2VRequest: Codable {
    let prompt: String
    let image_url: String
    let resolution: String?
    let duration: Int?
    let seed: Int?
    let generate_audio_switch: Bool?
}

struct PixverseV6T2VRequest: Codable {
    let prompt: String
    let aspect_ratio: String?
    let resolution: String?
    let duration: Int?
    let negative_prompt: String?
    let seed: Int?
    let generate_audio_switch: Bool?
}

public final class G_FAL_PIXVERSE_V6_I2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_PIXVERSE_V6_I2V
    }

    override var costPerSecond: Double {
        0.05
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = PixverseV6I2VRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            resolution: request.resolution ?? "720p",
            duration: request.durationSeconds ?? 5,
            seed: request.seed,
            generate_audio_switch: request.generateAudio ?? true
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

public final class G_FAL_PIXVERSE_V6_T2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_PIXVERSE_V6_T2V
    }

    override var costPerSecond: Double {
        0.05
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let durationSeconds = request.durationSeconds ?? defaultDuration
        let numberOfVideos = request.numberOfVideos ?? 1
        let baseCost = switch request.resolution {
        case "360p": 0.025
        case "540p": 0.035
        case "1080p": 0.10
        default: 0.05
        }
        let audioSurcharge = request.generateAudio == true ? 0.015 : 0
        return (baseCost + audioSurcharge) * Double(durationSeconds) * Double(numberOfVideos)
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = PixverseV6T2VRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: getAspectRatio(request.dimensions),
            resolution: request.resolution ?? "720p",
            duration: request.durationSeconds ?? 5,
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            generate_audio_switch: request.generateAudio ?? false
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

// MARK: - Alibaba Happy Horse

struct HappyHorseT2VRequest: Codable {
    let prompt: String
    let aspect_ratio: String?
    let resolution: String?
    let duration: Int?
    let seed: Int?
    let enable_safety_checker: Bool
}

struct HappyHorseI2VRequest: Codable {
    let prompt: String
    let image_url: String
    let aspect_ratio: String?
    let resolution: String?
    let duration: Int?
    let seed: Int?
    let enable_safety_checker: Bool
}

public final class G_FAL_HAPPY_HORSE_T2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_HAPPY_HORSE_T2V
    }

    override var costPerSecond: Double {
        0.05
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = HappyHorseT2VRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: getAspectRatio(request.dimensions),
            resolution: request.resolution ?? "1080p",
            duration: request.durationSeconds ?? 5,
            seed: request.seed,
            enable_safety_checker: true
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

public final class G_FAL_HAPPY_HORSE_I2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_HAPPY_HORSE_I2V
    }

    override var costPerSecond: Double {
        0.05
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = HappyHorseI2VRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            aspect_ratio: getAspectRatio(request.dimensions),
            resolution: request.resolution ?? "1080p",
            duration: request.durationSeconds ?? 5,
            seed: request.seed,
            enable_safety_checker: true
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

private struct HappyHorseRef2VRequest: Codable {
    let prompt: String
    let reference_image_urls: [String]
    let aspect_ratio: String?
    let resolution: String?
    let duration: Int?
    let seed: Int?
    let enable_safety_checker: Bool
}

private struct HappyHorseV11ImageToVideoRequest: Codable {
    let image_url: String
    let prompt: String?
    let resolution: String?
    let duration: Int?
    let seed: Int?
    let enable_safety_checker: Bool
}

private struct HappyHorseV11ReferenceToVideoRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let aspect_ratio: String?
    let resolution: String?
    let duration: Int?
    let seed: Int?
    let enable_safety_checker: Bool
}

public final class G_FAL_HAPPY_HORSE_REF2V: FalSeedanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_HAPPY_HORSE_REF2V
    }

    override var costPerSecond: Double {
        0.05
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
        let body = HappyHorseRef2VRequest(
            prompt: request.prompt ?? "",
            reference_image_urls: imageUrls,
            aspect_ratio: getAspectRatio(request.dimensions),
            resolution: request.resolution ?? "1080p",
            duration: request.durationSeconds ?? 5,
            seed: request.seed,
            enable_safety_checker: true
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

public class FalHappyHorseV11Base: FalSeedanceBase {
    override var costPerSecond: Double {
        0.18
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let durationSeconds = request.durationSeconds ?? defaultDuration
        let numberOfVideos = request.numberOfVideos ?? 1
        let perSecond = request.resolution == "720p" ? 0.14 : 0.18
        return perSecond * Double(durationSeconds) * Double(numberOfVideos)
    }
}

public final class G_FAL_HAPPY_HORSE_V11_I2V: FalHappyHorseV11Base {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_HAPPY_HORSE_V11_I2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = HappyHorseV11ImageToVideoRequest(
            image_url: toDataUri(clientImage),
            prompt: request.prompt,
            resolution: request.resolution ?? "1080p",
            duration: request.durationSeconds ?? 5,
            seed: request.seed,
            enable_safety_checker: true
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}

public final class G_FAL_HAPPY_HORSE_V11_REF2V: FalHappyHorseV11Base {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_HAPPY_HORSE_V11_REF2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let referenceImages = request.clientReferenceImages, !referenceImages.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires reference images"
            )
        }

        let body = HappyHorseV11ReferenceToVideoRequest(
            prompt: request.prompt ?? "",
            image_urls: referenceImages.map { toDataUri($0.base64Image) },
            aspect_ratio: getAspectRatio(request.dimensions),
            resolution: request.resolution ?? "1080p",
            duration: request.durationSeconds ?? 5,
            seed: request.seed,
            enable_safety_checker: true
        )
        return try await performSeedanceRequest(request: request, body: body)
    }
}
