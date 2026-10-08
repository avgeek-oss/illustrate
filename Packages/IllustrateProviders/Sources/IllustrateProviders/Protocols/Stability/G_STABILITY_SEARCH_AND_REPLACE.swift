// MARK: - G_STABILITY_SEARCH_AND_REPLACE.swift

// Implementation for Stability AI Search and Replace.
// Find and replace objects using text prompts.

import Foundation

/// Stability AI text-guided search and replace.
public class G_STABILITY_SEARCH_AND_REPLACE: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 4.0

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return cost == floor(cost) ? String(format: "%.0f credits", cost) : String(format: "%.1f credits", cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .STABILITY_SEARCH_AND_REPLACE)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let negative_prompt: String?
        let search_prompt: String
        let user: String

        public init(prompt: String, searchPrompt: String, negativePrompt: String?) {
            self.prompt = prompt
            search_prompt = searchPrompt
            negative_prompt = (negativePrompt?.isEmpty ?? true) ? nil : negativePrompt
            user = "illustrate_user"
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        ServiceRequest(
            prompt: request.prompt,
            searchPrompt: request.searchPrompt ?? "",
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
        guard request.clientImage != nil else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Reference Image Missing"
            )
        }

        let transformedRequest = transformRequest(request: request)

        let headers: [String: String] = [
            "Authorization": "\(request.providerSecret)",
            "Content-Type": "multipart/form-data",
            "Accept": "application/json",
        ]

        let response = try await ProviderDependencies.shared.networkProvider.performRequest(
            url: url,
            method: "POST",
            body: transformedRequest,
            headers: headers,
            attachments: [
                NetworkRequestAttachment(
                    name: "image",
                    mimeType: "jpeg",
                    data: Data(
                        base64Encoded: request.clientImage!.replacingOccurrences(
                            of: "^data:.*;base64,",
                            with: "",
                            options: .regularExpression
                        )
                    )!
                ),
            ]
        )

        return try transformResponse(request: request, response: response)
    }
}
