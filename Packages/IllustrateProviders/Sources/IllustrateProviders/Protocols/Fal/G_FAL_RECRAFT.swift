// MARK: - G_FAL_RECRAFT.swift

// Recraft models via Fal AI:
// - fal-ai/recraft/v3/text-to-image

import Foundation

// MARK: - Base Class

public class FalRecraftBase: ImageGenerationProtocol {
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

    // MARK: - Helpers

    func performRecraftRequest(
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

    func normalizeImageSize(from dimensions: String) -> String {
        let recraftSizes = [
            "square_hd",
            "square",
            "portrait_4_3",
            "portrait_16_9",
            "landscape_4_3",
            "landscape_16_9",
        ]
        if recraftSizes.contains(dimensions) { return dimensions }

        let normalized = dimensions.replacingOccurrences(of: "x", with: ":").lowercased()

        switch normalized {
        case "1:1", "1024:1024", "512:512", "768:768":
            return "square_hd"
        case "4:3", "1024:768", "1536:1152":
            return "landscape_4_3"
        case "3:4", "768:1024", "1152:1536":
            return "portrait_4_3"
        case "16:9", "1920:1080", "1536:864":
            return "landscape_16_9"
        case "9:16", "1080:1920", "864:1536":
            return "portrait_16_9"
        default:
            return "square_hd"
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

// MARK: - Recraft V3 Text-to-Image

private struct RecraftV3Request: Codable {
    let prompt: String
    let image_size: String?
    let style: String?
}

public final class G_FAL_RECRAFT_V3: FalRecraftBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_RECRAFT_V3
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Prompt is required"
            )
        }

        let body = RecraftV3Request(
            prompt: request.prompt,
            image_size: normalizeImageSize(from: request.dimensions),
            style: "realistic_image"
        )
        return try await performRecraftRequest(request: request, body: body)
    }
}

// MARK: - Recraft V4.1 Models

private struct RecraftV41Request: Codable {
    let prompt: String
    let image_size: String?
    let style: String?
    let seed: Int?
}

private struct RecraftV41EditRequest: Codable {
    let prompt: String
    let image_url: String
    let image_size: String?
    let style: String?
    let seed: Int?
}

public final class G_FAL_RECRAFT_V4_1: FalRecraftBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_RECRAFT_V4_1
    }

    override var baseCost: Double {
        0.04
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Prompt is required"
            )
        }

        let body = RecraftV41Request(
            prompt: request.prompt,
            image_size: normalizeImageSize(from: request.dimensions),
            style: "realistic_image",
            seed: request.seed
        )
        return try await performRecraftRequest(request: request, body: body)
    }
}

public final class G_FAL_RECRAFT_V4_1_EDIT: FalRecraftBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_RECRAFT_V4_1_EDIT
    }

    override var baseCost: Double {
        0.05
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = RecraftV41EditRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            image_size: normalizeImageSize(from: request.dimensions),
            style: "realistic_image",
            seed: request.seed
        )
        return try await performRecraftRequest(request: request, body: body)
    }

    func toDataUri(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:image/png;base64,\(base64)"
    }
}

public final class G_FAL_RECRAFT_V4_1_ULTRA: FalRecraftBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_RECRAFT_V4_1_ULTRA
    }

    override var baseCost: Double {
        0.06
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Prompt is required"
            )
        }

        let body = RecraftV41Request(
            prompt: request.prompt,
            image_size: normalizeImageSize(from: request.dimensions),
            style: "realistic_image",
            seed: request.seed
        )
        return try await performRecraftRequest(request: request, body: body)
    }
}

public final class G_FAL_RECRAFT_V4_1_ULTRA_EDIT: FalRecraftBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_RECRAFT_V4_1_ULTRA_EDIT
    }

    override var baseCost: Double {
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

        let body = RecraftV41EditRequest(
            prompt: request.prompt,
            image_url: toDataUri(clientImage),
            image_size: normalizeImageSize(from: request.dimensions),
            style: "realistic_image",
            seed: request.seed
        )
        return try await performRecraftRequest(request: request, body: body)
    }

    func toDataUri(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:image/png;base64,\(base64)"
    }
}
