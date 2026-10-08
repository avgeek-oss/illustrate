// MARK: - G_STABILITY_SDXL.swift

// Implementation for Stable Diffusion XL via Stability AI.
// Classic SDXL generation with broad compatibility.

import Foundation

/// Stable Diffusion XL via Stability AI.
public class G_STABILITY_SDXL: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.2

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return cost == floor(cost) ? String(format: "%.0f credits", cost) : String(format: "%.1f credits", cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .STABILITY_SDXL)!

    public struct ServiceRequest: Codable, Sendable {
        let text_prompts: [TextPrompt]
        let cfg_scale: Double
        let width: Int
        let height: Int
        let steps: Int
        let samples: Int
        let user: String

        struct TextPrompt: Codable {
            let text: String
        }

        public init(prompt: String, width: Int, height: Int) {
            text_prompts = [TextPrompt(text: prompt)]
            cfg_scale = 7.0
            self.width = width
            self.height = height
            steps = 30
            samples = 1
            user = "illustrate_user"
        }
    }

    func getImageDimensions(dimensions: String) -> (width: Int, height: Int) {
        switch dimensions {
        case "1152x896":
            (1152, 896)
        case "896x1152":
            (896, 1152)
        case "1216x832":
            (1216, 832)
        case "1344x768":
            (1344, 768)
        case "768x1344":
            (768, 1344)
        case "1536x640":
            (1536, 640)
        case "640x1536":
            (640, 1536)
        case "1024x1024":
            (1024, 1024)
        default:
            (1024, 1024)
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let dimensions = getImageDimensions(dimensions: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt,
            width: dimensions.width,
            height: dimensions.height
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        let rawResponse = extractRawResponse(from: response)

        switch response {
        case let .dictionary(_, data):
            if let artifacts = data["artifacts"] as? [[String: Any]],
               let firstArtifact = artifacts.first,
               let base64String = firstArtifact["base64"] as? String
            {
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: base64String,
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
               let artifacts = firstDict["artifacts"] as? [[String: Any]],
               let base64String = artifacts.first?["base64"] as? String
            {
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: base64String,
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
                    "Accept": "application/json",
                ],
                attachments: nil
            )

            do {
                return try transformResponse(request: request, response: generation)
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
