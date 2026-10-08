// MARK: - G_REPLICATE_GOOGLE_IMAGEN.swift

// Implementation for Google Imagen models via Replicate.
// Supports Imagen 3, Imagen 4, Imagen 4 Fast, and Imagen 4 Ultra.
// All variants share the same schema with different pricing.

import Foundation

/// Base adapter for Google Imagen models via Replicate.
public class G_REPLICATE_GOOGLE_IMAGEN: ImageGenerationProtocol {
    public let modelCode: EnumProviderModelCode

    public init(modelCode: EnumProviderModelCode = .REPLICATE_GOOGLE_IMAGEN_3) {
        self.modelCode = modelCode
    }

    /// Returns cost per image based on model variant
    private var baseCost: Double {
        switch modelCode {
        case .REPLICATE_GOOGLE_IMAGEN_3:
            0.05
        case .REPLICATE_GOOGLE_IMAGEN_3_FAST:
            0.025
        case .REPLICATE_GOOGLE_IMAGEN_4:
            0.04
        case .REPLICATE_GOOGLE_IMAGEN_4_FAST:
            0.02
        case .REPLICATE_GOOGLE_IMAGEN_4_ULTRA:
            0.06
        default:
            0.05
        }
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String
        public let aspect_ratio: String
        public let output_format: String
        public let safety_filter_level: String

        public init(
            prompt: String,
            aspectRatio: String = "1:1",
            safetyFilterLevel: String = "block_only_high"
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            output_format = "png"
            safety_filter_level = safetyFilterLevel
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)

        return ServiceRequest(
            prompt: request.prompt,
            aspectRatio: aspectRatio.ratio
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            // Output can be a single URL string
            if let imageUrl = data["output"] as? String {
                let url = URL(string: imageUrl)!
                let imageData = try Data(contentsOf: url)
                let base64 = imageData.base64EncodedString()

                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
            }
            // Or an array of URLs
            if let output = data["output"] as? [String],
               let imageUrl = output.first
            {
                let url = URL(string: imageUrl)!
                let imageData = try Data(contentsOf: url)
                let base64 = imageData.base64EncodedString()

                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
            }
            // Handle errors
            if let errorList = data["error"] as? [String],
               let error = errorList.first
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: error
                )
            }
            if let error = data["error"] as? String {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: error
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

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String],
        maxAttempts: Int = 60
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 3_000_000_000)

            do {
                let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                    url: url.appendingPathComponent("/\(requestId)"),
                    method: "GET",
                    body: nil as String?,
                    headers: headers,
                    attachments: nil
                )

                switch response {
                case let .dictionary(_, data):
                    if let status = data["status"] as? String,
                       status == "succeeded" || status == "failed" || status == "canceled"
                    {
                        return response
                    }
                default:
                    break
                }
            } catch {
                throw NSError(domain: "Polling failed", code: -1, userInfo: nil)
            }

            attempts += 1
        }

        throw NSError(domain: "Polling exceeded max attempts", code: -1, userInfo: nil)
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        let serviceRequest = transformRequest(request: request)

        do {
            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": serviceRequest],
                headers: headers,
                attachments: nil
            )

            guard case let .dictionary(_, data) = response,
                  let predictionId = data["id"] as? String
            else {
                return createInvalidResponseError(
                    response: response,
                    modelCode: model.modelCode,
                    customMessage: "Failed to create prediction"
                )
            }

            // Poll for result
            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await pollForResult(
                requestId: predictionId,
                url: statusUrl,
                headers: headers
            )

            return try transformResponse(request: request, response: finalResponse)
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Subclasses for specific models

public class G_REPLICATE_GOOGLE_IMAGEN_3: G_REPLICATE_GOOGLE_IMAGEN {
    public init() {
        super.init(modelCode: .REPLICATE_GOOGLE_IMAGEN_3)
    }
}

public class G_REPLICATE_GOOGLE_IMAGEN_3_FAST: G_REPLICATE_GOOGLE_IMAGEN {
    public init() {
        super.init(modelCode: .REPLICATE_GOOGLE_IMAGEN_3_FAST)
    }
}

public class G_REPLICATE_GOOGLE_IMAGEN_4: G_REPLICATE_GOOGLE_IMAGEN {
    public init() {
        super.init(modelCode: .REPLICATE_GOOGLE_IMAGEN_4)
    }
}

public class G_REPLICATE_GOOGLE_IMAGEN_4_FAST: G_REPLICATE_GOOGLE_IMAGEN {
    public init() {
        super.init(modelCode: .REPLICATE_GOOGLE_IMAGEN_4_FAST)
    }
}

public class G_REPLICATE_GOOGLE_IMAGEN_4_ULTRA: G_REPLICATE_GOOGLE_IMAGEN {
    public init() {
        super.init(modelCode: .REPLICATE_GOOGLE_IMAGEN_4_ULTRA)
    }
}
