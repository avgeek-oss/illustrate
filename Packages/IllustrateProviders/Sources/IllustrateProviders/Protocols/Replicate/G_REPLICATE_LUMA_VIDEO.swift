// MARK: - G_REPLICATE_LUMA_VIDEO.swift

// Luma video models via Replicate:
// - luma/ray (original Ray model, text/image-to-video)
// - luma/ray-2-* (Ray 2 variants with duration control)
// - luma/modify-video (video-to-video editing)

import Foundation

// MARK: - Base Class

public class ReplicateLumaVideoBase: VideoGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override modelCode")
    }

    var maxPollingAttempts: Int {
        90
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public struct ServiceRequest: Codable, Sendable {
        let placeholder: Bool
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        ServiceRequest(placeholder: true)
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        fatalError("Subclass must override getCostEstimate")
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
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

                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
                )
            }
            if let errorList = data["error"] as? [String],
               let error = errorList.first
            {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: error,
                    rawResponse: rawResponse
                )
            }
            if let error = data["error"] as? String {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: error,
                    rawResponse: rawResponse
                )
            }
        default:
            return createInvalidVideoResponseError(
                response: response,
                modelCode: model.modelCode,
                customMessage: "Unexpected response"
            )
        }

        return createInvalidVideoResponseError(
            response: response,
            modelCode: model.modelCode
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        fatalError("Subclass must override makeRequest")
    }

    // MARK: - Shared Helpers

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String]
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < maxPollingAttempts {
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

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

    func mapToLumaAspectRatio(dimension: String) -> String {
        let aspectRatio = getAspectRatio(dimension: dimension)
        let ratio = aspectRatio.ratio

        let supportedRatios = ["1:1", "3:4", "4:3", "9:16", "16:9", "9:21", "21:9"]

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

    func performLumaVideoRequest(
        request: VideoGenerationRequest,
        body: some Codable & Sendable
    ) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let headers: [String: String] = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": body],
                headers: headers,
                attachments: nil
            )

            var requestId: String?

            switch initialResponse {
            case let .dictionary(_, data):
                requestId = data["id"] as? String
                if let error = data["error"] as? String {
                    return VideoGenerationResponse(
                        status: .FAILED,
                        errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                        errorMessage: error
                    )
                }
            default:
                return createInvalidVideoResponseError(
                    response: initialResponse,
                    modelCode: model.modelCode
                )
            }

            guard let requestId else {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Failed to initiate request"
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidVideoStatusURLError()
            }

            let finalResponse = try await pollForResult(requestId: requestId, url: statusUrl, headers: headers)
            return try transformResponse(request: request, response: finalResponse)
        } catch {
            return VideoGenerationResponse(
                status: EnumGenerationStatus.FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Failed with error: \(error.localizedDescription)"
            )
        }
    }

    func uploadStartEndImages(
        request: VideoGenerationRequest
    ) async throws -> (startImageUrl: String?, endImageUrl: String?) {
        var startImageUrl: String?
        var endImageUrl: String?

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

        return (startImageUrl, endImageUrl)
    }
}

// MARK: - Luma Ray (Original)

private struct LumaRayRequest: Codable {
    let prompt: String
    let aspect_ratio: String
    let loop: Bool
    let start_image: String?
    let end_image: String?
}

public final class G_REPLICATE_LUMA_RAY: ReplicateLumaVideoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_LUMA_RAY
    }

    /// Flat cost per video ($0.45)
    static let baseCost = 0.45

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfVideos ?? 1)
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let aspectRatio = mapToLumaAspectRatio(dimension: request.dimensions)

        let (startImageUrl, endImageUrl) = try await uploadStartEndImages(request: request)

        let body = LumaRayRequest(
            prompt: request.prompt ?? "",
            aspect_ratio: aspectRatio,
            loop: false,
            start_image: startImageUrl,
            end_image: endImageUrl
        )

        return try await performLumaVideoRequest(request: request, body: body)
    }
}

// MARK: - Luma Ray 2 (Duration-based)

private struct LumaRay2Request: Codable {
    let prompt: String
    let aspect_ratio: String
    let duration: Int
    let loop: Bool
    let start_image: String?
    let end_image: String?
}

public class G_REPLICATE_LUMA_RAY_2_BASE: ReplicateLumaVideoBase {
    private let _modelCode: EnumProviderModelCode

    override var modelCode: EnumProviderModelCode {
        _modelCode
    }

    public init(modelCode: EnumProviderModelCode) {
        _modelCode = modelCode
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let durationSeconds = request.durationSeconds ?? 5
        let numberOfVideos = request.numberOfVideos ?? 1

        // Cost per second based on model variant
        let costPerSecond = switch _modelCode {
        case .REPLICATE_LUMA_RAY_2_540P:
            0.10
        case .REPLICATE_LUMA_RAY_2_720P:
            0.18
        case .REPLICATE_LUMA_RAY_FLASH_2_540P:
            0.033
        case .REPLICATE_LUMA_RAY_FLASH_2_720P:
            0.06
        default:
            0.10
        }

        return costPerSecond * Double(durationSeconds) * Double(numberOfVideos)
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let aspectRatio = mapToLumaAspectRatio(dimension: request.dimensions)
        let duration = request.durationSeconds ?? 5

        let (startImageUrl, endImageUrl) = try await uploadStartEndImages(request: request)

        let body = LumaRay2Request(
            prompt: request.prompt ?? "",
            aspect_ratio: aspectRatio,
            duration: duration,
            loop: false,
            start_image: startImageUrl,
            end_image: endImageUrl
        )

        return try await performLumaVideoRequest(request: request, body: body)
    }
}

public final class G_REPLICATE_LUMA_RAY_2_540P: G_REPLICATE_LUMA_RAY_2_BASE {
    public init() {
        super.init(modelCode: .REPLICATE_LUMA_RAY_2_540P)
    }
}

public final class G_REPLICATE_LUMA_RAY_2_720P: G_REPLICATE_LUMA_RAY_2_BASE {
    public init() {
        super.init(modelCode: .REPLICATE_LUMA_RAY_2_720P)
    }
}

public final class G_REPLICATE_LUMA_RAY_FLASH_2_540P: G_REPLICATE_LUMA_RAY_2_BASE {
    public init() {
        super.init(modelCode: .REPLICATE_LUMA_RAY_FLASH_2_540P)
    }
}

public final class G_REPLICATE_LUMA_RAY_FLASH_2_720P: G_REPLICATE_LUMA_RAY_2_BASE {
    public init() {
        super.init(modelCode: .REPLICATE_LUMA_RAY_FLASH_2_720P)
    }
}

// MARK: - Luma Modify Video (Video-to-Video)

private struct LumaModifyVideoRequest: Codable {
    let video: String
    let prompt: String?
    let mode: String
    let first_frame: String?
}

public final class G_REPLICATE_LUMA_MODIFY_VIDEO: ReplicateLumaVideoBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_LUMA_MODIFY_VIDEO
    }

    override var maxPollingAttempts: Int {
        120
    } // Video editing needs more time

    /// Cost per million output video pixels ($0.019)
    static let costPerMillionPixels = 0.019

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        // Estimate based on typical output video sizes
        // 720p (1280x720) at 24fps for 5s: ~110M pixels → ~$2.10
        let durationSeconds = request.durationSeconds ?? 5
        let numberOfVideos = request.numberOfVideos ?? 1

        // Estimate ~22M pixels per second for 720p at 24fps
        let estimatedPixelsPerSecond = 22_000_000.0
        let totalPixels = estimatedPixelsPerSecond * Double(durationSeconds)
        let cost = (totalPixels / 1_000_000.0) * Self.costPerMillionPixels

        return cost * Double(numberOfVideos)
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        // Require source video
        guard let clientVideo = request.clientVideo else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Source video is required for Luma Modify Video"
            )
        }

        // Upload the source video
        let videoUrl: String
        do {
            videoUrl = try await ReplicateFileUploader.uploadVideo(
                base64Video: clientVideo,
                apiToken: request.providerSecret
            )
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Failed to upload source video: \(error.localizedDescription)"
            )
        }

        // Upload first frame if provided
        var firstFrameUrl: String?
        if let clientImage = request.clientImage {
            do {
                firstFrameUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
            } catch {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Failed to upload first frame: \(error.localizedDescription)"
                )
            }
        }

        let body = LumaModifyVideoRequest(
            video: videoUrl,
            prompt: request.prompt,
            mode: "adhere_1",
            first_frame: firstFrameUrl
        )

        return try await performLumaVideoRequest(request: request, body: body)
    }
}
