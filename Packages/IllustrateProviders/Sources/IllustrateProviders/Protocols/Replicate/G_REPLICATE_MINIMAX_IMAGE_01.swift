// MARK: - G_REPLICATE_MINIMAX_IMAGE_01.swift

// Implementation for MiniMax Image-01 via Replicate.
// Image generation with optional subject reference (face) support.

import Foundation

/// MiniMax Image-01 via Replicate.
public class G_REPLICATE_MINIMAX_IMAGE_01: ImageGenerationProtocol {
    public init() {}
    /// Flat cost per image ($0.01)
    static let baseCost = 0.01

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_MINIMAX_IMAGE_01)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let number_of_images: Int
        let prompt_optimizer: Bool
        let subject_reference: String?

        init(
            prompt: String,
            aspectRatio: String = "1:1",
            numberOfImages: Int = 1,
            promptOptimizer: Bool = true,
            subjectReference: String? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            number_of_images = numberOfImages
            prompt_optimizer = promptOptimizer
            subject_reference = subjectReference
        }
    }

    func transformRequest(request: ImageGenerationRequest, subjectReferenceUrl: String? = nil) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            aspectRatio: aspectRatio.ratio,
            numberOfImages: 1,
            promptOptimizer: request.promptEnhance ?? true,
            subjectReference: subjectReferenceUrl
        )
    }

    /// Protocol conformance
    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, subjectReferenceUrl: nil)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            // Output is an array of URLs
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
            // Single URL output (fallback)
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

        // Upload subject reference image if present
        var subjectReferenceUrl: String? = nil
        if let clientImage = request.clientImage {
            do {
                subjectReferenceUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
            } catch {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Failed to upload subject reference: \(error.localizedDescription)"
                )
            }
        }

        let transformedRequest = transformRequest(request: request, subjectReferenceUrl: subjectReferenceUrl)

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
