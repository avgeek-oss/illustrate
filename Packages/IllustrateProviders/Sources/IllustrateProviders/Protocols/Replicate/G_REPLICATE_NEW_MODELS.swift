// MARK: - G_REPLICATE_NEW_VIDEO_MODELS.swift

// New video generation models via Replicate:
// - bytedance/seedance-2.0 (multimodal video generation with audio)
// - kwaivgi/kling-v3-omni-video (unified video generation)
// - pixverse/pixverse-v6 (multi-shot video generation)
// - google/veo-3.1-lite (cost-efficient Veo)
// - alibaba/happyhorse-1.0 (text/image-to-video)
// - runwayml/gen-4.5 (top-ranked video generation)
// - recraft-ai/recraft-v4.1 (design-focused image generation)
// - google/nano-banana-2 (fast image generation with 4K)
// - bytedance/seedream-5-lite (reasoning image generation)

import Foundation

// MARK: - Seedance 2.0

public class G_REPLICATE_SEEDANCE_2: VideoGenerationProtocol {
    public init() {}
    static let costPerSecond = 0.05

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_SEEDANCE_2)!
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        return Self.costPerSecond * duration
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let resolution: String
        let duration: Int
        let generate_audio: Bool
        let seed: Int?

        init(
            prompt: String,
            aspectRatio: String = "16:9",
            resolution: String = "720p",
            duration: Int = 5,
            generateAudio: Bool = true,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.resolution = resolution
            self.duration = duration
            generate_audio = generateAudio
            self.seed = seed
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = mapToSeedance2AspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt ?? "",
            aspectRatio: aspectRatio,
            resolution: request.resolution ?? "720p",
            duration: request.durationSeconds ?? 5,
            generateAudio: request.generateAudio ?? true,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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
            break
        }
        return createInvalidVideoResponseError(response: response, modelCode: model.modelCode)
    }

    private func mapToSeedance2AspectRatio(dimension: String) -> String {
        let aspectRatio = getAspectRatio(dimension: dimension)
        let ratio = aspectRatio.ratio
        let supported = ["16:9", "4:3", "1:1", "3:4", "9:16", "21:9"]
        return supported.contains(ratio) ? ratio : "16:9"
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
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - Kling V3 Omni

public class G_REPLICATE_KLING_V3_OMNI: VideoGenerationProtocol {
    public init() {}
    static let costPerSecond = 0.10

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_KLING_V3_OMNI)!
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        let resolution = request.resolution ?? "720p"
        let costPerSec = resolution == "1080p" ? 0.14 : Self.costPerSecond
        return costPerSec * duration
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let duration: Int
        let mode: String
        let generate_audio: Bool?
        let seed: Int?

        init(
            prompt: String,
            aspectRatio: String = "16:9",
            duration: Int = 5,
            mode: String = "standard",
            generateAudio: Bool? = nil,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.duration = duration
            self.mode = mode
            generate_audio = generateAudio
            self.seed = seed
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt ?? "",
            aspectRatio: aspectRatio.ratio,
            duration: request.durationSeconds ?? 5,
            mode: "standard",
            generateAudio: request.generateAudio,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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
            break
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
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - PixVerse V6

public class G_REPLICATE_PIXVERSE_V6: VideoGenerationProtocol {
    public init() {}
    static let costPerSecond = 0.09

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_PIXVERSE_V6)!
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        let resolution = request.resolution ?? "720p"
        let costPerSec = switch resolution {
        case "360p": 0.05
        case "540p": 0.07
        case "720p": Self.costPerSecond
        case "1080p": 0.18
        default: Self.costPerSecond
        }
        return costPerSec * duration
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let resolution: String
        let duration: Int
        let generate_audio_switch: Bool?
        let seed: Int?

        init(
            prompt: String,
            aspectRatio: String = "16:9",
            resolution: String = "720p",
            duration: Int = 5,
            generateAudio: Bool? = nil,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.resolution = resolution
            self.duration = duration
            generate_audio_switch = generateAudio
            self.seed = seed
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt ?? "",
            aspectRatio: aspectRatio.ratio,
            resolution: request.resolution ?? "720p",
            duration: request.durationSeconds ?? 5,
            generateAudio: request.generateAudio,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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
            break
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
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - Veo 3.1 Lite

public class G_REPLICATE_GOOGLE_VEO_3_1_LITE: VideoGenerationProtocol {
    public init() {}
    static let costPerSecond720p = 0.05
    static let costPerSecond1080p = 0.08

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_GOOGLE_VEO_3_1_LITE)!
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 6)
        let resolution = request.resolution ?? "720p"
        let costPerSec = resolution == "1080p" ? Self.costPerSecond1080p : Self.costPerSecond720p
        return costPerSec * duration
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let resolution: String
        let duration: Int
        let generate_audio: Bool
        let seed: Int?
        let image: String?

        init(
            prompt: String,
            aspectRatio: String = "16:9",
            resolution: String = "720p",
            duration: Int = 6,
            generateAudio: Bool = true,
            seed: Int? = nil,
            image: String? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.resolution = resolution
            self.duration = duration
            generate_audio = generateAudio
            self.seed = seed
            self.image = image
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt ?? "",
            aspectRatio: aspectRatio.ratio,
            resolution: request.resolution ?? "720p",
            duration: request.durationSeconds ?? 6,
            generateAudio: request.generateAudio ?? true,
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
            break
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
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        var imageUrl: String? = nil
        if let clientImage = request.clientImage {
            do {
                imageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
            } catch {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to upload image: \(error.localizedDescription)"
                )
            }
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let serviceRequest = ServiceRequest(
            prompt: request.prompt ?? "",
            aspectRatio: getAspectRatio(dimension: request.dimensions).ratio,
            resolution: request.resolution ?? "720p",
            duration: request.durationSeconds ?? 6,
            generateAudio: request.generateAudio ?? true,
            seed: request.seed,
            image: imageUrl
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

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - Happy Horse 1.0

public class G_REPLICATE_HAPPY_HORSE_1: VideoGenerationProtocol {
    public init() {}
    static let costPerSecond720p = 0.14
    static let costPerSecond1080p = 0.28

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_HAPPY_HORSE_1)!
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        let resolution = request.resolution ?? "720p"
        let costPerSec = resolution == "1080p" ? Self.costPerSecond1080p : Self.costPerSecond720p
        return costPerSec * duration
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let resolution: String
        let duration: Int
        let seed: Int?

        init(
            prompt: String,
            aspectRatio: String = "16:9",
            resolution: String = "720p",
            duration: Int = 5,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.resolution = resolution
            self.duration = duration
            self.seed = seed
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt ?? "",
            aspectRatio: aspectRatio.ratio,
            resolution: request.resolution ?? "720p",
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
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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
            break
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
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - Runway Gen-4.5

public class G_REPLICATE_RUNWAY_GEN_4_5: VideoGenerationProtocol {
    public init() {}
    static let costPerSecond = 0.50

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_RUNWAY_GEN_4_5)!
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        return Self.costPerSecond * duration
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let duration: Int
        let seed: Int?

        init(
            prompt: String,
            aspectRatio: String = "16:9",
            duration: Int = 5,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.duration = duration
            self.seed = seed
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt ?? "",
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
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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
            break
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
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - Recraft V4.1

public class G_REPLICATE_RECRAFT_V4_1: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.04

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_RECRAFT_V4_1)!
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let output_format: String?

        init(prompt: String, aspectRatio: String = "1:1", outputFormat: String? = nil) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            output_format = outputFormat
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt,
            aspectRatio: aspectRatio.ratio,
            outputFormat: "png"
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String]
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < 60 {
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

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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
                return createInvalidResponseError(
                    response: response,
                    modelCode: model.modelCode,
                    customMessage: "Failed to create prediction"
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - Nano Banana 2 (Replicate)

public class G_REPLICATE_GOOGLE_NANO_BANANA_2: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.04

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_GOOGLE_NANO_BANANA_2)!
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let resolution: String?
        let output_format: String?

        init(prompt: String, aspectRatio: String = "1:1", resolution: String? = nil, outputFormat: String? = nil) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.resolution = resolution
            output_format = outputFormat
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt,
            aspectRatio: aspectRatio.ratio,
            resolution: "2K",
            outputFormat: "png"
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String]
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < 60 {
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

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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
                return createInvalidResponseError(
                    response: response,
                    modelCode: model.modelCode,
                    customMessage: "Failed to create prediction"
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - Ideogram V3

public class G_REPLICATE_IDEOGRAM_V3: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.05

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_IDEOGRAM_V3)!
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let output_format: String?
        let seed: Int?

        init(prompt: String, aspectRatio: String = "1:1", outputFormat: String? = nil, seed: Int? = nil) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            output_format = outputFormat
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt,
            aspectRatio: aspectRatio.ratio,
            outputFormat: "png",
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String]
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < 60 {
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

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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
                return createInvalidResponseError(
                    response: response,
                    modelCode: model.modelCode,
                    customMessage: "Failed to create prediction"
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - Ideogram V3 Quality

public class G_REPLICATE_IDEOGRAM_V3_QUALITY: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.08

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_IDEOGRAM_V3_QUALITY)!
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let output_format: String?
        let seed: Int?

        init(prompt: String, aspectRatio: String = "1:1", outputFormat: String? = nil, seed: Int? = nil) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            output_format = outputFormat
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt,
            aspectRatio: aspectRatio.ratio,
            outputFormat: "png",
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String]
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < 60 {
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

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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
                return createInvalidResponseError(
                    response: response,
                    modelCode: model.modelCode,
                    customMessage: "Failed to create prediction"
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - Ideogram V3 Fast

public class G_REPLICATE_IDEOGRAM_V3_FAST: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.03

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_IDEOGRAM_V3_FAST)!
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let output_format: String?
        let seed: Int?

        init(prompt: String, aspectRatio: String = "1:1", outputFormat: String? = nil, seed: Int? = nil) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            output_format = outputFormat
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt,
            aspectRatio: aspectRatio.ratio,
            outputFormat: "png",
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String]
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < 60 {
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

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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
                return createInvalidResponseError(
                    response: response,
                    modelCode: model.modelCode,
                    customMessage: "Failed to create prediction"
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - Recraft V4

public class G_REPLICATE_RECRAFT_V4: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.04

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_RECRAFT_V4)!
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let output_format: String?
        let seed: Int?

        init(prompt: String, aspectRatio: String = "1:1", outputFormat: String? = nil, seed: Int? = nil) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            output_format = outputFormat
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt,
            aspectRatio: aspectRatio.ratio,
            outputFormat: "png",
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String]
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < 60 {
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

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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
                return createInvalidResponseError(
                    response: response,
                    modelCode: model.modelCode,
                    customMessage: "Failed to create prediction"
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - Recraft V4 Pro

public class G_REPLICATE_RECRAFT_V4_PRO: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.06

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_RECRAFT_V4_PRO)!
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let output_format: String?
        let seed: Int?

        init(prompt: String, aspectRatio: String = "1:1", outputFormat: String? = nil, seed: Int? = nil) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            output_format = outputFormat
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt,
            aspectRatio: aspectRatio.ratio,
            outputFormat: "png",
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String]
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < 60 {
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

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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
                return createInvalidResponseError(
                    response: response,
                    modelCode: model.modelCode,
                    customMessage: "Failed to create prediction"
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - PrunaAI P-Video

public class G_REPLICATE_PRUNA_P_VIDEO: VideoGenerationProtocol {
    public init() {}
    static let costPerSecond = 0.03

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_PRUNA_P_VIDEO)!
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        let numberOfVideos = Double(request.numberOfVideos ?? 1)
        return Self.costPerSecond * duration * numberOfVideos
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let duration: Int
        let seed: Int?

        init(
            prompt: String,
            aspectRatio: String = "16:9",
            duration: Int = 5,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.duration = duration
            self.seed = seed
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt ?? "",
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
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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
            break
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
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - WAN 2.7 T2V

private final class G_REPLICATE_WAN_2_7_T2V_LEGACY: VideoGenerationProtocol {
    init() {}
    static let costPerSecond = 0.04

    var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_WAN_2_7_T2V)!
    }

    func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        let numberOfVideos = Double(request.numberOfVideos ?? 1)
        return Self.costPerSecond * duration * numberOfVideos
    }

    func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    struct ServiceRequest: Codable {
        let prompt: String
        let aspect_ratio: String
        let duration: Int
        let seed: Int?

        init(
            prompt: String,
            aspectRatio: String = "16:9",
            duration: Int = 5,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.duration = duration
            self.seed = seed
        }
    }

    func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt ?? "",
            aspectRatio: aspectRatio.ratio,
            duration: request.durationSeconds ?? 5,
            seed: request.seed
        )
    }

    func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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
            break
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

    func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - WAN 2.7 I2V

private final class G_REPLICATE_WAN_2_7_I2V_LEGACY: VideoGenerationProtocol {
    init() {}
    static let costPerSecond = 0.04

    var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_WAN_2_7_I2V)!
    }

    func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        let numberOfVideos = Double(request.numberOfVideos ?? 1)
        return Self.costPerSecond * duration * numberOfVideos
    }

    func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    struct ServiceRequest: Codable {
        let prompt: String
        let image_url: String
        let aspect_ratio: String
        let duration: Int
        let seed: Int?

        init(
            prompt: String,
            imageUrl: String = "",
            aspectRatio: String = "16:9",
            duration: Int = 5,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            image_url = imageUrl
            aspect_ratio = aspectRatio
            self.duration = duration
            self.seed = seed
        }
    }

    func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt ?? "",
            imageUrl: "",
            aspectRatio: aspectRatio.ratio,
            duration: request.durationSeconds ?? 5,
            seed: request.seed
        )
    }

    func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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
            break
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

    func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        var imageUrl = ""
        if let clientImage = request.clientImage {
            do {
                imageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
            } catch {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to upload image: \(error.localizedDescription)"
                )
            }
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
        let serviceRequest = ServiceRequest(
            prompt: request.prompt ?? "",
            imageUrl: imageUrl,
            aspectRatio: getAspectRatio(dimension: request.dimensions).ratio,
            duration: request.durationSeconds ?? 5,
            seed: request.seed
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

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - Vidu Q3 Pro

private final class G_REPLICATE_VIDU_Q3_PRO_LEGACY: VideoGenerationProtocol {
    init() {}
    static let costPerSecond = 0.08

    var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_VIDU_Q3_PRO)!
    }

    func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        let numberOfVideos = Double(request.numberOfVideos ?? 1)
        return Self.costPerSecond * duration * numberOfVideos
    }

    func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    struct ServiceRequest: Codable {
        let prompt: String
        let aspect_ratio: String
        let duration: Int
        let resolution: String
        let seed: Int?

        init(
            prompt: String,
            aspectRatio: String = "16:9",
            duration: Int = 5,
            resolution: String = "720p",
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.duration = duration
            self.resolution = resolution
            self.seed = seed
        }
    }

    func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt ?? "",
            aspectRatio: aspectRatio.ratio,
            duration: request.durationSeconds ?? 5,
            resolution: request.resolution ?? "720p",
            seed: request.seed
        )
    }

    func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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
            break
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

    func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - Kling V3 Video

public class G_REPLICATE_KLING_V3_VIDEO: VideoGenerationProtocol {
    public init() {}
    static let costPerSecond = 0.09

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_KLING_V3_VIDEO)!
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        let numberOfVideos = Double(request.numberOfVideos ?? 1)
        return Self.costPerSecond * duration * numberOfVideos
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let duration: Int
        let generate_audio: Bool
        let seed: Int?

        init(
            prompt: String,
            aspectRatio: String = "16:9",
            duration: Int = 5,
            generateAudio: Bool = false,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.duration = duration
            generate_audio = generateAudio
            self.seed = seed
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt ?? "",
            aspectRatio: aspectRatio.ratio,
            duration: request.durationSeconds ?? 5,
            generateAudio: request.generateAudio ?? false,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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
            break
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
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - Seedance 2.0 Fast

public class G_REPLICATE_SEEDANCE_2_FAST: VideoGenerationProtocol {
    public init() {}
    static let costPerSecond = 0.03

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_SEEDANCE_2_FAST)!
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        let numberOfVideos = Double(request.numberOfVideos ?? 1)
        return Self.costPerSecond * duration * numberOfVideos
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let resolution: String
        let duration: Int
        let generate_audio: Bool
        let seed: Int?

        init(
            prompt: String,
            aspectRatio: String = "16:9",
            resolution: String = "720p",
            duration: Int = 5,
            generateAudio: Bool = true,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.resolution = resolution
            self.duration = duration
            generate_audio = generateAudio
            self.seed = seed
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt ?? "",
            aspectRatio: aspectRatio.ratio,
            resolution: request.resolution ?? "720p",
            duration: request.durationSeconds ?? 5,
            generateAudio: request.generateAudio ?? true,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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
            break
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
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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

// MARK: - PixVerse V5.6

public class G_REPLICATE_PIXVERSE_V5_6: VideoGenerationProtocol {
    public init() {}
    static let costPerSecond = 0.07

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_PIXVERSE_V5_6)!
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 5)
        let numberOfVideos = Double(request.numberOfVideos ?? 1)
        return Self.costPerSecond * duration * numberOfVideos
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String
        let duration: Int
        let resolution: String
        let seed: Int?

        init(
            prompt: String,
            aspectRatio: String = "16:9",
            duration: Int = 5,
            resolution: String = "720p",
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.duration = duration
            self.resolution = resolution
            self.seed = seed
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt ?? "",
            aspectRatio: aspectRatio.ratio,
            duration: request.durationSeconds ?? 5,
            resolution: request.resolution ?? "720p",
            seed: request.seed
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? String {
                let url = URL(string: output)!
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
            break
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
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]
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

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
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
