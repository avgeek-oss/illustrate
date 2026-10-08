// MARK: - G_REPLICATE_2026_VIDEO_REFRESH.swift

// Replicate official video generation refresh models added in 2026.

import Foundation

private struct ReplicateRefreshPredictionRequest<Input: Codable & Sendable>: Codable {
    let input: Input
}

private func replicateRefreshFormatCost(_ cost: Double) -> String {
    cost == 0 ? "Free" : formatEstimatedCost(cost)
}

private func replicateRefreshNumberOfVideos(_ request: VideoGenerationCostRequest) -> Double {
    Double(request.numberOfVideos ?? 1)
}

private func replicateRefreshDuration(
    _ request: VideoGenerationCostRequest,
    default defaultDuration: Int = 5
) -> Double {
    let duration = request.durationSeconds ?? defaultDuration
    return Double(max(duration, 1))
}

private func replicateRefreshSupportedValue(
    _ value: String?,
    supported: [String],
    default defaultValue: String
) -> String {
    guard let value, supported.contains(value) else {
        return defaultValue
    }
    return value
}

private func replicateRefreshSupportedDuration(_ value: Int?, supported: [Int], default defaultValue: Int) -> Int {
    guard let value, supported.contains(value) else {
        return defaultValue
    }
    return value
}

private func replicateRefreshAspectRatio(
    _ dimensions: String,
    supported: [String],
    default defaultRatio: String
) -> String {
    if supported.contains(dimensions) {
        return dimensions
    }

    let ratio = getAspectRatio(dimension: dimensions).ratio
    return supported.contains(ratio) ? ratio : defaultRatio
}

private func replicateRefreshErrorMessage(from data: [String: Any]) -> String? {
    if let error = data["error"] as? String, !error.isEmpty {
        return error
    }
    if let errors = data["error"] as? [String], let error = errors.first {
        return error
    }
    return nil
}

private func replicateRefreshVideoBase64(from output: String) throws -> String {
    if output.hasPrefix("data:"),
       let comma = output.firstIndex(of: ",")
    {
        return String(output[output.index(after: comma)...])
    }

    guard let url = URL(string: output) else {
        throw NSError(domain: "Invalid video output URL", code: -1, userInfo: nil)
    }

    return try Data(contentsOf: url).base64EncodedString()
}

private func replicateRefreshTransformResponse(
    request: VideoGenerationRequest,
    response: NetworkResponseData,
    modelCode: EnumProviderModelCode,
    cost: Double
) throws -> VideoGenerationResponse {
    switch response {
    case let .dictionary(_, data):
        if let status = data["status"] as? String,
           status == "failed" || status == "canceled"
        {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: replicateRefreshErrorMessage(from: data) ?? "Prediction \(status)",
                rawResponse: response.rawResponseString
            )
        }

        if let output = data["output"] as? String {
            return try VideoGenerationResponse(
                status: .GENERATED,
                base64: replicateRefreshVideoBase64(from: output),
                cost: cost
            )
        }

        if let output = data["output"] as? [String], let videoURL = output.first {
            return try VideoGenerationResponse(
                status: .GENERATED,
                base64: replicateRefreshVideoBase64(from: videoURL),
                cost: cost
            )
        }

        if let error = replicateRefreshErrorMessage(from: data) {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: error,
                rawResponse: response.rawResponseString
            )
        }
    default:
        break
    }

    return createInvalidVideoResponseError(response: response, modelCode: modelCode)
}

private func replicateRefreshPollForResult(
    requestId: String,
    url: URL,
    headers: [String: String],
    maxAttempts: Int = 180
) async throws -> NetworkResponseData {
    var attempts = 0

    while attempts < maxAttempts {
        try await Task.sleep(nanoseconds: 5_000_000_000)

        let response = try await ProviderDependencies.shared.networkProvider.performRequest(
            url: url.appendingPathComponent(requestId),
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

private func replicateRefreshPerformVideoRequest(
    request: VideoGenerationRequest,
    model: ProviderModelData,
    body: some Codable & Sendable,
    transformResponse: (NetworkResponseData) throws -> VideoGenerationResponse
) async throws -> VideoGenerationResponse {
    guard let url = model.generateURL else {
        return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
    }

    let headers = [
        "Authorization": "Bearer \(request.providerSecret)",
        "Content-Type": "application/json",
    ]

    do {
        let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
            url: url,
            method: "POST",
            body: ReplicateRefreshPredictionRequest(input: body),
            headers: headers,
            attachments: nil
        )

        guard case let .dictionary(_, data) = initialResponse else {
            return createInvalidVideoResponseError(response: initialResponse, modelCode: model.modelCode)
        }

        if let error = replicateRefreshErrorMessage(from: data) {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: error,
                rawResponse: initialResponse.rawResponseString
            )
        }

        guard let requestId = data["id"] as? String else {
            return createInvalidVideoResponseError(
                response: initialResponse,
                modelCode: model.modelCode,
                customMessage: "Failed to create prediction"
            )
        }

        guard let statusURL = model.statusURL else {
            return createInvalidVideoStatusURLError()
        }

        let finalResponse = try await replicateRefreshPollForResult(
            requestId: requestId,
            url: statusURL,
            headers: headers
        )
        return try transformResponse(finalResponse)
    } catch {
        return VideoGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: "Failed with error: \(error.localizedDescription)"
        )
    }
}

private func replicateRefreshUploadReferenceImages(
    _ referenceImages: [ReferenceImageData]?,
    apiToken: String,
    maxCount: Int
) async throws -> [String]? {
    guard let referenceImages, !referenceImages.isEmpty else {
        return nil
    }

    var uploadedUrls: [String] = []
    for referenceImage in referenceImages.prefix(maxCount) {
        let uploaded = try await ReplicateFileUploader.uploadImage(
            base64Image: referenceImage.base64Image,
            apiToken: apiToken
        )
        uploadedUrls.append(uploaded)
    }

    return uploadedUrls.isEmpty ? nil : uploadedUrls
}

// MARK: - Seedance 2.0 Mini

public final class G_REPLICATE_SEEDANCE_2_MINI: VideoGenerationProtocol {
    public init() {}

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_SEEDANCE_2_MINI)!
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let image: String?
        let last_frame_image: String?
        let reference_images: [String]?
        let duration: Int
        let resolution: String
        let aspect_ratio: String
        let generate_audio: Bool
        let seed: Int?

        init(
            prompt: String,
            image: String? = nil,
            lastFrameImage: String? = nil,
            referenceImages: [String]? = nil,
            duration: Int = 5,
            resolution: String = "720p",
            aspectRatio: String = "16:9",
            generateAudio: Bool = true,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            self.image = image
            last_frame_image = lastFrameImage
            reference_images = referenceImages
            self.duration = duration
            self.resolution = resolution
            aspect_ratio = aspectRatio
            generate_audio = generateAudio
            self.seed = seed
        }
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = replicateRefreshDuration(request)
        let resolution = replicateRefreshSupportedValue(
            request.resolution,
            supported: ["480p", "720p"],
            default: "720p"
        )
        let rate = resolution == "480p" ? 0.04 : 0.09
        return rate * duration * replicateRefreshNumberOfVideos(request)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        replicateRefreshFormatCost(getCostEstimate(request: request))
    }

    func transformRequest(
        request: VideoGenerationRequest,
        imageUrl: String? = nil,
        lastFrameImageUrl: String? = nil,
        referenceImageUrls: [String]? = nil
    ) -> ServiceRequest {
        let supportedRatios = ["16:9", "4:3", "1:1", "3:4", "9:16", "21:9", "9:21", "adaptive"]
        let imageReferenceUrls = imageUrl == nil ? referenceImageUrls : nil

        return ServiceRequest(
            prompt: request.prompt ?? "",
            image: imageUrl,
            lastFrameImage: imageUrl == nil ? nil : lastFrameImageUrl,
            referenceImages: imageReferenceUrls,
            duration: replicateRefreshSupportedDuration(
                request.durationSeconds,
                supported: [-1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                default: 5
            ),
            resolution: replicateRefreshSupportedValue(
                request.resolution,
                supported: ["480p", "720p"],
                default: "720p"
            ),
            aspectRatio: replicateRefreshAspectRatio(request.dimensions, supported: supportedRatios, default: "16:9"),
            generateAudio: request.generateAudio ?? true,
            seed: request.seed
        )
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, imageUrl: nil, lastFrameImageUrl: nil, referenceImageUrls: nil)
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        try replicateRefreshTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        var imageUrl: String?
        var lastFrameImageUrl: String?
        var referenceImageUrls: [String]?

        do {
            if let clientImage = request.clientImage {
                imageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
                if let clientLastFrame = request.clientLastFrame {
                    lastFrameImageUrl = try await ReplicateFileUploader.uploadImage(
                        base64Image: clientLastFrame,
                        apiToken: request.providerSecret
                    )
                }
            } else {
                referenceImageUrls = try await replicateRefreshUploadReferenceImages(
                    request.clientReferenceImages,
                    apiToken: request.providerSecret,
                    maxCount: 9
                )
            }
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed to upload image: \(error.localizedDescription)"
            )
        }

        let body = transformRequest(
            request: request,
            imageUrl: imageUrl,
            lastFrameImageUrl: lastFrameImageUrl,
            referenceImageUrls: referenceImageUrls
        )
        return try await replicateRefreshPerformVideoRequest(
            request: request,
            model: model,
            body: body
        ) { response in
            try self.transformResponse(request: request, response: response)
        }
    }
}

// MARK: - Happy Horse 1.1

public final class G_REPLICATE_HAPPY_HORSE_1_1: VideoGenerationProtocol {
    public init() {}

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_HAPPY_HORSE_1_1)!
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let images: [String]?
        let resolution: String
        let aspect_ratio: String
        let duration: Int
        let seed: Int?

        init(
            prompt: String,
            images: [String]? = nil,
            resolution: String = "1080p",
            aspectRatio: String = "16:9",
            duration: Int = 5,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            self.images = images
            self.resolution = resolution
            aspect_ratio = aspectRatio
            self.duration = duration
            self.seed = seed
        }
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = replicateRefreshDuration(request)
        let resolution = replicateRefreshSupportedValue(
            request.resolution,
            supported: ["720p", "1080p"],
            default: "1080p"
        )
        let rate = resolution == "720p" ? 0.14 : 0.18
        return rate * duration * replicateRefreshNumberOfVideos(request)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        replicateRefreshFormatCost(getCostEstimate(request: request))
    }

    func transformRequest(
        request: VideoGenerationRequest,
        imageUrls: [String]? = nil
    ) -> ServiceRequest {
        let supportedRatios = ["16:9", "9:16", "1:1", "4:3", "3:4"]

        return ServiceRequest(
            prompt: request.prompt ?? "",
            images: imageUrls,
            resolution: replicateRefreshSupportedValue(
                request.resolution,
                supported: ["720p", "1080p"],
                default: "1080p"
            ),
            aspectRatio: replicateRefreshAspectRatio(request.dimensions, supported: supportedRatios, default: "16:9"),
            duration: replicateRefreshSupportedDuration(
                request.durationSeconds,
                supported: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                default: 5
            ),
            seed: request.seed
        )
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, imageUrls: nil)
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        try replicateRefreshTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        var imageUrls: [String] = []

        do {
            if let clientImage = request.clientImage {
                let uploaded = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
                imageUrls.append(uploaded)
            }

            if let referenceImageUrls = try await replicateRefreshUploadReferenceImages(
                request.clientReferenceImages,
                apiToken: request.providerSecret,
                maxCount: max(9 - imageUrls.count, 0)
            ) {
                imageUrls.append(contentsOf: referenceImageUrls)
            }
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed to upload image: \(error.localizedDescription)"
            )
        }

        let body = transformRequest(request: request, imageUrls: imageUrls.isEmpty ? nil : imageUrls)
        return try await replicateRefreshPerformVideoRequest(
            request: request,
            model: model,
            body: body
        ) { response in
            try self.transformResponse(request: request, response: response)
        }
    }
}

// MARK: - Luma Ray 3.2

public final class G_REPLICATE_LUMA_RAY_3_2: VideoGenerationProtocol {
    public init() {}

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_LUMA_RAY_3_2)!
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let resolution: String
        let duration: Int
        let hdr: Bool
        let exr_export: Bool
        let loop: Bool
        let start_image: String?
        let end_image: String?

        init(
            prompt: String,
            aspectRatio: String = "16:9",
            resolution: String = "720p",
            duration: Int = 5,
            startImage: String? = nil,
            endImage: String? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.resolution = resolution
            self.duration = duration
            hdr = false
            exr_export = false
            loop = false
            start_image = startImage
            end_image = endImage
        }
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let resolution = replicateRefreshSupportedValue(
            request.resolution,
            supported: ["540p", "720p", "1080p"],
            default: "720p"
        )
        let duration = replicateRefreshSupportedDuration(request.durationSeconds, supported: [5, 10], default: 5)

        let cost = switch (resolution, duration) {
        case ("540p", 10):
            0.45
        case ("720p", 5):
            0.30
        case ("720p", 10):
            0.90
        case ("1080p", 5):
            1.20
        case ("1080p", 10):
            3.60
        default:
            0.15
        }

        return cost * replicateRefreshNumberOfVideos(request)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        replicateRefreshFormatCost(getCostEstimate(request: request))
    }

    func transformRequest(
        request: VideoGenerationRequest,
        startImageUrl: String? = nil,
        endImageUrl: String? = nil
    ) -> ServiceRequest {
        let supportedRatios = ["9:16", "3:4", "1:1", "4:3", "16:9", "21:9"]
        let hasImage = startImageUrl != nil || endImageUrl != nil || request.clientImage != nil || request
            .clientLastFrame != nil

        return ServiceRequest(
            prompt: request.prompt ?? "",
            aspectRatio: replicateRefreshAspectRatio(request.dimensions, supported: supportedRatios, default: "16:9"),
            resolution: replicateRefreshSupportedValue(
                request.resolution,
                supported: ["540p", "720p", "1080p"],
                default: "720p"
            ),
            duration: hasImage ? 5 : replicateRefreshSupportedDuration(
                request.durationSeconds,
                supported: [5, 10],
                default: 5
            ),
            startImage: startImageUrl,
            endImage: endImageUrl
        )
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, startImageUrl: nil, endImageUrl: nil)
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        var costRequest = VideoGenerationCostRequest(from: request)
        if request.clientImage != nil || request.clientLastFrame != nil {
            costRequest.durationSeconds = 5
        }

        return try replicateRefreshTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            cost: getCostEstimate(request: costRequest)
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        var startImageUrl: String?
        var endImageUrl: String?

        do {
            if let clientImage = request.clientImage {
                startImageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
            }

            if let clientLastFrame = request.clientLastFrame {
                endImageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientLastFrame,
                    apiToken: request.providerSecret
                )
            }
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed to upload image: \(error.localizedDescription)"
            )
        }

        let body = transformRequest(request: request, startImageUrl: startImageUrl, endImageUrl: endImageUrl)
        return try await replicateRefreshPerformVideoRequest(
            request: request,
            model: model,
            body: body
        ) { response in
            try self.transformResponse(request: request, response: response)
        }
    }
}

// MARK: - Vidu Q3 Turbo

public final class G_REPLICATE_VIDU_Q3_TURBO: VideoGenerationProtocol {
    public init() {}

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_VIDU_Q3_TURBO)!
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let start_image: String?
        let end_image: String?
        let duration: Int
        let aspect_ratio: String
        let resolution: String
        let audio: Bool
        let seed: Int?

        init(
            prompt: String,
            startImage: String? = nil,
            endImage: String? = nil,
            duration: Int = 5,
            aspectRatio: String = "16:9",
            resolution: String = "720p",
            audio: Bool = true,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            start_image = startImage
            end_image = endImage
            self.duration = duration
            aspect_ratio = aspectRatio
            self.resolution = resolution
            self.audio = audio
            self.seed = seed
        }
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = replicateRefreshDuration(request)
        let resolution = replicateRefreshSupportedValue(
            request.resolution,
            supported: ["540p", "720p", "1080p"],
            default: "720p"
        )
        let rate = switch resolution {
        case "540p":
            0.04
        case "1080p":
            0.08
        default:
            0.06
        }
        return rate * duration * replicateRefreshNumberOfVideos(request)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        replicateRefreshFormatCost(getCostEstimate(request: request))
    }

    func transformRequest(
        request: VideoGenerationRequest,
        startImageUrl: String? = nil,
        endImageUrl: String? = nil
    ) -> ServiceRequest {
        let supportedRatios = ["16:9", "9:16", "3:4", "4:3", "1:1"]

        return ServiceRequest(
            prompt: request.prompt ?? "",
            startImage: startImageUrl,
            endImage: startImageUrl == nil ? nil : endImageUrl,
            duration: min(max(request.durationSeconds ?? 5, 1), 16),
            aspectRatio: replicateRefreshAspectRatio(request.dimensions, supported: supportedRatios, default: "16:9"),
            resolution: replicateRefreshSupportedValue(
                request.resolution,
                supported: ["540p", "720p", "1080p"],
                default: "720p"
            ),
            audio: request.generateAudio ?? true,
            seed: request.seed
        )
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, startImageUrl: nil, endImageUrl: nil)
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        try replicateRefreshTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        var startImageUrl: String?
        var endImageUrl: String?

        do {
            if let clientImage = request.clientImage {
                startImageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
            }

            if startImageUrl != nil, let clientLastFrame = request.clientLastFrame {
                endImageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientLastFrame,
                    apiToken: request.providerSecret
                )
            }
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed to upload image: \(error.localizedDescription)"
            )
        }

        let body = transformRequest(request: request, startImageUrl: startImageUrl, endImageUrl: endImageUrl)
        return try await replicateRefreshPerformVideoRequest(
            request: request,
            model: model,
            body: body
        ) { response in
            try self.transformResponse(request: request, response: response)
        }
    }
}
