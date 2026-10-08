// MARK: - G_REPLICATE_OPENAI.swift

// Consolidated implementation for OpenAI image models via Replicate.
// Supports GPT-Image-2, GPT-Image-1.5, DALL-E 3, and DALL-E 2.

import Foundation

// MARK: - Shared Helpers

private func openaiTransformResponse(
    request: ImageGenerationRequest,
    response: NetworkResponseData,
    modelCode: EnumProviderModelCode,
    costEstimate: Double
) throws -> ImageGenerationResponse {
    switch response {
    case let .dictionary(_, data):
        // Output can be an array of URLs
        if let output = data["output"] as? [String], let imageUrl = output.first {
            let url = URL(string: imageUrl)!
            let imageData = try Data(contentsOf: url)
            let base64 = imageData.base64EncodedString()
            return ImageGenerationResponse(status: .GENERATED, base64: base64, cost: costEstimate)
        }
        // Or a single URL string
        if let imageUrl = data["output"] as? String {
            let url = URL(string: imageUrl)!
            let imageData = try Data(contentsOf: url)
            let base64 = imageData.base64EncodedString()
            return ImageGenerationResponse(status: .GENERATED, base64: base64, cost: costEstimate)
        }
        // Handle errors
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

private func openaiPollForResult(
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

// MARK: - GPT-Image-1.5

public class G_REPLICATE_OPENAI_GPT_IMAGE_1_5: ImageGenerationProtocol {
    public init() {}
    /// Cost varies by quality: auto=$0.136, low=$0.013, medium=$0.05, high=$0.136
    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let quality = request.quality ?? "auto"
        let baseCost = switch quality {
        case "low": 0.013
        case "medium": 0.05
        case "high": 0.136
        default: 0.136 // "auto" defaults to high
        }
        return baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_OPENAI_GPT_IMAGE_1_5)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let quality: String
        let background: String
        let moderation: String
        let aspect_ratio: String
        let input_images: [String]?
        let output_format: String
        let input_fidelity: String
        let number_of_images: Int

        init(
            prompt: String,
            quality: String = "auto",
            background: String = "auto",
            moderation: String = "auto",
            aspectRatio: String = "1:1",
            inputImages: [String]? = nil,
            inputFidelity: String = "low",
            numberOfImages: Int = 1
        ) {
            self.prompt = prompt
            self.quality = quality
            self.background = background
            self.moderation = moderation
            aspect_ratio = aspectRatio
            input_images = inputImages
            output_format = "png"
            input_fidelity = inputFidelity
            number_of_images = numberOfImages
        }
    }

    private func mapToAspectRatio(dimension: String) -> String {
        let aspectRatio = getAspectRatio(dimension: dimension)
        let ratio = aspectRatio.ratio

        // Supported: 1:1, 3:2, 2:3
        let supportedRatios = ["1:1", "3:2", "2:3"]
        if supportedRatios.contains(ratio) {
            return ratio
        }

        // Map to closest supported ratio
        let width = aspectRatio.width
        let height = aspectRatio.height
        let aspectValue = Double(width) / Double(height)

        if aspectValue > 1.2 {
            return "3:2" // Landscape
        } else if aspectValue < 0.85 {
            return "2:3" // Portrait
        }
        return "1:1" // Square
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = mapToAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt

        return ServiceRequest(
            prompt: prompt,
            quality: request.quality.isEmpty ? "auto" : request.quality,
            background: request.background ?? "auto",
            moderation: request.moderation ?? "auto",
            aspectRatio: aspectRatio,
            inputImages: nil,
            inputFidelity: request.inputFidelity ?? "low",
            numberOfImages: 1
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try openaiTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            costEstimate: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        // Upload reference images if provided
        var inputImageUrls: [String]? = nil
        if let clientReferenceImages = request.clientReferenceImages, !clientReferenceImages.isEmpty {
            var urls: [String] = []
            for refImage in clientReferenceImages {
                let imageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: refImage.base64Image,
                    apiToken: request.providerSecret
                )
                urls.append(imageUrl)
            }
            inputImageUrls = urls
        } else if let clientImage = request.clientImage {
            let imageUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
            inputImageUrls = [imageUrl]
        }

        let aspectRatio = mapToAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt

        let serviceRequest = ServiceRequest(
            prompt: prompt,
            quality: request.quality.isEmpty ? "auto" : request.quality,
            background: request.background ?? "auto",
            moderation: request.moderation ?? "auto",
            aspectRatio: aspectRatio,
            inputImages: inputImageUrls,
            inputFidelity: request.inputFidelity ?? "low",
            numberOfImages: 1
        )

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": serviceRequest],
                headers: headers,
                attachments: nil
            )

            guard case let .dictionary(_, data) = initialResponse,
                  let requestId = data["id"] as? String
            else {
                return createInvalidResponseError(
                    response: initialResponse,
                    modelCode: model.modelCode
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await openaiPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "GPT-Image-1.5"
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

// MARK: - GPT-Image-2

public class G_REPLICATE_OPENAI_GPT_IMAGE_2: ImageGenerationProtocol {
    public init() {}
    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let quality = request.quality ?? "auto"
        let baseCost = switch quality {
        case "low": 0.015
        case "medium": 0.06
        case "high": 0.16
        default: 0.16
        }
        return baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_OPENAI_GPT_IMAGE_2)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let quality: String
        let background: String
        let moderation: String
        let aspect_ratio: String
        let input_images: [String]?
        let output_format: String
        let number_of_images: Int

        init(
            prompt: String,
            quality: String = "auto",
            background: String = "auto",
            moderation: String = "auto",
            aspectRatio: String = "1:1",
            inputImages: [String]? = nil,
            numberOfImages: Int = 1
        ) {
            self.prompt = prompt
            self.quality = quality
            self.background = background
            self.moderation = moderation
            aspect_ratio = aspectRatio
            input_images = inputImages
            output_format = "png"
            number_of_images = numberOfImages
        }
    }

    private func mapToAspectRatio(dimension: String) -> String {
        let aspectRatio = getAspectRatio(dimension: dimension)
        let ratio = aspectRatio.ratio

        let supportedRatios = ["1:1", "3:2", "2:3"]
        if supportedRatios.contains(ratio) {
            return ratio
        }

        let width = aspectRatio.width
        let height = aspectRatio.height
        let aspectValue = Double(width) / Double(height)

        if aspectValue > 1.2 {
            return "3:2"
        } else if aspectValue < 0.85 {
            return "2:3"
        }
        return "1:1"
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = mapToAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt

        return ServiceRequest(
            prompt: prompt,
            quality: request.quality.isEmpty ? "auto" : request.quality,
            background: request.background ?? "auto",
            moderation: request.moderation ?? "auto",
            aspectRatio: aspectRatio,
            inputImages: nil,
            numberOfImages: 1
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try openaiTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            costEstimate: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        var inputImageUrls: [String]? = nil
        if let clientReferenceImages = request.clientReferenceImages, !clientReferenceImages.isEmpty {
            var urls: [String] = []
            for refImage in clientReferenceImages {
                let imageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: refImage.base64Image,
                    apiToken: request.providerSecret
                )
                urls.append(imageUrl)
            }
            inputImageUrls = urls
        } else if let clientImage = request.clientImage {
            let imageUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
            inputImageUrls = [imageUrl]
        }

        let aspectRatio = mapToAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt

        let serviceRequest = ServiceRequest(
            prompt: prompt,
            quality: request.quality.isEmpty ? "auto" : request.quality,
            background: request.background ?? "auto",
            moderation: request.moderation ?? "auto",
            aspectRatio: aspectRatio,
            inputImages: inputImageUrls,
            numberOfImages: 1
        )

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": serviceRequest],
                headers: headers,
                attachments: nil
            )

            guard case let .dictionary(_, data) = initialResponse,
                  let requestId = data["id"] as? String
            else {
                return createInvalidResponseError(
                    response: initialResponse,
                    modelCode: model.modelCode
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await openaiPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "GPT-Image-2"
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

// MARK: - DALL-E 3

public class G_REPLICATE_OPENAI_DALL_E_3: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.12

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_OPENAI_DALL_E_3)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let style: String
        let aspect_ratio: String

        init(
            prompt: String,
            style: String = "vivid",
            aspectRatio: String = "1:1"
        ) {
            self.prompt = prompt
            self.style = style
            aspect_ratio = aspectRatio
        }
    }

    private func mapToAspectRatio(dimension: String) -> String {
        let aspectRatio = getAspectRatio(dimension: dimension)
        let ratio = aspectRatio.ratio

        let supportedRatios = ["1:1", "3:2", "2:3"]
        if supportedRatios.contains(ratio) {
            return ratio
        }

        let width = aspectRatio.width
        let height = aspectRatio.height
        let aspectValue = Double(width) / Double(height)

        if aspectValue > 1.2 {
            return "3:2"
        } else if aspectValue < 0.85 {
            return "2:3"
        }
        return "1:1"
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = mapToAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt

        return ServiceRequest(
            prompt: prompt,
            style: request.style.isEmpty ? "vivid" : request.style,
            aspectRatio: aspectRatio
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try openaiTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            costEstimate: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        let transformedRequest = transformRequest(request: request)

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": transformedRequest],
                headers: headers,
                attachments: nil
            )

            guard case let .dictionary(_, data) = initialResponse,
                  let requestId = data["id"] as? String
            else {
                return createInvalidResponseError(
                    response: initialResponse,
                    modelCode: model.modelCode
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await openaiPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "DALL-E 3"
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

// MARK: - DALL-E 2

public class G_REPLICATE_OPENAI_DALL_E_2: ImageGenerationProtocol {
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
        .model(by: .REPLICATE_OPENAI_DALL_E_2)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let number_of_images: Int

        init(
            prompt: String,
            numberOfImages: Int = 1
        ) {
            self.prompt = prompt
            number_of_images = numberOfImages
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt

        return ServiceRequest(
            prompt: prompt,
            numberOfImages: 1
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        try openaiTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            costEstimate: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        let transformedRequest = transformRequest(request: request)

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": transformedRequest],
                headers: headers,
                attachments: nil
            )

            guard case let .dictionary(_, data) = initialResponse,
                  let requestId = data["id"] as? String
            else {
                return createInvalidResponseError(
                    response: initialResponse,
                    modelCode: model.modelCode
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await openaiPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "DALL-E 2"
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

// MARK: - Video Models Shared Helpers

private func openaiVideoTransformResponse(
    request: VideoGenerationRequest,
    response: NetworkResponseData,
    modelCode: EnumProviderModelCode,
    costEstimate: Double
) throws -> VideoGenerationResponse {
    let rawResponse = extractRawResponse(from: response)
    switch response {
    case let .dictionary(_, data):
        if let output = data["output"] as? String {
            let url = URL(string: output)!
            let videoData = try Data(contentsOf: url)
            let base64 = videoData.base64EncodedString()
            return VideoGenerationResponse(status: .GENERATED, base64: base64, cost: costEstimate)
        }
        if let errorList = data["error"] as? [String], let error = errorList.first {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: error,
                rawResponse: rawResponse
            )
        }
        if let error = data["error"] as? String {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: error,
                rawResponse: rawResponse
            )
        }
    default:
        break
    }
    return createInvalidVideoResponseError(
        response: response,
        modelCode: modelCode,
        customMessage: "Unexpected response"
    )
}

private func openaiVideoPollForResult(
    requestId: String,
    url: URL,
    headers: [String: String],
    modelName: String,
    maxAttempts: Int = 60
) async throws -> NetworkResponseData {
    var attempts = 0
    while attempts < maxAttempts {
        try await Task.sleep(nanoseconds: 5_000_000_000)

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

// MARK: - Sora 2

public class G_REPLICATE_OPENAI_SORA_2: VideoGenerationProtocol {
    public init() {}
    /// $0.10 per second
    static let costPerSecond = 0.10

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = request.durationSeconds ?? 4
        let numberOfVideos = request.numberOfVideos ?? 1
        return Self.costPerSecond * Double(duration) * Double(numberOfVideos)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_OPENAI_SORA_2)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let seconds: Int
        let aspect_ratio: String
        let input_reference: String?

        init(
            prompt: String,
            seconds: Int = 4,
            aspectRatio: String = "landscape",
            inputReference: String? = nil
        ) {
            self.prompt = prompt
            self.seconds = seconds
            aspect_ratio = aspectRatio
            input_reference = inputReference
        }
    }

    private func mapToAspectRatio(dimension: String) -> String {
        let aspectRatio = getAspectRatio(dimension: dimension)
        let width = aspectRatio.width
        let height = aspectRatio.height

        // Portrait vs landscape
        if width > height {
            return "landscape"
        }
        return "portrait"
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = mapToAspectRatio(dimension: request.dimensions)

        return ServiceRequest(
            prompt: request.prompt ?? "",
            seconds: request.durationSeconds ?? 4,
            aspectRatio: aspectRatio,
            inputReference: nil
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        try openaiVideoTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            costEstimate: getCostEstimate(request: VideoGenerationCostRequest(from: request))
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        // Upload input reference image if provided
        var inputReferenceUrl: String? = nil
        if let clientImage = request.clientImage {
            inputReferenceUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
        }

        let aspectRatio = mapToAspectRatio(dimension: request.dimensions)

        let serviceRequest = ServiceRequest(
            prompt: request.prompt ?? "",
            seconds: request.durationSeconds ?? 4,
            aspectRatio: aspectRatio,
            inputReference: inputReferenceUrl
        )

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": serviceRequest],
                headers: headers,
                attachments: nil
            )

            guard case let .dictionary(_, data) = initialResponse,
                  let requestId = data["id"] as? String
            else {
                return createInvalidVideoResponseError(
                    response: initialResponse,
                    modelCode: model.modelCode
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidVideoStatusURLError()
            }

            let finalResponse = try await openaiVideoPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "Sora 2"
            )

            return try transformResponse(request: request, response: finalResponse)
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Sora 2 Pro

public class G_REPLICATE_OPENAI_SORA_2_PRO: VideoGenerationProtocol {
    public init() {}
    /// $0.30/second (standard) or $0.50/second (high)
    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let resolution = request.resolution ?? "standard"
        let duration = request.durationSeconds ?? 4
        let numberOfVideos = request.numberOfVideos ?? 1

        let costPerSecond = switch resolution {
        case "high": 0.50
        default: 0.30
        }

        return costPerSecond * Double(duration) * Double(numberOfVideos)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_OPENAI_SORA_2_PRO)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let seconds: Int
        let resolution: String
        let aspect_ratio: String
        let input_reference: String?

        init(
            prompt: String,
            seconds: Int = 4,
            resolution: String = "standard",
            aspectRatio: String = "landscape",
            inputReference: String? = nil
        ) {
            self.prompt = prompt
            self.seconds = seconds
            self.resolution = resolution
            aspect_ratio = aspectRatio
            input_reference = inputReference
        }
    }

    private func mapToAspectRatio(dimension: String) -> String {
        let aspectRatio = getAspectRatio(dimension: dimension)
        let width = aspectRatio.width
        let height = aspectRatio.height

        if width > height {
            return "landscape"
        }
        return "portrait"
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = mapToAspectRatio(dimension: request.dimensions)

        return ServiceRequest(
            prompt: request.prompt ?? "",
            seconds: request.durationSeconds ?? 4,
            resolution: request.resolution ?? "standard",
            aspectRatio: aspectRatio,
            inputReference: nil
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        try openaiVideoTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            costEstimate: getCostEstimate(request: VideoGenerationCostRequest(from: request))
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        // Upload input reference image if provided
        var inputReferenceUrl: String? = nil
        if let clientImage = request.clientImage {
            inputReferenceUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
        }

        let aspectRatio = mapToAspectRatio(dimension: request.dimensions)

        let serviceRequest = ServiceRequest(
            prompt: request.prompt ?? "",
            seconds: request.durationSeconds ?? 4,
            resolution: request.resolution ?? "standard",
            aspectRatio: aspectRatio,
            inputReference: inputReferenceUrl
        )

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": serviceRequest],
                headers: headers,
                attachments: nil
            )

            guard case let .dictionary(_, data) = initialResponse,
                  let requestId = data["id"] as? String
            else {
                return createInvalidVideoResponseError(
                    response: initialResponse,
                    modelCode: model.modelCode
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidVideoStatusURLError()
            }

            let finalResponse = try await openaiVideoPollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "Sora 2 Pro"
            )

            return try transformResponse(request: request, response: finalResponse)
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }
}
