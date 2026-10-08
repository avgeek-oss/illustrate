// MARK: - G_FAL_GLM.swift

// GLM Image models via Fal AI:
// - fal-ai/glm-image (text-to-image)
// - fal-ai/glm-image/image-to-image (image-to-image)

import Foundation

// MARK: - Base Class

public class FalGlmBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var costPerMegapixel: Double {
        0.05
    } // $0.05/megapixel

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    /// Required by protocol - placeholder
    public struct ServiceRequest: Codable, Sendable {
        let placeholder: Bool
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        ServiceRequest(placeholder: true)
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let megapixels = falParseMegapixels(from: request.dimensions)
        return costPerMegapixel * megapixels * Double(request.numberOfImages ?? 1)
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
            // GLM models return: { images: [ { url } ] }
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

    func performGlmRequest(
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

    /// Converts dimensions to GLM image_size format.
    /// GLM supports: "square_hd", "square", "portrait_4_3", "portrait_16_9", "landscape_4_3", "landscape_16_9"
    func normalizeImageSize(from dimensions: String) -> String {
        // If already in GLM format, return as-is
        let glmSizes = ["square_hd", "square", "portrait_4_3", "portrait_16_9", "landscape_4_3", "landscape_16_9"]
        if glmSizes.contains(dimensions) { return dimensions }

        // Handle aspect ratio format (e.g., "1:1", "16:9")
        if dimensions.contains(":") {
            switch dimensions {
            case "1:1": return "square_hd"
            case "4:3": return "landscape_4_3"
            case "3:4": return "portrait_4_3"
            case "16:9": return "landscape_16_9"
            case "9:16": return "portrait_16_9"
            default: return "square_hd"
            }
        }

        // Handle pixel dimensions (e.g., "1024x1024")
        let parts = dimensions.split(separator: "x")
        guard parts.count == 2,
              let w = Double(parts[0]),
              let h = Double(parts[1]),
              w > 0, h > 0
        else {
            return "square_hd"
        }

        let ratio = w / h
        if abs(ratio - 1.0) < 0.1 {
            return "square_hd"
        } else if ratio > 1.0 {
            // Landscape
            return ratio > 1.5 ? "landscape_16_9" : "landscape_4_3"
        } else {
            // Portrait
            return ratio < 0.67 ? "portrait_16_9" : "portrait_4_3"
        }
    }

    func clampInt(_ value: Int?, min: Int, max: Int, defaultValue: Int) -> Int {
        guard let value else { return defaultValue }
        return Swift.max(min, Swift.min(max, value))
    }

    func clampDouble(_ value: Double?, min: Double, max: Double, defaultValue: Double) -> Double {
        guard let value else { return defaultValue }
        return Swift.max(min, Swift.min(max, value))
    }

    private func downloadAndReturnImage(
        urlStr: String,
        request: ImageGenerationRequest
    ) throws -> ImageGenerationResponse {
        // Handle base64 data URIs
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

// MARK: - Text-to-Image Model

/// Request body for text-to-image (glm-image)
private struct GlmImageTextRequest: Codable {
    let prompt: String
    let image_size: String?
    let num_inference_steps: Int?
    let guidance_scale: Double?
    let seed: Int?
    let num_images: Int?
    let enable_prompt_expansion: Bool?
    let sync_mode: Bool
}

/// GLM Image - Text-to-image with accurate text rendering
public final class G_FAL_GLM_IMAGE: FalGlmBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GLM_IMAGE
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Prompt is required"
            )
        }

        let steps = clampInt(request.steps, min: 10, max: 100, defaultValue: 30)
        let guidance = clampDouble(request.guidance, min: 1, max: 10, defaultValue: 1.5)
        let numImages = clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1)

        let body = GlmImageTextRequest(
            prompt: request.prompt,
            image_size: normalizeImageSize(from: request.dimensions),
            num_inference_steps: steps,
            guidance_scale: guidance,
            seed: request.seed,
            num_images: numImages,
            enable_prompt_expansion: request.promptEnhance,
            sync_mode: true
        )
        return try await performGlmRequest(request: request, body: body)
    }
}

// MARK: - Image-to-Image Model

/// Request body for image-to-image (glm-image/image-to-image)
private struct GlmImageToImageRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let image_size: String?
    let num_inference_steps: Int?
    let guidance_scale: Double?
    let seed: Int?
    let num_images: Int?
    let enable_prompt_expansion: Bool?
    let sync_mode: Bool
}

/// GLM Image-to-Image - Edit images with text instructions
public final class G_FAL_GLM_IMAGE_TO_IMAGE: FalGlmBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GLM_IMAGE_TO_IMAGE
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Prompt is required"
            )
        }

        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let steps = clampInt(request.steps, min: 10, max: 100, defaultValue: 30)
        let guidance = clampDouble(request.guidance, min: 1, max: 10, defaultValue: 1.5)
        let numImages = clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1)

        let body = GlmImageToImageRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            image_size: normalizeImageSize(from: request.dimensions),
            num_inference_steps: steps,
            guidance_scale: guidance,
            seed: request.seed,
            num_images: numImages,
            enable_prompt_expansion: request.promptEnhance,
            sync_mode: true
        )
        return try await performGlmRequest(request: request, body: body)
    }
}
