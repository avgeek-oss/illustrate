// MARK: - G_FAL_GPT_IMAGE.swift

// OpenAI GPT Image models via Fal AI:
// - fal-ai/gpt-image-1-mini
// - fal-ai/gpt-image-1-mini/edit
// - fal-ai/gpt-image-1/text-to-image
// - fal-ai/gpt-image-1/edit-image
// - fal-ai/gpt-image-1.5
// - fal-ai/gpt-image-1.5/edit
// - openai/gpt-image-2
// - openai/gpt-image-2/edit

import Foundation

// MARK: - Base Class

public class FalGptImageBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var baseCost: Double {
        0.02
    } // mini=$0.02, gpt-1=$0.04, gpt-1.5=$0.001

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public struct ServiceRequest: Codable, Sendable { let placeholder: Bool }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        ServiceRequest(placeholder: true)
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let images = data["images"] as? [[String: Any]],
               let urlStr = images.first?["url"] as? String
            {
                return try downloadAndReturnImage(urlStr: urlStr, request: request)
            }

            if let error = data["detail"] as? String {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: error,
                    rawResponse: extractRawResponse(from: response)
                )
            }
            if let errorObj = data["error"] as? [String: Any],
               let message = errorObj["message"] as? String
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: message,
                    rawResponse: extractRawResponse(from: response)
                )
            }
        default:
            break
        }
        return createInvalidResponseError(response: response, modelCode: modelCode)
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        fatalError("Subclass must override makeRequest")
    }

    // MARK: - Helpers

    func performGptImageRequest(
        request: ImageGenerationRequest,
        body: some Codable & Sendable
    ) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(
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
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }

    func toDataUri(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:image/png;base64,\(base64)"
    }

    func clampInt(_ value: Int?, min: Int, max: Int, defaultValue: Int) -> Int {
        guard let value else { return defaultValue }
        return Swift.max(min, Swift.min(max, value))
    }

    func normalizeImageSize(from dimensions: String) -> String {
        // Support both "WxH" and "W:H" formats
        let normalized = dimensions.replacingOccurrences(of: ":", with: "x").lowercased()

        switch normalized {
        case "1024x1024", "1x1", "square", "square_hd":
            return "1024x1024"
        case "1536x1024", "3x2", "landscape_4_3", "landscape":
            return "1536x1024"
        case "1024x1536", "2x3", "portrait_4_3", "portrait":
            return "1024x1536"
        default:
            return "auto"
        }
    }

    private func downloadAndReturnImage(
        urlStr: String,
        request: ImageGenerationRequest
    ) throws -> ImageGenerationResponse {
        if urlStr.contains("base64") {
            let base64 = urlStr.replacingOccurrences(
                of: "^data:.*;base64,",
                with: "",
                options: .regularExpression
            )
            return ImageGenerationResponse(
                status: .GENERATED,
                base64: base64,
                cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
            )
        }

        let url = URL(string: urlStr)!
        let imageData = try Data(contentsOf: url)
        return ImageGenerationResponse(
            status: .GENERATED,
            base64: imageData.base64EncodedString(),
            cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }
}

// MARK: - GPT Image 1 Mini Text-to-Image

private struct GptImageMiniTextRequest: Codable {
    let prompt: String
    let image_size: String?
    let background: String?
    let quality: String?
    let num_images: Int?
    let sync_mode: Bool
}

public final class G_FAL_GPT_IMAGE_1_MINI: FalGptImageBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GPT_IMAGE_1_MINI
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = GptImageMiniTextRequest(
            prompt: request.prompt,
            image_size: normalizeImageSize(from: request.dimensions),
            background: "auto",
            quality: "auto",
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            sync_mode: true
        )
        return try await performGptImageRequest(request: request, body: body)
    }
}

// MARK: - GPT Image 1 Mini Edit

private struct GptImageMiniEditRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let image_size: String?
    let background: String?
    let quality: String?
    let num_images: Int?
    let sync_mode: Bool
}

public final class G_FAL_GPT_IMAGE_1_MINI_EDIT: FalGptImageBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GPT_IMAGE_1_MINI_EDIT
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = GptImageMiniEditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            image_size: "auto",
            background: "auto",
            quality: "auto",
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            sync_mode: true
        )
        return try await performGptImageRequest(request: request, body: body)
    }
}

// MARK: - GPT Image 1 Text-to-Image

private struct GptImage1TextRequest: Codable {
    let prompt: String
    let image_size: String?
    let background: String?
    let quality: String?
    let num_images: Int?
    let sync_mode: Bool
}

public final class G_FAL_GPT_IMAGE_1: FalGptImageBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GPT_IMAGE_1
    }

    override var baseCost: Double {
        0.04
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = GptImage1TextRequest(
            prompt: request.prompt,
            image_size: normalizeImageSize(from: request.dimensions),
            background: "auto",
            quality: "auto",
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            sync_mode: true
        )
        return try await performGptImageRequest(request: request, body: body)
    }
}

// MARK: - GPT Image 1 Edit

private struct GptImage1EditRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let image_size: String?
    let background: String?
    let quality: String?
    let input_fidelity: String?
    let num_images: Int?
    let sync_mode: Bool
}

public final class G_FAL_GPT_IMAGE_1_EDIT: FalGptImageBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GPT_IMAGE_1_EDIT
    }

    override var baseCost: Double {
        0.04
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = GptImage1EditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            image_size: "auto",
            background: "auto",
            quality: "auto",
            input_fidelity: "high",
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            sync_mode: true
        )
        return try await performGptImageRequest(request: request, body: body)
    }
}

// MARK: - GPT Image 1.5 Text-to-Image

private struct GptImage15TextRequest: Codable {
    let prompt: String
    let image_size: String?
    let background: String?
    let quality: String?
    let num_images: Int?
    let sync_mode: Bool
}

public final class G_FAL_GPT_IMAGE_15: FalGptImageBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GPT_IMAGE_15
    }

    override var baseCost: Double {
        0.001
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = GptImage15TextRequest(
            prompt: request.prompt,
            image_size: normalizeImageSize(from: request.dimensions),
            background: "auto",
            quality: "high",
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            sync_mode: true
        )
        return try await performGptImageRequest(request: request, body: body)
    }
}

// MARK: - GPT Image 1.5 Edit

private struct GptImage15EditRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let image_size: String?
    let background: String?
    let quality: String?
    let input_fidelity: String?
    let num_images: Int?
    let mask_image_url: String?
    let sync_mode: Bool
}

public final class G_FAL_GPT_IMAGE_15_EDIT: FalGptImageBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GPT_IMAGE_15_EDIT
    }

    override var baseCost: Double {
        0.001
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let maskUrl: String? = request.clientMask.map { toDataUri($0) }

        let body = GptImage15EditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            image_size: "auto",
            background: "auto",
            quality: "high",
            input_fidelity: "high",
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            mask_image_url: maskUrl,
            sync_mode: true
        )
        return try await performGptImageRequest(request: request, body: body)
    }
}

// MARK: - GPT Image 2 Text-to-Image

private struct GptImage2TextRequest: Codable {
    let prompt: String
    let image_size: String?
    let quality: String?
    let num_images: Int?
    let sync_mode: Bool
}

public final class G_FAL_GPT_IMAGE_2: FalGptImageBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GPT_IMAGE_2
    }

    override var baseCost: Double {
        0.04
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = GptImage2TextRequest(
            prompt: request.prompt,
            image_size: normalizeImageSize(from: request.dimensions),
            quality: "high",
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            sync_mode: true
        )
        return try await performGptImageRequest(request: request, body: body)
    }
}

// MARK: - GPT Image 2 Edit

private struct GptImage2EditRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let image_size: String?
    let quality: String?
    let num_images: Int?
    let mask_image_url: String?
    let sync_mode: Bool
}

public final class G_FAL_GPT_IMAGE_2_EDIT: FalGptImageBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GPT_IMAGE_2_EDIT
    }

    override var baseCost: Double {
        0.05
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let maskUrl: String? = request.clientMask.map { toDataUri($0) }

        let body = GptImage2EditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            image_size: "auto",
            quality: "high",
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            mask_image_url: maskUrl,
            sync_mode: true
        )
        return try await performGptImageRequest(request: request, body: body)
    }
}
