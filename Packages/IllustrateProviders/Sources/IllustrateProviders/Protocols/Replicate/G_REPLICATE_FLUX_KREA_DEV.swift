// MARK: - G_REPLICATE_FLUX_KREA_DEV.swift

// Implementation for FLUX Krea Dev via Replicate.
// A fine-tuned FLUX model with image-to-image support and guidance control.

import Foundation

/// FLUX Krea Dev via Replicate.
public class G_REPLICATE_FLUX_KREA_DEV: ImageGenerationProtocol {
    public init() {}
    /// Flat cost per image ($0.025)
    static let baseCost = 0.025

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_FLUX_KREA_DEV)!

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String
        public let aspect_ratio: String
        public let megapixels: String
        public let num_outputs: Int
        public let num_inference_steps: Int
        public let guidance: Double
        public let go_fast: Bool
        public let output_format: String
        public let output_quality: Int
        public let seed: Int?
        public let image: String?

        public init(
            prompt: String,
            aspectRatio: String,
            megapixels: String = "1",
            numOutputs: Int = 1,
            steps: Int = 28,
            guidance: Double = 4.5,
            goFast: Bool = true,
            seed: Int? = nil,
            image: String? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.megapixels = megapixels
            num_outputs = numOutputs
            num_inference_steps = steps
            self.guidance = guidance
            go_fast = goFast
            output_format = "png"
            output_quality = 100
            self.seed = seed
            self.image = image
        }
    }

    public func transformRequest(request: ImageGenerationRequest, sourceImageUrl: String? = nil) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        // Convert resolution format (e.g., "1 MP" -> "1", "0.25 MP" -> "0.25")
        let megapixels: String = if let resolution = request.resolution {
            resolution
                .replacingOccurrences(of: " MP", with: "")
                .replacingOccurrences(of: "MP", with: "")
                .trimmingCharacters(in: .whitespaces)
        } else {
            "1"
        }

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            aspectRatio: aspectRatio.ratio,
            megapixels: megapixels,
            numOutputs: 1, // We handle batch generation at the adapter level
            steps: request.steps ?? 28,
            guidance: request.guidance ?? 4.5,
            goFast: request.promptEnhance ?? true,
            seed: request.seed,
            image: sourceImageUrl
        )
    }

    /// Protocol conformance - simplified version without source image URL
    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, sourceImageUrl: nil)
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

        // Upload source image if present
        var sourceImageUrl: String? = nil
        if let clientImage = request.clientImage {
            do {
                sourceImageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
            } catch {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Failed to upload source image: \(error.localizedDescription)"
                )
            }
        }

        let transformedRequest = transformRequest(request: request, sourceImageUrl: sourceImageUrl)

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
