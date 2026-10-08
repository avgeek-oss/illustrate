// MARK: - G_REPLICATE_KLING.swift

// Implementation for Kling video models via Replicate.
// Pro-level text-to-video and image-to-video with smooth motion and cinematic depth.

import Foundation

/// Kling 2.5 Turbo Pro video generation via Replicate.
public class G_REPLICATE_KLING_2_5_TURBO_PRO: VideoGenerationProtocol {
    public init() {}
    /// Cost per second ($0.07)
    static let costPerSecond = 0.07

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        return Self.costPerSecond * duration
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_KLING_2_5_TURBO_PRO)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let negative_prompt: String?
        let start_image: String?
        let end_image: String?
        let aspect_ratio: String
        let duration: Int

        init(
            prompt: String,
            negativePrompt: String? = nil,
            startImage: String? = nil,
            endImage: String? = nil,
            aspectRatio: String = "16:9",
            duration: Int = 5
        ) {
            self.prompt = prompt
            negative_prompt = negativePrompt
            start_image = startImage
            end_image = endImage
            aspect_ratio = aspectRatio
            self.duration = duration
        }
    }

    func transformRequest(
        request: VideoGenerationRequest,
        startImageUrl: String? = nil,
        endImageUrl: String? = nil
    ) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)

        return ServiceRequest(
            prompt: request.prompt ?? "",
            negativePrompt: request.negativePrompt,
            startImage: startImageUrl,
            endImage: endImageUrl,
            aspectRatio: aspectRatio.ratio,
            duration: request.durationSeconds ?? 5
        )
    }

    /// Protocol conformance
    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, startImageUrl: nil, endImageUrl: nil)
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
                let base64 = videoData.base64EncodedString()

                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
                )
            }
            if let output = data["output"] as? [String],
               let videoUrl = output.first
            {
                let url = URL(string: videoUrl)!
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
                    errorMessage: error
                )
            }
            if let error = data["error"] as? String {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: error
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

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String],
        maxAttempts: Int = 180
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 5_000_000_000)

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

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        // Upload start image if provided
        var startImageUrl: String? = nil
        if let clientImage = request.clientImage {
            do {
                startImageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
            } catch {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Failed to upload start image: \(error.localizedDescription)"
                )
            }
        }

        // Upload end/last frame image if provided
        var endImageUrl: String? = nil
        if let clientLastFrame = request.clientLastFrame {
            do {
                endImageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientLastFrame,
                    apiToken: request.providerSecret
                )
            } catch {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Failed to upload end image: \(error.localizedDescription)"
                )
            }
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        let serviceRequest = transformRequest(
            request: request,
            startImageUrl: startImageUrl,
            endImageUrl: endImageUrl
        )

        do {
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
                return createInvalidVideoResponseError(
                    response: response,
                    modelCode: model.modelCode,
                    customMessage: "Failed to create prediction"
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidVideoStatusURLError()
            }

            let finalResponse = try await pollForResult(
                requestId: predictionId,
                url: statusUrl,
                headers: headers
            )

            return try transformResponse(request: request, response: finalResponse)
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }
}

/// Kling 2.6 video generation via Replicate with audio support.
public class G_REPLICATE_KLING_2_6: VideoGenerationProtocol {
    public init() {}
    /// Cost per second without audio ($0.07), with audio ($0.14)
    static let costPerSecondNoAudio = 0.07
    static let costPerSecondWithAudio = 0.14

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        let withAudio = request.generateAudio ?? true
        let costPerSecond = withAudio ? Self.costPerSecondWithAudio : Self.costPerSecondNoAudio
        return costPerSecond * duration
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_KLING_2_6)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let negative_prompt: String?
        let start_image: String?
        let aspect_ratio: String
        let duration: Int
        let generate_audio: Bool

        init(
            prompt: String,
            negativePrompt: String? = nil,
            startImage: String? = nil,
            aspectRatio: String = "16:9",
            duration: Int = 5,
            generateAudio: Bool = true
        ) {
            self.prompt = prompt
            negative_prompt = negativePrompt
            start_image = startImage
            aspect_ratio = aspectRatio
            self.duration = duration
            generate_audio = generateAudio
        }
    }

    func transformRequest(
        request: VideoGenerationRequest,
        startImageUrl: String? = nil
    ) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)

        return ServiceRequest(
            prompt: request.prompt ?? "",
            negativePrompt: request.negativePrompt,
            startImage: startImageUrl,
            aspectRatio: aspectRatio.ratio,
            duration: request.durationSeconds ?? 5,
            generateAudio: request.generateAudio ?? true
        )
    }

    /// Protocol conformance
    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, startImageUrl: nil)
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
                let base64 = videoData.base64EncodedString()

                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
                )
            }
            if let output = data["output"] as? [String],
               let videoUrl = output.first
            {
                let url = URL(string: videoUrl)!
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
                    errorMessage: error
                )
            }
            if let error = data["error"] as? String {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: error
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

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String],
        maxAttempts: Int = 180
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 5_000_000_000)

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

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        // Upload start image if provided
        var startImageUrl: String? = nil
        if let clientImage = request.clientImage {
            do {
                startImageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
            } catch {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Failed to upload start image: \(error.localizedDescription)"
                )
            }
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        let serviceRequest = transformRequest(
            request: request,
            startImageUrl: startImageUrl
        )

        do {
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
                return createInvalidVideoResponseError(
                    response: response,
                    modelCode: model.modelCode,
                    customMessage: "Failed to create prediction"
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidVideoStatusURLError()
            }

            let finalResponse = try await pollForResult(
                requestId: predictionId,
                url: statusUrl,
                headers: headers
            )

            return try transformResponse(request: request, response: finalResponse)
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }
}
