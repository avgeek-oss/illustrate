// MARK: - G_REPLICATE_XAI.swift

// xAI Grok models via Replicate:
// - xai/grok-imagine-image (text-to-image, fast)
// - xai/grok-imagine-image-quality (text-to-image, quality)
// - xai/grok-imagine-video (text-to-video / image-to-video with audio)

import Foundation

// MARK: - Grok Imagine Image (Standard)

public class G_REPLICATE_XAI_GROK_IMAGINE_IMAGE: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.03

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_XAI_GROK_IMAGINE_IMAGE)!
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
        let aspect_ratio: String?
        let resolution: String?
        let output_format: String?

        init(prompt: String, aspectRatio: String? = nil, resolution: String? = nil, outputFormat: String? = nil) {
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
            resolution: "1k",
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

// MARK: - Grok Imagine Image Quality

public class G_REPLICATE_XAI_GROK_IMAGINE_IMAGE_QUALITY: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.05

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_XAI_GROK_IMAGINE_IMAGE_QUALITY)!
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let resolution = request.quality ?? "1k"
        let cost = resolution == "2k" ? 0.07 : Self.baseCost
        return cost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String?
        let resolution: String?
        let output_format: String?

        init(prompt: String, aspectRatio: String? = nil, resolution: String? = nil, outputFormat: String? = nil) {
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
            resolution: "2k",
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
        while attempts < 90 {
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

// MARK: - Grok Imagine Video

public class G_REPLICATE_XAI_GROK_IMAGINE_VIDEO: VideoGenerationProtocol {
    public init() {}
    static let costPerSecond = 0.10

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_XAI_GROK_IMAGINE_VIDEO)!
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

        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let serviceRequest = ServiceRequest(
            prompt: request.prompt ?? "",
            aspectRatio: imageUrl != nil ? aspectRatio.ratio : aspectRatio.ratio,
            resolution: request.resolution ?? "720p",
            duration: request.durationSeconds ?? 5,
            generateAudio: request.generateAudio ?? true,
            seed: request.seed
        )

        let headers = ["Authorization": "Bearer \(request.providerSecret)", "Content-Type": "application/json"]

        do {
            var body: [String: Any] = ["input": serviceRequest]
            if let imageUrl {
                body["input"] = serviceRequest
            }

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
