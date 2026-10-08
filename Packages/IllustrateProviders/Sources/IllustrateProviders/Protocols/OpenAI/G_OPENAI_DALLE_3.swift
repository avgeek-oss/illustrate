// MARK: - G_OPENAI_DALLE_3.swift

// Implementation for OpenAI DALL-E 3 model.
// Classic image generation with quality and size options.

import Foundation

/// DALL-E 3 image generation implementation.
public class G_OPENAI_DALLE_3: ImageGenerationProtocol {
    public init() {}
    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let quality = request.quality ?? ""
        let dimensions = request.dimensions ?? "1024x1024"
        let numberOfImages = request.numberOfImages ?? 1

        let baseCost = switch quality.lowercased() {
        case "hd":
            switch dimensions {
            case "1024x1024":
                0.08
            case "1792x1024", "1024x1792":
                0.12
            default:
                0.12
            }
        default:
            switch dimensions {
            case "1024x1024":
                0.04
            case "1792x1024", "1024x1792":
                0.08
            default:
                0.08
            }
        }
        return baseCost * Double(numberOfImages)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .OPENAI_DALLE3)!

    public struct ServiceRequest: Codable, Sendable {
        let model: String
        let prompt: String
        let n: Int
        let size: String
        let quality: String
        let style: String?
        let response_format: String?
        let user: String

        public init(prompt: String, aspectRatio: String, quality: String, stylePreset: String) {
            model = "dall-e-3"
            self.prompt = prompt
            n = 1
            size = aspectRatio
            self.quality = quality
            style = stylePreset
            response_format = "b64_json"
            user = "illustrate_user"
        }
    }

    func getImageDimensions(dimensions: String) -> String {
        switch dimensions {
        case "1792x1024":
            "1792x1024"
        case "1024x1792":
            "1024x1792"
        case "1024x1024":
            "1024x1024"
        default:
            "1024x1024"
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getImageDimensions(dimensions: request.dimensions)
        let promptWithVariant = request
            .variant != "photographic" ? "\(request.variant) - \(request.prompt)" : request.prompt

        return ServiceRequest(
            prompt: promptWithVariant,
            aspectRatio: aspectRatio,
            quality: request.quality.lowercased(),
            stylePreset: request.style.lowercased()
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        let rawResponse = extractRawResponse(from: response)

        switch response {
        case let .dictionary(_, data):
            if let nestedData = data["data"] as? [[String: Any]],
               let imageData = nestedData.first?["b64_json"] as? String
            {
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData,
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
                    modelPrompt: nestedData.first?["revised_prompt"] as? String? ?? request.prompt
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
            } else if let error = data["error"] as? [String: Any],
                      let message = error["message"] as? String
            {
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
                    "Authorization": "Bearer \(request.providerSecret)",
                    "Content-Type": "application/json",
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
