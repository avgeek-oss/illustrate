// MARK: - G_REPLICATE_HAILUO.swift

// MiniMax Hailuo video models via Replicate:
// - minimax/hailuo-02 (text/image-to-video with first/last frame)
// - minimax/hailuo-02-fast (fast version, 512p only)
// - minimax/hailuo-2.3 (text/image-to-video, first frame only)
// - minimax/hailuo-2.3-fast (fast version)

import Foundation

// MARK: - Base Class

public class ReplicateHailuoVideoBase: VideoGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override modelCode")
    }

    var supportsLastFrame: Bool {
        false
    }

    var defaultResolution: String {
        "768p"
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
        headers: [String: String],
        maxAttempts: Int = 90
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < maxAttempts {
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

    func performHailuoRequest(
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

    func uploadFirstFrameImage(request: VideoGenerationRequest) async throws -> String? {
        guard let clientImage = request.clientImage else { return nil }
        return try await ReplicateFileUploader.uploadImage(
            base64Image: clientImage,
            apiToken: request.providerSecret
        )
    }
}

// MARK: - Hailuo 02 (with first + last frame support)

private struct Hailuo02Request: Codable {
    let prompt: String
    let duration: Int
    let resolution: String
    let prompt_optimizer: Bool
    let first_frame_image: String?
    let last_frame_image: String?
}

public class G_REPLICATE_HAILUO_BASE: ReplicateHailuoVideoBase {
    private let _modelCode: EnumProviderModelCode

    override var modelCode: EnumProviderModelCode {
        _modelCode
    }

    override var supportsLastFrame: Bool {
        true
    }

    override var defaultResolution: String {
        "1080p"
    }

    public init(modelCode: EnumProviderModelCode) {
        _modelCode = modelCode
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let resolution = request.resolution ?? "1080p"
        let durationSeconds = request.durationSeconds ?? 6
        let numberOfVideos = request.numberOfVideos ?? 1

        let baseCost: Double = if _modelCode == .REPLICATE_HAILUO_02_FAST {
            // Fast version only supports 512p
            durationSeconds == 10 ? 0.15 : 0.10
        } else {
            // Standard version
            switch resolution {
            case "512p":
                durationSeconds == 10 ? 0.15 : 0.10
            case "768p":
                durationSeconds == 10 ? 0.45 : 0.27
            case "1080p":
                0.48 // 1080p only supports 6s
            default:
                0.48
            }
        }

        return baseCost * Double(numberOfVideos)
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let duration = request.durationSeconds ?? 6
        let resolution = request.resolution ?? "1080p"

        var firstFrameUrl: String?
        var lastFrameUrl: String?

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

        if let clientLastFrame = request.clientLastFrame {
            do {
                lastFrameUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientLastFrame,
                    apiToken: request.providerSecret
                )
            } catch {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Failed to upload last frame: \(error.localizedDescription)"
                )
            }
        }

        let body = Hailuo02Request(
            prompt: request.prompt ?? "",
            duration: duration,
            resolution: resolution,
            prompt_optimizer: request.promptEnhance ?? true,
            first_frame_image: firstFrameUrl,
            last_frame_image: lastFrameUrl
        )

        return try await performHailuoRequest(request: request, body: body)
    }
}

public final class G_REPLICATE_HAILUO_02: G_REPLICATE_HAILUO_BASE {
    public init() {
        super.init(modelCode: .REPLICATE_HAILUO_02)
    }
}

public final class G_REPLICATE_HAILUO_02_FAST: G_REPLICATE_HAILUO_BASE {
    public init() {
        super.init(modelCode: .REPLICATE_HAILUO_02_FAST)
    }
}

// MARK: - Hailuo 2.3 (first frame only, no 512p)

private struct Hailuo23Request: Codable {
    let prompt: String
    let duration: Int
    let resolution: String
    let prompt_optimizer: Bool
    let first_frame_image: String?
}

public class G_REPLICATE_HAILUO_2_3_BASE: ReplicateHailuoVideoBase {
    private let _modelCode: EnumProviderModelCode

    override var modelCode: EnumProviderModelCode {
        _modelCode
    }

    override var defaultResolution: String {
        "768p"
    }

    public init(modelCode: EnumProviderModelCode) {
        _modelCode = modelCode
    }

    override public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let resolution = request.resolution ?? "768p"
        let durationSeconds = request.durationSeconds ?? 6
        let numberOfVideos = request.numberOfVideos ?? 1

        let baseCost: Double = if _modelCode == .REPLICATE_HAILUO_2_3_FAST {
            // Fast version pricing
            switch resolution {
            case "768p":
                durationSeconds == 10 ? 0.32 : 0.19
            case "1080p":
                0.33 // 1080p only supports 6s
            default:
                0.19
            }
        } else {
            // Standard version pricing
            switch resolution {
            case "768p":
                durationSeconds == 10 ? 0.56 : 0.28
            case "1080p":
                0.49 // 1080p only supports 6s
            default:
                0.28
            }
        }

        return baseCost * Double(numberOfVideos)
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let duration = request.durationSeconds ?? 6
        let resolution = request.resolution ?? "768p"

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

        let body = Hailuo23Request(
            prompt: request.prompt ?? "",
            duration: duration,
            resolution: resolution,
            prompt_optimizer: request.promptEnhance ?? true,
            first_frame_image: firstFrameUrl
        )

        return try await performHailuoRequest(request: request, body: body)
    }
}

public final class G_REPLICATE_HAILUO_2_3: G_REPLICATE_HAILUO_2_3_BASE {
    public init() {
        super.init(modelCode: .REPLICATE_HAILUO_2_3)
    }
}

public final class G_REPLICATE_HAILUO_2_3_FAST: G_REPLICATE_HAILUO_2_3_BASE {
    public init() {
        super.init(modelCode: .REPLICATE_HAILUO_2_3_FAST)
    }
}
