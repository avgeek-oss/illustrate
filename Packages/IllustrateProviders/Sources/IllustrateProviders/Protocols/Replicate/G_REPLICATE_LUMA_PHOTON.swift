// MARK: - G_REPLICATE_LUMA_PHOTON.swift

// Implementation for Luma Photon image models via Replicate.
// Image generation with image, style, and character reference support.

import Foundation

/// Base implementation for Luma Photon image generation.
public class G_REPLICATE_LUMA_PHOTON_BASE: ImageGenerationProtocol {
    let modelCode: EnumProviderModelCode

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(modelCode: EnumProviderModelCode) {
        self.modelCode = modelCode
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let baseCost: Double = modelCode == .REPLICATE_LUMA_PHOTON_FLASH ? 0.01 : 0.03
        return baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let seed: Int?
        let image_reference: String?
        let image_reference_weight: Double?
        let style_reference: String?
        let style_reference_weight: Double?
        let character_reference: String?

        init(
            prompt: String,
            aspectRatio: String = "16:9",
            seed: Int? = nil,
            imageReference: String? = nil,
            imageReferenceWeight: Double? = nil,
            styleReference: String? = nil,
            styleReferenceWeight: Double? = nil,
            characterReference: String? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.seed = seed
            image_reference = imageReference
            image_reference_weight = imageReferenceWeight
            style_reference = styleReference
            style_reference_weight = styleReferenceWeight
            character_reference = characterReference
        }
    }

    func transformRequest(
        request: ImageGenerationRequest,
        imageReferenceUrl: String? = nil,
        styleReferenceUrl: String? = nil,
        characterReferenceUrl: String? = nil
    ) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            aspectRatio: aspectRatio.ratio,
            seed: request.seed,
            imageReference: imageReferenceUrl,
            imageReferenceWeight: imageReferenceUrl != nil ? 0.85 : nil,
            styleReference: styleReferenceUrl,
            styleReferenceWeight: styleReferenceUrl != nil ? 0.85 : nil,
            characterReference: characterReferenceUrl
        )
    }

    /// Protocol conformance
    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, imageReferenceUrl: nil, styleReferenceUrl: nil, characterReferenceUrl: nil)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            // Output is a single URL string
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
            // Array output fallback
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
        maxAttempts: Int = 30
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 4_000_000_000)

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

        // Upload source image as image reference if present
        var imageReferenceUrl: String? = nil
        if let clientImage = request.clientImage {
            do {
                imageReferenceUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
            } catch {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Failed to upload image reference: \(error.localizedDescription)"
                )
            }
        }

        let transformedRequest = transformRequest(
            request: request,
            imageReferenceUrl: imageReferenceUrl,
            styleReferenceUrl: nil,
            characterReferenceUrl: nil
        )

        do {
            let headers: [String: String] = [
                "Authorization": "Bearer \(request.providerSecret)",
                "Content-Type": "application/json",
            ]

            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: [
                    "input": transformedRequest,
                ],
                headers: headers,
                attachments: nil
            )

            do {
                var requestId: String? = nil
                switch initialResponse {
                case let .dictionary(_, data):
                    if data["id"] as? String != nil {
                        requestId = data["id"] as? String
                    }
                default:
                    return createInvalidResponseError(
                        response: initialResponse,
                        modelCode: model.modelCode,
                        customMessage: "Unexpected response"
                    )
                }

                guard let requestId else {
                    return ImageGenerationResponse(
                        status: .FAILED,
                        errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                        errorMessage: "Failed to initiate request"
                    )
                }

                guard let statusUrl = model.statusURL else {
                    return createInvalidStatusURLError()
                }

                let finalResponse = try await pollForResult(requestId: requestId, url: statusUrl, headers: headers)

                return try transformResponse(request: request, response: finalResponse)
            } catch {
                return ImageGenerationResponse(
                    status: EnumGenerationStatus.FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.TRANSFORM_RESPONSE_ERROR,
                    errorMessage: "Failed with error: \(error.localizedDescription)",
                    rawResponse: "Error: \(error.localizedDescription)"
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

public class G_REPLICATE_LUMA_PHOTON: G_REPLICATE_LUMA_PHOTON_BASE {
    public init() {
        super.init(modelCode: .REPLICATE_LUMA_PHOTON)
    }
}

public class G_REPLICATE_LUMA_PHOTON_FLASH: G_REPLICATE_LUMA_PHOTON_BASE {
    public init() {
        super.init(modelCode: .REPLICATE_LUMA_PHOTON_FLASH)
    }
}
