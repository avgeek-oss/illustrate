// MARK: - G_FAL_GOOGLE_OMNI.swift

// Gemini Omni Flash video generation models via Fal.ai.

import Foundation

private struct FalGoogleOmniTextToVideoRequest: Codable {
    let prompt: String
    let aspect_ratio: String
    let duration: Int
}

private struct FalGoogleOmniImageToVideoRequest: Codable {
    let prompt: String
    let image_url: String
    let aspect_ratio: String
    let duration: Int
}

private struct FalGoogleOmniEditVideoRequest: Codable {
    let prompt: String
    let video_url: String
}

private struct FalGoogleOmniReferenceToVideoRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let aspect_ratio: String
    let duration: Int
}

public class FalGoogleOmniFlashVideoBase: VideoGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var costPerSecond: Double {
        0.13
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    var defaultDuration: Int {
        8
    }

    public struct ServiceRequest: Codable, Sendable {
        let placeholder: Bool
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        ServiceRequest(placeholder: true)
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let durationSeconds = getDuration(request.durationSeconds)
        let numberOfVideos = request.numberOfVideos ?? 1
        return costPerSecond * Double(durationSeconds) * Double(numberOfVideos)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost) + "+"
    }

    func toDataUri(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:image/png;base64,\(base64)"
    }

    func toVideoDataUri(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:video/mp4;base64,\(base64)"
    }

    func getAspectRatio(_ dimensions: String) -> String {
        let normalized = dimensions.lowercased()
        if normalized == "9:16" { return "9:16" }
        if normalized == "16:9" { return "16:9" }

        let parts = normalized.split(separator: "x")
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1])
        else {
            return "16:9"
        }

        return height > width ? "9:16" : "16:9"
    }

    func getDuration(_ durationSeconds: Int?) -> Int {
        let duration = durationSeconds ?? defaultDuration
        return Swift.max(3, Swift.min(10, duration))
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let video = data["video"] as? [String: Any],
               let urlStr = video["url"] as? String
            {
                return try downloadAndReturnVideo(urlStr: urlStr, request: request)
            }

            if let detail = data["detail"] as? String {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: detail,
                    rawResponse: response.rawResponseString
                )
            }
            if let errorObj = data["error"] as? [String: Any],
               let message = errorObj["message"] as? String
            {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: message,
                    rawResponse: response.rawResponseString
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
        if urlStr.hasPrefix("data:") {
            let base64 = urlStr.replacingOccurrences(
                of: "^data:.*;base64,",
                with: "",
                options: .regularExpression
            )
            return VideoGenerationResponse(
                status: .GENERATED,
                base64: base64,
                cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
                modelPrompt: request.prompt
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
        return VideoGenerationResponse(
            status: .GENERATED,
            base64: videoData.base64EncodedString(),
            cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
            modelPrompt: request.prompt
        )
    }

    func performOmniRequest(
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

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        fatalError("Subclass must override makeRequest")
    }
}

public final class G_FAL_GOOGLE_GEMINI_OMNI_FLASH_T2V: FalGoogleOmniFlashVideoBase {
    override public init() {}

    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_GEMINI_OMNI_FLASH_T2V
    }

    override var costPerSecond: Double {
        0.125
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let body = FalGoogleOmniTextToVideoRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: getAspectRatio(request.dimensions),
            duration: getDuration(request.durationSeconds)
        )
        return try await performOmniRequest(request: request, body: body)
    }
}

public final class G_FAL_GOOGLE_GEMINI_OMNI_FLASH_I2V: FalGoogleOmniFlashVideoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_GEMINI_OMNI_FLASH_I2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientImage = request.clientImage, !clientImage.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = FalGoogleOmniImageToVideoRequest(
            prompt: request.prompt ?? "",
            image_url: toDataUri(clientImage),
            aspect_ratio: getAspectRatio(request.dimensions),
            duration: getDuration(request.durationSeconds)
        )
        return try await performOmniRequest(request: request, body: body)
    }
}

public final class G_FAL_GOOGLE_GEMINI_OMNI_FLASH_EDIT: FalGoogleOmniFlashVideoBase {
    override public init() {}

    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_GEMINI_OMNI_FLASH_EDIT
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let clientVideo = request.clientVideo, !clientVideo.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input video"
            )
        }

        let body = FalGoogleOmniEditVideoRequest(
            prompt: request.prompt ?? "",
            video_url: toVideoDataUri(clientVideo)
        )
        return try await performOmniRequest(request: request, body: body)
    }
}

public final class G_FAL_GOOGLE_GEMINI_OMNI_FLASH_REF2V: FalGoogleOmniFlashVideoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_GEMINI_OMNI_FLASH_REF2V
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let referenceImages = request.clientReferenceImages, !referenceImages.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires reference images"
            )
        }

        let imageUrls = referenceImages.prefix(10).map { toDataUri($0.base64Image) }
        let body = FalGoogleOmniReferenceToVideoRequest(
            prompt: request.prompt ?? "",
            image_urls: Array(imageUrls),
            aspect_ratio: getAspectRatio(request.dimensions),
            duration: getDuration(request.durationSeconds)
        )
        return try await performOmniRequest(request: request, body: body)
    }
}
