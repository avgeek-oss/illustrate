// MARK: - G_FAL_KLING.swift

// Kling video and image generation models via Fal.ai
//
// Supported versions:
// - v2.6 Pro: Latest with native audio ($0.07/sec)
// - v2.5 Turbo Pro/Standard: Fast generation ($0.07/sec, $0.042/sec)
// - v2.1 Master/Pro/Standard: Premium quality ($0.28/sec, $0.09/sec, $0.05/sec)
// - v2.0 Master: High quality ($0.28/sec)
// - v1.6 Pro/Standard: Reliable ($0.095/sec, $0.045/sec)
// - v1.5 Pro: Motion control ($0.10/sec)
// - v1.0 Pro/Standard: Original ($0.10/sec, $0.045/sec)
// - O1: First-last frame, reference-to-video ($0.112/sec)
// - LipSync: Audio/text to realistic lip movements ($0.014/unit)

import Foundation

// MARK: - Request Structs

struct FalKlingT2VRequest: Codable {
    let prompt: String
    let duration: String?
    let aspect_ratio: String?
    let negative_prompt: String?
    let cfg_scale: Double?
    let generate_audio: Bool?
}

struct FalKlingI2VRequest: Codable {
    let prompt: String
    let start_image_url: String
    let duration: String?
    let negative_prompt: String?
    let generate_audio: Bool?
    let end_image_url: String?
}

struct FalKlingO1I2VRequest: Codable {
    let prompt: String
    let start_image_url: String
    let end_image_url: String?
    let duration: String?
    let negative_prompt: String?
}

struct FalKlingRef2VRequest: Codable {
    let prompt: String
    let reference_images: [FalKlingRefImage]
    let duration: String?
    let negative_prompt: String?
}

struct FalKlingRefImage: Codable {
    let image_url: String
    let type: String? // "subject" or "face"
}

struct FalKlingLipSyncA2VRequest: Codable {
    let video_url: String
    let audio_url: String
}

struct FalKlingLipSyncT2VRequest: Codable {
    let video_url: String
    let text: String
    let voice_id: String?
}

// MARK: - Image Request Structs

struct FalKlingImageO1Request: Codable {
    let prompt: String
    let image_url: String?
    let negative_prompt: String?
    let num_images: Int?
    let aspect_ratio: String?
}

// MARK: - Base Class

public class FalKlingBase: VideoGenerationProtocol {
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

    var supportsAudio: Bool {
        model.modelParams.supportsAudio
    }

    /// Required by protocol - placeholder
    public struct ServiceRequest: Codable, Sendable {
        let placeholder: Bool
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        ServiceRequest(placeholder: true)
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let durationSeconds = Double(request.durationSeconds ?? defaultDuration)
        let numberOfVideos = request.numberOfVideos ?? 1
        return costPerSecond * durationSeconds * Double(numberOfVideos)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    /// Converts base64 to data URI for Fal
    func toDataUri(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:image/png;base64,\(base64)"
    }

    /// Convert aspect ratio from dimensions
    func getAspectRatio(from request: VideoGenerationRequest) -> String? {
        let dimensions = request.dimensions
        guard !dimensions.isEmpty else { return nil }
        if dimensions.contains("16:9") || dimensions.contains("landscape") {
            return "16:9"
        } else if dimensions.contains("9:16") || dimensions.contains("portrait") {
            return "9:16"
        } else if dimensions.contains("1:1") || dimensions.contains("square") {
            return "1:1"
        }
        return dimensions
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

    func performKlingRequest(
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

// MARK: - Per-Unit Pricing Base (for LipSync)

public class FalKlingPerUnitBase: FalKlingBase {
    var costPerUnit: Double {
        0.014
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let numberOfVideos = request.numberOfVideos ?? 1
        return costPerUnit * Double(numberOfVideos)
    }
}

// MARK: - Kling v2.6 Pro Models

public final class G_FAL_KLING_V26_PRO_T2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V26_PRO_T2V
    }

    override var costPerSecond: Double {
        0.07
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let duration = request.durationSeconds ?? 5
        let body = FalKlingT2VRequest(
            prompt: request.prompt ?? "",
            duration: "\(duration)",
            aspect_ratio: getAspectRatio(from: request) ?? "16:9",
            negative_prompt: request.negativePrompt,
            cfg_scale: request.guidance ?? 0.5,
            generate_audio: request.generateAudio ?? true
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V26_PRO_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V26_PRO_I2V
    }

    override var costPerSecond: Double {
        0.07
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let duration = request.durationSeconds ?? 5
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(duration)",
            negative_prompt: request.negativePrompt,
            generate_audio: request.generateAudio ?? true,
            end_image_url: request.clientLastFrame.map { toDataUri($0) }
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

// MARK: - Kling v2.5 Turbo Models

public final class G_FAL_KLING_V25_TURBO_PRO_T2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V25_TURBO_PRO_T2V
    }

    override var costPerSecond: Double {
        0.07
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let duration = request.durationSeconds ?? 5
        let body = FalKlingT2VRequest(
            prompt: request.prompt ?? "",
            duration: "\(duration)",
            aspect_ratio: getAspectRatio(from: request) ?? "16:9",
            negative_prompt: request.negativePrompt,
            cfg_scale: request.guidance ?? 0.5,
            generate_audio: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V25_TURBO_PRO_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V25_TURBO_PRO_I2V
    }

    override var costPerSecond: Double {
        0.07
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let duration = request.durationSeconds ?? 5
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(duration)",
            negative_prompt: request.negativePrompt,
            generate_audio: nil,
            end_image_url: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V25_TURBO_STD_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V25_TURBO_STD_I2V
    }

    override var costPerSecond: Double {
        0.042
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let duration = request.durationSeconds ?? 5
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(duration)",
            negative_prompt: request.negativePrompt,
            generate_audio: nil,
            end_image_url: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

// MARK: - Kling v2.1 Models

public final class G_FAL_KLING_V21_MASTER_T2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V21_MASTER_T2V
    }

    override var costPerSecond: Double {
        0.28
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let duration = request.durationSeconds ?? 5
        let body = FalKlingT2VRequest(
            prompt: request.prompt ?? "",
            duration: "\(duration)",
            aspect_ratio: getAspectRatio(from: request) ?? "16:9",
            negative_prompt: request.negativePrompt,
            cfg_scale: request.guidance ?? 0.5,
            generate_audio: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V21_MASTER_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V21_MASTER_I2V
    }

    override var costPerSecond: Double {
        0.28
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let duration = request.durationSeconds ?? 5
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(duration)",
            negative_prompt: request.negativePrompt,
            generate_audio: nil,
            end_image_url: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V21_PRO_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V21_PRO_I2V
    }

    override var costPerSecond: Double {
        0.09
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let duration = request.durationSeconds ?? 5
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(duration)",
            negative_prompt: request.negativePrompt,
            generate_audio: nil,
            end_image_url: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V21_STD_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V21_STD_I2V
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
        let duration = request.durationSeconds ?? 5
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(duration)",
            negative_prompt: request.negativePrompt,
            generate_audio: nil,
            end_image_url: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

// MARK: - Kling v2.0 Models

public final class G_FAL_KLING_V20_MASTER_T2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V20_MASTER_T2V
    }

    override var costPerSecond: Double {
        0.28
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let duration = request.durationSeconds ?? 5
        let body = FalKlingT2VRequest(
            prompt: request.prompt ?? "",
            duration: "\(duration)",
            aspect_ratio: getAspectRatio(from: request) ?? "16:9",
            negative_prompt: request.negativePrompt,
            cfg_scale: request.guidance ?? 0.5,
            generate_audio: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V20_MASTER_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V20_MASTER_I2V
    }

    override var costPerSecond: Double {
        0.28
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let duration = request.durationSeconds ?? 5
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(duration)",
            negative_prompt: request.negativePrompt,
            generate_audio: nil,
            end_image_url: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

// MARK: - Kling v1.6 Models

public final class G_FAL_KLING_V16_PRO_T2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V16_PRO_T2V
    }

    override var costPerSecond: Double {
        0.095
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let duration = request.durationSeconds ?? 5
        let body = FalKlingT2VRequest(
            prompt: request.prompt ?? "",
            duration: "\(duration)",
            aspect_ratio: getAspectRatio(from: request) ?? "16:9",
            negative_prompt: request.negativePrompt,
            cfg_scale: request.guidance ?? 0.5,
            generate_audio: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V16_PRO_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V16_PRO_I2V
    }

    override var costPerSecond: Double {
        0.095
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let duration = request.durationSeconds ?? 5
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(duration)",
            negative_prompt: request.negativePrompt,
            generate_audio: nil,
            end_image_url: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V16_STD_T2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V16_STD_T2V
    }

    override var costPerSecond: Double {
        0.045
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let duration = request.durationSeconds ?? 5
        let body = FalKlingT2VRequest(
            prompt: request.prompt ?? "",
            duration: "\(duration)",
            aspect_ratio: getAspectRatio(from: request) ?? "16:9",
            negative_prompt: request.negativePrompt,
            cfg_scale: request.guidance ?? 0.5,
            generate_audio: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V16_STD_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V16_STD_I2V
    }

    override var costPerSecond: Double {
        0.045
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let duration = request.durationSeconds ?? 5
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(duration)",
            negative_prompt: request.negativePrompt,
            generate_audio: nil,
            end_image_url: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

// MARK: - Kling v1.5 Models

public final class G_FAL_KLING_V15_PRO_T2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V15_PRO_T2V
    }

    override var costPerSecond: Double {
        0.10
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let duration = request.durationSeconds ?? 5
        let body = FalKlingT2VRequest(
            prompt: request.prompt ?? "",
            duration: "\(duration)",
            aspect_ratio: getAspectRatio(from: request) ?? "16:9",
            negative_prompt: request.negativePrompt,
            cfg_scale: request.guidance ?? 0.5,
            generate_audio: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V15_PRO_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V15_PRO_I2V
    }

    override var costPerSecond: Double {
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
        let duration = request.durationSeconds ?? 5
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(duration)",
            negative_prompt: request.negativePrompt,
            generate_audio: nil,
            end_image_url: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

// MARK: - Kling v1.0 Models

public final class G_FAL_KLING_V10_PRO_T2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V10_PRO_T2V
    }

    override var costPerSecond: Double {
        0.10
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let duration = request.durationSeconds ?? 5
        let body = FalKlingT2VRequest(
            prompt: request.prompt ?? "",
            duration: "\(duration)",
            aspect_ratio: getAspectRatio(from: request) ?? "16:9",
            negative_prompt: request.negativePrompt,
            cfg_scale: request.guidance ?? 0.5,
            generate_audio: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V10_PRO_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V10_PRO_I2V
    }

    override var costPerSecond: Double {
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
        let duration = request.durationSeconds ?? 5
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(duration)",
            negative_prompt: request.negativePrompt,
            generate_audio: nil,
            end_image_url: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V10_STD_T2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V10_STD_T2V
    }

    override var costPerSecond: Double {
        0.045
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let duration = request.durationSeconds ?? 5
        let body = FalKlingT2VRequest(
            prompt: request.prompt ?? "",
            duration: "\(duration)",
            aspect_ratio: getAspectRatio(from: request) ?? "16:9",
            negative_prompt: request.negativePrompt,
            cfg_scale: request.guidance ?? 0.5,
            generate_audio: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V10_STD_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V10_STD_I2V
    }

    override var costPerSecond: Double {
        0.045
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let duration = request.durationSeconds ?? 5
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(duration)",
            negative_prompt: request.negativePrompt,
            generate_audio: nil,
            end_image_url: nil
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

// MARK: - Kling O1 Special Models

public final class G_FAL_KLING_O1_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_O1_I2V
    }

    override var costPerSecond: Double {
        0.112
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a start image"
            )
        }
        let duration = request.durationSeconds ?? 5
        let body = FalKlingO1I2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            end_image_url: request.clientLastFrame.map { toDataUri($0) },
            duration: "\(duration)",
            negative_prompt: request.negativePrompt
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_O1_REF2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_O1_REF2V
    }

    override var costPerSecond: Double {
        0.112
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        // Build reference images from clientReferenceImages or clientImage
        var refImages: [FalKlingRefImage] = []

        if let refImageData = request.clientReferenceImages {
            for ref in refImageData {
                refImages.append(FalKlingRefImage(
                    image_url: toDataUri(ref.base64Image),
                    type: "subject"
                ))
            }
        } else if let clientImage = request.clientImage {
            refImages.append(FalKlingRefImage(
                image_url: toDataUri(clientImage),
                type: "subject"
            ))
        }

        guard !refImages.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires at least one reference image"
            )
        }

        let duration = request.durationSeconds ?? 5
        let body = FalKlingRef2VRequest(
            prompt: request.prompt ?? "",
            reference_images: refImages,
            duration: "\(duration)",
            negative_prompt: request.negativePrompt
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

// MARK: - Kling LipSync Models

public final class G_FAL_KLING_LIPSYNC_A2V: FalKlingPerUnitBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_LIPSYNC_A2V
    }

    override var costPerUnit: Double {
        0.014
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        // This model requires a video URL and audio URL
        // For now, we use clientImage as video and expect audio in sourceMetadata
        guard let clientVideo = request.clientVideo else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a video input"
            )
        }
        guard let audioUrl = request.sourceMetadata?["audio_url"] else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an audio URL in sourceMetadata"
            )
        }

        let body = FalKlingLipSyncA2VRequest(
            video_url: toDataUri(clientVideo),
            audio_url: audioUrl
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_LIPSYNC_T2V: FalKlingPerUnitBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_LIPSYNC_T2V
    }

    override var costPerUnit: Double {
        0.014
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientVideo = request.clientVideo else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a video input"
            )
        }
        guard let text = request.prompt, !text.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires text for lip sync"
            )
        }

        let body = FalKlingLipSyncT2VRequest(
            video_url: toDataUri(clientVideo),
            text: text,
            voice_id: request.sourceMetadata?["voice_id"]
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

// MARK: - Kling Image Model

public final class G_FAL_KLING_IMAGE_O1: ImageGenerationProtocol {
    public init() {}
    var modelCode: EnumProviderModelCode {
        .FAL_KLING_IMAGE_O1
    }

    var baseCost: Double {
        0.03
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public struct ServiceRequest: Codable, Sendable {
        let placeholder: Bool
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        ServiceRequest(placeholder: true)
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let numberOfImages = request.numberOfImages ?? 1
        return baseCost * Double(numberOfImages)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    func toDataUri(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:image/png;base64,\(base64)"
    }

    func getAspectRatio(from request: ImageGenerationRequest) -> String {
        let dimensions = request.dimensions
        if dimensions.contains("16:9") || dimensions.contains("landscape") {
            return "16:9"
        } else if dimensions.contains("9:16") || dimensions.contains("portrait") {
            return "9:16"
        } else if dimensions.contains("1:1") || dimensions.contains("square") {
            return "1:1"
        } else if dimensions.contains("4:3") {
            return "4:3"
        } else if dimensions.contains("3:4") {
            return "3:4"
        } else if dimensions.contains("3:2") {
            return "3:2"
        } else if dimensions.contains("2:3") {
            return "2:3"
        } else if dimensions.contains("21:9") {
            return "21:9"
        }
        return "1:1"
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let images = data["images"] as? [[String: Any]],
               let firstImage = images.first,
               let urlStr = firstImage["url"] as? String
            {
                return try downloadAndReturnImage(urlStr: urlStr, request: request)
            }

            if let detail = data["detail"] as? String {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: detail
                )
            }
            if let errorObj = data["error"] as? [String: Any],
               let message = errorObj["message"] as? String
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: message
                )
            }
        default:
            break
        }
        return ImageGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: "Invalid response from Kling Image API"
        )
    }

    private func downloadAndReturnImage(
        urlStr: String,
        request: ImageGenerationRequest
    ) throws -> ImageGenerationResponse {
        guard let url = URL(string: urlStr) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid image URL"
            )
        }
        let imageData = try Data(contentsOf: url)
        let base64 = imageData.base64EncodedString()
        return ImageGenerationResponse(
            status: .GENERATED,
            base64: base64,
            cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let body = FalKlingImageO1Request(
            prompt: request.prompt,
            image_url: request.clientImage.map { toDataUri($0) },
            negative_prompt: request.negativePrompt,
            num_images: request.numberOfImages,
            aspect_ratio: getAspectRatio(from: request)
        )

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
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Kling v3 Pro Models

public final class G_FAL_KLING_V3_PRO_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V3_PRO_I2V
    }

    override var costPerSecond: Double {
        0.09
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(request.durationSeconds ?? 5)",
            negative_prompt: nil,
            generate_audio: request.generateAudio ?? true,
            end_image_url: request.clientLastFrame.map { toDataUri($0) }
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V3_PRO_T2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V3_PRO_T2V
    }

    override var costPerSecond: Double {
        0.09
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalKlingT2VRequest(
            prompt: request.prompt ?? "",
            duration: "\(request.durationSeconds ?? 5)",
            aspect_ratio: getAspectRatio(from: request),
            negative_prompt: nil,
            cfg_scale: nil,
            generate_audio: request.generateAudio ?? true
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

// MARK: - Kling v3 Standard Models

public final class G_FAL_KLING_V3_STD_T2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V3_STD_T2V
    }

    override var costPerSecond: Double {
        0.05
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalKlingT2VRequest(
            prompt: request.prompt ?? "",
            duration: "\(request.durationSeconds ?? 5)",
            aspect_ratio: getAspectRatio(from: request),
            negative_prompt: nil,
            cfg_scale: nil,
            generate_audio: request.generateAudio ?? true
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V3_STD_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V3_STD_I2V
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
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(request.durationSeconds ?? 5)",
            negative_prompt: nil,
            generate_audio: request.generateAudio ?? true,
            end_image_url: request.clientLastFrame.map { toDataUri($0) }
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

// MARK: - Kling v3 4K Models

public final class G_FAL_KLING_V3_4K_T2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V3_4K_T2V
    }

    override var costPerSecond: Double {
        0.18
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalKlingT2VRequest(
            prompt: request.prompt ?? "",
            duration: "\(request.durationSeconds ?? 5)",
            aspect_ratio: getAspectRatio(from: request),
            negative_prompt: nil,
            cfg_scale: nil,
            generate_audio: request.generateAudio ?? true
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_V3_4K_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_V3_4K_I2V
    }

    override var costPerSecond: Double {
        0.18
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(request.durationSeconds ?? 5)",
            negative_prompt: nil,
            generate_audio: request.generateAudio ?? true,
            end_image_url: request.clientLastFrame.map { toDataUri($0) }
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

// MARK: - Kling O3 4K Models

public final class G_FAL_KLING_O3_4K_T2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_O3_4K_T2V
    }

    override var costPerSecond: Double {
        0.20
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalKlingT2VRequest(
            prompt: request.prompt ?? "",
            duration: "\(request.durationSeconds ?? 5)",
            aspect_ratio: getAspectRatio(from: request),
            negative_prompt: nil,
            cfg_scale: nil,
            generate_audio: request.generateAudio ?? true
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_O3_4K_I2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_O3_4K_I2V
    }

    override var costPerSecond: Double {
        0.20
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalKlingI2VRequest(
            prompt: request.prompt ?? "",
            start_image_url: toDataUri(clientImage),
            duration: "\(request.durationSeconds ?? 5)",
            negative_prompt: nil,
            generate_audio: request.generateAudio ?? true,
            end_image_url: request.clientLastFrame.map { toDataUri($0) }
        )
        return try await performKlingRequest(request: request, body: body)
    }
}

public final class G_FAL_KLING_O3_4K_REF2V: FalKlingBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KLING_O3_4K_REF2V
    }

    override var costPerSecond: Double {
        0.20
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        var refImages: [FalKlingRefImage] = []
        if let refImageData = request.clientReferenceImages {
            for ref in refImageData {
                refImages.append(FalKlingRefImage(
                    image_url: toDataUri(ref.base64Image),
                    type: "subject"
                ))
            }
        } else if let clientImage = request.clientImage {
            refImages.append(FalKlingRefImage(
                image_url: toDataUri(clientImage),
                type: "subject"
            ))
        }

        guard !refImages.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires at least one reference image"
            )
        }

        let duration = request.durationSeconds ?? 5
        let body = FalKlingRef2VRequest(
            prompt: request.prompt ?? "",
            reference_images: refImages,
            duration: "\(duration)",
            negative_prompt: request.negativePrompt
        )
        return try await performKlingRequest(request: request, body: body)
    }
}
