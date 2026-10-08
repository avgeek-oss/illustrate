// MARK: - G_FAL_FLUX.swift

// Consolidated implementation for all FAL FLUX models.
// Uses a base class pattern to reduce code duplication.

import Foundation

// MARK: - Base Class

/// Base class for all FAL FLUX models with shared functionality.
public class FalFluxBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    /// Cost per megapixel (most Fal FLUX models use megapixel-based pricing)
    var costPerMegapixel: Double {
        fatalError("Subclass must override")
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    /// Required by protocol - using a simple placeholder struct
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

    func clampImageCount(_ value: Int, max: Int = 4) -> Int {
        Swift.max(1, Swift.min(max, value))
    }

    /// Convert pixel dimensions to FAL image size format
    func getImageSize(_ dimensions: String) -> String {
        switch dimensions {
        case "1024x1024": "square_hd"
        case "1920x1080": "landscape_16_9"
        case "1440x1080": "landscape_4_3"
        case "1080x1920": "portrait_16_9"
        case "1080x1440": "portrait_4_3"
        case "1344x768": "landscape_16_9"
        case "768x1344": "portrait_16_9"
        default: "landscape_4_3"
        }
    }

    /// Converts base64 to data URI for FAL
    func toDataUri(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:image/png;base64,\(base64)"
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            // Handle "images" array output (most FLUX models)
            if let images = data["images"] as? [[String: Any]],
               let urlStr = images.first?["url"] as? String
            {
                return try downloadAndReturnImage(urlStr: urlStr, request: request)
            }
            // Handle single "image" output
            if let imageObj = data["image"] as? [String: Any],
               let urlStr = imageObj["url"] as? String
            {
                return try downloadAndReturnImage(urlStr: urlStr, request: request)
            }
            // Handle errors
            if let error = data["detail"] as? String {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: error
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
        return createInvalidResponseError(response: response, modelCode: modelCode)
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
        // Download from URL
        let url = URL(string: urlStr)!
        let imageData = try Data(contentsOf: url)
        return ImageGenerationResponse(
            status: .GENERATED,
            base64: imageData.base64EncodedString(),
            cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }

    /// Helper to perform request with a Codable body
    func performFluxRequest(
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

    /// Default implementation - subclasses must override
    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        fatalError("Subclass must override makeRequest")
    }
}

// MARK: - Request Body Types

/// Text-to-image request (FLUX 1/2)
private struct FluxT2IRequest: Codable {
    let prompt: String
    let image_size: String
    let num_images: Int
    let seed: Int?
    let guidance_scale: Double?
    let num_inference_steps: Int?
    let safety_tolerance: String?
    let enable_safety_checker: Bool
    let sync_mode: Bool
}

/// Text-to-image request for simple Fal image endpoints that use image_size and output_format.
private struct FalSimpleImageRequest: Codable {
    let prompt: String
    let image_size: String
    let num_images: Int
    let seed: Int?
    let safety_tolerance: String?
    let output_format: String?
    let sync_mode: Bool
}

/// Text-to-image request for Krea 2 Turbo.
private struct FalKrea2TurboRequest: Codable {
    let prompt: String
    let image_size: String
    let num_images: Int
    let seed: Int?
    let output_format: String?
    let enable_prompt_expansion: Bool?
    let sync_mode: Bool
}

/// Text-to-image request for Ideogram V4.
private struct FalIdeogramV4Request: Codable {
    let prompt: String
    let image_size: String
    let num_images: Int
    let seed: Int?
    let output_format: String?
    let expansion_model: String
    let rendering_speed: String?
    let sync_mode: Bool
}

/// Text-to-image request for the fixed instant Ideogram V4 sampler.
private struct FalIdeogramV4InstantRequest: Codable {
    let prompt: String
    let image_size: String
    let num_images: Int
    let seed: Int?
    let output_format: String?
    let expansion_model: String
    let sync_mode: Bool
}

/// Image-to-image request (with strength)
private struct FluxI2IRequest: Codable {
    let prompt: String
    let image_url: String
    let strength: Double
    let num_images: Int
    let seed: Int?
    let guidance_scale: Double?
    let num_inference_steps: Int?
    let enable_safety_checker: Bool
    let sync_mode: Bool
}

/// Redux request (image variation)
private struct FluxReduxRequest: Codable {
    let image_url: String
    let image_size: String
    let num_images: Int
    let seed: Int?
    let guidance_scale: Double?
    let num_inference_steps: Int?
    let enable_safety_checker: Bool
    let sync_mode: Bool
}

/// Edit request (FLUX 2 with image_urls array)
private struct Flux2EditRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let num_images: Int
    let seed: Int?
    let guidance_scale: Double?
    let num_inference_steps: Int?
    let enable_safety_checker: Bool
    let sync_mode: Bool
}

/// Kontext request (image editing)
private struct FluxKontextRequest: Codable {
    let prompt: String
    let image_url: String
    let num_images: Int
    let seed: Int?
    let guidance_scale: Double?
    let num_inference_steps: Int?
    let safety_tolerance: String?
    let enable_safety_checker: Bool
    let output_format: String
    let sync_mode: Bool
}

/// Kontext T2I request
private struct FluxKontextT2IRequest: Codable {
    let prompt: String
    let aspect_ratio: String
    let num_images: Int
    let seed: Int?
    let guidance_scale: Double?
    let safety_tolerance: String?
    let output_format: String
    let sync_mode: Bool
}

// MARK: - FLUX 1 Image-to-Image & Redux Models

/// FLUX.1 [dev] Image-to-Image - Style transfer and image modifications
public final class G_FAL_FLUX_DEV_IMAGE_TO_IMAGE: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_DEV_IMAGE_TO_IMAGE
    }

    override var costPerMegapixel: Double {
        0.03
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FluxI2IRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            strength: 0.95,
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 3.5,
            num_inference_steps: request.steps ?? 40,
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX.1 [dev] Redux - Image variation/style transfer
public final class G_FAL_FLUX_DEV_REDUX: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_DEV_REDUX
    }

    override var costPerMegapixel: Double {
        0.025
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FluxReduxRequest(
            image_url: toDataUri(clientImage),
            image_size: getImageSize(request.dimensions),
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 3.5,
            num_inference_steps: request.steps ?? 28,
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX.1 [schnell] Redux - Fast image variation
public final class G_FAL_FLUX_SCHNELL_REDUX: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_SCHNELL_REDUX
    }

    override var costPerMegapixel: Double {
        0.025
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FluxReduxRequest(
            image_url: toDataUri(clientImage),
            image_size: getImageSize(request.dimensions),
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 3.5,
            num_inference_steps: request.steps ?? 4,
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

// MARK: - FLUX 2 Text-to-Image Models

/// FLUX 2 [dev] - Enhanced text-to-image
public final class G_FAL_FLUX_2: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2
    }

    override var costPerMegapixel: Double {
        0.012
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FluxT2IRequest(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 2.5,
            num_inference_steps: request.steps ?? 28,
            safety_tolerance: request.safetyTolerance.map { String($0) },
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX 2 [pro] - High quality text-to-image
public final class G_FAL_FLUX_2_PRO: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2_PRO
    }

    override var costPerMegapixel: Double {
        0.03
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FluxT2IRequest(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: 1,
            seed: request.seed,
            guidance_scale: nil,
            num_inference_steps: nil,
            safety_tolerance: request.safetyTolerance.map { String($0) } ?? "2",
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX 2 [flex] - Adjustable inference text-to-image
public final class G_FAL_FLUX_2_FLEX: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2_FLEX
    }

    override var costPerMegapixel: Double {
        0.06
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FluxT2IRequest(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 3.5,
            num_inference_steps: request.steps ?? 28,
            safety_tolerance: request.safetyTolerance.map { String($0) } ?? "2",
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX 2 [max] - Maximum quality text-to-image
public final class G_FAL_FLUX_2_MAX: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2_MAX
    }

    override var costPerMegapixel: Double {
        0.07
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FluxT2IRequest(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: 1,
            seed: request.seed,
            guidance_scale: nil,
            num_inference_steps: nil,
            safety_tolerance: request.safetyTolerance.map { String($0) } ?? "2",
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX 2 [turbo] - Fast text-to-image
public final class G_FAL_FLUX_2_TURBO: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2_TURBO
    }

    override var costPerMegapixel: Double {
        0.008
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FluxT2IRequest(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 2.5,
            num_inference_steps: nil,
            safety_tolerance: nil,
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX 2 Klein 4B - Smaller fast model
public final class G_FAL_FLUX_2_KLEIN_4B: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2_KLEIN_4B
    }

    override var costPerMegapixel: Double {
        0.009
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FluxT2IRequest(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: 1,
            seed: request.seed,
            guidance_scale: nil,
            num_inference_steps: request.steps ?? 4,
            safety_tolerance: nil,
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX 2 Klein 9B - Larger fast Klein model
public final class G_FAL_FLUX_2_KLEIN_9B: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2_KLEIN_9B
    }

    override var costPerMegapixel: Double {
        0.006
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FalSimpleImageRequest(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: clampImageCount(request.numberOfImages),
            seed: request.seed,
            safety_tolerance: request.safetyTolerance.map { String($0) },
            output_format: "png",
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX 2 Flash - Fast generation
public final class G_FAL_FLUX_2_FLASH: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2_FLASH
    }

    override var costPerMegapixel: Double {
        0.005
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FluxT2IRequest(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 2.5,
            num_inference_steps: request.steps ?? 4,
            safety_tolerance: nil,
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// Krea 2 Turbo - Fast high-quality image generation
public final class G_FAL_KREA_2_TURBO: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_KREA_2_TURBO
    }

    override var costPerMegapixel: Double {
        0.008
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FalKrea2TurboRequest(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: clampImageCount(request.numberOfImages),
            seed: request.seed,
            output_format: "png",
            enable_prompt_expansion: request.promptEnhance,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

public class FalIdeogramV4Base: FalFluxBase {
    override public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let binaryMegapixels = falParseMegapixels(from: request.dimensions) * (1_000_000.0 / 1_048_576.0)
        return costPerMegapixel * binaryMegapixels * Double(request.numberOfImages ?? 1)
    }
}

/// Ideogram V4 - Typography and design-oriented image generation
public final class G_FAL_IDEOGRAM_V4: FalIdeogramV4Base {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_IDEOGRAM_V4
    }

    override var costPerMegapixel: Double {
        0.015
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FalIdeogramV4Request(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: clampImageCount(request.numberOfImages),
            seed: request.seed,
            output_format: "png",
            expansion_model: request.promptEnhance == false ? "None" : "Medium",
            rendering_speed: "BALANCED",
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// Ideogram V4 Fast - Faster CFG-distilled image generation.
public final class G_FAL_IDEOGRAM_V4_FAST: FalIdeogramV4Base {
    override public init() {}

    override var modelCode: EnumProviderModelCode {
        .FAL_IDEOGRAM_V4_FAST
    }

    override var costPerMegapixel: Double {
        0.0105
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FalIdeogramV4Request(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: clampImageCount(request.numberOfImages),
            seed: request.seed,
            output_format: "png",
            expansion_model: request.promptEnhance == false ? "None" : "Medium",
            rendering_speed: "BALANCED",
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// Ideogram V4 Instant - Fixed instant sampler.
public final class G_FAL_IDEOGRAM_V4_INSTANT: FalIdeogramV4Base {
    override public init() {}

    override var modelCode: EnumProviderModelCode {
        .FAL_IDEOGRAM_V4_INSTANT
    }

    override var costPerMegapixel: Double {
        0.0075
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FalIdeogramV4InstantRequest(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: clampImageCount(request.numberOfImages),
            seed: request.seed,
            output_format: "png",
            expansion_model: request.promptEnhance == false ? "None" : "Medium",
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

// MARK: - FLUX 2 Edit Models

/// FLUX 2 [pro] Edit - High quality image editing
public final class G_FAL_FLUX_2_PRO_EDIT: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2_PRO_EDIT
    }

    override var costPerMegapixel: Double {
        0.03
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = Flux2EditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: 1,
            seed: request.seed,
            guidance_scale: nil,
            num_inference_steps: nil,
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX 2 [dev] Edit - Image editing
public final class G_FAL_FLUX_2_EDIT: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2_EDIT
    }

    override var costPerMegapixel: Double {
        0.012
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = Flux2EditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 2.5,
            num_inference_steps: request.steps ?? 28,
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX 2 [flex] Edit - Adjustable image editing
public final class G_FAL_FLUX_2_FLEX_EDIT: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2_FLEX_EDIT
    }

    override var costPerMegapixel: Double {
        0.06
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = Flux2EditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 3.5,
            num_inference_steps: request.steps ?? 28,
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX 2 [max] Edit - Maximum quality image editing
public final class G_FAL_FLUX_2_MAX_EDIT: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2_MAX_EDIT
    }

    override var costPerMegapixel: Double {
        0.07
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = Flux2EditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: 1,
            seed: request.seed,
            guidance_scale: nil,
            num_inference_steps: nil,
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX 2 [turbo] Edit - Fast image editing
public final class G_FAL_FLUX_2_TURBO_EDIT: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2_TURBO_EDIT
    }

    override var costPerMegapixel: Double {
        0.008
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = Flux2EditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 2.5,
            num_inference_steps: nil,
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX 2 Klein 4B Edit
public final class G_FAL_FLUX_2_KLEIN_4B_EDIT: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2_KLEIN_4B_EDIT
    }

    override var costPerMegapixel: Double {
        0.009
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = Flux2EditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: 1,
            seed: request.seed,
            guidance_scale: nil,
            num_inference_steps: request.steps ?? 4,
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX 2 Flash Edit
public final class G_FAL_FLUX_2_FLASH_EDIT: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_2_FLASH_EDIT
    }

    override var costPerMegapixel: Double {
        0.005
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = Flux2EditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 2.5,
            num_inference_steps: request.steps ?? 4,
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

// MARK: - FLUX Kontext Models

/// FLUX Kontext [dev] - Frontier image editing
public final class G_FAL_FLUX_KONTEXT_DEV: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_KONTEXT_DEV
    }

    override var costPerMegapixel: Double {
        0.025
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FluxKontextRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 2.5,
            num_inference_steps: request.steps ?? 28,
            safety_tolerance: nil,
            enable_safety_checker: false,
            output_format: "jpeg",
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX Kontext [pro] - Professional image editing ($0.04/image flat rate)
public final class G_FAL_FLUX_PRO_KONTEXT: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_PRO_KONTEXT
    }

    override var costPerMegapixel: Double {
        0.04
    } // Actually per-image, not per-megapixel

    override public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        0.04 * Double(request.numberOfImages ?? 1) // Flat per-image pricing
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FluxKontextRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 3.5,
            num_inference_steps: nil,
            safety_tolerance: request.safetyTolerance.map { String($0) } ?? "2",
            enable_safety_checker: false,
            output_format: "jpeg",
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX Kontext [max] - Maximum quality image editing ($0.08/image flat rate)
public final class G_FAL_FLUX_PRO_KONTEXT_MAX: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_PRO_KONTEXT_MAX
    }

    override var costPerMegapixel: Double {
        0.08
    } // Actually per-image, not per-megapixel

    override public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        0.08 * Double(request.numberOfImages ?? 1) // Flat per-image pricing
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = FluxKontextRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 3.5,
            num_inference_steps: nil,
            safety_tolerance: request.safetyTolerance.map { String($0) } ?? "2",
            enable_safety_checker: false,
            output_format: "jpeg",
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX Kontext [pro] Text-to-Image ($0.04/image flat rate)
public final class G_FAL_FLUX_PRO_KONTEXT_T2I: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_PRO_KONTEXT_T2I
    }

    override var costPerMegapixel: Double {
        0.04
    } // Actually per-image, not per-megapixel

    override public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        0.04 * Double(request.numberOfImages ?? 1) // Flat per-image pricing
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FluxKontextT2IRequest(
            prompt: request.prompt,
            aspect_ratio: "1:1",
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 3.5,
            safety_tolerance: request.safetyTolerance.map { String($0) } ?? "2",
            output_format: "jpeg",
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX Kontext [max] Text-to-Image ($0.08/image flat rate)
public final class G_FAL_FLUX_PRO_KONTEXT_MAX_T2I: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_PRO_KONTEXT_MAX_T2I
    }

    override var costPerMegapixel: Double {
        0.08
    } // Actually per-image, not per-megapixel

    override public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        0.08 * Double(request.numberOfImages ?? 1) // Flat per-image pricing
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FluxKontextT2IRequest(
            prompt: request.prompt,
            aspect_ratio: "1:1",
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 3.5,
            safety_tolerance: request.safetyTolerance.map { String($0) } ?? "2",
            output_format: "jpeg",
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

// MARK: - FLUX 1 Original Models

/// FLUX.1 [schnell] - Fast 1-4 step generation
public final class G_FAL_FLUX_SCHNELL: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_SCHNELL
    }

    override var costPerMegapixel: Double {
        0.003
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FluxT2IRequest(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 3.5,
            num_inference_steps: request.steps ?? 4,
            safety_tolerance: request.safetyTolerance.map { String($0) } ?? "5",
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX.1 [dev] - Development model with configurable steps
public final class G_FAL_FLUX_DEV: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_DEV
    }

    override var costPerMegapixel: Double {
        0.025
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FluxT2IRequest(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 3.5,
            num_inference_steps: request.steps ?? 28,
            safety_tolerance: request.safetyTolerance.map { String($0) } ?? "5",
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}

/// FLUX.1 [pro] - Professional quality generation
public final class G_FAL_FLUX_PRO: FalFluxBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_FLUX_PRO
    }

    override var costPerMegapixel: Double {
        0.05
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FluxT2IRequest(
            prompt: request.prompt,
            image_size: getImageSize(request.dimensions),
            num_images: 1,
            seed: request.seed,
            guidance_scale: request.guidance ?? 3.5,
            num_inference_steps: request.steps ?? 50,
            safety_tolerance: request.safetyTolerance.map { String($0) } ?? "5",
            enable_safety_checker: false,
            sync_mode: true
        )
        return try await performFluxRequest(request: request, body: body)
    }
}
