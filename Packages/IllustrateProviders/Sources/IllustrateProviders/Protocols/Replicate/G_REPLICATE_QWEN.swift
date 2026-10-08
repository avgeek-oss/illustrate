// MARK: - G_REPLICATE_QWEN.swift

// Consolidated implementation for Qwen Image models via Replicate.
// Includes: Image, Image Edit, Image Edit Plus, Image Edit 2511, and Image Edit 2512.

import Foundation

// MARK: - Shared Helpers

private func qwenTransformResponse(
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

private func qwenPollForResult(
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

private func uploadReferenceImages(
    _ images: [ReferenceImageData],
    apiToken: String,
    modelName: String
) async throws -> [String] {
    var urls: [String] = []
    for (index, img) in images.enumerated() {
        let url = try await ReplicateFileUploader.uploadImage(base64Image: img.base64Image, apiToken: apiToken)
        urls.append(url)
    }
    return urls
}

// MARK: - Qwen Image

/// Qwen Image via Replicate - $0.025 flat rate. Supports img2img.
public class G_REPLICATE_QWEN_IMAGE: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.025

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_QWEN_IMAGE)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let negative_prompt: String?
        let aspect_ratio: String
        let num_inference_steps: Int
        let guidance: Double
        let go_fast: Bool
        let enhance_prompt: Bool
        let image_size: String
        let output_format: String
        let output_quality: Int
        let seed: Int?
        let image: String?
        let strength: Double?

        init(
            prompt: String,
            negativePrompt: String? = nil,
            aspectRatio: String,
            steps: Int = 30,
            guidance: Double = 3.0,
            goFast: Bool = true,
            enhancePrompt: Bool = false,
            seed: Int? = nil,
            image: String? = nil,
            strength: Double? = nil
        ) {
            self.prompt = prompt
            negative_prompt = negativePrompt
            aspect_ratio = aspectRatio
            num_inference_steps = steps
            self.guidance = guidance
            go_fast = goFast
            enhance_prompt = enhancePrompt
            image_size = "optimize_for_quality"
            output_format = "png"
            output_quality = 100
            self.seed = seed
            self.image = image
            self.strength = strength
        }
    }

    public func transformRequest(request: ImageGenerationRequest, sourceImageUrl: String? = nil) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            negativePrompt: request.negativePrompt,
            aspectRatio: aspectRatio.ratio,
            steps: request.steps ?? 30,
            guidance: request.guidance ?? 3.0,
            goFast: true,
            enhancePrompt: request.promptEnhance ?? false,
            seed: request.seed,
            image: sourceImageUrl,
            strength: sourceImageUrl != nil ? 0.9 : nil
        )
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, sourceImageUrl: nil)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try qwenTransformResponse(
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
                    errorMessage: "Failed to upload image: \(error.localizedDescription)"
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

            let finalResponse = try await qwenPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "Qwen Image"
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

// MARK: - Qwen Image Edit (Base)

/// Base class for Qwen Image Edit and Plus - $0.03 flat rate. Requires reference images array.
public class G_REPLICATE_QWEN_IMAGE_EDIT: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.03

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_QWEN_IMAGE_EDIT)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let image: [String]
        let aspect_ratio: String
        let go_fast: Bool
        let output_format: String
        let output_quality: Int
        let seed: Int?
        let disable_safety_checker: Bool

        public init(prompt: String, images: [String], aspectRatio: String, goFast: Bool = true, seed: Int? = nil) {
            self.prompt = prompt
            image = images
            aspect_ratio = aspectRatio
            go_fast = goFast
            output_format = "png"
            output_quality = 100
            self.seed = seed
            disable_safety_checker = false
        }
    }

    public func transformRequest(request: ImageGenerationRequest, inputImageUrls: [String] = []) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            images: inputImageUrls,
            aspectRatio: aspectRatio.ratio,
            goFast: request.promptEnhance ?? true,
            seed: request.seed
        )
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, inputImageUrls: [])
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try qwenTransformResponse(
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

        guard let clientReferenceImages = request.clientReferenceImages, !clientReferenceImages.isEmpty else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "At least one reference image is required"
            )
        }

        var inputImageUrls: [String] = []
        do {
            inputImageUrls = try await uploadReferenceImages(
                clientReferenceImages,
                apiToken: request.providerSecret,
                modelName: "Qwen Image Edit"
            )
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed to upload images: \(error.localizedDescription)"
            )
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let transformedRequest = transformRequest(request: request, inputImageUrls: inputImageUrls)

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

            let finalResponse = try await qwenPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "Qwen Image Edit"
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

// MARK: - Qwen Image Edit Plus

/// Qwen Image Edit Plus via Replicate - $0.03 flat rate. Same as Edit.
public class G_REPLICATE_QWEN_IMAGE_EDIT_PLUS: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.03

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_QWEN_IMAGE_EDIT_PLUS)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let image: [String]
        let aspect_ratio: String
        let go_fast: Bool
        let output_format: String
        let output_quality: Int
        let seed: Int?
        let disable_safety_checker: Bool

        public init(prompt: String, images: [String], aspectRatio: String, goFast: Bool = true, seed: Int? = nil) {
            self.prompt = prompt
            image = images
            aspect_ratio = aspectRatio
            go_fast = goFast
            output_format = "png"
            output_quality = 100
            self.seed = seed
            disable_safety_checker = false
        }
    }

    public func transformRequest(request: ImageGenerationRequest, inputImageUrls: [String] = []) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            images: inputImageUrls,
            aspectRatio: aspectRatio.ratio,
            goFast: request.promptEnhance ?? true,
            seed: request.seed
        )
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, inputImageUrls: [])
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try qwenTransformResponse(
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

        guard let clientReferenceImages = request.clientReferenceImages, !clientReferenceImages.isEmpty else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "At least one reference image is required"
            )
        }

        var inputImageUrls: [String] = []
        do {
            inputImageUrls = try await uploadReferenceImages(
                clientReferenceImages,
                apiToken: request.providerSecret,
                modelName: "Qwen Image Edit Plus"
            )
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed to upload images: \(error.localizedDescription)"
            )
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let transformedRequest = transformRequest(request: request, inputImageUrls: inputImageUrls)

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

            let finalResponse = try await qwenPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "Qwen Image Edit Plus"
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

// MARK: - Qwen Image Edit 2511

/// Qwen Image Edit 2511 via Replicate - $0.02 flat rate. Optional single image with guidance/steps.
public class G_REPLICATE_QWEN_IMAGE_EDIT_2511: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.02

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_QWEN_IMAGE_EDIT_2511)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let negative_prompt: String?
        let aspect_ratio: String
        let width: Int?
        let height: Int?
        let num_inference_steps: Int
        let guidance: Double
        let go_fast: Bool
        let output_format: String
        let output_quality: Int
        let seed: Int?
        let image: String?
        let strength: Double?
        let disable_safety_checker: Bool

        init(
            prompt: String,
            negativePrompt: String? = nil,
            aspectRatio: String,
            width: Int? = nil,
            height: Int? = nil,
            steps: Int = 40,
            guidance: Double = 4.0,
            goFast: Bool = true,
            seed: Int? = nil,
            image: String? = nil,
            strength: Double? = nil
        ) {
            self.prompt = prompt
            negative_prompt = negativePrompt
            aspect_ratio = aspectRatio
            self.width = width
            self.height = height
            num_inference_steps = steps
            self.guidance = guidance
            go_fast = goFast
            output_format = "png"
            output_quality = 100
            self.seed = seed
            self.image = image
            self.strength = strength
            disable_safety_checker = false
        }
    }

    public func transformRequest(request: ImageGenerationRequest, sourceImageUrl: String? = nil) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        var width: Int? = nil
        var height: Int? = nil
        let parts = request.dimensions.split(separator: "x")
        if parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]) {
            width = w
            height = h
        }

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            negativePrompt: request.negativePrompt,
            aspectRatio: aspectRatio.ratio,
            width: width,
            height: height,
            steps: request.steps ?? 40,
            guidance: request.guidance ?? 4.0,
            goFast: true,
            seed: request.seed,
            image: sourceImageUrl,
            strength: sourceImageUrl != nil ? 0.8 : nil
        )
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, sourceImageUrl: nil)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try qwenTransformResponse(
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
                    errorMessage: "Failed to upload image: \(error.localizedDescription)"
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

            let finalResponse = try await qwenPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "Qwen Image Edit 2511"
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

// MARK: - Qwen Image Edit 2512

/// Qwen Image Edit 2512 via Replicate - $0.02 flat rate. Same as 2511.
public class G_REPLICATE_QWEN_IMAGE_EDIT_2512: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.02

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_QWEN_IMAGE_EDIT_2512)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let negative_prompt: String?
        let aspect_ratio: String
        let width: Int?
        let height: Int?
        let num_inference_steps: Int
        let guidance: Double
        let go_fast: Bool
        let output_format: String
        let output_quality: Int
        let seed: Int?
        let image: String?
        let strength: Double?
        let disable_safety_checker: Bool

        init(
            prompt: String,
            negativePrompt: String? = nil,
            aspectRatio: String,
            width: Int? = nil,
            height: Int? = nil,
            steps: Int = 40,
            guidance: Double = 4.0,
            goFast: Bool = true,
            seed: Int? = nil,
            image: String? = nil,
            strength: Double? = nil
        ) {
            self.prompt = prompt
            negative_prompt = negativePrompt
            aspect_ratio = aspectRatio
            self.width = width
            self.height = height
            num_inference_steps = steps
            self.guidance = guidance
            go_fast = goFast
            output_format = "png"
            output_quality = 100
            self.seed = seed
            self.image = image
            self.strength = strength
            disable_safety_checker = false
        }
    }

    public func transformRequest(request: ImageGenerationRequest, sourceImageUrl: String? = nil) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        var width: Int? = nil
        var height: Int? = nil
        let parts = request.dimensions.split(separator: "x")
        if parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]) {
            width = w
            height = h
        }

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            negativePrompt: request.negativePrompt,
            aspectRatio: aspectRatio.ratio,
            width: width,
            height: height,
            steps: request.steps ?? 40,
            guidance: request.guidance ?? 4.0,
            goFast: true,
            seed: request.seed,
            image: sourceImageUrl,
            strength: sourceImageUrl != nil ? 0.8 : nil
        )
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, sourceImageUrl: nil)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try qwenTransformResponse(
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
                    errorMessage: "Failed to upload image: \(error.localizedDescription)"
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

            let finalResponse = try await qwenPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "Qwen Image Edit 2512"
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
