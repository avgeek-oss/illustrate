// MARK: - G_REPLICATE_NEW_MODELS_JUNE.swift

// New Replicate models added June 2026:
// - FLUX 1.1 Pro Ultra (image, 4MP ultra + raw mode)
// - HiDream L1 Fast (image, PrunaAI optimised)
// - Wan 2.7 Image (image, up to 2K)
// - Wan 2.7 Image Pro (image, up to 4K + thinking mode)
// - Wan 2.7 Reference-to-Video (video, preserves subject identity)
// - Hunyuan Image 3 (image, 80B MoE native multimodal)

import Foundation

// MARK: - Shared Helpers

private func newModelsJuneTransformResponse(
    response: NetworkResponseData,
    modelCode: EnumProviderModelCode,
    costEstimate: Double,
    isVideo: Bool = false
) throws -> NetworkResponseData {
    response
}

private func replicateJunePollForResult(
    requestId: String,
    url: URL,
    headers: [String: String],
    maxAttempts: Int = 120
) async throws -> NetworkResponseData {
    var attempts = 0
    while attempts < maxAttempts {
        try await Task.sleep(nanoseconds: 3_000_000_000)

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

private func performReplicateImageJuneRequest(
    request: ImageGenerationRequest,
    model: ProviderModelData,
    body: some Codable & Sendable
) async throws -> ImageGenerationResponse {
    guard let url = URL(string: model.modelGenerateBaseURL) else {
        return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
    }

    let headers = [
        "Authorization": "Bearer \(request.providerSecret)",
        "Content-Type": "application/json",
    ]

    let response = try await ProviderDependencies.shared.networkProvider.performRequest(
        url: url,
        method: "POST",
        body: ["input": body],
        headers: headers,
        attachments: nil
    )

    guard case let .dictionary(_, data) = response,
          let predictionId = data["id"] as? String
    else {
        if case let .dictionary(_, d) = response {
            if let errorList = d["error"] as? [String], let error = errorList.first {
                return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
            }
            if let error = d["error"] as? String {
                return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
            }
        }
        return createInvalidResponseError(response: response, modelCode: model.modelCode)
    }

    guard let statusUrl = model.statusURL else {
        return createInvalidStatusURLError()
    }

    let finalResponse = try await replicateJunePollForResult(
        requestId: predictionId,
        url: statusUrl,
        headers: headers
    )

    if case let .dictionary(_, finalData) = finalResponse {
        if let imageUrl = finalData["output"] as? String {
            let imgData = try Data(contentsOf: URL(string: imageUrl)!)
            return ImageGenerationResponse(
                status: .GENERATED,
                base64: imgData.base64EncodedString(),
                cost: 0
            )
        }
        if let output = finalData["output"] as? [String], let firstUrl = output.first {
            let imgData = try Data(contentsOf: URL(string: firstUrl)!)
            return ImageGenerationResponse(
                status: .GENERATED,
                base64: imgData.base64EncodedString(),
                cost: 0
            )
        }
        if let errorList = finalData["error"] as? [String], let error = errorList.first {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
        }
        if let error = finalData["error"] as? String {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
        }
    }

    return createInvalidResponseError(response: finalResponse, modelCode: model.modelCode)
}

// MARK: - FLUX 1.1 Pro Ultra

public class G_REPLICATE_FLUX_11_PRO_ULTRA: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.06

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_FLUX_11_PRO_ULTRA)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let safety_tolerance: Int
        let seed: Int?
        let raw: Bool

        init(prompt: String, aspectRatio: String, safetyTolerance: Int = 5, seed: Int? = nil, raw: Bool = false) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            safety_tolerance = safetyTolerance
            self.seed = seed
            self.raw = raw
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let prompt = request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt
        return ServiceRequest(
            prompt: prompt,
            aspectRatio: aspectRatio.ratio,
            safetyTolerance: request.safetyTolerance ?? 5,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let imageUrl = data["output"] as? String {
                let url = URL(string: imageUrl)!
                let imageData = try Data(contentsOf: url)
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData.base64EncodedString(),
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
            }
            if let output = data["output"] as? [String], let imageUrl = output.first {
                let url = URL(string: imageUrl)!
                let imageData = try Data(contentsOf: url)
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData.base64EncodedString(),
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
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
        return createInvalidResponseError(response: response, modelCode: model.modelCode)
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let serviceRequest = transformRequest(request: request)
        var finalResponse = try await performReplicateImageJuneRequest(
            request: request,
            model: model,
            body: serviceRequest
        )
        if finalResponse.status == .GENERATED {
            finalResponse = ImageGenerationResponse(
                status: .GENERATED,
                base64: finalResponse.base64,
                cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
            )
        }
        return finalResponse
    }
}

// MARK: - HiDream L1 Fast

public class G_REPLICATE_HIDREAM_L1_FAST: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.005

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_HIDREAM_L1_FAST)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let seed: Int?

        init(prompt: String, aspectRatio: String, seed: Int? = nil) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt,
            aspectRatio: aspectRatio.ratio,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let imageUrl = data["output"] as? String {
                let url = URL(string: imageUrl)!
                let imageData = try Data(contentsOf: url)
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData.base64EncodedString(),
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
            }
            if let output = data["output"] as? [String], let imageUrl = output.first {
                let url = URL(string: imageUrl)!
                let imageData = try Data(contentsOf: url)
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData.base64EncodedString(),
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
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
        return createInvalidResponseError(response: response, modelCode: model.modelCode)
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let serviceRequest = transformRequest(request: request)
        var finalResponse = try await performReplicateImageJuneRequest(
            request: request,
            model: model,
            body: serviceRequest
        )
        if finalResponse.status == .GENERATED {
            finalResponse = ImageGenerationResponse(
                status: .GENERATED,
                base64: finalResponse.base64,
                cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
            )
        }
        return finalResponse
    }
}

// MARK: - Wan 2.7 Image (Standard)

public class G_REPLICATE_WAN_2_7_IMAGE: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.03

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_WAN_2_7_IMAGE)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let images: [String]?
        let size: String
        let num_outputs: Int
        let thinking_mode: Bool
        let seed: Int?

        init(
            prompt: String,
            images: [String]? = nil,
            size: String = "1K",
            numOutputs: Int = 1,
            thinkingMode: Bool = true,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            self.images = images
            self.size = size
            num_outputs = numOutputs
            thinking_mode = thinkingMode
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        ServiceRequest(
            prompt: request.prompt,
            size: "2K",
            numOutputs: 1,
            thinkingMode: true,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let imageUrl = data["output"] as? String {
                let url = URL(string: imageUrl)!
                let imageData = try Data(contentsOf: url)
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData.base64EncodedString(),
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
            }
            if let output = data["output"] as? [String], let imageUrl = output.first {
                let url = URL(string: imageUrl)!
                let imageData = try Data(contentsOf: url)
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData.base64EncodedString(),
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
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
        return createInvalidResponseError(response: response, modelCode: model.modelCode)
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        var uploadedImageUrls: [String]?
        if let clientImage = request.clientImage {
            do {
                let uploaded = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
                uploadedImageUrls = [uploaded]
            } catch {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to upload image: \(error.localizedDescription)"
                )
            }
        }

        let serviceRequest = ServiceRequest(
            prompt: request.prompt,
            images: uploadedImageUrls,
            size: "2K",
            numOutputs: 1,
            thinkingMode: true,
            seed: request.seed
        )

        var finalResponse = try await performReplicateImageJuneRequest(
            request: request,
            model: model,
            body: serviceRequest
        )
        if finalResponse.status == .GENERATED {
            finalResponse = ImageGenerationResponse(
                status: .GENERATED,
                base64: finalResponse.base64,
                cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
            )
        }
        return finalResponse
    }
}

// MARK: - Wan 2.7 Image Pro

public class G_REPLICATE_WAN_2_7_IMAGE_PRO: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.05

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_WAN_2_7_IMAGE_PRO)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let images: [String]?
        let size: String
        let num_outputs: Int
        let thinking_mode: Bool
        let seed: Int?

        init(
            prompt: String,
            images: [String]? = nil,
            size: String = "2K",
            numOutputs: Int = 1,
            thinkingMode: Bool = true,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            self.images = images
            self.size = size
            num_outputs = numOutputs
            thinking_mode = thinkingMode
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        ServiceRequest(
            prompt: request.prompt,
            size: "4K",
            numOutputs: 1,
            thinkingMode: true,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let imageUrl = data["output"] as? String {
                let url = URL(string: imageUrl)!
                let imageData = try Data(contentsOf: url)
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData.base64EncodedString(),
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
            }
            if let output = data["output"] as? [String], let imageUrl = output.first {
                let url = URL(string: imageUrl)!
                let imageData = try Data(contentsOf: url)
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData.base64EncodedString(),
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
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
        return createInvalidResponseError(response: response, modelCode: model.modelCode)
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        var uploadedImageUrls: [String]?
        if let clientImage = request.clientImage {
            do {
                let uploaded = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
                uploadedImageUrls = [uploaded]
            } catch {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to upload image: \(error.localizedDescription)"
                )
            }
        }

        let size = (uploadedImageUrls == nil) ? "4K" : "2K"
        let serviceRequest = ServiceRequest(
            prompt: request.prompt,
            images: uploadedImageUrls,
            size: size,
            numOutputs: 1,
            thinkingMode: true,
            seed: request.seed
        )

        var finalResponse = try await performReplicateImageJuneRequest(
            request: request,
            model: model,
            body: serviceRequest
        )
        if finalResponse.status == .GENERATED {
            finalResponse = ImageGenerationResponse(
                status: .GENERATED,
                base64: finalResponse.base64,
                cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
            )
        }
        return finalResponse
    }
}

// MARK: - Wan 2.7 Reference-to-Video

public class G_REPLICATE_WAN_2_7_R2V: VideoGenerationProtocol {
    public init() {}
    static let costPerSecond = 0.05

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        Self.costPerSecond * Double(request.durationSeconds ?? 5)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_WAN_2_7_R2V)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let reference_images: [String]?
        let reference_videos: [String]?
        let negative_prompt: String?
        let resolution: String
        let aspect_ratio: String
        let duration: Int
        let shot_type: String
        let seed: Int?

        init(
            prompt: String,
            referenceImages: [String]? = nil,
            referenceVideos: [String]? = nil,
            negativePrompt: String? = nil,
            resolution: String = "1080p",
            aspectRatio: String = "16:9",
            duration: Int = 5,
            shotType: String = "single",
            seed: Int? = nil
        ) {
            self.prompt = prompt
            reference_images = referenceImages
            reference_videos = referenceVideos
            negative_prompt = negativePrompt
            self.resolution = resolution
            aspect_ratio = aspectRatio
            self.duration = duration
            shot_type = shotType
            self.seed = seed
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt ?? "",
            negativePrompt: request.negativePrompt,
            resolution: request.resolution ?? "1080p",
            aspectRatio: aspectRatio.ratio,
            duration: request.durationSeconds ?? 5,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let videoUrl = data["output"] as? String {
                let url = URL(string: videoUrl)!
                let videoData = try Data(contentsOf: url)
                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: videoData.base64EncodedString(),
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
                )
            }
            if let output = data["output"] as? [String], let videoUrl = output.first {
                let url = URL(string: videoUrl)!
                let videoData = try Data(contentsOf: url)
                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: videoData.base64EncodedString(),
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
                )
            }
            if let errorList = data["error"] as? [String], let error = errorList.first {
                return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
            }
            if let error = data["error"] as? String {
                return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
            }
        default:
            return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
        }
        return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        var uploadedImageUrls: [String]?
        if let clientImage = request.clientImage {
            do {
                let uploaded = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
                uploadedImageUrls = [uploaded]
            } catch {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to upload reference image: \(error.localizedDescription)"
                )
            }
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let serviceRequest = ServiceRequest(
            prompt: request.prompt ?? "",
            referenceImages: uploadedImageUrls,
            negativePrompt: request.negativePrompt,
            resolution: request.resolution ?? "1080p",
            aspectRatio: aspectRatio.ratio,
            duration: request.durationSeconds ?? 5,
            seed: request.seed
        )

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
            return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
        }

        guard let statusUrl = model.statusURL else {
            return createInvalidVideoStatusURLError()
        }

        let finalResponse = try await replicateJunePollForResult(
            requestId: predictionId,
            url: statusUrl,
            headers: headers
        )

        return try transformResponse(request: request, response: finalResponse)
    }
}

// MARK: - Hunyuan Image 3

public class G_REPLICATE_HUNYUAN_IMAGE_3: ImageGenerationProtocol {
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
        .model(by: .REPLICATE_HUNYUAN_IMAGE_3)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let seed: Int?

        init(prompt: String, aspectRatio: String, seed: Int? = nil) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt,
            aspectRatio: aspectRatio.ratio,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let imageUrl = data["output"] as? String {
                let url = URL(string: imageUrl)!
                let imageData = try Data(contentsOf: url)
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData.base64EncodedString(),
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
            }
            if let output = data["output"] as? [String], let imageUrl = output.first {
                let url = URL(string: imageUrl)!
                let imageData = try Data(contentsOf: url)
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData.base64EncodedString(),
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
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
        return createInvalidResponseError(response: response, modelCode: model.modelCode)
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let serviceRequest = transformRequest(request: request)
        var finalResponse = try await performReplicateImageJuneRequest(
            request: request,
            model: model,
            body: serviceRequest
        )
        if finalResponse.status == .GENERATED {
            finalResponse = ImageGenerationResponse(
                status: .GENERATED,
                base64: finalResponse.base64,
                cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
            )
        }
        return finalResponse
    }
}
