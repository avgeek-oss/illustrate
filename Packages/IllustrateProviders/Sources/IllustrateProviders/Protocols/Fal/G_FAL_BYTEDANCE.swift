// MARK: - G_FAL_BYTEDANCE.swift

// ByteDance models via Fal AI:
// - fal-ai/bytedance/seedream/v4.5/text-to-image
// - fal-ai/bytedance/seedream/v4.5/edit
// - fal-ai/bytedance/seedream/v4/text-to-image
// - fal-ai/bytedance/seedream/v4/edit
// - fal-ai/bytedance/seedream/v3/text-to-image
// - fal-ai/bytedance/dreamina/v3.1/text-to-image
// - fal-ai/bagel
// - fal-ai/bagel/edit
// - bytedance/seedream/v5/pro/text-to-image
// - bytedance/seedream/v5/pro/edit
// - bytedance/seedream/v5/lite/text-to-image
// - bytedance/seedream/v5/lite/edit
// - fal-ai/bernini-r/edit-image

import Foundation

// MARK: - Base Class

public class FalByteDanceBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var baseCost: Double {
        0.04
    } // v5 pro=$0.135, v5 lite=$0.02, v4.5=$0.04, v4/v3=$0.03, bagel=$0.10

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
            if let image = data["image"] as? [String: Any],
               let urlStr = image["url"] as? String
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

    func performByteDanceRequest(
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

    func imageUrls(sourceImage: String, referenceImages: [ReferenceImageData]?, maxCount: Int) -> [String] {
        var urls = [toDataUri(sourceImage)]
        for reference in referenceImages ?? [] where urls.count < maxCount {
            urls.append(toDataUri(reference.base64Image))
        }
        return urls
    }

    func clampInt(_ value: Int?, min: Int, max: Int, defaultValue: Int) -> Int {
        guard let value else { return defaultValue }
        return Swift.max(min, Swift.min(max, value))
    }

    func clampDouble(_ value: Double?, min: Double, max: Double, defaultValue: Double) -> Double {
        guard let value else { return defaultValue }
        return Swift.max(min, Swift.min(max, value))
    }

    func seedreamV5ProImageSize(resolution: String?) -> String {
        resolution?.uppercased() == "1K" ? "auto_1K" : "auto_2K"
    }

    func seedreamV5LiteImageSize(resolution: String?) -> String {
        switch resolution?.uppercased() {
        case "3K": "auto_3K"
        case "4K": "auto_4K"
        default: "auto_2K"
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

// MARK: - Seedream v4.5 Text-to-Image

private struct SeedreamV45TextRequest: Codable {
    let prompt: String
    let image_size: String?
    let num_images: Int?
    let seed: Int?
    let sync_mode: Bool
}

public final class G_FAL_BYTEDANCE_SEEDREAM_V45_TEXT_TO_IMAGE: FalByteDanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_SEEDREAM_V45_TEXT_TO_IMAGE
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = SeedreamV45TextRequest(
            prompt: request.prompt,
            image_size: "auto_2K",
            num_images: clampInt(request.numberOfImages, min: 1, max: 6, defaultValue: 1),
            seed: request.seed,
            sync_mode: true
        )
        return try await performByteDanceRequest(request: request, body: body)
    }
}

// MARK: - Seedream v4.5 Edit

private struct SeedreamV45EditRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let image_size: String?
    let num_images: Int?
    let seed: Int?
    let sync_mode: Bool
}

public final class G_FAL_BYTEDANCE_SEEDREAM_V45_EDIT: FalByteDanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_SEEDREAM_V45_EDIT
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

        let body = SeedreamV45EditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            image_size: "auto_4K",
            num_images: clampInt(request.numberOfImages, min: 1, max: 6, defaultValue: 1),
            seed: request.seed,
            sync_mode: true
        )
        return try await performByteDanceRequest(request: request, body: body)
    }
}

// MARK: - Seedream v4 Text-to-Image

private struct SeedreamV4TextRequest: Codable {
    let prompt: String
    let num_images: Int?
    let seed: Int?
    let enhance_prompt_mode: String?
    let sync_mode: Bool
}

public final class G_FAL_BYTEDANCE_SEEDREAM_V4_TEXT_TO_IMAGE: FalByteDanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_SEEDREAM_V4_TEXT_TO_IMAGE
    }

    override var baseCost: Double {
        0.03
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = SeedreamV4TextRequest(
            prompt: request.prompt,
            num_images: clampInt(request.numberOfImages, min: 1, max: 6, defaultValue: 1),
            seed: request.seed,
            enhance_prompt_mode: request.promptEnhance == true ? "standard" : "fast",
            sync_mode: true
        )
        return try await performByteDanceRequest(request: request, body: body)
    }
}

// MARK: - Seedream v4 Edit

private struct SeedreamV4EditRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let num_images: Int?
    let seed: Int?
    let enhance_prompt_mode: String?
    let sync_mode: Bool
}

public final class G_FAL_BYTEDANCE_SEEDREAM_V4_EDIT: FalByteDanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_SEEDREAM_V4_EDIT
    }

    override var baseCost: Double {
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

        let body = SeedreamV4EditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: clampInt(request.numberOfImages, min: 1, max: 6, defaultValue: 1),
            seed: request.seed,
            enhance_prompt_mode: request.promptEnhance == true ? "standard" : "fast",
            sync_mode: true
        )
        return try await performByteDanceRequest(request: request, body: body)
    }
}

// MARK: - Seedream v3 Text-to-Image

private struct SeedreamV3TextRequest: Codable {
    let prompt: String
    let guidance_scale: Double?
    let num_images: Int?
    let seed: Int?
    let sync_mode: Bool
}

public final class G_FAL_BYTEDANCE_SEEDREAM_V3_TEXT_TO_IMAGE: FalByteDanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_SEEDREAM_V3_TEXT_TO_IMAGE
    }

    override var baseCost: Double {
        0.03
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = SeedreamV3TextRequest(
            prompt: request.prompt,
            guidance_scale: clampDouble(request.guidance, min: 1, max: 10, defaultValue: 2.5),
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            seed: request.seed,
            sync_mode: true
        )
        return try await performByteDanceRequest(request: request, body: body)
    }
}

// MARK: - Dreamina v3.1 Text-to-Image

private struct DreaminaV31TextRequest: Codable {
    let prompt: String
    let enhance_prompt: Bool?
    let num_images: Int?
    let seed: Int?
    let sync_mode: Bool
}

public final class G_FAL_BYTEDANCE_DREAMINA_V31_TEXT_TO_IMAGE: FalByteDanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_DREAMINA_V31_TEXT_TO_IMAGE
    }

    override var baseCost: Double {
        0.03
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = DreaminaV31TextRequest(
            prompt: request.prompt,
            enhance_prompt: request.promptEnhance,
            num_images: clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1),
            seed: request.seed,
            sync_mode: true
        )
        return try await performByteDanceRequest(request: request, body: body)
    }
}

// MARK: - Bagel Text-to-Image

private struct BagelTextRequest: Codable {
    let prompt: String
    let seed: Int?
    let use_thought: Bool?
}

public final class G_FAL_BYTEDANCE_BAGEL: FalByteDanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_BAGEL
    }

    override var baseCost: Double {
        0.10
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = BagelTextRequest(
            prompt: request.prompt,
            seed: request.seed,
            use_thought: false
        )
        return try await performByteDanceRequest(request: request, body: body)
    }
}

// MARK: - Bagel Edit

private struct BagelEditRequest: Codable {
    let prompt: String
    let image_url: String
    let seed: Int?
    let use_thought: Bool?
}

public final class G_FAL_BYTEDANCE_BAGEL_EDIT: FalByteDanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_BAGEL_EDIT
    }

    override var baseCost: Double {
        0.10
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

        let body = BagelEditRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            seed: request.seed,
            use_thought: false
        )
        return try await performByteDanceRequest(request: request, body: body)
    }
}

// MARK: - Seedream 5.0 Pro (Text-to-Image)

private struct SeedreamV5ProTextRequest: Codable {
    let prompt: String
    let image_size: String?
    let num_images: Int?
    let output_format: String
    let sync_mode: Bool
    let enable_safety_checker: Bool
}

public final class G_FAL_BYTEDANCE_SEEDREAM_V5_PRO_TEXT_TO_IMAGE: FalByteDanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_SEEDREAM_V5_PRO_TEXT_TO_IMAGE
    }

    override var baseCost: Double {
        0.135
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = SeedreamV5ProTextRequest(
            prompt: request.prompt,
            image_size: seedreamV5ProImageSize(resolution: request.resolution),
            num_images: clampInt(request.numberOfImages, min: 1, max: 6, defaultValue: 1),
            output_format: "png",
            sync_mode: true,
            enable_safety_checker: true
        )
        return try await performByteDanceRequest(request: request, body: body)
    }
}

// MARK: - Seedream 5.0 Pro Edit

private struct SeedreamV5ProEditRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let image_size: String?
    let num_images: Int?
    let output_format: String
    let sync_mode: Bool
    let enable_safety_checker: Bool
}

public final class G_FAL_BYTEDANCE_SEEDREAM_V5_PRO_EDIT: FalByteDanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_SEEDREAM_V5_PRO_EDIT
    }

    override var baseCost: Double {
        0.135
    }

    override public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let outputCost = baseCost * Double(request.numberOfImages ?? 1)
        return outputCost + (0.0045 * Double(request.referenceImageCount))
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

        let body = SeedreamV5ProEditRequest(
            prompt: request.prompt,
            image_urls: imageUrls(
                sourceImage: clientImage,
                referenceImages: request.clientReferenceImages,
                maxCount: 10
            ),
            image_size: seedreamV5ProImageSize(resolution: request.resolution),
            num_images: clampInt(request.numberOfImages, min: 1, max: 6, defaultValue: 1),
            output_format: "png",
            sync_mode: true,
            enable_safety_checker: true
        )
        return try await performByteDanceRequest(request: request, body: body)
    }
}

// MARK: - Seedream 5.0 Lite (Text-to-Image)

private struct SeedreamV5LiteTextRequest: Codable {
    let prompt: String
    let image_size: String
    let num_images: Int
    let max_images: Int
    let enable_safety_checker: Bool
    let sync_mode: Bool
}

public final class G_FAL_BYTEDANCE_SEEDREAM_V5_LITE_TEXT_TO_IMAGE: FalByteDanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_SEEDREAM_V5_LITE_TEXT_TO_IMAGE
    }

    override var baseCost: Double {
        0.035
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = SeedreamV5LiteTextRequest(
            prompt: request.prompt,
            image_size: seedreamV5LiteImageSize(resolution: request.resolution),
            num_images: clampInt(request.numberOfImages, min: 1, max: 6, defaultValue: 1),
            max_images: 1,
            enable_safety_checker: true,
            sync_mode: true
        )
        return try await performByteDanceRequest(request: request, body: body)
    }
}

// MARK: - Seedream 5.0 Lite Edit

private struct SeedreamV5LiteEditRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let image_size: String
    let num_images: Int
    let max_images: Int
    let enable_safety_checker: Bool
    let sync_mode: Bool
}

public final class G_FAL_BYTEDANCE_SEEDREAM_V5_LITE_EDIT: FalByteDanceBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_SEEDREAM_V5_LITE_EDIT
    }

    override var baseCost: Double {
        0.035
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

        let body = SeedreamV5LiteEditRequest(
            prompt: request.prompt,
            image_urls: imageUrls(
                sourceImage: clientImage,
                referenceImages: request.clientReferenceImages,
                maxCount: 10
            ),
            image_size: seedreamV5LiteImageSize(resolution: request.resolution),
            num_images: clampInt(request.numberOfImages, min: 1, max: 6, defaultValue: 1),
            max_images: 1,
            enable_safety_checker: true,
            sync_mode: true
        )
        return try await performByteDanceRequest(request: request, body: body)
    }
}

// MARK: - Bernini-R Edit Image

private struct BerniniREditImageRequest: Codable {
    let prompt: String
    let image_url: String
    let max_image_size: Int
    let num_inference_steps: Int
    let negative_prompt: String?
    let seed: Int?
    let enable_prompt_expansion: Bool
}

public final class G_FAL_BYTEDANCE_BERNINI_R_EDIT_IMAGE: FalByteDanceBase {
    override public init() {}

    override var modelCode: EnumProviderModelCode {
        .FAL_BYTEDANCE_BERNINI_R_EDIT_IMAGE
    }

    override var baseCost: Double {
        0.03
    }

    override public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let dimensions = request.dimensions ?? "1024x1024"
        let sides = dimensions.lowercased().split(separator: "x").compactMap { Double($0) }
        guard sides.count == 2, let longest = sides.max(), longest > 0 else {
            return baseCost * Double(request.numberOfImages ?? 1)
        }

        let scale = min(1, Double(maxImageSize(for: dimensions)) / longest)
        let binaryMegapixels = sides[0] * scale * sides[1] * scale / 1_048_576
        return baseCost * ceil(binaryMegapixels) * Double(request.numberOfImages ?? 1)
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage, !clientImage.isEmpty else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = BerniniREditImageRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            max_image_size: maxImageSize(for: request.dimensions),
            num_inference_steps: clampInt(request.steps, min: 1, max: 50, defaultValue: 30),
            negative_prompt: request.negativePrompt,
            seed: request.seed,
            enable_prompt_expansion: request.promptEnhance ?? false
        )
        return try await performByteDanceRequest(request: request, body: body)
    }

    private func maxImageSize(for dimensions: String) -> Int {
        let sides = dimensions.lowercased().split(separator: "x").compactMap { Int($0) }
        guard let longest = sides.max() else { return 848 }
        if longest <= 576 { return 576 }
        if longest <= 848 { return 848 }
        return 1280
    }
}
