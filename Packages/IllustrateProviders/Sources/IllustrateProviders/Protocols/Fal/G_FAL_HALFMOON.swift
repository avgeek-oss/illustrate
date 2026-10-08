// MARK: - G_FAL_HALFMOON.swift

// Half Moon AI Home models via Fal AI:
// - half-moon-ai/ai-home/style
// - half-moon-ai/ai-home/edit

import Foundation

// MARK: - Base Class

public class FalHalfMoonBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var baseCost: Double {
        0.001
    } // $0.00003/compute-second (~30 sec = ~$0.001)

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
            // AI Home returns single "image" not "images" array
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

    func performHalfMoonRequest(
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

// MARK: - AI Home Style

private struct AIHomeStyleRequest: Codable {
    let input_image_url: String
    let architecture_type: String
    let style: String
    let color_palette: String
    let custom_prompt: String?
    let input_image_strength: Double?
    let output_format: String
}

public final class G_FAL_HALFMOON_AI_HOME_STYLE: FalHalfMoonBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_HALFMOON_AI_HOME_STYLE
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        // Use prompt as custom_prompt if provided, otherwise use defaults
        let customPrompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : request.prompt

        let body = AIHomeStyleRequest(
            input_image_url: toDataUri(clientImage),
            architecture_type: "living room-interior",
            style: "modern-interior",
            color_palette: "surprise me",
            custom_prompt: customPrompt,
            input_image_strength: 0.85,
            output_format: "png"
        )
        return try await performHalfMoonRequest(request: request, body: body)
    }
}

// MARK: - AI Home Edit

private struct AIHomeEditRequest: Codable {
    let input_image_url: String
    let editing_type: String
    let architecture_type: String
    let style: String
    let color_palette: String
    let custom_prompt: String?
    let output_format: String
}

public final class G_FAL_HALFMOON_AI_HOME_EDIT: FalHalfMoonBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_HALFMOON_AI_HOME_EDIT
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        // Use prompt as custom_prompt if provided, otherwise use defaults
        let customPrompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : request.prompt

        let body = AIHomeEditRequest(
            input_image_url: toDataUri(clientImage),
            editing_type: "both",
            architecture_type: "living room-interior",
            style: "modern-interior",
            color_palette: "surprise me",
            custom_prompt: customPrompt,
            output_format: "png"
        )
        return try await performHalfMoonRequest(request: request, body: body)
    }
}
