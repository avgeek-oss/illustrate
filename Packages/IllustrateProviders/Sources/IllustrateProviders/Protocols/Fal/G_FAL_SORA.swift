// MARK: - G_FAL_SORA.swift

// OpenAI Sora video generation models via Fal.ai
//
// Supported models:
// - Sora 2 Pro: Text-to-video and Image-to-video (up to 1080p)
// - Sora 2: Text-to-video and Image-to-video (720p)
//
// All models support:
// - Audio generation
// - Duration: 4, 8, or 12 seconds
// - Aspect ratios: 16:9, 9:16
// - Privacy deletion option
//
// Pricing: $0.10/second for all models

import Foundation

// MARK: - Request Structs

struct FalSoraT2VRequest: Codable {
    let prompt: String
    let resolution: String?
    let aspect_ratio: String?
    let duration: Int?
    let delete_video: Bool?
    let model: String?
}

struct FalSoraI2VRequest: Codable {
    let prompt: String
    let image_url: String
    let resolution: String?
    let aspect_ratio: String?
    let duration: Int?
    let delete_video: Bool?
    let model: String?
}

// MARK: - Base Class

public class FalSoraBase: VideoGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var costPerSecond: Double {
        0.10
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    var defaultDuration: Int {
        model.modelParams.supportedVideoDurations.first ?? 4
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

    /// Convert aspect ratio from dimensions to format like "16:9"
    func getAspectRatio(from request: VideoGenerationRequest) -> String? {
        let dimensions = request.dimensions
        guard !dimensions.isEmpty else { return nil }
        if dimensions.contains("16:9") || dimensions.contains("landscape") {
            return "16:9"
        } else if dimensions.contains("9:16") || dimensions.contains("portrait") {
            return "9:16"
        }
        return dimensions
    }

    /// Get resolution string
    func getResolution(from request: VideoGenerationRequest) -> String? {
        guard let resolution = request.resolution, !resolution.isEmpty else {
            return nil
        }
        return resolution
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

    func performSoraRequest(
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

// MARK: - Sora 2 Pro Models

public final class G_FAL_SORA_2_PRO_T2V: FalSoraBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SORA_2_PRO_T2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalSoraT2VRequest(
            prompt: request.prompt ?? "",
            resolution: getResolution(from: request) ?? "1080p",
            aspect_ratio: getAspectRatio(from: request) ?? "16:9",
            duration: request.durationSeconds ?? 4,
            delete_video: true,
            model: nil
        )
        return try await performSoraRequest(request: request, body: body)
    }
}

public final class G_FAL_SORA_2_PRO_I2V: FalSoraBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SORA_2_PRO_I2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalSoraI2VRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            resolution: getResolution(from: request) ?? "auto",
            aspect_ratio: getAspectRatio(from: request) ?? "auto",
            duration: request.durationSeconds ?? 4,
            delete_video: true,
            model: nil
        )
        return try await performSoraRequest(request: request, body: body)
    }
}

// MARK: - Sora 2 Standard Models

public final class G_FAL_SORA_2_T2V: FalSoraBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SORA_2_T2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalSoraT2VRequest(
            prompt: request.prompt ?? "",
            resolution: "720p",
            aspect_ratio: getAspectRatio(from: request) ?? "16:9",
            duration: request.durationSeconds ?? 4,
            delete_video: true,
            model: "sora-2"
        )
        return try await performSoraRequest(request: request, body: body)
    }
}

public final class G_FAL_SORA_2_I2V: FalSoraBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_SORA_2_I2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FalSoraI2VRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            resolution: getResolution(from: request) ?? "auto",
            aspect_ratio: getAspectRatio(from: request) ?? "auto",
            duration: request.durationSeconds ?? 4,
            delete_video: true,
            model: "sora-2"
        )
        return try await performSoraRequest(request: request, body: body)
    }
}
