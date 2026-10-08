// MARK: - G_FAL_QWEN.swift

// Qwen Image models via Fal AI:
// - fal-ai/qwen-image (text-to-image)
// - fal-ai/qwen-image-2512 (text-to-image)
// - fal-ai/qwen-image/image-to-image (image-to-image)
// - fal-ai/qwen-image-edit (image-to-image)
// - fal-ai/qwen-image-edit-plus (image-to-image, multi-image)
// - fal-ai/qwen-image-edit/image-to-image (image-to-image)
// - fal-ai/qwen-image-edit/inpaint (inpainting)
// - fal-ai/qwen-image-layered (layer decomposition)
// - fal-ai/qwen-image-edit-2511 (image-to-image)
// - fal-ai/qwen-image-edit-2511-multiple-angles (multi-angle generation)
// - fal-ai/qwen-image-edit-2509 (image-to-image, multi-image)

import Foundation

// MARK: - Base Class

public class FalQwenBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var costPerMegapixel: Double {
        0.02
    } // $0.02/megapixel for base, $0.03 for edit variants

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

    func performQwenRequest(
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

    func normalizeImageSize(from dimensions: String) -> String {
        let qwenSizes = ["square_hd", "square", "portrait_4_3", "portrait_16_9", "landscape_4_3", "landscape_16_9"]
        if qwenSizes.contains(dimensions) { return dimensions }

        if dimensions.contains(":") {
            switch dimensions {
            case "1:1": return "square_hd"
            case "4:3": return "landscape_4_3"
            case "3:4": return "portrait_4_3"
            case "16:9": return "landscape_16_9"
            case "9:16": return "portrait_16_9"
            default: return "landscape_4_3"
            }
        }

        let parts = dimensions.split(separator: "x")
        guard parts.count == 2,
              let w = Double(parts[0]),
              let h = Double(parts[1]),
              w > 0, h > 0
        else { return "landscape_4_3" }

        let ratio = w / h
        if abs(ratio - 1.0) < 0.1 { return "square_hd" }
        else if ratio > 1.0 { return ratio > 1.5 ? "landscape_16_9" : "landscape_4_3" }
        else { return ratio < 0.67 ? "portrait_16_9" : "portrait_4_3" }
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

// MARK: - Text-to-Image Models

private struct QwenImageTextRequest: Codable {
    let prompt: String
    let image_size: String?
    let num_inference_steps: Int?
    let guidance_scale: Double?
    let seed: Int?
    let num_images: Int?
    let negative_prompt: String?
    let sync_mode: Bool
}

/// Qwen Image - Text-to-image with complex text rendering
public final class G_FAL_QWEN_IMAGE: FalQwenBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_QWEN_IMAGE
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = QwenImageTextRequest(
            prompt: request.prompt,
            image_size: normalizeImageSize(from: request.dimensions),
            num_inference_steps: clampInt(request.steps, min: 2, max: 250, defaultValue: 30),
            guidance_scale: clampDouble(request.guidance, min: 0, max: 20, defaultValue: 2.5),
            seed: request.seed,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            negative_prompt: request.negativePrompt,
            sync_mode: true
        )
        return try await performQwenRequest(request: request, body: body)
    }
}

private struct QwenImage2512Request: Codable {
    let prompt: String
    let negative_prompt: String?
    let image_size: String?
    let num_inference_steps: Int?
    let guidance_scale: Double?
    let seed: Int?
    let num_images: Int?
    let sync_mode: Bool
}

/// Qwen Image 2512 - Improved text rendering and human generation
public final class G_FAL_QWEN_IMAGE_2512: FalQwenBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_QWEN_IMAGE_2512
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = QwenImage2512Request(
            prompt: request.prompt,
            negative_prompt: request.negativePrompt,
            image_size: normalizeImageSize(from: request.dimensions),
            num_inference_steps: clampInt(request.steps, min: 1, max: 50, defaultValue: 28),
            guidance_scale: clampDouble(request.guidance, min: 0, max: 20, defaultValue: 4),
            seed: request.seed,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            sync_mode: true
        )
        return try await performQwenRequest(request: request, body: body)
    }
}

// MARK: - Image-to-Image Models

private struct QwenImageToImageRequest: Codable {
    let prompt: String
    let image_url: String
    let strength: Double?
    let image_size: String?
    let num_inference_steps: Int?
    let guidance_scale: Double?
    let seed: Int?
    let num_images: Int?
    let negative_prompt: String?
    let sync_mode: Bool
}

/// Qwen Image-to-Image - Style transfer and modification
public final class G_FAL_QWEN_IMAGE_TO_IMAGE: FalQwenBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_QWEN_IMAGE_TO_IMAGE
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

        let strength = clampDouble(request.guidance.map { $0 / 10.0 }, min: 0, max: 1, defaultValue: 0.6)

        let body = QwenImageToImageRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            strength: strength,
            image_size: normalizeImageSize(from: request.dimensions),
            num_inference_steps: clampInt(request.steps, min: 2, max: 250, defaultValue: 30),
            guidance_scale: clampDouble(request.guidance, min: 0, max: 20, defaultValue: 2.5),
            seed: request.seed,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            negative_prompt: request.negativePrompt,
            sync_mode: true
        )
        return try await performQwenRequest(request: request, body: body)
    }
}

private struct QwenImageEditRequest: Codable {
    let prompt: String
    let image_url: String
    let image_size: String?
    let num_inference_steps: Int?
    let guidance_scale: Double?
    let seed: Int?
    let num_images: Int?
    let negative_prompt: String?
    let sync_mode: Bool
}

/// Qwen Image Edit - Superior text editing capabilities
public final class G_FAL_QWEN_IMAGE_EDIT: FalQwenBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_QWEN_IMAGE_EDIT
    }

    override var costPerMegapixel: Double {
        0.03
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

        let body = QwenImageEditRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            image_size: normalizeImageSize(from: request.dimensions),
            num_inference_steps: clampInt(request.steps, min: 2, max: 50, defaultValue: 30),
            guidance_scale: clampDouble(request.guidance, min: 0, max: 20, defaultValue: 4),
            seed: request.seed,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            negative_prompt: request.negativePrompt,
            sync_mode: true
        )
        return try await performQwenRequest(request: request, body: body)
    }
}

private struct QwenImageEditPlusRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let image_size: String?
    let num_inference_steps: Int?
    let guidance_scale: Double?
    let seed: Int?
    let num_images: Int?
    let negative_prompt: String?
    let sync_mode: Bool
}

/// Qwen Image Edit Plus (2509) - Multi-image support
public final class G_FAL_QWEN_IMAGE_EDIT_PLUS: FalQwenBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_QWEN_IMAGE_EDIT_PLUS
    }

    override var costPerMegapixel: Double {
        0.03
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

        let body = QwenImageEditPlusRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            image_size: normalizeImageSize(from: request.dimensions),
            num_inference_steps: clampInt(request.steps, min: 2, max: 100, defaultValue: 50),
            guidance_scale: clampDouble(request.guidance, min: 0, max: 20, defaultValue: 4),
            seed: request.seed,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            negative_prompt: request.negativePrompt,
            sync_mode: true
        )
        return try await performQwenRequest(request: request, body: body)
    }
}

private struct QwenImageEditI2IRequest: Codable {
    let prompt: String
    let image_url: String
    let strength: Double?
    let image_size: String?
    let num_inference_steps: Int?
    let guidance_scale: Double?
    let seed: Int?
    let num_images: Int?
    let negative_prompt: String?
    let sync_mode: Bool
}

/// Qwen Image Edit Image-to-Image
public final class G_FAL_QWEN_IMAGE_EDIT_IMAGE_TO_IMAGE: FalQwenBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_QWEN_IMAGE_EDIT_IMAGE_TO_IMAGE
    }

    override var costPerMegapixel: Double {
        0.03
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

        let body = QwenImageEditI2IRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            strength: clampDouble(request.guidance.map { $0 / 10.0 }, min: 0.01, max: 1, defaultValue: 0.94),
            image_size: normalizeImageSize(from: request.dimensions),
            num_inference_steps: clampInt(request.steps, min: 2, max: 50, defaultValue: 30),
            guidance_scale: clampDouble(request.guidance, min: 0, max: 20, defaultValue: 4),
            seed: request.seed,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            negative_prompt: request.negativePrompt,
            sync_mode: true
        )
        return try await performQwenRequest(request: request, body: body)
    }
}

private struct QwenImageEditInpaintRequest: Codable {
    let prompt: String
    let image_url: String
    let mask_url: String
    let strength: Double?
    let image_size: String?
    let num_inference_steps: Int?
    let guidance_scale: Double?
    let seed: Int?
    let num_images: Int?
    let negative_prompt: String?
    let sync_mode: Bool
}

/// Qwen Image Edit Inpaint
public final class G_FAL_QWEN_IMAGE_EDIT_INPAINT: FalQwenBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_QWEN_IMAGE_EDIT_INPAINT
    }

    override var costPerMegapixel: Double {
        0.03
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
        guard let maskImage = request.clientMask else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a mask image"
            )
        }

        let body = QwenImageEditInpaintRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            mask_url: toDataUri(maskImage),
            strength: clampDouble(request.guidance.map { $0 / 10.0 }, min: 0.01, max: 1, defaultValue: 0.93),
            image_size: normalizeImageSize(from: request.dimensions),
            num_inference_steps: clampInt(request.steps, min: 2, max: 50, defaultValue: 30),
            guidance_scale: clampDouble(request.guidance, min: 0, max: 20, defaultValue: 4),
            seed: request.seed,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            negative_prompt: request.negativePrompt,
            sync_mode: true
        )
        return try await performQwenRequest(request: request, body: body)
    }
}

private struct QwenImageLayeredRequest: Codable {
    let image_url: String
    let prompt: String?
    let negative_prompt: String?
    let num_inference_steps: Int?
    let guidance_scale: Double?
    let seed: Int?
    let num_layers: Int?
    let sync_mode: Bool
}

/// Qwen Image Layered - Decompose image into RGBA layers
public final class G_FAL_QWEN_IMAGE_LAYERED: FalQwenBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_QWEN_IMAGE_LAYERED
    }

    override var costPerMegapixel: Double {
        0.05
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = QwenImageLayeredRequest(
            image_url: toDataUri(clientImage),
            prompt: request.prompt.isEmpty ? nil : request.prompt,
            negative_prompt: request.negativePrompt,
            num_inference_steps: clampInt(request.steps, min: 1, max: 50, defaultValue: 28),
            guidance_scale: clampDouble(request.guidance, min: 1, max: 20, defaultValue: 5),
            seed: request.seed,
            num_layers: 4,
            sync_mode: true
        )
        return try await performQwenRequest(request: request, body: body)
    }
}

private struct QwenImageEdit2511Request: Codable {
    let prompt: String
    let image_urls: [String]
    let negative_prompt: String?
    let image_size: String?
    let num_inference_steps: Int?
    let guidance_scale: Double?
    let seed: Int?
    let num_images: Int?
    let sync_mode: Bool
}

/// Qwen Image Edit 2511
public final class G_FAL_QWEN_IMAGE_EDIT_2511: FalQwenBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_QWEN_IMAGE_EDIT_2511
    }

    override var costPerMegapixel: Double {
        0.03
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

        let body = QwenImageEdit2511Request(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            negative_prompt: request.negativePrompt,
            image_size: normalizeImageSize(from: request.dimensions),
            num_inference_steps: clampInt(request.steps, min: 1, max: 50, defaultValue: 28),
            guidance_scale: clampDouble(request.guidance, min: 1, max: 20, defaultValue: 4.5),
            seed: request.seed,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            sync_mode: true
        )
        return try await performQwenRequest(request: request, body: body)
    }
}

private struct QwenImageEdit2511MultiAngleRequest: Codable {
    let image_urls: [String]
    let horizontal_angle: Double?
    let vertical_angle: Double?
    let zoom: Double?
    let additional_prompt: String?
    let lora_scale: Double?
    let image_size: String?
    let guidance_scale: Double?
    let num_inference_steps: Int?
    let negative_prompt: String?
    let seed: Int?
    let num_images: Int?
    let sync_mode: Bool
}

/// Qwen Image Edit 2511 Multiple Angles
public final class G_FAL_QWEN_IMAGE_EDIT_2511_MULTIPLE_ANGLES: FalQwenBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_QWEN_IMAGE_EDIT_2511_MULTIPLE_ANGLES
    }

    override var costPerMegapixel: Double {
        0.035
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = QwenImageEdit2511MultiAngleRequest(
            image_urls: [toDataUri(clientImage)],
            horizontal_angle: 0,
            vertical_angle: 0,
            zoom: 5,
            additional_prompt: request.prompt.isEmpty ? nil : request.prompt,
            lora_scale: 1,
            image_size: normalizeImageSize(from: request.dimensions),
            guidance_scale: clampDouble(request.guidance, min: 1, max: 20, defaultValue: 4.5),
            num_inference_steps: clampInt(request.steps, min: 1, max: 50, defaultValue: 28),
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            sync_mode: true
        )
        return try await performQwenRequest(request: request, body: body)
    }
}

private struct QwenImageEdit2509Request: Codable {
    let prompt: String
    let image_urls: [String]
    let image_size: String?
    let num_inference_steps: Int?
    let guidance_scale: Double?
    let seed: Int?
    let num_images: Int?
    let negative_prompt: String?
    let sync_mode: Bool
}

/// Qwen Image Edit 2509 - Multi-image support
public final class G_FAL_QWEN_IMAGE_EDIT_2509: FalQwenBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_QWEN_IMAGE_EDIT_2509
    }

    override var costPerMegapixel: Double {
        0.03
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

        let body = QwenImageEdit2509Request(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            image_size: normalizeImageSize(from: request.dimensions),
            num_inference_steps: clampInt(request.steps, min: 2, max: 100, defaultValue: 50),
            guidance_scale: clampDouble(request.guidance, min: 0, max: 20, defaultValue: 4),
            seed: request.seed,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            negative_prompt: request.negativePrompt,
            sync_mode: true
        )
        return try await performQwenRequest(request: request, body: body)
    }
}
