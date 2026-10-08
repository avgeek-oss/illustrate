// MARK: - G_FAL_HIDREAM.swift

// HiDream O1 Image generation models via Fal AI:
// - fal-ai/hidream-o1-image (text-to-image)
// - fal-ai/hidream-o1-image/dev (text-to-image dev)
// - fal-ai/hidream-o1-image/edit (image edit)
// - fal-ai/hidream-o1-image/dev/edit (image edit dev)
//
// Pricing: ~$0.04/image (standard), ~$0.02/image (dev)

import Foundation

// MARK: - Request Structs

private struct HiDreamTextRequest: Codable {
    let prompt: String
    let image_size: String?
    let num_inference_steps: Int?
    let guidance_scale: Double?
    let seed: Int?
    let num_images: Int?
    let output_format: String?
    let enable_safety_checker: Bool?
}

private struct HiDreamEditRequest: Codable {
    let prompt: String
    let reference_image_urls: [String]
    let image_size: String?
    let num_inference_steps: Int?
    let guidance_scale: Double?
    let seed: Int?
    let num_images: Int?
    let output_format: String?
    let enable_safety_checker: Bool?
}

// MARK: - Base Class

public class FalHiDreamBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var baseCost: Double {
        0.04
    }

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

    func performHiDreamRequest(
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

    func mapImageSize(from dimensions: String) -> String {
        let normalized = dimensions.lowercased()
        if normalized.contains("1024x1024") || normalized == "1:1" || normalized == "square" { return "square_hd" }
        if normalized.contains("768x1024") || normalized == "3:4" { return "portrait_4_3" }
        if normalized.contains("1024x768") || normalized == "4:3" { return "landscape_4_3" }
        if normalized.contains("864x1536") || normalized == "9:16" { return "portrait_16_9" }
        if normalized.contains("1536x864") || normalized == "16:9" { return "landscape_16_9" }
        return "square_hd"
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

// MARK: - HiDream O1 Image (Text-to-Image)

public final class G_FAL_HIDREAM_O1_IMAGE: FalHiDreamBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_HIDREAM_O1_IMAGE
    }

    override var baseCost: Double {
        0.04
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = HiDreamTextRequest(
            prompt: request.prompt,
            image_size: mapImageSize(from: request.dimensions),
            num_inference_steps: 50,
            guidance_scale: 5.0,
            seed: request.seed,
            num_images: request.numberOfImages ?? 1,
            output_format: "png",
            enable_safety_checker: true
        )
        return try await performHiDreamRequest(request: request, body: body)
    }
}

// MARK: - HiDream O1 Image Dev (Text-to-Image)

public final class G_FAL_HIDREAM_O1_IMAGE_DEV: FalHiDreamBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_HIDREAM_O1_IMAGE_DEV
    }

    override var baseCost: Double {
        0.02
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = HiDreamTextRequest(
            prompt: request.prompt,
            image_size: mapImageSize(from: request.dimensions),
            num_inference_steps: 50,
            guidance_scale: 5.0,
            seed: request.seed,
            num_images: request.numberOfImages ?? 1,
            output_format: "png",
            enable_safety_checker: true
        )
        return try await performHiDreamRequest(request: request, body: body)
    }
}

// MARK: - HiDream O1 Image Edit

public final class G_FAL_HIDREAM_O1_IMAGE_EDIT: FalHiDreamBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_HIDREAM_O1_IMAGE_EDIT
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

        let body = HiDreamEditRequest(
            prompt: request.prompt,
            reference_image_urls: [
                "data:image/png;base64,\(clientImage.hasPrefix("data:") ? clientImage.replacingOccurrences(of: "^data:.*;base64,", with: "", options: .regularExpression) : clientImage)",
            ],
            image_size: mapImageSize(from: request.dimensions),
            num_inference_steps: 50,
            guidance_scale: 5.0,
            seed: request.seed,
            num_images: request.numberOfImages ?? 1,
            output_format: "png",
            enable_safety_checker: true
        )
        return try await performHiDreamRequest(request: request, body: body)
    }
}

// MARK: - HiDream O1 Image Dev Edit

public final class G_FAL_HIDREAM_O1_IMAGE_DEV_EDIT: FalHiDreamBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_HIDREAM_O1_IMAGE_DEV_EDIT
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

        let body = HiDreamEditRequest(
            prompt: request.prompt,
            reference_image_urls: [
                "data:image/png;base64,\(clientImage.hasPrefix("data:") ? clientImage.replacingOccurrences(of: "^data:.*;base64,", with: "", options: .regularExpression) : clientImage)",
            ],
            image_size: mapImageSize(from: request.dimensions),
            num_inference_steps: 50,
            guidance_scale: 5.0,
            seed: request.seed,
            num_images: request.numberOfImages ?? 1,
            output_format: "png",
            enable_safety_checker: true
        )
        return try await performHiDreamRequest(request: request, body: body)
    }
}
