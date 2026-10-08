// MARK: - G_REPLICATE_SEEDANCE.swift

// Consolidated implementation for ByteDance Seedance video models via Replicate.
// Supports Seedance 1 (Pro, Pro Fast, Lite) and Seedance 1.5 Pro variants.

import Foundation

// MARK: - Shared Helpers

private func seedanceTransformResponse(
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
    return createInvalidVideoResponseError(response: response, modelCode: modelCode)
}

private func seedancePollForResult(
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

private func mapToSeedanceAspectRatio(dimension: String) -> String {
    let aspectRatio = getAspectRatio(dimension: dimension)
    let ratio = aspectRatio.ratio

    let supportedRatios = ["16:9", "4:3", "1:1", "3:4", "9:16", "21:9", "9:21"]

    if supportedRatios.contains(ratio) {
        return ratio
    }

    let width = aspectRatio.width
    let height = aspectRatio.height
    let aspectValue = Double(width) / Double(height)

    let ratioValues: [(String, Double)] = [
        ("16:9", 1.778),
        ("4:3", 1.333),
        ("1:1", 1.0),
        ("3:4", 0.75),
        ("9:16", 0.5625),
        ("21:9", 2.333),
        ("9:21", 0.429),
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

private func mapToResolution(_ dimensions: String) -> String {
    let parts = dimensions.lowercased().split(separator: "x")
    guard parts.count == 2,
          let width = Int(parts[0]),
          let height = Int(parts[1])
    else {
        return "1080p"
    }

    let maxDim = max(width, height)
    if maxDim >= 1080 {
        return "1080p"
    } else if maxDim >= 720 {
        return "720p"
    }
    return "480p"
}

// MARK: - Seedance 1 Base

/// Base implementation for Seedance 1 video generation (Pro, Pro Fast, Lite).
public class G_REPLICATE_SEEDANCE_BASE: VideoGenerationProtocol {
    let modelCode: EnumProviderModelCode

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(modelCode: EnumProviderModelCode) {
        self.modelCode = modelCode
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let resolution = request.resolution ?? "1080p"
        let durationSeconds = request.durationSeconds ?? 5
        let numberOfVideos = request.numberOfVideos ?? 1

        let baseCost = switch modelCode {
        case .REPLICATE_SEEDANCE_1_PRO:
            switch resolution {
            case "1080p": 0.15
            case "720p": 0.06
            case "480p": 0.03
            default: 0.15
            }
        case .REPLICATE_SEEDANCE_1_PRO_FAST:
            switch resolution {
            case "1080p": 0.06
            case "720p": 0.025
            case "480p": 0.015
            default: 0.06
            }
        case .REPLICATE_SEEDANCE_1_LITE:
            switch resolution {
            case "1080p": 0.072
            case "720p": 0.036
            case "480p": 0.018
            default: 0.072
            }
        default:
            0.03
        }

        return baseCost * Double(durationSeconds) * Double(numberOfVideos)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let duration: Int
        let resolution: String
        let aspect_ratio: String
        let fps: Int
        let camera_fixed: Bool
        let image: String?
        let last_frame_image: String?

        init(
            prompt: String,
            duration: Int = 5,
            resolution: String = "1080p",
            aspectRatio: String = "16:9",
            fps: Int = 24,
            cameraFixed: Bool = false,
            image: String? = nil,
            lastFrameImage: String? = nil
        ) {
            self.prompt = prompt
            self.duration = duration
            self.resolution = resolution
            aspect_ratio = aspectRatio
            self.fps = fps
            camera_fixed = cameraFixed
            self.image = image
            last_frame_image = lastFrameImage
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = mapToSeedanceAspectRatio(dimension: request.dimensions)
        let resolution = request.resolution ?? mapToResolution(request.dimensions)
        let duration = request.durationSeconds ?? 5

        return ServiceRequest(
            prompt: request.prompt ?? "",
            duration: duration,
            resolution: resolution,
            aspectRatio: aspectRatio,
            fps: request.fps ?? 24
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        try seedanceTransformResponse(
            request: request,
            response: response,
            modelCode: model.modelCode,
            costEstimate: getCostEstimate(request: VideoGenerationCostRequest(from: request))
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let aspectRatio = mapToSeedanceAspectRatio(dimension: request.dimensions)
        let resolution = mapToResolution(request.dimensions)
        let duration = request.durationSeconds ?? 5

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]

        var imageUrl: String? = nil
        var lastFrameUrl: String? = nil

        if let clientImage = request.clientImage {
            imageUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
        }

        if let clientLastFrame = request.clientLastFrame, imageUrl != nil {
            lastFrameUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientLastFrame,
                apiToken: request.providerSecret
            )
        }

        let serviceRequest = ServiceRequest(
            prompt: request.prompt ?? "",
            duration: duration,
            resolution: resolution,
            aspectRatio: aspectRatio,
            fps: request.fps ?? 24,
            image: imageUrl,
            lastFrameImage: lastFrameUrl
        )

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": serviceRequest],
                headers: headers,
                attachments: nil
            )

            guard case let .dictionary(_, data) = initialResponse else {
                return createInvalidVideoResponseError(response: initialResponse, modelCode: model.modelCode)
            }

            if let error = data["error"] as? String {
                return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
            }

            guard let requestId = data["id"] as? String else {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to initiate request"
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidVideoStatusURLError()
            }

            let finalResponse = try await seedancePollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "Seedance"
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

// MARK: - Seedance 1 Variants

public class G_REPLICATE_SEEDANCE_1_PRO: G_REPLICATE_SEEDANCE_BASE {
    public init() {
        super.init(modelCode: .REPLICATE_SEEDANCE_1_PRO)
    }
}

public class G_REPLICATE_SEEDANCE_1_PRO_FAST: G_REPLICATE_SEEDANCE_BASE {
    public init() {
        super.init(modelCode: .REPLICATE_SEEDANCE_1_PRO_FAST)
    }
}

public class G_REPLICATE_SEEDANCE_1_LITE: G_REPLICATE_SEEDANCE_BASE {
    public init() {
        super.init(modelCode: .REPLICATE_SEEDANCE_1_LITE)
    }
}

// MARK: - Seedance 1.5 Pro

public class G_REPLICATE_SEEDANCE_1_5_PRO: VideoGenerationProtocol {
    public init() {}
    static let costPerSecondWithAudio = 0.052
    static let costPerSecondNoAudio = 0.026

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_SEEDANCE_1_5_PRO)!
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let durationSeconds = request.durationSeconds ?? 5
        let numberOfVideos = request.numberOfVideos ?? 1
        // Default to with audio for cost estimate
        let costPerSecond = Self.costPerSecondWithAudio
        return costPerSecond * Double(durationSeconds) * Double(numberOfVideos)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let duration: Int
        let aspect_ratio: String
        let fps: Int
        let camera_fixed: Bool
        let generate_audio: Bool
        let seed: Int?
        let image: String?
        let last_frame_image: String?

        init(
            prompt: String,
            duration: Int = 5,
            aspectRatio: String = "16:9",
            fps: Int = 24,
            cameraFixed: Bool = false,
            generateAudio: Bool = true,
            seed: Int? = nil,
            image: String? = nil,
            lastFrameImage: String? = nil
        ) {
            self.prompt = prompt
            self.duration = duration
            aspect_ratio = aspectRatio
            self.fps = fps
            camera_fixed = cameraFixed
            generate_audio = generateAudio
            self.seed = seed
            self.image = image
            last_frame_image = lastFrameImage
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = mapToSeedanceAspectRatio(dimension: request.dimensions)
        let duration = request.durationSeconds ?? 5
        let generateAudio = request.generateAudio ?? true

        return ServiceRequest(
            prompt: request.prompt ?? "",
            duration: duration,
            aspectRatio: aspectRatio,
            fps: request.fps ?? 24,
            generateAudio: generateAudio,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        let rawResponse = extractRawResponse(from: response)

        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
                let videoData = try Data(contentsOf: url)
                let base64 = videoData.base64EncodedString()

                // Calculate actual cost based on audio setting
                let durationSeconds = request.durationSeconds ?? 5
                let generateAudio = request.generateAudio ?? true
                let costPerSecond = generateAudio ? Self.costPerSecondWithAudio : Self.costPerSecondNoAudio
                let cost = costPerSecond * Double(durationSeconds)

                return VideoGenerationResponse(status: .GENERATED, base64: base64, cost: cost)
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
        return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let aspectRatio = mapToSeedanceAspectRatio(dimension: request.dimensions)
        let duration = request.durationSeconds ?? 5
        let generateAudio = request.generateAudio ?? true

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]

        var imageUrl: String? = nil
        var lastFrameUrl: String? = nil

        if let clientImage = request.clientImage {
            imageUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
        }

        if let clientLastFrame = request.clientLastFrame, imageUrl != nil {
            lastFrameUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientLastFrame,
                apiToken: request.providerSecret
            )
        }

        let serviceRequest = ServiceRequest(
            prompt: request.prompt ?? "",
            duration: duration,
            aspectRatio: aspectRatio,
            fps: request.fps ?? 24,
            generateAudio: generateAudio,
            seed: request.seed,
            image: imageUrl,
            lastFrameImage: lastFrameUrl
        )

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": serviceRequest],
                headers: headers,
                attachments: nil
            )

            guard case let .dictionary(_, data) = initialResponse else {
                return createInvalidVideoResponseError(response: initialResponse, modelCode: model.modelCode)
            }

            if let error = data["error"] as? String {
                return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
            }

            guard let requestId = data["id"] as? String else {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to initiate request"
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidVideoStatusURLError()
            }

            let finalResponse = try await seedancePollForResult(
                requestId: requestId,
                url: statusUrl,
                headers: headers,
                modelName: "Seedance 1.5 Pro",
                maxAttempts: 90
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
