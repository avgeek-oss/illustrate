// MARK: - G_REPLICATE_WAN.swift

// Implementation for Wan video models via Replicate.
// Text-to-video and image-to-video with audio synchronization support.

import Foundation

/// Wan 2.6 Image-to-Video via Replicate.
public class G_REPLICATE_WAN_2_6_I2V: VideoGenerationProtocol {
    public init() {}
    /// Cost per second without audio ($0.10), with audio ($0.15)
    static let costPerSecondNoAudio = 0.10
    static let costPerSecondWithAudio = 0.15

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        let withAudio = request.generateAudio ?? false
        let costPerSecond = withAudio ? Self.costPerSecondWithAudio : Self.costPerSecondNoAudio
        return costPerSecond * duration
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_WAN_2_6_I2V)!

    public struct ServiceRequest: Codable, Sendable {
        let image: String
        let prompt: String
        let negative_prompt: String?
        let resolution: String
        let duration: Int
        let enable_prompt_expansion: Bool
        let seed: Int?

        init(
            image: String,
            prompt: String,
            negativePrompt: String? = nil,
            resolution: String = "720p",
            duration: Int = 5,
            enablePromptExpansion: Bool = true,
            seed: Int? = nil
        ) {
            self.image = image
            self.prompt = prompt
            negative_prompt = negativePrompt
            self.resolution = resolution
            self.duration = duration
            enable_prompt_expansion = enablePromptExpansion
            self.seed = seed
        }
    }

    func transformRequest(
        request: VideoGenerationRequest,
        imageUrl: String
    ) -> ServiceRequest {
        // Map resolution from request
        let resolution = request.resolution ?? "720p"

        return ServiceRequest(
            image: imageUrl,
            prompt: request.prompt ?? "",
            negativePrompt: request.negativePrompt,
            resolution: resolution,
            duration: request.durationSeconds ?? 5,
            enablePromptExpansion: request.promptEnhance ?? true,
            seed: request.seed
        )
    }

    /// Protocol conformance - not used directly for i2v
    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        ServiceRequest(image: "", prompt: request.prompt ?? "")
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

        // Image is required for i2v
        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Image is required for Wan I2V"
            )
        }

        // Upload image
        var imageUrl: String
        do {
            imageUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Failed to upload image: \(error.localizedDescription)"
            )
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        let serviceRequest = transformRequest(request: request, imageUrl: imageUrl)

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

/// Wan 2.6 Text-to-Video via Replicate.
public class G_REPLICATE_WAN_2_6_T2V: VideoGenerationProtocol {
    public init() {}
    /// Cost per second without audio ($0.10), with audio ($0.15)
    static let costPerSecondNoAudio = 0.10
    static let costPerSecondWithAudio = 0.15

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        let withAudio = request.generateAudio ?? false
        let costPerSecond = withAudio ? Self.costPerSecondWithAudio : Self.costPerSecondNoAudio
        return costPerSecond * duration
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_WAN_2_6_T2V)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let negative_prompt: String?
        let size: String
        let duration: Int
        let enable_prompt_expansion: Bool
        let seed: Int?

        init(
            prompt: String,
            negativePrompt: String? = nil,
            size: String = "1280*720",
            duration: Int = 5,
            enablePromptExpansion: Bool = true,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            negative_prompt = negativePrompt
            self.size = size
            self.duration = duration
            enable_prompt_expansion = enablePromptExpansion
            self.seed = seed
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        // Map aspect ratio to size
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let resolution = request.resolution ?? "720p"

        let size: String = if aspectRatio.ratio == "9:16" {
            resolution == "1080p" ? "1080*1920" : "720*1280"
        } else {
            // Default to 16:9
            resolution == "1080p" ? "1920*1080" : "1280*720"
        }

        return ServiceRequest(
            prompt: request.prompt ?? "",
            negativePrompt: request.negativePrompt,
            size: size,
            duration: request.durationSeconds ?? 5,
            enablePromptExpansion: request.promptEnhance ?? true,
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

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        let serviceRequest = transformRequest(request: request)

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

// MARK: - Wan 2.5 Models

/// Wan 2.5 Image-to-Video via Replicate - resolution-based pricing.
public class G_REPLICATE_WAN_2_5_I2V: VideoGenerationProtocol {
    public init() {}
    /// Cost based on resolution: 480p $0.05, 720p $0.10, 1080p $0.15
    static func costForResolution(_ resolution: String?) -> Double {
        switch resolution {
        case "480p": 0.05
        case "1080p": 0.15
        default: 0.10 // 720p default
        }
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        Self.costForResolution(request.resolution)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_WAN_2_5_I2V)!

    public struct ServiceRequest: Codable, Sendable {
        let image: String
        let prompt: String
        let negative_prompt: String?
        let resolution: String
        let seed: Int?

        init(
            image: String,
            prompt: String,
            negativePrompt: String? = nil,
            resolution: String = "720p",
            seed: Int? = nil
        ) {
            self.image = image
            self.prompt = prompt
            negative_prompt = negativePrompt
            self.resolution = resolution
            self.seed = seed
        }
    }

    func transformRequest(
        request: VideoGenerationRequest,
        imageUrl: String
    ) -> ServiceRequest {
        ServiceRequest(
            image: imageUrl,
            prompt: request.prompt ?? "",
            negativePrompt: request.negativePrompt,
            resolution: request.resolution ?? "720p",
            seed: request.seed
        )
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        ServiceRequest(image: "", prompt: request.prompt ?? "")
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
            if let output = data["output"] as? [String], let videoUrl = output.first {
                let url = URL(string: videoUrl)!
                let videoData = try Data(contentsOf: url)
                let base64 = videoData.base64EncodedString()

                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
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
            return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
        }
        return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
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

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Image required")
        }

        let imageUrl = try await ReplicateFileUploader.uploadImage(
            base64Image: clientImage,
            apiToken: request.providerSecret
        )
        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let serviceRequest = transformRequest(request: request, imageUrl: imageUrl)

        let response = try await ProviderDependencies.shared.networkProvider.performRequest(
            url: url, method: "POST", body: ["input": serviceRequest], headers: headers, attachments: nil
        )

        guard case let .dictionary(_, data) = response, let predictionId = data["id"] as? String else {
            return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
        }

        guard let statusUrl = model.statusURL else {
            return createInvalidVideoStatusURLError()
        }

        let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
        return try transformResponse(request: request, response: finalResponse)
    }
}

/// Wan 2.5 Text-to-Video via Replicate - resolution-based pricing.
public class G_REPLICATE_WAN_2_5_T2V: VideoGenerationProtocol {
    public init() {}
    /// Cost based on resolution: 480p $0.05, 720p $0.10, 1080p $0.15
    static func costForResolution(_ resolution: String?) -> Double {
        switch resolution {
        case "480p": 0.05
        case "1080p": 0.15
        default: 0.10
        }
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        Self.costForResolution(request.resolution)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_WAN_2_5_T2V)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let negative_prompt: String?
        let size: String
        let seed: Int?

        init(
            prompt: String,
            negativePrompt: String? = nil,
            size: String = "1280*720",
            seed: Int? = nil
        ) {
            self.prompt = prompt
            negative_prompt = negativePrompt
            self.size = size
            self.seed = seed
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let resolution = request.resolution ?? "720p"

        let size = if aspectRatio.ratio == "9:16" {
            switch resolution {
            case "480p": "480*854"
            case "1080p": "1080*1920"
            default: "720*1280"
            }
        } else {
            switch resolution {
            case "480p": "854*480"
            case "1080p": "1920*1080"
            default: "1280*720"
            }
        }

        return ServiceRequest(
            prompt: request.prompt ?? "",
            negativePrompt: request.negativePrompt,
            size: size,
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
                let base64 = videoData.base64EncodedString()

                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
                )
            }
            if let output = data["output"] as? [String], let videoUrl = output.first {
                let url = URL(string: videoUrl)!
                let videoData = try Data(contentsOf: url)
                let base64 = videoData.base64EncodedString()

                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
                )
            }
            if let error = data["error"] as? String {
                return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
            }
        default:
            return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
        }
        return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
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

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let serviceRequest = transformRequest(request: request)

        let response = try await ProviderDependencies.shared.networkProvider.performRequest(
            url: url, method: "POST", body: ["input": serviceRequest], headers: headers, attachments: nil
        )

        guard case let .dictionary(_, data) = response, let predictionId = data["id"] as? String else {
            return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
        }

        guard let statusUrl = model.statusURL else {
            return createInvalidVideoStatusURLError()
        }

        let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
        return try transformResponse(request: request, response: finalResponse)
    }
}

/// Wan 2.5 Image-to-Video Fast via Replicate - audio-based pricing.
public class G_REPLICATE_WAN_2_5_I2V_FAST: VideoGenerationProtocol {
    public init() {}
    /// Cost: $0.068 without audio, $0.102 with audio
    static let costNoAudio = 0.068
    static let costWithAudio = 0.102

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let withAudio = request.generateAudio ?? false
        return withAudio ? Self.costWithAudio : Self.costNoAudio
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_WAN_2_5_I2V_FAST)!

    public struct ServiceRequest: Codable, Sendable {
        let image: String
        let prompt: String
        let negative_prompt: String?
        let seed: Int?

        public init(image: String, prompt: String, negativePrompt: String? = nil, seed: Int? = nil) {
            self.image = image
            self.prompt = prompt
            negative_prompt = negativePrompt
            self.seed = seed
        }
    }

    func transformRequest(request: VideoGenerationRequest, imageUrl: String) -> ServiceRequest {
        ServiceRequest(
            image: imageUrl,
            prompt: request.prompt ?? "",
            negativePrompt: request.negativePrompt,
            seed: request.seed
        )
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        ServiceRequest(image: "", prompt: request.prompt ?? "")
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
            if let output = data["output"] as? [String], let videoUrl = output.first {
                let url = URL(string: videoUrl)!
                let videoData = try Data(contentsOf: url)
                let base64 = videoData.base64EncodedString()
                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
                )
            }
            if let error = data["error"] as? String {
                return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
            }
        default:
            return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
        }
        return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
    }

    func pollForResult(
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

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        guard let clientImage = request.clientImage else {
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Image required")
        }

        let imageUrl = try await ReplicateFileUploader.uploadImage(
            base64Image: clientImage,
            apiToken: request.providerSecret
        )
        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let serviceRequest = transformRequest(request: request, imageUrl: imageUrl)

        let response = try await ProviderDependencies.shared.networkProvider.performRequest(
            url: url, method: "POST", body: ["input": serviceRequest], headers: headers, attachments: nil
        )

        guard case let .dictionary(_, data) = response, let predictionId = data["id"] as? String else {
            return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
        }

        guard let statusUrl = model.statusURL else {
            return createInvalidVideoStatusURLError()
        }

        let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
        return try transformResponse(request: request, response: finalResponse)
    }
}

/// Wan 2.5 Text-to-Video Fast via Replicate - audio-based pricing.
public class G_REPLICATE_WAN_2_5_T2V_FAST: VideoGenerationProtocol {
    public init() {}
    /// Cost: $0.068 without audio, $0.102 with audio
    static let costNoAudio = 0.068
    static let costWithAudio = 0.102

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let withAudio = request.generateAudio ?? false
        return withAudio ? Self.costWithAudio : Self.costNoAudio
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .REPLICATE_WAN_2_5_T2V_FAST)!

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let negative_prompt: String?
        let size: String
        let seed: Int?

        public init(prompt: String, negativePrompt: String? = nil, size: String = "1280*720", seed: Int? = nil) {
            self.prompt = prompt
            negative_prompt = negativePrompt
            self.size = size
            self.seed = seed
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let size = aspectRatio.ratio == "9:16" ? "720*1280" : "1280*720"

        return ServiceRequest(
            prompt: request.prompt ?? "",
            negativePrompt: request.negativePrompt,
            size: size,
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
                let base64 = videoData.base64EncodedString()
                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
                )
            }
            if let output = data["output"] as? [String], let videoUrl = output.first {
                let url = URL(string: videoUrl)!
                let videoData = try Data(contentsOf: url)
                let base64 = videoData.base64EncodedString()
                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
                )
            }
            if let error = data["error"] as? String {
                return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
            }
        default:
            return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
        }
        return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
    }

    func pollForResult(
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

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let serviceRequest = transformRequest(request: request)

        let response = try await ProviderDependencies.shared.networkProvider.performRequest(
            url: url, method: "POST", body: ["input": serviceRequest], headers: headers, attachments: nil
        )

        guard case let .dictionary(_, data) = response, let predictionId = data["id"] as? String else {
            return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
        }

        guard let statusUrl = model.statusURL else {
            return createInvalidVideoStatusURLError()
        }

        let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
        return try transformResponse(request: request, response: finalResponse)
    }
}
