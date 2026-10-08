// MARK: - G_FAL_GOOGLE.swift

// Google models via Fal AI:
// - fal-ai/gemini-3-pro-image-preview
// - fal-ai/gemini-3-pro-image-preview/edit
// - fal-ai/nano-banana-pro
// - fal-ai/nano-banana-pro/edit
// - fal-ai/gemini-25-flash-image
// - fal-ai/gemini-25-flash-image/edit
// - fal-ai/nano-banana
// - fal-ai/nano-banana/edit
// - fal-ai/nano-banana-2
// - fal-ai/nano-banana-2/edit
// - google/nano-banana-lite
// - google/nano-banana-lite/edit
// - google/nano-banana-2-lite
// - fal-ai/imagen4/preview
// - fal-ai/imagen4/preview/fast
// - fal-ai/imagen4/preview/ultra

import Foundation

// MARK: - Base Class

public class FalGoogleBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var baseCost: Double {
        0.0398
    } // gemini-25-flash/nano-banana=$0.0398, gemini-3-pro/nano-banana-pro=$0.15

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

    func performGoogleRequest(
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

    func normalizeAspectRatio(from dimensions: String) -> String {
        let normalized = dimensions.replacingOccurrences(of: "x", with: ":").lowercased()

        switch normalized {
        case "1:1", "1024:1024", "512:512", "768:768":
            return "1:1"
        case "16:9", "1920:1080", "1536:864":
            return "16:9"
        case "9:16", "1080:1920", "864:1536":
            return "9:16"
        case "4:3", "1024:768", "1536:1152":
            return "4:3"
        case "3:4", "768:1024", "1152:1536":
            return "3:4"
        case "3:2", "1536:1024":
            return "3:2"
        case "2:3", "1024:1536":
            return "2:3"
        case "5:4":
            return "5:4"
        case "4:5":
            return "4:5"
        case "21:9":
            return "21:9"
        case "4:1":
            return "4:1"
        case "1:4":
            return "1:4"
        case "8:1":
            return "8:1"
        case "1:8":
            return "1:8"
        default:
            return "1:1"
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

// MARK: - Gemini 3 Pro Image Preview (Text-to-Image)

private struct Gemini3ProTextRequest: Codable {
    let prompt: String
    let num_images: Int?
    let seed: Int?
    let aspect_ratio: String?
    let resolution: String?
    let sync_mode: Bool
}

public final class G_FAL_GOOGLE_GEMINI_3_PRO_IMAGE: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_GEMINI_3_PRO_IMAGE
    }

    override var baseCost: Double {
        0.15
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = Gemini3ProTextRequest(
            prompt: request.prompt,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            seed: request.seed,
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            resolution: "1K",
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Gemini 3 Pro Image Preview Edit

private struct Gemini3ProEditRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let num_images: Int?
    let seed: Int?
    let aspect_ratio: String?
    let resolution: String?
    let sync_mode: Bool
}

public final class G_FAL_GOOGLE_GEMINI_3_PRO_IMAGE_EDIT: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_GEMINI_3_PRO_IMAGE_EDIT
    }

    override var baseCost: Double {
        0.15
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

        let body = Gemini3ProEditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            seed: request.seed,
            aspect_ratio: "auto",
            resolution: "1K",
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Nano Banana Pro (Text-to-Image)

public final class G_FAL_GOOGLE_NANO_BANANA_PRO: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_NANO_BANANA_PRO
    }

    override var baseCost: Double {
        0.15
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = Gemini3ProTextRequest(
            prompt: request.prompt,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            seed: request.seed,
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            resolution: "1K",
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Nano Banana Pro Edit

public final class G_FAL_GOOGLE_NANO_BANANA_PRO_EDIT: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_NANO_BANANA_PRO_EDIT
    }

    override var baseCost: Double {
        0.15
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

        let body = Gemini3ProEditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            seed: request.seed,
            aspect_ratio: "auto",
            resolution: "1K",
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Gemini 2.5 Flash Image (Text-to-Image)

private struct GeminiFlashTextRequest: Codable {
    let prompt: String
    let num_images: Int?
    let aspect_ratio: String?
    let sync_mode: Bool
}

public final class G_FAL_GOOGLE_GEMINI_25_FLASH_IMAGE: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_GEMINI_25_FLASH_IMAGE
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = GeminiFlashTextRequest(
            prompt: request.prompt,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Gemini 2.5 Flash Image Edit

private struct GeminiFlashEditRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let num_images: Int?
    let aspect_ratio: String?
    let sync_mode: Bool
}

public final class G_FAL_GOOGLE_GEMINI_25_FLASH_IMAGE_EDIT: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_GEMINI_25_FLASH_IMAGE_EDIT
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

        let body = GeminiFlashEditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            aspect_ratio: "auto",
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Nano Banana (Text-to-Image)

public final class G_FAL_GOOGLE_NANO_BANANA: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_NANO_BANANA
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = GeminiFlashTextRequest(
            prompt: request.prompt,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Nano Banana Edit

public final class G_FAL_GOOGLE_NANO_BANANA_EDIT: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_NANO_BANANA_EDIT
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

        let body = GeminiFlashEditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            aspect_ratio: "auto",
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Imagen 4 Preview

private struct Imagen4Request: Codable {
    let prompt: String
    let num_images: Int?
    let aspect_ratio: String?
    let resolution: String?
    let sync_mode: Bool
}

public final class G_FAL_GOOGLE_IMAGEN4_PREVIEW: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_IMAGEN4_PREVIEW
    }

    override var baseCost: Double {
        0.04
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = Imagen4Request(
            prompt: request.prompt,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            resolution: "1K",
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Imagen 4 Preview Fast

private struct Imagen4FastRequest: Codable {
    let prompt: String
    let num_images: Int?
    let aspect_ratio: String?
    let sync_mode: Bool
}

public final class G_FAL_GOOGLE_IMAGEN4_PREVIEW_FAST: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_IMAGEN4_PREVIEW_FAST
    }

    override var baseCost: Double {
        0.02
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = Imagen4FastRequest(
            prompt: request.prompt,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Imagen 4 Preview Ultra

public final class G_FAL_GOOGLE_IMAGEN4_PREVIEW_ULTRA: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_IMAGEN4_PREVIEW_ULTRA
    }

    override var baseCost: Double {
        0.06
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = Imagen4Request(
            prompt: request.prompt,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            resolution: "1K",
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Nano Banana 2 (Text-to-Image)

private struct NanoBanana2TextRequest: Codable {
    let prompt: String
    let num_images: Int?
    let seed: Int?
    let aspect_ratio: String?
    let resolution: String?
    let output_format: String?
    let sync_mode: Bool
}

public final class G_FAL_GOOGLE_NANO_BANANA_2: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_NANO_BANANA_2
    }

    override var baseCost: Double {
        0.04
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = NanoBanana2TextRequest(
            prompt: request.prompt,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            seed: request.seed,
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            resolution: "1K",
            output_format: "png",
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Nano Banana 2 Edit

private struct NanoBanana2EditRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let num_images: Int?
    let seed: Int?
    let aspect_ratio: String?
    let resolution: String?
    let output_format: String?
    let sync_mode: Bool
}

public final class G_FAL_GOOGLE_NANO_BANANA_2_EDIT: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_NANO_BANANA_2_EDIT
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

        let body = NanoBanana2EditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            seed: request.seed,
            aspect_ratio: "auto",
            resolution: "1K",
            output_format: "png",
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Nano Banana Lite (Text-to-Image)

private struct NanoBananaLiteTextRequest: Codable {
    let prompt: String
    let num_images: Int?
    let seed: Int?
    let aspect_ratio: String?
    let output_format: String?
    let sync_mode: Bool
}

public final class G_FAL_GOOGLE_NANO_BANANA_LITE: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_NANO_BANANA_LITE
    }

    override public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost) + "+"
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = NanoBananaLiteTextRequest(
            prompt: request.prompt,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            seed: request.seed,
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            output_format: "png",
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Nano Banana Lite Edit

private struct NanoBananaLiteEditRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let num_images: Int?
    let seed: Int?
    let aspect_ratio: String?
    let output_format: String?
    let sync_mode: Bool
}

public final class G_FAL_GOOGLE_NANO_BANANA_LITE_EDIT: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_NANO_BANANA_LITE_EDIT
    }

    override public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost) + "+"
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

        let body = NanoBananaLiteEditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            seed: request.seed,
            aspect_ratio: "auto",
            output_format: "png",
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}

// MARK: - Nano Banana 2 Lite (Text-to-Image)

public final class G_FAL_GOOGLE_NANO_BANANA_2_LITE: FalGoogleBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_GOOGLE_NANO_BANANA_2_LITE
    }

    override var baseCost: Double {
        0.04
    }

    override public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost) + "+"
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = NanoBananaLiteTextRequest(
            prompt: request.prompt,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            seed: request.seed,
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            output_format: "png",
            sync_mode: true
        )
        return try await performGoogleRequest(request: request, body: body)
    }
}
