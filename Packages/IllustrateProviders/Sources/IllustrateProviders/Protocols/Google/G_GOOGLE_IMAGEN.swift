// MARK: - G_GOOGLE_IMAGEN.swift

// Base implementation for Google Imagen models.
// Supports Imagen 3, Imagen 4 Fast/Standard/Ultra.
//
// ## Imagen 4 Quality Tiers
// - 2K: Higher resolution output
// - Standard: Default quality

import Foundation

/// Base implementation for Google Imagen models.
public class G_GOOGLE_IMAGEN_BASE: ImageGenerationProtocol {
    let modelCode: EnumProviderModelCode
    let costPerImage: Double
    let supportsImageSize: Bool

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(modelCode: EnumProviderModelCode, costPerImage: Double, supportsImageSize: Bool) {
        self.modelCode = modelCode
        self.costPerImage = costPerImage
        self.supportsImageSize = supportsImageSize
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let quality = request.quality ?? ""
        let numberOfImages = request.numberOfImages ?? 1

        let baseCost = switch modelCode {
        case .GOOGLE_IMAGEN_3:
            0.03
        case .GOOGLE_IMAGEN_4_FAST:
            0.02
        case .GOOGLE_IMAGEN_4_STANDARD:
            switch quality.uppercased() {
            case "2K":
                0.08
            default:
                0.04
            }
        case .GOOGLE_IMAGEN_4_ULTRA:
            switch quality.uppercased() {
            case "2K":
                0.12
            default:
                0.06
            }
        default:
            0.03
        }
        return baseCost * Double(numberOfImages)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public struct Instance: Codable, Sendable {
        var prompt: String
    }

    public struct Parameters: Codable, Sendable {
        var aspectRatio: String?
        var sampleCount: Int?
        var imageSize: String?
        var personGeneration: String?
        var seed: Int?

        public init(
            aspectRatio: String?,
            sampleCount: Int? = 1,
            imageSize: String? = nil,
            personGeneration: String? = nil,
            seed: Int? = nil
        ) {
            self.aspectRatio = aspectRatio
            self.sampleCount = sampleCount
            self.imageSize = imageSize
            self.personGeneration = personGeneration
            self.seed = seed
        }
    }

    public struct ServiceRequest: Codable, Sendable {
        var instances: [Instance]
        var parameters: Parameters?

        public init(
            prompt: String,
            aspectRatio: String?,
            imageSize: String?,
            personGeneration: String?,
            seed: Int?,
            sampleCount: Int?
        ) {
            instances = [Instance(prompt: prompt)]
            parameters = Parameters(
                aspectRatio: aspectRatio,
                sampleCount: sampleCount,
                imageSize: imageSize,
                personGeneration: personGeneration,
                seed: seed
            )
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = convertToAspectRatio(request.dimensions)
        var imageSize: String? = nil

        if supportsImageSize {
            switch request.quality.uppercased() {
            case "2K":
                imageSize = "2K"
            default:
                imageSize = "1K"
            }
        }

        let sampleCount = min(max(request.numberOfImages, 1), 4)

        return ServiceRequest(
            prompt: request.prompt,
            aspectRatio: aspectRatio,
            imageSize: imageSize,
            personGeneration: request.personGeneration,
            seed: request.seed,
            sampleCount: sampleCount
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        let rawResponse = extractRawResponse(from: response)

        switch response {
        case let .dictionary(_, data):
            if let predictions = data["predictions"] as? [[String: Any]],
               let firstPrediction = predictions.first,
               let base64Data = firstPrediction["bytesBase64Encoded"] as? String
            {
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: base64Data,
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
                    modelPrompt: request.prompt
                )
            }

            if let error = data["error"] as? [String: Any],
               let message = error["message"] as? String
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message,

                    rawResponse: rawResponse
                )
            }

            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "No image was generated. The prompt may have been filtered by safety controls. Try rephrasing your prompt.",
                rawResponse: rawResponse
            )

        default:
            return createInvalidResponseError(
                response: response,
                modelCode: model.modelCode,
                customMessage: "Unexpected response format"
            )
        }
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "key", value: request.providerSecret)]

        guard let finalURL = components.url else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Failed to construct URL with API key"
            )
        }

        let transformedRequest = transformRequest(request: request)

        do {
            let generation = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: finalURL,
                method: "POST",
                body: transformedRequest,
                headers: [
                    "Content-Type": "application/json",
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

public class G_GOOGLE_IMAGEN_3: G_GOOGLE_IMAGEN_BASE {
    public init() {
        super.init(
            modelCode: .GOOGLE_IMAGEN_3,
            costPerImage: 0.03,
            supportsImageSize: false
        )
    }
}

public class G_GOOGLE_IMAGEN_4_FAST: G_GOOGLE_IMAGEN_BASE {
    public init() {
        super.init(
            modelCode: .GOOGLE_IMAGEN_4_FAST,
            costPerImage: 0.02,
            supportsImageSize: false
        )
    }
}

public class G_GOOGLE_IMAGEN_4_STANDARD: G_GOOGLE_IMAGEN_BASE {
    public init() {
        super.init(
            modelCode: .GOOGLE_IMAGEN_4_STANDARD,
            costPerImage: 0.04,
            supportsImageSize: true
        )
    }
}

public class G_GOOGLE_IMAGEN_4_ULTRA: G_GOOGLE_IMAGEN_BASE {
    public init() {
        super.init(
            modelCode: .GOOGLE_IMAGEN_4_ULTRA,
            costPerImage: 0.06,
            supportsImageSize: true
        )
    }
}
