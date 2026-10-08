// MARK: - G_REPLICATE_FLUX_KONTEXT.swift

// Consolidated implementation for FLUX Kontext models via Replicate.
// Context-aware image generation and editing.
// Includes: Max, Pro, and Dev variants.

import Foundation

// MARK: - Shared Helpers

private func kontextTransformResponse(
    request: ImageGenerationRequest,
    response: NetworkResponseData,
    modelCode: EnumProviderModelCode,
    costEstimate: Double
) throws -> ImageGenerationResponse {
    switch response {
    case let .dictionary(_, data):
        if let imageUrl = data["output"] as? String {
            let url = URL(string: imageUrl)!
            let imageData = try Data(contentsOf: url)
            let base64 = imageData.base64EncodedString()
            return ImageGenerationResponse(status: .GENERATED, base64: base64, cost: costEstimate)
        }
        if let output = data["output"] as? [String], let imageUrl = output.first {
            let url = URL(string: imageUrl)!
            let imageData = try Data(contentsOf: url)
            let base64 = imageData.base64EncodedString()
            return ImageGenerationResponse(status: .GENERATED, base64: base64, cost: costEstimate)
        }
        if let errorList = data["error"] as? [String], let error = errorList.first {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
        }
        if let error = data["error"] as? String {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
        }
    default:
        break
    }
    return createInvalidResponseError(response: response, modelCode: modelCode)
}

private func kontextPollForResult(
    requestId: String,
    url: URL,
    headers: [String: String],
    modelName: String,
    maxAttempts: Int = 30
) async throws -> NetworkResponseData {
    var attempts = 0
    while attempts < maxAttempts {
        try await Task.sleep(nanoseconds: 4_000_000_000)

        let response = try await ProviderDependencies.shared.networkProvider.performRequest(
            url: url.appendingPathComponent("/\(requestId)"),
            method: "GET",
            body: nil as String?,
            headers: headers,
            attachments: nil
        )

        if case let .dictionary(_, data) = response,
           let status = data["status"] as? String,
           status == "succeeded" || status == "failed" || status == "canceled"
        {
            return response
        }
        attempts += 1
    }
    throw NSError(domain: "Polling exceeded max attempts", code: -1, userInfo: nil)
}

// MARK: - FLUX Kontext Max

/// FLUX Kontext Max via Replicate - $0.08 flat rate.
public class G_REPLICATE_FLUX_KONTEXT_MAX: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.08

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_FLUX_KONTEXT_MAX)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let safety_tolerance: Int
        let prompt_upsampling: Bool
        let output_format: String
        let seed: Int?
        let input_image: String?

        init(
            prompt: String,
            aspectRatio: String,
            safetyTolerance: Int = 2,
            promptUpsampling: Bool = false,
            seed: Int? = nil,
            inputImage: String? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            safety_tolerance = safetyTolerance
            prompt_upsampling = promptUpsampling
            output_format = "png"
            self.seed = seed
            input_image = inputImage
        }
    }

    public func transformRequest(request: ImageGenerationRequest, sourceImageUrl: String? = nil) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            aspectRatio: sourceImageUrl != nil ? "1:1" : aspectRatio.ratio,
            safetyTolerance: request.safetyTolerance ?? 2,
            promptUpsampling: request.promptEnhance ?? false,
            seed: request.seed,
            inputImage: sourceImageUrl
        )
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, sourceImageUrl: nil)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try kontextTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            costEstimate: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

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
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to upload source image: \(error.localizedDescription)"
                )
            }
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let transformedRequest = transformRequest(request: request, sourceImageUrl: sourceImageUrl)

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": transformedRequest],
                headers: headers,
                attachments: nil
            )

            guard case let .dictionary(_, data) = initialResponse, let requestId = data["id"] as? String else {
                return createInvalidResponseError(response: initialResponse, modelCode: model.modelCode)
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await kontextPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "FLUX Kontext Max"
            )
            return try transformResponse(request: request, response: finalResponse)
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - FLUX Kontext Pro

/// FLUX Kontext Pro via Replicate - $0.04 flat rate.
public class G_REPLICATE_FLUX_KONTEXT_PRO: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.04

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_FLUX_KONTEXT_PRO)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let safety_tolerance: Int
        let prompt_upsampling: Bool
        let output_format: String
        let seed: Int?
        let input_image: String?

        init(
            prompt: String,
            aspectRatio: String,
            safetyTolerance: Int = 2,
            promptUpsampling: Bool = false,
            seed: Int? = nil,
            inputImage: String? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            safety_tolerance = safetyTolerance
            prompt_upsampling = promptUpsampling
            output_format = "png"
            self.seed = seed
            input_image = inputImage
        }
    }

    public func transformRequest(request: ImageGenerationRequest, sourceImageUrl: String? = nil) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            aspectRatio: sourceImageUrl != nil ? "1:1" : aspectRatio.ratio,
            safetyTolerance: request.safetyTolerance ?? 2,
            promptUpsampling: request.promptEnhance ?? false,
            seed: request.seed,
            inputImage: sourceImageUrl
        )
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, sourceImageUrl: nil)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try kontextTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            costEstimate: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

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
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to upload source image: \(error.localizedDescription)"
                )
            }
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let transformedRequest = transformRequest(request: request, sourceImageUrl: sourceImageUrl)

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": transformedRequest],
                headers: headers,
                attachments: nil
            )

            guard case let .dictionary(_, data) = initialResponse, let requestId = data["id"] as? String else {
                return createInvalidResponseError(response: initialResponse, modelCode: model.modelCode)
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await kontextPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "FLUX Kontext Pro"
            )
            return try transformResponse(request: request, response: finalResponse)
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - FLUX Kontext Dev

/// FLUX Kontext Dev via Replicate - $0.025 flat rate. Requires input image.
public class G_REPLICATE_FLUX_KONTEXT_DEV: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.025

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_FLUX_KONTEXT_DEV)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let input_image: String
        let aspect_ratio: String
        let num_inference_steps: Int
        let guidance: Double
        let go_fast: Bool
        let output_format: String
        let output_quality: Int
        let seed: Int?

        init(
            prompt: String,
            inputImage: String,
            aspectRatio: String = "1:1",
            steps: Int = 28,
            guidance: Double = 2.5,
            goFast: Bool = true,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            input_image = inputImage
            aspect_ratio = aspectRatio
            num_inference_steps = steps
            self.guidance = guidance
            go_fast = goFast
            output_format = "png"
            output_quality = 100
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest, sourceImageUrl: String) -> ServiceRequest {
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            inputImage: sourceImageUrl,
            aspectRatio: "1:1",
            steps: request.steps ?? 28,
            guidance: request.guidance ?? 2.5,
            goFast: request.promptEnhance ?? true,
            seed: request.seed
        )
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, sourceImageUrl: "")
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try kontextTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            costEstimate: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        // This model REQUIRES a source image
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "FLUX Kontext Dev requires an input image"
            )
        }

        let sourceImageUrl: String
        do {
            sourceImageUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed to upload source image: \(error.localizedDescription)"
            )
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let transformedRequest = transformRequest(request: request, sourceImageUrl: sourceImageUrl)

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": transformedRequest],
                headers: headers,
                attachments: nil
            )

            guard case let .dictionary(_, data) = initialResponse, let requestId = data["id"] as? String else {
                return createInvalidResponseError(response: initialResponse, modelCode: model.modelCode)
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await kontextPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "FLUX Kontext Dev"
            )
            return try transformResponse(request: request, response: finalResponse)
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }
}
