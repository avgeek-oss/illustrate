// MARK: - G_FAL_WAN_IMAGE.swift

// WAN image generation models via Fal.ai
//
// Supported models:
// - wan/v2.6/text-to-image: Text-to-image with Chinese/English prompts
// - wan/v2.6/image-to-image: Multi-image reference editing

import Foundation

// MARK: - Base Class

public class FalWanImageBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var baseCost: Double {
        0.03
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

    // MARK: - Helpers

    func performWanImageRequest(
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

    /// Converts base64 to data URI for Fal
    func toDataUri(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:image/png;base64,\(base64)"
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
        guard let url = URL(string: urlStr) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid image URL: \(urlStr)"
            )
        }

        let imageData = try Data(contentsOf: url)
        let base64 = imageData.base64EncodedString()

        return ImageGenerationResponse(
            status: .GENERATED,
            base64: base64,
            cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }
}

// MARK: - Request Structs

struct FalWanTextToImageRequest: Codable {
    let prompt: String
    let negative_prompt: String?
    let image_size: String
    let num_images: Int
    let seed: Int?
    let reference_image_url: String?
}

struct FalWanImageToImageRequest: Codable {
    let prompt: String
    let negative_prompt: String?
    let image_size: String
    let num_images: Int
    let seed: Int?
    let image_urls: [String]
}

// MARK: - WAN v2.6 Text-to-Image

public final class G_FAL_WAN_V26_TEXT_TO_IMAGE: FalWanImageBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_V26_TEXT_TO_IMAGE
    }

    override var baseCost: Double {
        0.03
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = FalWanTextToImageRequest(
            prompt: request.prompt,
            negative_prompt: request.negativePrompt,
            image_size: request.dimensions,
            num_images: request.numberOfImages,
            seed: request.seed,
            reference_image_url: request.clientImage.map { toDataUri($0) }
        )
        return try await performWanImageRequest(request: request, body: body)
    }
}

// MARK: - WAN v2.6 Image-to-Image

public final class G_FAL_WAN_V26_IMAGE_TO_IMAGE: FalWanImageBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_WAN_V26_IMAGE_TO_IMAGE
    }

    override var baseCost: Double {
        0.03
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        var imageUrls: [String] = []
        if let clientImage = request.clientImage {
            imageUrls.append(toDataUri(clientImage))
        }
        if let referenceImages = request.clientReferenceImages {
            imageUrls.append(contentsOf: referenceImages.map { toDataUri($0.base64Image) })
        }

        let body = FalWanImageToImageRequest(
            prompt: request.prompt,
            negative_prompt: request.negativePrompt,
            image_size: request.dimensions,
            num_images: request.numberOfImages,
            seed: request.seed,
            image_urls: imageUrls
        )
        return try await performWanImageRequest(request: request, body: body)
    }
}
