// MARK: - G_FAL_ZIMAGE.swift

// Z-Image Turbo models via Fal AI:
// - fal-ai/z-image/turbo
// - fal-ai/z-image/turbo/image-to-image
// - fal-ai/z-image/turbo/inpaint
// - fal-ai/z-image/turbo/inpaint/lora

import Foundation

// MARK: - Base Class

public class FalZImageBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var costPerMegapixel: Double {
        0.005
    } // $0.005/mp base, $0.01 inpaint, $0.0115 inpaint+lora

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public struct ServiceRequest: Codable, Sendable { let placeholder: Bool }

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

    func performZImageRequest(
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

    func clampDouble(_ value: Double?, min: Double, max: Double, defaultValue: Double) -> Double {
        guard let value else { return defaultValue }
        return Swift.max(min, Swift.min(max, value))
    }

    func normalizeImageSize(from dimensions: String) -> String {
        // Support both "WxH" and "W:H" formats
        let normalized = dimensions.replacingOccurrences(of: "x", with: ":").lowercased()

        switch normalized {
        case "1:1", "1024:1024", "512:512", "768:768", "square", "square_hd":
            return "square_hd"
        case "4:3", "1024:768", "1536:1152", "landscape_4_3":
            return "landscape_4_3"
        case "3:4", "768:1024", "1152:1536", "portrait_4_3":
            return "portrait_4_3"
        case "16:9", "1920:1080", "1536:864", "landscape_16_9":
            return "landscape_16_9"
        case "9:16", "1080:1920", "864:1536", "portrait_16_9":
            return "portrait_16_9"
        default:
            return "landscape_4_3"
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

// MARK: - Z-Image Turbo (Text-to-Image)

private struct ZImageTurboTextRequest: Codable {
    let prompt: String
    let image_size: String?
    let num_inference_steps: Int?
    let seed: Int?
    let num_images: Int?
    let enable_prompt_expansion: Bool?
    let sync_mode: Bool
}

public final class G_FAL_ZIMAGE_TURBO: FalZImageBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_ZIMAGE_TURBO
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = ZImageTurboTextRequest(
            prompt: request.prompt,
            image_size: normalizeImageSize(from: request.dimensions),
            num_inference_steps: clampInt(request.steps, min: 1, max: 8, defaultValue: 8),
            seed: request.seed,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            enable_prompt_expansion: request.promptEnhance,
            sync_mode: true
        )
        return try await performZImageRequest(request: request, body: body)
    }
}

// MARK: - Z-Image Turbo Image-to-Image

private struct ZImageTurboI2IRequest: Codable {
    let prompt: String
    let image_url: String
    let image_size: String?
    let num_inference_steps: Int?
    let seed: Int?
    let num_images: Int?
    let enable_prompt_expansion: Bool?
    let strength: Double?
    let sync_mode: Bool
}

public final class G_FAL_ZIMAGE_TURBO_IMAGE_TO_IMAGE: FalZImageBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_ZIMAGE_TURBO_IMAGE_TO_IMAGE
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

        let body = ZImageTurboI2IRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            image_size: "auto",
            num_inference_steps: clampInt(request.steps, min: 1, max: 8, defaultValue: 8),
            seed: request.seed,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            enable_prompt_expansion: request.promptEnhance,
            strength: clampDouble(request.guidance.map { $0 / 10.0 }, min: 0, max: 1, defaultValue: 0.6),
            sync_mode: true
        )
        return try await performZImageRequest(request: request, body: body)
    }
}

// MARK: - Z-Image Turbo Inpaint

private struct ZImageTurboInpaintRequest: Codable {
    let prompt: String
    let image_url: String
    let mask_image_url: String
    let image_size: String?
    let num_inference_steps: Int?
    let seed: Int?
    let num_images: Int?
    let enable_prompt_expansion: Bool?
    let strength: Double?
    let control_scale: Double?
    let sync_mode: Bool
}

public final class G_FAL_ZIMAGE_TURBO_INPAINT: FalZImageBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_ZIMAGE_TURBO_INPAINT
    }

    override var costPerMegapixel: Double {
        0.01
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
        guard let clientMask = request.clientMask else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a mask image"
            )
        }

        let body = ZImageTurboInpaintRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            mask_image_url: toDataUri(clientMask),
            image_size: "auto",
            num_inference_steps: clampInt(request.steps, min: 1, max: 8, defaultValue: 8),
            seed: request.seed,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            enable_prompt_expansion: request.promptEnhance,
            strength: 1.0,
            control_scale: 0.75,
            sync_mode: true
        )
        return try await performZImageRequest(request: request, body: body)
    }
}

// MARK: - Z-Image Turbo Inpaint LoRA

private struct ZImageTurboInpaintLoraRequest: Codable {
    let prompt: String
    let image_url: String
    let mask_image_url: String
    let image_size: String?
    let num_inference_steps: Int?
    let seed: Int?
    let num_images: Int?
    let enable_prompt_expansion: Bool?
    let strength: Double?
    let control_scale: Double?
    let sync_mode: Bool
}

public final class G_FAL_ZIMAGE_TURBO_INPAINT_LORA: FalZImageBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_ZIMAGE_TURBO_INPAINT_LORA
    }

    override var costPerMegapixel: Double {
        0.0115
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
        guard let clientMask = request.clientMask else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a mask image"
            )
        }

        let body = ZImageTurboInpaintLoraRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            mask_image_url: toDataUri(clientMask),
            image_size: "auto",
            num_inference_steps: clampInt(request.steps, min: 1, max: 8, defaultValue: 8),
            seed: request.seed,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            enable_prompt_expansion: request.promptEnhance,
            strength: 1.0,
            control_scale: 0.75,
            sync_mode: true
        )
        return try await performZImageRequest(request: request, body: body)
    }
}
