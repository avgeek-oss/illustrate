// MARK: - G_STABILITY_SD3.swift

// Implementation for Stable Diffusion 3 via Stability AI.
// Latest SD generation with improved quality and detail.

import Foundation

/// Stable Diffusion 3 via Stability AI.
public class G_STABILITY_SD3: ImageGenerationProtocol {
    static let baseCost = 6.5

    private let modelCode: EnumProviderModelCode

    public init(modelCode: EnumProviderModelCode = .STABILITY_SD3) {
        self.modelCode = modelCode
    }

    static func baseCost(for modelCode: EnumProviderModelCode) -> Double {
        switch modelCode {
        case .STABILITY_SD35_LARGE:
            6.5
        case .STABILITY_SD35_LARGE_TURBO:
            4.0
        case .STABILITY_SD35_MEDIUM:
            3.5
        case .STABILITY_SD35_FLASH:
            2.5
        default:
            baseCost
        }
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let requestedModelCode = request.modelId.flatMap(EnumProviderModelCode.init(rawValue:)) ?? modelCode
        return Self.baseCost(for: requestedModelCode) * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return cost == floor(cost) ? String(format: "%.0f credits", cost) : String(format: "%.1f credits", cost)
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let model: String
        let aspect_ratio: String
        let negative_prompt: String?
        let user: String

        public init(prompt: String, model: String, aspectRatio: String, negativePrompt: String?) {
            self.prompt = prompt
            self.model = model
            aspect_ratio = aspectRatio
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
        case "1024x1024":
            "1:1"
        default:
            "1:1"
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getImageDimensions(dimensions: request.dimensions)

        let requestedModelCode = EnumProviderModelCode(rawValue: request.modelId) ?? modelCode
        let modelString = switch requestedModelCode {
        case .STABILITY_SD3_TURBO:
            "sd3-turbo"
        case .STABILITY_SD3:
            "sd3"
        case .STABILITY_SD35_LARGE:
            "sd3.5-large"
        case .STABILITY_SD35_LARGE_TURBO:
            "sd3.5-large-turbo"
        case .STABILITY_SD35_MEDIUM:
            "sd3.5-medium"
        case .STABILITY_SD35_FLASH:
            "sd3.5-flash"
        default:
            "sd3"
        }

        return ServiceRequest(
            prompt: request.prompt,
            model: modelString,
            aspectRatio: aspectRatio,
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
