// MARK: - G_REPLICATE_STABLE_DIFFUSION_3.swift

// Implementation for Stability AI Stable Diffusion 3.x models via Replicate.
// Supports SD3, SD3.5 Large, SD3.5 Large Turbo, and SD3.5 Medium variants.
// All variants share the same schema with different pricing.

import Foundation

/// Base adapter for Stable Diffusion 3.x models via Replicate.
/// Handles SD3, SD3.5 Large, SD3.5 Large Turbo, and SD3.5 Medium.
public class G_REPLICATE_STABLE_DIFFUSION_3: ImageGenerationProtocol {
    let modelCode: EnumProviderModelCode

    public init(modelCode: EnumProviderModelCode = .REPLICATE_STABLE_DIFFUSION_3) {
        self.modelCode = modelCode
    }

    /// Returns cost per image based on model variant
    private var baseCost: Double {
        switch modelCode {
        case .REPLICATE_STABLE_DIFFUSION_3:
            0.035
        case .REPLICATE_STABLE_DIFFUSION_3_5_LARGE:
            0.065
        case .REPLICATE_STABLE_DIFFUSION_3_5_LARGE_TURBO:
            0.04
        case .REPLICATE_STABLE_DIFFUSION_3_5_MEDIUM:
            0.035
        default:
            0.035
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
        let prompt: String
        let cfg: Double
        let seed: Int?
        let image: String?
        let aspect_ratio: String
        let output_format: String
        let negative_prompt: String?
        let prompt_strength: Double?

        init(
            prompt: String,
            cfg: Double = 5.0,
            seed: Int? = nil,
            image: String? = nil,
            aspectRatio: String = "1:1",
            negativePrompt: String? = nil,
            promptStrength: Double? = nil
        ) {
            self.prompt = prompt
            self.cfg = cfg
            self.seed = seed
            self.image = image
            aspect_ratio = aspectRatio
            output_format = "png"
            negative_prompt = negativePrompt
            prompt_strength = promptStrength
        }
    }

    func transformRequest(request: ImageGenerationRequest, inputImageUrl: String? = nil) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)

        return ServiceRequest(
            prompt: request.prompt,
            cfg: request.guidance ?? 5.0,
            seed: request.seed,
            image: inputImageUrl,
            aspectRatio: aspectRatio.ratio,
            negativePrompt: request.negativePrompt,
            promptStrength: inputImageUrl != nil ? 0.85 : nil
        )
    }

    /// Protocol conformance
    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, inputImageUrl: nil)
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

        // Upload reference image if provided (for img2img)
        var inputImageUrl: String? = nil
        if let clientImage = request.clientImage {
            do {
                inputImageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
            } catch {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Failed to upload input image: \(error.localizedDescription)"
                )
            }
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        let serviceRequest = transformRequest(request: request, inputImageUrl: inputImageUrl)

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

public class G_REPLICATE_STABLE_DIFFUSION_3_5_LARGE: G_REPLICATE_STABLE_DIFFUSION_3 {
    public init() {
        super.init(modelCode: .REPLICATE_STABLE_DIFFUSION_3_5_LARGE)
    }
}

public class G_REPLICATE_STABLE_DIFFUSION_3_5_LARGE_TURBO: G_REPLICATE_STABLE_DIFFUSION_3 {
    public init() {
        super.init(modelCode: .REPLICATE_STABLE_DIFFUSION_3_5_LARGE_TURBO)
    }
}

public class G_REPLICATE_STABLE_DIFFUSION_3_5_MEDIUM: G_REPLICATE_STABLE_DIFFUSION_3 {
    public init() {
        super.init(modelCode: .REPLICATE_STABLE_DIFFUSION_3_5_MEDIUM)
    }
}
