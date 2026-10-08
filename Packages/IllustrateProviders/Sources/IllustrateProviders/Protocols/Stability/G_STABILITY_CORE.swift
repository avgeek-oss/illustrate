// MARK: - G_STABILITY_CORE.swift

// Implementation for Stability AI Core image generation model.
//
// Stable Image Core provides fast, high-quality image generation
// with extensive style preset support.
//
// ## Request Format
// Uses multipart/form-data with:
// - prompt: Generation prompt
// - aspect_ratio: Target aspect ratio (e.g., "16:9")
// - style_preset: Optional style (anime, cinematic, etc.)
// - negative_prompt: What to avoid
//
// ## Response Format
// Returns JSON with base64-encoded image in "image" field.

import Foundation

/// Stability AI Core model implementation.
public class G_STABILITY_CORE: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 3.0

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return cost == floor(cost) ? String(format: "%.0f credits", cost) : String(format: "%.1f credits", cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .STABILITY_CORE)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let style_preset: String?
        let negative_prompt: String?
        let user: String

        public init(prompt: String, aspectRatio: String, stylePreset: String?, negativePrompt: String?) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            style_preset = (stylePreset?.isEmpty ?? true || stylePreset == "default") ? nil : stylePreset
            negative_prompt = (negativePrompt?.isEmpty ?? true) ? nil : negativePrompt
            user = "illustrate_user"
        }
    }

    func getImageDimensions(dimensions: String) -> String {
        switch dimensions {
        case "576x1024":
            "9:16"
        case "1024x576":
            "16:9"
        case "768x1024":
            "3:4"
        case "1024x768":
            "4:3"
        case "1344x576":
            "21:9"
        case "576x1344":
            "9:21"
        case "1536x1024":
            "3:2"
        case "1024x1536":
            "2:3"
        case "1280x1024":
            "5:4"
        case "1024x1280":
            "4:5"
        default:
            "1:1"
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getImageDimensions(dimensions: request.dimensions)

        return ServiceRequest(
            prompt: request.prompt,
            aspectRatio: aspectRatio,
            stylePreset: request.variant,
            negativePrompt: request.negativePrompt
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        let rawResponse = extractRawResponse(from: response)

        switch response {
        case let .dictionary(_, data):
            if let imageData = data["image"] as? String {
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData,
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
                    modelPrompt: request.prompt
                )
            } else if let errors = data["errors"] as? [String],
                      let message = errors.first
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message,

                    rawResponse: rawResponse
                )
            } else if let message = data["message"] as? String {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message,

                    rawResponse: rawResponse
                )
            }
        case let .array(_, data):
            if let firstDict = data.first,
               let imageData = firstDict["image"] as? String
            {
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData,
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
                    modelPrompt: request.prompt
                )
            } else if let errors = data.first?["errors"] as? [String],
                      let message = errors.first
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message,

                    rawResponse: rawResponse
                )
            } else if let message = data.first?["message"] as? String {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message,

                    rawResponse: rawResponse
                )
            }
        default:
            return createInvalidResponseError(
                response: response,

                modelCode: model.modelCode,
                customMessage: "Unexpected response"
            )
        }

        return createInvalidResponseError(
            response: response,

            modelCode: model.modelCode
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let transformedRequest = transformRequest(request: request)

        do {
            let generation = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: transformedRequest,
                headers: [
                    "Authorization": "\(request.providerSecret)",
                    "Content-Type": "multipart/form-data",
                    "Accept": "application/json",
                ],
                attachments: nil
            )

            do {
                let response = try transformResponse(request: request, response: generation)
                if response.status == .GENERATED {}
                return response
            } catch {
                let rawResponse = extractRawResponse(from: generation)
                return ImageGenerationResponse(
                    status: EnumGenerationStatus.FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.TRANSFORM_RESPONSE_ERROR,
                    errorMessage: "Failed with error: \(error.localizedDescription)",
                    rawResponse: rawResponse
                )
            }
        } catch {
            return ImageGenerationResponse(
                status: EnumGenerationStatus.FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Failed with error: \(error.localizedDescription)",
                rawResponse: "Error: \(error.localizedDescription)"
            )
        }
    }
}
