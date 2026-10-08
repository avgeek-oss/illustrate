// MARK: - G_REPLICATE_FLUX_2.swift

// Consolidated implementation for FLUX.2 models via Replicate.
// Includes: Pro, Dev, Max, Klein, and Flex variants.

import Foundation

// MARK: - Shared Helpers

private func parseMegapixels(from input: String?) -> Double {
    guard let input else { return 1.0 }

    // Simple numeric like "1" or "0.5"
    if let mp = Double(input.trimmingCharacters(in: .whitespaces)) {
        return mp
    }

    // Resolution string like "1 MP"
    if input.contains("MP") {
        let cleaned = input
            .replacingOccurrences(of: " MP", with: "")
            .replacingOccurrences(of: "MP", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 1.0
    }

    // Pixel dimensions like "1024x1024"
    let parts = input.lowercased().split(separator: "x")
    if parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]) {
        return (width * height) / 1_000_000.0
    }

    return 1.0
}

private func flux2TransformResponse(
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

private func flux2PollForResult(
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
    _ referenceImages: [ReferenceImageData],
    apiToken: String,
    modelName: String
) async throws -> [String] {
    var uploadedUrls: [String] = []
    for (index, refImage) in referenceImages.enumerated() {
        let uploadedUrl = try await ReplicateFileUploader.uploadImage(
            base64Image: refImage.base64Image,
            apiToken: apiToken
        )
        uploadedUrls.append(uploadedUrl)
    }
    return uploadedUrls
}

// MARK: - FLUX.2 [pro]

/// FLUX.2 [pro] via Replicate - $0.015 per megapixel.
public class G_REPLICATE_FLUX_2_PRO: ImageGenerationProtocol {
    public init() {}
    static let costPerMegapixel = 0.015

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let megapixels = parseMegapixels(from: request.dimensions)
        return Self.costPerMegapixel * megapixels * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_FLUX_2_PRO)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let resolution: String
        let safety_tolerance: Int
        let output_format: String
        let output_quality: Int
        let seed: Int?
        let input_images: [String]?

        init(
            prompt: String,
            aspectRatio: String,
            resolution: String = "1 MP",
            safetyTolerance: Int = 2,
            seed: Int? = nil,
            inputImages: [String]? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.resolution = resolution
            safety_tolerance = safetyTolerance
            output_format = "png"
            output_quality = 100
            self.seed = seed
            input_images = inputImages
        }
    }

    public func transformRequest(request: ImageGenerationRequest, inputImageUrls: [String]? = nil) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            aspectRatio: aspectRatio.ratio,
            resolution: request.resolution ?? "1 MP",
            safetyTolerance: request.safetyTolerance ?? 2,
            seed: request.seed,
            inputImages: inputImageUrls
        )
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, inputImageUrls: nil)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try flux2TransformResponse(
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

        var uploadedImageUrls: [String]? = nil
        if let referenceImages = request.clientReferenceImages, !referenceImages.isEmpty {
            do {
                uploadedImageUrls = try await uploadReferenceImages(
                    referenceImages,
                    apiToken: request.providerSecret,
                    modelName: "FLUX 2 Pro"
                )
            } catch {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to upload reference images: \(error.localizedDescription)"
                )
            }
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let transformedRequest = transformRequest(request: request, inputImageUrls: uploadedImageUrls)

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

            let finalResponse = try await flux2PollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "FLUX 2 Pro"
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

// MARK: - FLUX.2 [dev]

/// FLUX.2 [dev] via Replicate - $0.014 per megapixel.
public class G_REPLICATE_FLUX_2_DEV: ImageGenerationProtocol {
    public init() {}
    static let costPerMegapixel = 0.014

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let megapixels = parseMegapixels(from: request.dimensions)
        return Self.costPerMegapixel * megapixels * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost) + "+"
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_FLUX_2_DEV)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let go_fast: Bool
        let output_format: String
        let output_quality: Int
        let seed: Int?
        let input_images: [String]?

        public init(
            prompt: String,
            aspectRatio: String,
            goFast: Bool = true,
            seed: Int? = nil,
            inputImages: [String]? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            go_fast = goFast
            output_format = "png"
            output_quality = 100
            self.seed = seed
            input_images = inputImages
        }
    }

    public func transformRequest(request: ImageGenerationRequest, inputImageUrls: [String]? = nil) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            aspectRatio: aspectRatio.ratio,
            goFast: request.promptEnhance ?? true,
            seed: request.seed,
            inputImages: inputImageUrls
        )
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, inputImageUrls: nil)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        var cost = Self.costPerMegapixel * 1.0
        if let refs = request.clientReferenceImages {
            cost += Double(refs.count) * Self.costPerMegapixel
        }
        return try flux2TransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            costEstimate: cost
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        var uploadedImageUrls: [String]? = nil
        if let referenceImages = request.clientReferenceImages, !referenceImages.isEmpty {
            do {
                uploadedImageUrls = try await uploadReferenceImages(
                    referenceImages,
                    apiToken: request.providerSecret,
                    modelName: "FLUX 2 Dev"
                )
            } catch {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to upload reference images: \(error.localizedDescription)"
                )
            }
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let transformedRequest = transformRequest(request: request, inputImageUrls: uploadedImageUrls)

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

            let finalResponse = try await flux2PollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "FLUX 2 Dev"
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

// MARK: - FLUX.2 [max]

/// FLUX.2 [max] via Replicate - $0.04/image + $0.03 per input megapixel.
public class G_REPLICATE_FLUX_2_MAX: ImageGenerationProtocol {
    public init() {}
    static let baseCostPerImage = 0.04
    static let costPerInputMegapixel = 0.03

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCostPerImage * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost) + "+"
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_FLUX_2_MAX)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let resolution: String
        let safety_tolerance: Int
        let output_format: String
        let output_quality: Int
        let seed: Int?
        let input_images: [String]?

        init(
            prompt: String,
            aspectRatio: String,
            resolution: String = "1 MP",
            safetyTolerance: Int = 2,
            seed: Int? = nil,
            inputImages: [String]? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.resolution = resolution
            safety_tolerance = safetyTolerance
            output_format = "png"
            output_quality = 100
            self.seed = seed
            input_images = inputImages
        }
    }

    public func transformRequest(request: ImageGenerationRequest, inputImageUrls: [String]? = nil) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            aspectRatio: aspectRatio.ratio,
            resolution: request.resolution ?? "1 MP",
            safetyTolerance: request.safetyTolerance ?? 2,
            seed: request.seed,
            inputImages: inputImageUrls
        )
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, inputImageUrls: nil)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        var cost = Self.baseCostPerImage
        if let refs = request.clientReferenceImages {
            cost += Double(refs.count) * Self.costPerInputMegapixel
        }
        return try flux2TransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            costEstimate: cost
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        var uploadedImageUrls: [String]? = nil
        if let referenceImages = request.clientReferenceImages, !referenceImages.isEmpty {
            do {
                uploadedImageUrls = try await uploadReferenceImages(
                    referenceImages,
                    apiToken: request.providerSecret,
                    modelName: "FLUX 2 Max"
                )
            } catch {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to upload reference images: \(error.localizedDescription)"
                )
            }
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let transformedRequest = transformRequest(request: request, inputImageUrls: uploadedImageUrls)

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

            let finalResponse = try await flux2PollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "FLUX 2 Max"
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

// MARK: - FLUX.2 [klein]

/// FLUX.2 Klein 4B via Replicate - $0.001 per megapixel.
public class G_REPLICATE_FLUX_2_KLEIN: ImageGenerationProtocol {
    public init() {}
    static let costPerMegapixel = 0.001

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let megapixels = parseMegapixels(from: request.dimensions)
        return Self.costPerMegapixel * megapixels * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_FLUX_2_KLEIN)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let output_megapixels: String
        let go_fast: Bool
        let output_format: String
        let output_quality: Int
        let seed: Int?
        let images: [String]?

        init(
            prompt: String,
            aspectRatio: String,
            outputMegapixels: String = "1",
            goFast: Bool = true,
            seed: Int? = nil,
            images: [String]? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            output_megapixels = outputMegapixels
            go_fast = goFast
            output_format = "png"
            output_quality = 100
            self.seed = seed
            self.images = images
        }
    }

    public func transformRequest(request: ImageGenerationRequest, inputImageUrls: [String]? = nil) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        let megapixels: String = if let resolution = request.resolution {
            resolution.replacingOccurrences(of: " MP", with: "").replacingOccurrences(of: "MP", with: "")
                .trimmingCharacters(in: .whitespaces)
        } else {
            "1"
        }

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            aspectRatio: aspectRatio.ratio,
            outputMegapixels: megapixels,
            goFast: request.promptEnhance ?? false,
            seed: request.seed,
            images: inputImageUrls
        )
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, inputImageUrls: nil)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try flux2TransformResponse(
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

        var uploadedImageUrls: [String]? = nil
        if let referenceImages = request.clientReferenceImages, !referenceImages.isEmpty {
            do {
                uploadedImageUrls = try await uploadReferenceImages(
                    referenceImages,
                    apiToken: request.providerSecret,
                    modelName: "FLUX 2 Klein"
                )
            } catch {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to upload reference images: \(error.localizedDescription)"
                )
            }
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let transformedRequest = transformRequest(request: request, inputImageUrls: uploadedImageUrls)

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

            let finalResponse = try await flux2PollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "FLUX 2 Klein"
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

// MARK: - FLUX.2 [flex]

/// FLUX.2 Flex via Replicate - $0.06 flat rate.
public class G_REPLICATE_FLUX_2_FLEX: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.06

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_FLUX_2_FLEX)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let resolution: String
        let steps: Int
        let guidance: Double
        let output_format: String
        let output_quality: Int
        let safety_tolerance: Int
        let prompt_upsampling: Bool
        let seed: Int?

        init(
            prompt: String,
            aspectRatio: String,
            resolution: String = "1 MP",
            steps: Int = 30,
            guidance: Double = 4.5,
            safetyTolerance: Int = 5,
            promptUpsampling: Bool = true,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.resolution = resolution
            self.steps = steps
            self.guidance = guidance
            output_format = "png"
            output_quality = 100
            safety_tolerance = safetyTolerance
            prompt_upsampling = promptUpsampling
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let promptPrefix = request.variant != "Normal" ? "\(request.variant) - " : ""

        return ServiceRequest(
            prompt: promptPrefix + request.prompt,
            aspectRatio: aspectRatio.ratio,
            resolution: request.resolution ?? "1 MP",
            steps: request.steps ?? 30,
            guidance: request.guidance ?? 4.5,
            safetyTolerance: request.safetyTolerance ?? 5,
            promptUpsampling: request.promptEnhance ?? true,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try flux2TransformResponse(
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

            let finalResponse = try await flux2PollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "FLUX 2 Flex"
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
