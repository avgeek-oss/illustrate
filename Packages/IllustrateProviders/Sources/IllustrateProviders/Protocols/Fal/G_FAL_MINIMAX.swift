// MARK: - G_FAL_MINIMAX.swift

// MiniMax video generation models via Fal.ai
//
// Supported models:
// - Hailuo 2.3 Pro/Standard: Advanced video generation (1080p/768p)
// - Hailuo 2.3 Fast: Faster generation
// - Hailuo 02 Pro/Standard: Per-second pricing (1080p/768p)
// - Video-01: Image-to-video, Director (camera controls), Live, Subject Reference
//
// Pricing:
// - Hailuo 2.3 Pro: $0.49/video
// - Hailuo 2.3 Standard: $0.28/video
// - Hailuo 2.3 Fast Pro: $0.33/video
// - Hailuo 2.3 Fast Standard: $0.19/video
// - Hailuo 02 Pro: $0.08/sec
// - Hailuo 02 Standard: $0.045/sec
// - Video-01: $0.50/video

import Foundation

// MARK: - Request Structs

struct FalMinimaxT2VRequest: Codable {
    let prompt: String
    let prompt_optimizer: Bool?
    let duration: String?
}

struct FalMinimaxI2VRequest: Codable {
    let prompt: String
    let image_url: String
    let prompt_optimizer: Bool?
    let duration: String?
    let end_image_url: String?
}

struct FalMinimaxSubjectRefRequest: Codable {
    let prompt: String
    let subject_reference_image_url: String
    let prompt_optimizer: Bool?
}

// MARK: - Base Class

public class FalMinimaxBase: VideoGenerationProtocol {
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
        model.modelParams.supportedVideoDurations.first ?? 6
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

    func performMinimaxRequest(
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

public class FalMinimaxPerSecondBase: FalMinimaxBase {
    var costPerSecond: Double {
        0.08
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let durationSeconds = Double(request.durationSeconds ?? 6)
        let numberOfVideos = request.numberOfVideos ?? 1
        return costPerSecond * durationSeconds * Double(numberOfVideos)
    }
}

// MARK: - Hailuo 2.3 Pro Models

public final class G_FAL_MINIMAX_HAILUO_23_PRO_T2V: FalMinimaxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_HAILUO_23_PRO_T2V
    }

    override var costPerVideo: Double {
        0.49
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalMinimaxT2VRequest(
            prompt: request.prompt ?? "",
            prompt_optimizer: request.promptEnhance ?? true,
            duration: nil
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

public final class G_FAL_MINIMAX_HAILUO_23_PRO_I2V: FalMinimaxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_HAILUO_23_PRO_I2V
    }

    override var costPerVideo: Double {
        0.49
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalMinimaxI2VRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            prompt_optimizer: request.promptEnhance ?? true,
            duration: nil,
            end_image_url: nil
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

// MARK: - Hailuo 2.3 Standard Models

public final class G_FAL_MINIMAX_HAILUO_23_STD_T2V: FalMinimaxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_HAILUO_23_STD_T2V
    }

    override var costPerVideo: Double {
        0.28
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let duration = request.durationSeconds ?? 6
        let body = FalMinimaxT2VRequest(
            prompt: request.prompt ?? "",
            prompt_optimizer: request.promptEnhance ?? true,
            duration: "\(duration)"
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

public final class G_FAL_MINIMAX_HAILUO_23_STD_I2V: FalMinimaxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_HAILUO_23_STD_I2V
    }

    override var costPerVideo: Double {
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
        let duration = request.durationSeconds ?? 6
        let body = FalMinimaxI2VRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            prompt_optimizer: request.promptEnhance ?? true,
            duration: "\(duration)",
            end_image_url: nil
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

// MARK: - Hailuo 2.3 Fast Models

public final class G_FAL_MINIMAX_HAILUO_23_FAST_PRO_I2V: FalMinimaxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_HAILUO_23_FAST_PRO_I2V
    }

    override var costPerVideo: Double {
        0.33
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalMinimaxI2VRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            prompt_optimizer: request.promptEnhance ?? true,
            duration: nil,
            end_image_url: nil
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

public final class G_FAL_MINIMAX_HAILUO_23_FAST_STD_I2V: FalMinimaxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_HAILUO_23_FAST_STD_I2V
    }

    override var costPerVideo: Double {
        0.19
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalMinimaxI2VRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            prompt_optimizer: request.promptEnhance ?? true,
            duration: nil,
            end_image_url: nil
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

// MARK: - Hailuo 02 Pro Models

public final class G_FAL_MINIMAX_HAILUO_02_PRO_T2V: FalMinimaxPerSecondBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_HAILUO_02_PRO_T2V
    }

    override var costPerVideo: Double {
        0.48
    } // Fallback ~6s
    override var costPerSecond: Double {
        0.08
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalMinimaxT2VRequest(
            prompt: request.prompt ?? "",
            prompt_optimizer: request.promptEnhance ?? true,
            duration: nil
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

public final class G_FAL_MINIMAX_HAILUO_02_PRO_I2V: FalMinimaxPerSecondBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_HAILUO_02_PRO_I2V
    }

    override var costPerVideo: Double {
        0.48
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
        let body = FalMinimaxI2VRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            prompt_optimizer: request.promptEnhance ?? true,
            duration: nil,
            end_image_url: request.clientLastFrame.map { toDataUri($0) }
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

// MARK: - Hailuo 02 Standard Models

public final class G_FAL_MINIMAX_HAILUO_02_STD_T2V: FalMinimaxPerSecondBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_HAILUO_02_STD_T2V
    }

    override var costPerVideo: Double {
        0.27
    } // Fallback ~6s
    override var costPerSecond: Double {
        0.045
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalMinimaxT2VRequest(
            prompt: request.prompt ?? "",
            prompt_optimizer: request.promptEnhance ?? true,
            duration: nil
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

public final class G_FAL_MINIMAX_HAILUO_02_STD_I2V: FalMinimaxPerSecondBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_HAILUO_02_STD_I2V
    }

    override var costPerVideo: Double {
        0.27
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
        let body = FalMinimaxI2VRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            prompt_optimizer: request.promptEnhance ?? true,
            duration: nil,
            end_image_url: nil
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

// MARK: - Video-01 Models

public final class G_FAL_MINIMAX_VIDEO_01_I2V: FalMinimaxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_VIDEO_01_I2V
    }

    override var costPerVideo: Double {
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
        let body = FalMinimaxI2VRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            prompt_optimizer: request.promptEnhance ?? true,
            duration: nil,
            end_image_url: nil
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

public final class G_FAL_MINIMAX_VIDEO_01_DIRECTOR: FalMinimaxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_VIDEO_01_DIRECTOR
    }

    override var costPerVideo: Double {
        0.50
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalMinimaxT2VRequest(
            prompt: request.prompt ?? "",
            prompt_optimizer: request.promptEnhance ?? true,
            duration: nil
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

public final class G_FAL_MINIMAX_VIDEO_01_DIRECTOR_I2V: FalMinimaxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_VIDEO_01_DIRECTOR_I2V
    }

    override var costPerVideo: Double {
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
        let body = FalMinimaxI2VRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            prompt_optimizer: request.promptEnhance ?? true,
            duration: nil,
            end_image_url: nil
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

public final class G_FAL_MINIMAX_VIDEO_01_LIVE: FalMinimaxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_VIDEO_01_LIVE
    }

    override var costPerVideo: Double {
        0.50
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalMinimaxT2VRequest(
            prompt: request.prompt ?? "",
            prompt_optimizer: request.promptEnhance ?? true,
            duration: nil
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

public final class G_FAL_MINIMAX_VIDEO_01_LIVE_I2V: FalMinimaxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_VIDEO_01_LIVE_I2V
    }

    override var costPerVideo: Double {
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
        let body = FalMinimaxI2VRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            prompt_optimizer: request.promptEnhance ?? true,
            duration: nil,
            end_image_url: nil
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}

public final class G_FAL_MINIMAX_VIDEO_01_SUBJECT_REF: FalMinimaxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_MINIMAX_VIDEO_01_SUBJECT_REF
    }

    override var costPerVideo: Double {
        0.50
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a subject reference image"
            )
        }
        let body = FalMinimaxSubjectRefRequest(
            prompt: request.prompt ?? "",
            subject_reference_image_url: toDataUri(clientImage),
            prompt_optimizer: request.promptEnhance ?? true
        )
        return try await performMinimaxRequest(request: request, body: body)
    }
}
