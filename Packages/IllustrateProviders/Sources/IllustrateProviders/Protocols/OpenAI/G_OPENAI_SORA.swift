// MARK: - G_OPENAI_SORA.swift

// Base implementation for OpenAI Sora video generation models.
//
// Handles all Sora model variants:
// - Sora 2: Standard video generation (720p)
// - Sora 2 Pro: Higher resolution support
// - Sora 2: Video extension
// - Sora 2 Pro: Pro video extension variant
//
// ## Video Generation
// Sora generates videos from text prompts or images.
// Supports variable durations.
//
// ## Video Extension
// Extension models continue existing Sora videos:
// - Requires soraVideoId from original generation
// - Stored in Generation.metadata

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Base implementation for OpenAI Sora video models.
public class G_OPENAI_SORA_BASE: VideoGenerationProtocol {
    let modelCode: EnumProviderModelCode
    let modelName: String

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    var defaultDuration: Int {
        supportedDurations.first ?? 4
    }

    static let soraVideoIdKey = "soraVideoId"

    public init(modelCode: EnumProviderModelCode, modelName: String) {
        self.modelCode = modelCode
        self.modelName = modelName
    }

    private var fallbackSupportedDurations: [Int] {
        switch modelCode {
        case .OPENAI_SORA_2_REMIX,
             .OPENAI_SORA_2_PRO_REMIX:
            [4, 8, 12, 16, 20]
        default:
            [4, 8, 12]
        }
    }

    private var fallbackSupportedDimensions: [String] {
        switch modelCode {
        case .OPENAI_SORA_2_PRO,
             .OPENAI_SORA_2_PRO_REMIX:
            ["1280x720", "720x1280", "1792x1024", "1024x1792"]
        default:
            ["1280x720", "720x1280"]
        }
    }

    private var supportedDurations: [Int] {
        guard ProviderDependencies.shared.isConfigured,
              let durations = ProviderDependencies.shared.modelProvider.model(by: modelCode)?.modelParams
              .supportedVideoDurations,
              !durations.isEmpty
        else {
            return fallbackSupportedDurations
        }

        return durations
    }

    private var supportedDimensions: [String] {
        guard ProviderDependencies.shared.isConfigured,
              let dimensions = ProviderDependencies.shared.modelProvider.model(by: modelCode)?.modelParams
              .supportedDimensions,
              !dimensions.isEmpty
        else {
            return fallbackSupportedDimensions
        }

        return dimensions
    }

    private func closestSupportedDuration(to requestedDuration: Int) -> Int {
        let durations = supportedDurations
        guard !durations.isEmpty else { return requestedDuration }
        if durations.contains(requestedDuration) { return requestedDuration }

        return durations.min {
            abs($0 - requestedDuration) == abs($1 - requestedDuration)
                ? $0 < $1
                : abs($0 - requestedDuration) < abs($1 - requestedDuration)
        } ?? defaultDuration
    }

    func effectiveDuration(_ requestedDuration: Int?) -> Int {
        let duration = requestedDuration ?? defaultDuration
        guard duration > 0 else { return defaultDuration }
        return closestSupportedDuration(to: duration)
    }

    private func effectiveDimensions(_ requestedDimensions: String) -> String {
        let dimensions = supportedDimensions
        guard !dimensions.isEmpty else { return requestedDimensions }
        if dimensions.contains(requestedDimensions) { return requestedDimensions }

        guard let requestedSize = parseDimensions(requestedDimensions) else {
            return dimensions.first ?? requestedDimensions
        }

        let isRequestedPortrait = requestedSize.height > requestedSize.width
        let matchingOrientation = dimensions.first {
            guard let size = parseDimensions($0) else { return false }
            return isRequestedPortrait ? size.height > size.width : size.width >= size.height
        }

        return matchingOrientation ?? dimensions.first ?? requestedDimensions
    }

    private func parseDimensions(_ dimensions: String) -> (width: Int, height: Int)? {
        let parts = dimensions.split(separator: "x", maxSplits: 1)
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1])
        else {
            return nil
        }

        return (width, height)
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let dimensions = request.dimensions ?? "1280x720"
        let durationSeconds = request.durationSeconds ?? defaultDuration
        let numberOfVideos = request.numberOfVideos ?? 1

        let baseCost = switch modelCode {
        case .OPENAI_SORA_2,
             .OPENAI_SORA_2_REMIX:
            0.10
        case .OPENAI_SORA_2_PRO,
             .OPENAI_SORA_2_PRO_REMIX:
            switch dimensions {
            case "1920x1080", "1080x1920":
                0.70
            case "1792x1024", "1024x1792":
                0.50
            default:
                0.30
            }
        default:
            0.10
        }
        return baseCost * Double(durationSeconds) * Double(numberOfVideos)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let model: String
        let prompt: String
        let seconds: Int
        let size: String

        public init(model: String, prompt: String, seconds: Int, size: String) {
            self.model = model
            self.prompt = prompt
            self.seconds = seconds
            self.size = size
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let duration = effectiveDuration(request.durationSeconds)
        let size = effectiveDimensions(request.dimensions)

        return ServiceRequest(
            model: modelName,
            prompt: request.prompt ?? "",
            seconds: duration,
            size: size
        )
    }

    func transformCostRequest(
        request: VideoGenerationRequest,
        serviceRequest: ServiceRequest
    ) -> VideoGenerationCostRequest {
        VideoGenerationCostRequest(
            dimensions: serviceRequest.size,
            durationSeconds: serviceRequest.seconds,
            numberOfVideos: request.numberOfVideos,
            resolution: request.resolution,
            generateAudio: request.generateAudio,
            hasReferenceImages: request.clientReferenceImages?.isEmpty == false
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        VideoGenerationResponse(
            status: .FAILED,
            errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
            errorMessage: "Use makeRequest directly for Sora models"
        )
    }

    func pollForResult(
        videoId: String,
        apiKey: String,
        progressCallback: ((Int) -> Void)? = nil,
        maxAttempts: Int = 120
    ) async throws -> [String: Any] {
        var attempts = 0

        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 5_000_000_000)

            guard let statusURL = URL(string: "https://api.openai.com/v1/videos/\(videoId)") else {
                throw NSError(domain: "Invalid status URL", code: -1, userInfo: nil)
            }

            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: statusURL,
                method: "GET",
                body: nil as String?,
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": "application/json",
                ],
                attachments: nil
            )

            switch response {
            case let .dictionary(_, data):
                if let progress = data["progress"] as? Int, progress > 0 {
                    progressCallback?(progress)
                }

                if let status = data["status"] as? String {
                    if status == "completed" {
                        progressCallback?(100)
                        return data
                    } else if status == "failed" {
                        let errorMessage = (data["error"] as? [
                            String: Any
                        ])?["message"] as? String ?? "Video generation failed"
                        throw NSError(domain: errorMessage, code: -1, userInfo: nil)
                    }
                }

                if let error = data["error"] as? [String: Any],
                   let message = error["message"] as? String
                {
                    throw NSError(domain: message, code: -1, userInfo: nil)
                }
            default:
                break
            }

            attempts += 1
        }

        throw NSError(domain: "Polling exceeded max attempts (10 minutes)", code: -1, userInfo: nil)
    }

    func downloadVideo(videoId: String, apiKey: String) async throws -> Data {
        guard let downloadURL = URL(string: "https://api.openai.com/v1/videos/\(videoId)/content") else {
            throw NSError(domain: "Invalid download URL", code: -1, userInfo: nil)
        }

        var request = URLRequest(url: downloadURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw NSError(domain: "Failed to download video from content endpoint", code: -1, userInfo: nil)
        }

        return data
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let transformedRequest = transformRequest(request: request)
        let costRequest = transformCostRequest(request: request, serviceRequest: transformedRequest)

        do {
            let headers: [String: String] = [
                "Authorization": "Bearer \(request.providerSecret)",
                "Content-Type": "multipart/form-data",
                "Accept": "application/json",
            ]

            var attachments: [NetworkRequestAttachment]? = nil
            if let clientImage = request.clientImage {
                let cleanBase64 = clientImage.replacingOccurrences(
                    of: "^data:.*;base64,",
                    with: "",
                    options: .regularExpression
                )
                if let imageData = Data(base64Encoded: cleanBase64) {
                    attachments = [
                        NetworkRequestAttachment(
                            name: "input_reference",
                            mimeType: "image/png",
                            data: imageData
                        ),
                    ]
                }
            }

            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: transformedRequest,
                headers: headers,
                attachments: attachments
            )

            var videoId: String? = nil
            var status: String? = nil

            let rawResponse = initialResponse.rawResponseString

            switch initialResponse {
            case let .dictionary(_, data):
                if let error = data["error"] as? [String: Any],
                   let message = error["message"] as? String
                {
                    return VideoGenerationResponse(
                        status: .FAILED,
                        errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                        errorMessage: message,

                        rawResponse: rawResponse
                    )
                }

                videoId = data["id"] as? String
                status = data["status"] as? String

                if status == "completed" {}
            default:
                return createInvalidVideoResponseError(
                    response: initialResponse,

                    modelCode: model.modelCode,
                    customMessage: "Unexpected response"
                )
            }

            guard let id = videoId else {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "No video ID in response",

                    rawResponse: rawResponse
                )
            }

            if status == "completed" {
                let videoData = try await downloadVideo(videoId: id, apiKey: request.providerSecret)
                let base64Video = videoData.base64EncodedString()

                let metadata = [G_OPENAI_SORA_BASE.soraVideoIdKey: id]

                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: base64Video,
                    cost: getCostEstimate(request: costRequest),
                    modelPrompt: request.prompt,

                    metadata: metadata
                )
            }

            let finalResult = try await pollForResult(
                videoId: id,
                apiKey: request.providerSecret,
                progressCallback: nil
            )

            var finalResultRawResponse: String? = nil
            if let jsonData = try? JSONSerialization.data(
                withJSONObject: finalResult,
                options: [.prettyPrinted, .sortedKeys]
            ),
                let jsonString = String(data: jsonData, encoding: .utf8)
            {
                finalResultRawResponse = jsonString
            }

            if let error = finalResult["error"] as? [String: Any],
               let message = error["message"] as? String
            {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message,

                    rawResponse: finalResultRawResponse
                )
            }

            let videoData = try await downloadVideo(videoId: id, apiKey: request.providerSecret)
            let base64Video = videoData.base64EncodedString()

            let metadata = [G_OPENAI_SORA_BASE.soraVideoIdKey: id]

            return VideoGenerationResponse(
                status: .GENERATED,
                base64: base64Video,
                cost: getCostEstimate(request: costRequest),
                modelPrompt: request.prompt,

                metadata: metadata
            )

        } catch {
            return VideoGenerationResponse(
                status: EnumGenerationStatus.FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Failed with error: \(error.localizedDescription)",
                rawResponse: "Error: \(error.localizedDescription)"
            )
        }
    }
}

public class G_OPENAI_SORA_2: G_OPENAI_SORA_BASE {
    public init() {
        super.init(modelCode: .OPENAI_SORA_2, modelName: "sora-2")
    }
}

public class G_OPENAI_SORA_2_PRO: G_OPENAI_SORA_BASE {
    public init() {
        super.init(modelCode: .OPENAI_SORA_2_PRO, modelName: "sora-2-pro")
    }
}

public class G_OPENAI_SORA_EXTENSION_BASE: G_OPENAI_SORA_BASE {
    public struct ExtensionVideo: Codable, Sendable {
        let id: String

        public init(id: String) {
            self.id = id
        }
    }

    public struct ExtensionServiceRequest: Codable, Sendable {
        let video: ExtensionVideo
        let prompt: String
        let seconds: String

        public init(video: ExtensionVideo, prompt: String, seconds: String) {
            self.video = video
            self.prompt = prompt
            self.seconds = seconds
        }
    }

    public func transformExtensionRequest(
        request: VideoGenerationRequest,
        soraVideoId: String
    ) -> ExtensionServiceRequest {
        ExtensionServiceRequest(
            video: ExtensionVideo(id: soraVideoId),
            prompt: request.prompt ?? "",
            seconds: String(effectiveDuration(request.durationSeconds))
        )
    }

    override public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let soraVideoId = request.sourceMetadata?[G_OPENAI_SORA_BASE.soraVideoIdKey], !soraVideoId.isEmpty else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "No Sora video ID provided for extension"
            )
        }

        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Invalid extension URL"
            )
        }

        let extensionRequest = transformExtensionRequest(request: request, soraVideoId: soraVideoId)

        do {
            let headers: [String: String] = [
                "Authorization": "Bearer \(request.providerSecret)",
                "Content-Type": "application/json",
                "Accept": "application/json",
            ]

            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: extensionRequest,
                headers: headers,
                attachments: nil
            )

            var videoId: String? = nil
            var status: String? = nil

            let rawResponse = initialResponse.rawResponseString

            switch initialResponse {
            case let .dictionary(_, data):
                if let error = data["error"] as? [String: Any],
                   let message = error["message"] as? String
                {
                    return VideoGenerationResponse(
                        status: .FAILED,
                        errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                        errorMessage: message,

                        rawResponse: rawResponse
                    )
                }

                videoId = data["id"] as? String
                status = data["status"] as? String
            default:
                return createInvalidVideoResponseError(
                    response: initialResponse,

                    modelCode: model.modelCode
                )
            }

            guard let id = videoId else {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "No video ID in extension response",

                    rawResponse: rawResponse
                )
            }

            if status == "completed" {
                let videoData = try await downloadVideo(videoId: id, apiKey: request.providerSecret)
                let base64Video = videoData.base64EncodedString()

                // Store the new Sora video ID in metadata so it can be extended again.
                let metadata = [G_OPENAI_SORA_BASE.soraVideoIdKey: id]

                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: base64Video,
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
                    modelPrompt: request.prompt,

                    metadata: metadata
                )
            }

            let finalResult = try await pollForResult(
                videoId: id,
                apiKey: request.providerSecret,
                progressCallback: nil
            )

            var finalResultRawResponse: String? = nil
            if let jsonData = try? JSONSerialization.data(
                withJSONObject: finalResult,
                options: [.prettyPrinted, .sortedKeys]
            ),
                let jsonString = String(data: jsonData, encoding: .utf8)
            {
                finalResultRawResponse = jsonString
            }

            if let error = finalResult["error"] as? [String: Any],
               let message = error["message"] as? String
            {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message,

                    rawResponse: finalResultRawResponse
                )
            }

            let videoData = try await downloadVideo(videoId: id, apiKey: request.providerSecret)
            let base64Video = videoData.base64EncodedString()

            // Store the new Sora video ID in metadata so it can be extended again.
            let metadata = [G_OPENAI_SORA_BASE.soraVideoIdKey: id]

            return VideoGenerationResponse(
                status: .GENERATED,
                base64: base64Video,
                cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
                modelPrompt: request.prompt,

                metadata: metadata
            )

        } catch {
            return VideoGenerationResponse(
                status: EnumGenerationStatus.FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Extension failed with error: \(error.localizedDescription)",
                rawResponse: "Error: \(error.localizedDescription)"
            )
        }
    }
}

public class G_OPENAI_SORA_2_REMIX: G_OPENAI_SORA_EXTENSION_BASE {
    public init() {
        super.init(modelCode: .OPENAI_SORA_2_REMIX, modelName: "sora-2")
    }
}

public class G_OPENAI_SORA_2_PRO_REMIX: G_OPENAI_SORA_EXTENSION_BASE {
    public init() {
        super.init(modelCode: .OPENAI_SORA_2_PRO_REMIX, modelName: "sora-2-pro")
    }
}
