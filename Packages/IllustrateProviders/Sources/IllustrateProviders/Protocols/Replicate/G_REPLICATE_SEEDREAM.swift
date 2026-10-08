// MARK: - G_REPLICATE_SEEDREAM.swift

// Consolidated implementation for ByteDance Seedream models via Replicate.
// Supports Seedream 3, 4, 4.5, and 5 variants.

import Foundation

// MARK: - Shared Helpers

private func seedreamTransformResponse(
    request: ImageGenerationRequest,
    response: NetworkResponseData,
    modelCode: EnumProviderModelCode,
    costEstimate: Double
) throws -> ImageGenerationResponse {
    switch response {
    case let .dictionary(_, data):
        if let output = data["output"] as? [String], let pngUrl = output.first {
            return try seedreamImageResponse(from: pngUrl, costEstimate: costEstimate)
        }
        if let pngUrl = data["output"] as? String {
            return try seedreamImageResponse(from: pngUrl, costEstimate: costEstimate)
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

private func seedreamImageResponse(from output: String, costEstimate: Double) throws -> ImageGenerationResponse {
    if output.hasPrefix("data:") {
        let base64 = output.replacingOccurrences(
            of: "^data:.*;base64,",
            with: "",
            options: .regularExpression
        )
        return ImageGenerationResponse(status: .GENERATED, base64: base64, cost: costEstimate)
    }

    let url = URL(string: output)!
    let pngData = try Data(contentsOf: url)
    return ImageGenerationResponse(status: .GENERATED, base64: pngData.base64EncodedString(), cost: costEstimate)
}

private func seedreamPollForResult(
    requestId: String,
    url: URL,
    headers: [String: String],
    modelName: String,
    maxAttempts: Int = 20
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

private func mapToSeedreamAspectRatio(dimension: String) -> String {
    if dimension == "match_input_image" {
        return dimension
    }

    let aspectRatio = getAspectRatio(dimension: dimension)
    let ratio = aspectRatio.ratio

    let supportedRatios = ["1:1", "3:4", "4:3", "16:9", "9:16", "2:3", "3:2", "21:9"]

    if supportedRatios.contains(ratio) {
        return ratio
    }

    let width = aspectRatio.width
    let height = aspectRatio.height
    let aspectValue = Double(width) / Double(height)

    let ratioValues: [(String, Double)] = [
        ("1:1", 1.0),
        ("3:4", 0.75),
        ("4:3", 1.333),
        ("16:9", 1.778),
        ("9:16", 0.5625),
        ("2:3", 0.667),
        ("3:2", 1.5),
        ("21:9", 2.333),
    ]

    var closestRatio = "16:9"
    var minDiff = Double.greatestFiniteMagnitude

    for (ratioStr, ratioVal) in ratioValues {
        let diff = abs(aspectValue - ratioVal)
        if diff < minDiff {
            minDiff = diff
            closestRatio = ratioStr
        }
    }

    return closestRatio
}

private func seedreamPrompt(from request: ImageGenerationRequest) -> String {
    request.variant.isEmpty || request.variant == "Normal" ? request.prompt : "\(request.variant) - \(request.prompt)"
}

private func seedream5Size(from resolution: String?) -> String {
    resolution?.uppercased() == "1K" ? "1K" : "2K"
}

// MARK: - Seedream 3

public class G_REPLICATE_SEEDREAM_3: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.03

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_SEEDREAM_3)!

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String
        public let aspect_ratio: String
        public let size: String
        public let guidance_scale: Double
        public let seed: Int?

        public init(
            prompt: String,
            aspectRatio: String,
            size: String = "regular",
            guidanceScale: Double = 2.5,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.size = size
            guidance_scale = guidanceScale
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = mapToSeedreamAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt

        return ServiceRequest(
            prompt: prompt,
            aspectRatio: aspectRatio,
            size: request.resolution ?? "regular",
            guidanceScale: request.guidance ?? 2.5,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try seedreamTransformResponse(
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

            let finalResponse = try await seedreamPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "Seedream 3",
                maxAttempts: 15
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

// MARK: - Seedream 4

public class G_REPLICATE_SEEDREAM_4: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.03

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_SEEDREAM_4)!

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String
        public let image_input: [String]?
        public let aspect_ratio: String
        public let size: String
        public let enhance_prompt: Bool
        public let sequential_image_generation: String
        public let seed: Int?

        public init(
            prompt: String,
            imageInput: [String]? = nil,
            aspectRatio: String,
            size: String = "2K",
            enhancePrompt: Bool = true,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            image_input = imageInput
            aspect_ratio = aspectRatio
            self.size = size
            enhance_prompt = enhancePrompt
            sequential_image_generation = "disabled"
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = mapToSeedreamAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt

        return ServiceRequest(
            prompt: prompt,
            imageInput: nil,
            aspectRatio: aspectRatio,
            size: request.resolution ?? "2K",
            enhancePrompt: request.promptEnhance ?? true,
            seed: request.seed
        )
    }

    private func createEditServiceRequest(request: ImageGenerationRequest, imageUrl: String) -> ServiceRequest {
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt
        return ServiceRequest(
            prompt: prompt,
            imageInput: [imageUrl],
            aspectRatio: "1:1",
            size: request.resolution ?? "2K",
            enhancePrompt: request.promptEnhance ?? true,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try seedreamTransformResponse(
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

        let transformedRequest: ServiceRequest
        if let clientImage = request.clientImage, model.modelParams.supportsSourceImage {
            let imageUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
            transformedRequest = createEditServiceRequest(request: request, imageUrl: imageUrl)
        } else {
            transformedRequest = transformRequest(request: request)
        }

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

            let finalResponse = try await seedreamPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "Seedream 4"
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

// MARK: - Seedream 4.5

public class G_REPLICATE_SEEDREAM_4_5: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.03

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_SEEDREAM_4_5)!

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String
        public let image_input: [String]?
        public let aspect_ratio: String
        public let size: String
        public let sequential_image_generation: String
        public let seed: Int?

        public init(
            prompt: String,
            imageInput: [String]? = nil,
            aspectRatio: String = "1:1",
            size: String = "2K",
            seed: Int? = nil
        ) {
            self.prompt = prompt
            image_input = imageInput
            aspect_ratio = aspectRatio
            self.size = size
            sequential_image_generation = "disabled"
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = mapToSeedreamAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt

        return ServiceRequest(
            prompt: prompt,
            imageInput: nil,
            aspectRatio: aspectRatio,
            size: request.resolution ?? "2K",
            seed: request.seed
        )
    }

    private func createEditServiceRequest(request: ImageGenerationRequest, imageUrl: String) -> ServiceRequest {
        let aspectRatio = mapToSeedreamAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt
        return ServiceRequest(
            prompt: prompt,
            imageInput: [imageUrl],
            aspectRatio: aspectRatio,
            size: request.resolution ?? "2K",
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try seedreamTransformResponse(
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

        let transformedRequest: ServiceRequest
        if let clientImage = request.clientImage, model.modelParams.supportsSourceImage {
            let imageUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
            transformedRequest = createEditServiceRequest(request: request, imageUrl: imageUrl)
        } else {
            transformedRequest = transformRequest(request: request)
        }

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

            let finalResponse = try await seedreamPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "Seedream 4.5"
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

// MARK: - Seedream 5 Pro

public class G_REPLICATE_SEEDREAM_5_PRO: ImageGenerationProtocol {
    public init() {}
    static let oneKCost = 0.045
    static let twoKCost = 0.09

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let costPerImage = request.quality?.uppercased() == "1K" ? Self.oneKCost : Self.twoKCost
        return costPerImage * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_SEEDREAM_5_PRO)!

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String
        public let image_input: [String]?
        public let size: String
        public let aspect_ratio: String
        public let output_format: String

        public init(
            prompt: String,
            imageInput: [String]? = nil,
            size: String = "2K",
            aspectRatio: String = "1:1",
            outputFormat: String = "png"
        ) {
            self.prompt = prompt
            image_input = imageInput
            self.size = size
            aspect_ratio = aspectRatio
            output_format = outputFormat
        }
    }

    public func transformRequest(request: ImageGenerationRequest, imageURLs: [String]? = nil) -> ServiceRequest {
        ServiceRequest(
            prompt: seedreamPrompt(from: request),
            imageInput: imageURLs?.isEmpty == false ? imageURLs : nil,
            size: seedream5Size(from: request.resolution),
            aspectRatio: mapToSeedreamAspectRatio(dimension: request.dimensions),
            outputFormat: "png"
        )
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, imageURLs: nil)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        var costRequest = ImageGenerationCostRequest(from: request)
        if costRequest.quality?.isEmpty != false {
            costRequest.quality = request.resolution
        }

        return try seedreamTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            costEstimate: getCostEstimate(request: costRequest)
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        var imageURLs: [String] = []

        if let clientImage = request.clientImage, model.modelParams.supportsSourceImage {
            let imageURL = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
            imageURLs.append(imageURL)
        }

        if let references = request.clientReferenceImages {
            for reference in references where imageURLs.count < 10 {
                let imageURL = try await ReplicateFileUploader.uploadImage(
                    base64Image: reference.base64Image,
                    apiToken: request.providerSecret
                )
                imageURLs.append(imageURL)
            }
        }

        let transformedRequest = transformRequest(
            request: request,
            imageURLs: imageURLs.isEmpty ? nil : imageURLs
        )

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

            let finalResponse = try await seedreamPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "Seedream 5 Pro"
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

// MARK: - Seedream 5 Lite

private final class G_REPLICATE_SEEDREAM_5_LITE_LEGACY: ImageGenerationProtocol {
    init() {}
    static let baseCost = 0.02

    func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_SEEDREAM_5_LITE)!

    struct ServiceRequest: Codable {
        let prompt: String
        let image_input: [String]?
        let aspect_ratio: String
        let size: String
        let sequential_image_generation: String
        let seed: Int?

        init(
            prompt: String,
            imageInput: [String]? = nil,
            aspectRatio: String = "1:1",
            size: String = "1K",
            seed: Int? = nil
        ) {
            self.prompt = prompt
            image_input = imageInput
            aspect_ratio = aspectRatio
            self.size = size
            sequential_image_generation = "disabled"
            self.seed = seed
        }
    }

    func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = mapToSeedreamAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt

        return ServiceRequest(
            prompt: prompt,
            imageInput: nil,
            aspectRatio: aspectRatio,
            size: request.resolution ?? "1K",
            seed: request.seed
        )
    }

    private func createEditServiceRequest(request: ImageGenerationRequest, imageUrl: String) -> ServiceRequest {
        let aspectRatio = mapToSeedreamAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt
        return ServiceRequest(
            prompt: prompt,
            imageInput: [imageUrl],
            aspectRatio: aspectRatio,
            size: request.resolution ?? "1K",
            seed: request.seed
        )
    }

    func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try seedreamTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            costEstimate: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }

    func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]

        let transformedRequest: ServiceRequest
        if let clientImage = request.clientImage, model.modelParams.supportsSourceImage {
            let imageUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
            transformedRequest = createEditServiceRequest(request: request, imageUrl: imageUrl)
        } else {
            transformedRequest = transformRequest(request: request)
        }

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

            let finalResponse = try await seedreamPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "Seedream 5 Lite"
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
