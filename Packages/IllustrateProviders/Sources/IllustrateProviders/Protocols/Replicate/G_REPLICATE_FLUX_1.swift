// MARK: - G_REPLICATE_FLUX_1.swift

// Consolidated implementation for FLUX.1 models via Replicate.
// Includes: Pro, Dev, and Schnell variants.

import Foundation

// MARK: - Shared Helpers

private func fluxTransformResponse(
    request: ImageGenerationRequest,
    response: NetworkResponseData,
    modelCode: EnumProviderModelCode,
    costEstimate: Double
) throws -> ImageGenerationResponse {
    switch response {
    case let .dictionary(_, data):
        if let output = data["output"] as? [String], let imageUrl = output.first {
            let url = URL(string: imageUrl)!
            let imageData = try Data(contentsOf: url)
            let base64 = imageData.base64EncodedString()
            return ImageGenerationResponse(status: .GENERATED, base64: base64, cost: costEstimate)
        }
        if let imageUrl = data["output"] as? String {
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

private func fluxPollForResult(
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

// MARK: - FLUX.1 [pro]

/// FLUX.1 [pro] via Replicate - Professional quality model.
public class G_REPLICATE_FLUX_PRO: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.055

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_FLUX_PRO)!

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String
        public let aspect_ratio: String
        public let safety_tolerance: Int
        public let steps: Int?
        public let guidance: Double?
        public let seed: Int?

        public init(
            prompt: String,
            aspectRatio: String,
            safetyTolerance: Int = 5,
            steps: Int? = nil,
            guidance: Double? = nil,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            safety_tolerance = safetyTolerance
            self.steps = steps
            self.guidance = guidance
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt

        return ServiceRequest(
            prompt: prompt,
            aspectRatio: aspectRatio.ratio,
            safetyTolerance: request.safetyTolerance ?? 5,
            steps: request.steps,
            guidance: request.guidance,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try fluxTransformResponse(
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

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let transformedRequest = transformRequest(request: request)

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

            let finalResponse = try await fluxPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "FLUX Pro"
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

// MARK: - FLUX.1 [dev]

/// FLUX.1 [dev] via Replicate - Development model with configurable inference.
public class G_REPLICATE_FLUX_DEV: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.03

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_FLUX_DEV)!

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String
        public let num_outputs: Int
        public let aspect_ratio: String
        public let output_quality: Int
        public let output_format: String?
        public let num_inference_steps: Int?
        public let guidance: Double?
        public let seed: Int?

        public init(prompt: String, aspectRatio: String, steps: Int? = nil, guidance: Double? = nil, seed: Int? = nil) {
            self.prompt = prompt
            num_outputs = 1
            aspect_ratio = aspectRatio
            output_quality = 100
            output_format = "png"
            num_inference_steps = steps
            self.guidance = guidance
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt

        return ServiceRequest(
            prompt: prompt,
            aspectRatio: aspectRatio.ratio,
            steps: request.steps,
            guidance: request.guidance,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try fluxTransformResponse(
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

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let transformedRequest = transformRequest(request: request)

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

            let finalResponse = try await fluxPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "FLUX Dev"
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

// MARK: - FLUX.1 [schnell]

/// FLUX.1 [schnell] via Replicate - Fastest FLUX variant (1-4 inference steps).
public class G_REPLICATE_FLUX_SCHNELL: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.003

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_FLUX_SCHNELL)!

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String
        public let num_outputs: Int
        public let aspect_ratio: String
        public let output_quality: Int
        public let output_format: String?
        public let num_inference_steps: Int?
        public let guidance: Double?
        public let seed: Int?

        public init(prompt: String, aspectRatio: String, steps: Int? = nil, guidance: Double? = nil, seed: Int? = nil) {
            self.prompt = prompt
            num_outputs = 1
            aspect_ratio = aspectRatio
            output_quality = 100
            output_format = "png"
            num_inference_steps = steps
            self.guidance = guidance
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt

        return ServiceRequest(
            prompt: prompt,
            aspectRatio: aspectRatio.ratio,
            steps: request.steps,
            guidance: request.guidance,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try fluxTransformResponse(
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

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let transformedRequest = transformRequest(request: request)

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

            let finalResponse = try await fluxPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "FLUX Schnell"
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
