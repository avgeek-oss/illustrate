// MARK: - G_GOOGLE_VEO.swift

// Base implementation for Google Veo video generation models.
//
// Handles all Veo model variants:
// - Veo 2: Standard video generation
// - Veo 3/3.1: Improved quality
// - Veo 3.1 Fast: Faster generation
// - Veo 3.1 Extend: Video extension
//
// ## Async Architecture
// Veo uses async operations with status polling:
// 1. Submit generation request -> Get operation name
// 2. Poll status endpoint until complete
// 3. Fetch result video from response
//
// ## Video Extension
// Extension models require veoGeneratedUri from original generation.
// This is stored in Generation.metadata.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Base implementation for Google Veo video models.
public class G_GOOGLE_VEO_BASE: VideoGenerationProtocol {
    let modelCode: EnumProviderModelCode

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    var supportsAudio: Bool {
        model.modelParams.supportsAudio
    }

    var defaultDuration: Int {
        model.modelParams.supportedVideoDurations.last ?? 8
    }

    private func clampDuration(_ duration: Int) -> Int {
        let supported = model.modelParams.supportedVideoDurations
        if supported.isEmpty { return duration }
        if supported.contains(duration) { return duration }
        return supported.min(by: { abs($0 - duration) < abs($1 - duration) }) ?? supported.last!
    }

    private func clampResolution(_ resolution: String) -> String {
        let supported = model.modelParams.supportedVideoResolutions
        let canonicalResolution = canonicalizeResolution(resolution)
        if supported.isEmpty { return canonicalResolution }

        if let matchingResolution = supported.first(where: { canonicalizeResolution($0) == canonicalResolution }) {
            return matchingResolution
        }

        return supported.first ?? resolution
    }

    private func canonicalizeResolution(_ resolution: String) -> String {
        resolution.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func resolvedResolution(dimensions: String?, requestedResolution: String?) -> String? {
        convertToResolution(dimensions ?? "", requestedResolution: requestedResolution)
            .map { clampResolution($0) }
    }

    private func requiresEightSecondDuration(resolution: String?, hasReferenceImages: Bool) -> Bool {
        if requiresVeoGeneratedUri || hasReferenceImages {
            return true
        }

        let canonicalResolution = resolution.map(canonicalizeResolution)
        return canonicalResolution == "1080p" || canonicalResolution == "4k"
    }

    private func effectiveDuration(
        requestedDuration: Int?,
        resolution: String?,
        hasReferenceImages: Bool = false
    ) -> Int {
        let clampedDuration = clampDuration(requestedDuration ?? defaultDuration)
        if clampedDuration == 0 { return 0 }
        if requiresEightSecondDuration(resolution: resolution, hasReferenceImages: hasReferenceImages) {
            return 8
        }
        return clampedDuration
    }

    private func effectiveCostDuration(
        requestedDuration: Int?,
        resolution: String?,
        hasReferenceImages: Bool
    ) -> Int {
        let duration = requestedDuration ?? defaultDuration
        if duration == 0 { return 0 }
        if requiresEightSecondDuration(resolution: resolution, hasReferenceImages: hasReferenceImages) {
            return 8
        }
        return duration
    }

    var requiresVeoGeneratedUri: Bool {
        model.modelParams.requiredMetadata.contains(G_GOOGLE_VEO_BASE.veoGeneratedUriKey)
    }

    public init(modelCode: EnumProviderModelCode) {
        self.modelCode = modelCode
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let resolution: String? = resolvedResolution(
            dimensions: request.dimensions,
            requestedResolution: request.resolution
        )
        let durationSeconds: Int = effectiveCostDuration(
            requestedDuration: request.durationSeconds,
            resolution: resolution,
            hasReferenceImages: request.hasReferenceImages
        )
        let numberOfVideos: Int = request.numberOfVideos ?? 1
        let canonicalResolution: String = canonicalizeResolution(resolution ?? "720p")

        let costPerSecond = switch modelCode {
        case .GOOGLE_VEO_31,
             .GOOGLE_VEO_3:
            canonicalResolution == "4k" ? 0.60 : 0.40
        case .GOOGLE_VEO_31_EXTEND:
            0.40
        case .GOOGLE_VEO_31_FAST,
             .GOOGLE_VEO_3_FAST:
            switch canonicalResolution {
            case "4k":
                0.30
            case "1080p":
                0.12
            default:
                0.10
            }
        case .GOOGLE_VEO_31_FAST_EXTEND:
            0.10
        case .GOOGLE_VEO_31_LITE:
            canonicalResolution == "1080p" ? 0.08 : 0.05
        case .GOOGLE_VEO_2:
            0.35
        default:
            0.40
        }

        return costPerSecond * Double(durationSeconds) * Double(numberOfVideos)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost: Double = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    struct ImageObject: Codable {
        var bytesBase64Encoded: String?
        var mimeType: String

        init(base64: String, mimeType: String = "image/png") {
            bytesBase64Encoded = base64
            self.mimeType = mimeType
        }
    }

    struct VideoObject: Codable {
        var uri: String

        init(uri: String) {
            self.uri = uri
        }
    }

    struct ReferenceImageObject: Codable {
        var image: ImageObject
        var referenceType: String

        init(image: ImageObject, referenceType: String) {
            self.image = image
            self.referenceType = referenceType
        }
    }

    struct ProcessedReferenceImage {
        var base64Image: String
        var mimeType: String
        var referenceType: String
    }

    static let veoGeneratedUriKey = "veoGeneratedUri"

    struct Instance: Codable {
        var prompt: String
        var image: ImageObject?
        var lastFrame: ImageObject?
        var video: VideoObject?
        var referenceImages: [ReferenceImageObject]?

        init(
            prompt: String,
            image: ImageObject? = nil,
            lastFrame: ImageObject? = nil,
            video: VideoObject? = nil,
            referenceImages: [ReferenceImageObject]? = nil
        ) {
            self.prompt = prompt
            self.image = image
            self.lastFrame = lastFrame
            self.video = video
            self.referenceImages = referenceImages
        }
    }

    struct Parameters: Codable {
        var aspectRatio: String?
        var durationSeconds: Int?
        var negativePrompt: String?
        var generateAudio: Bool?
        var resolution: String?

        init(
            aspectRatio: String? = nil,
            durationSeconds: Int? = nil,
            negativePrompt: String? = nil,
            generateAudio: Bool? = nil,
            resolution: String? = nil
        ) {
            self.aspectRatio = aspectRatio
            self.durationSeconds = durationSeconds
            self.negativePrompt = negativePrompt
            self.generateAudio = generateAudio
            self.resolution = resolution
        }
    }

    public struct ServiceRequest: Codable, Sendable {
        var instances: [Instance]
        var parameters: Parameters?

        init(instance: Instance, parameters: Parameters? = nil) {
            instances = [instance]
            self.parameters = parameters
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        buildServiceRequest(request: request, processedReferenceImages: nil)
    }

    private func buildServiceRequest(
        request: VideoGenerationRequest,
        processedReferenceImages: [ProcessedReferenceImage]?
    ) -> ServiceRequest {
        let aspectRatio: String = convertToAspectRatio(request.dimensions)
        let rawDuration: Int = request.durationSeconds ?? defaultDuration
        let rawResolution: String? = convertToResolution(request.dimensions, requestedResolution: request.resolution)
        let resolution: String? = rawResolution.map { clampResolution($0) }
        let hasReferenceImages: Bool = processedReferenceImages?.isEmpty == false
            || request.clientReferenceImages?.isEmpty == false
        let duration: Int = effectiveDuration(
            requestedDuration: rawDuration,
            resolution: resolution,
            hasReferenceImages: hasReferenceImages
        )

        var imageObj: ImageObject? = nil
        if let clientImage: String = request.clientImage {
            let cleanBase64: String = clientImage.replacingOccurrences(
                of: "^data:.*;base64,",
                with: "",
                options: .regularExpression
            )
            imageObj = ImageObject(base64: cleanBase64)
        }

        var lastFrameObj: ImageObject? = nil
        if let lastFrame: String = request.clientLastFrame {
            let cleanBase64: String = lastFrame.replacingOccurrences(
                of: "^data:.*;base64,",
                with: "",
                options: .regularExpression
            )
            lastFrameObj = ImageObject(base64: cleanBase64)
        }

        var videoObj: VideoObject? = nil
        if let veoUri: String = request.sourceMetadata?[G_GOOGLE_VEO_BASE.veoGeneratedUriKey], !veoUri.isEmpty {
            videoObj = VideoObject(uri: veoUri)
        }

        var referenceImagesObj: [ReferenceImageObject]? = nil
        if let processedRefs: [G_GOOGLE_VEO_BASE.ProcessedReferenceImage] = processedReferenceImages,
           !processedRefs.isEmpty
        {
            referenceImagesObj = processedRefs.map { ref in
                ReferenceImageObject(
                    image: ImageObject(base64: ref.base64Image, mimeType: ref.mimeType),
                    referenceType: ref.referenceType
                )
            }
        }

        let instance: G_GOOGLE_VEO_BASE.Instance = Instance(
            prompt: request.prompt ?? "",
            image: imageObj,
            lastFrame: lastFrameObj,
            video: videoObj,
            referenceImages: referenceImagesObj
        )

        let parameters: G_GOOGLE_VEO_BASE.Parameters = Parameters(
            aspectRatio: aspectRatio,
            durationSeconds: duration,
            negativePrompt: model.modelParams.supportsNegativePrompt ? request.negativePrompt : nil,
            generateAudio: nil,
            resolution: resolution
        )

        return ServiceRequest(instance: instance, parameters: parameters)
    }

    func processReferenceImages(
        _ clientReferenceImages: [ReferenceImageData]
    ) -> [ProcessedReferenceImage] {
        clientReferenceImages.map { refImage in
            let cleanBase64: String = refImage.base64Image.replacingOccurrences(
                of: "^data:.*;base64,",
                with: "",
                options: .regularExpression
            )
            return ProcessedReferenceImage(
                base64Image: cleanBase64,
                mimeType: refImage.mimeType,
                referenceType: refImage.referenceType
            )
        }
    }

    private func convertToResolution(_ dimensions: String, requestedResolution: String?) -> String? {
        if let resolution = requestedResolution, !resolution.isEmpty {
            return canonicalizeResolution(resolution)
        }

        if dimensions.contains(":") {
            return "720p"
        }

        let parts: [String.SubSequence] = dimensions.lowercased().split(separator: "x")
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1])
        else {
            return "720p"
        }

        let maxDim: Int = max(width, height)
        if maxDim >= 1080 {
            return "1080p"
        }
        return "720p"
    }

    func pollForResult(
        operationName: String,
        baseURL: String,
        apiKey: String,
        maxAttempts: Int = 60
    ) async throws -> [String: Any] {
        var attempts = 0

        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 10_000_000_000)

            guard let statusURL = URL(string: "\(baseURL)/\(operationName)") else {
                throw NSError(domain: "Invalid status URL", code: -1, userInfo: nil)
            }

            let response: NetworkResponseData = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: statusURL,
                method: "GET",
                body: nil as String?,
                headers: [
                    "Content-Type": "application/json",
                    "x-goog-api-key": apiKey,
                ],
                attachments: nil
            )

            switch response {
            case let .dictionary(_, data):
                if let done: Bool = data["done"] as? Bool, done {
                    return data
                }

                if let error: [String: Any] = data["error"] as? [String: Any],
                   let message: String = error["message"] as? String
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

    func downloadVideo(uri: String, apiKey: String) async throws -> Data {
        guard let downloadURL = URL(string: uri) else {
            throw NSError(domain: "Invalid download URL", code: -1, userInfo: nil)
        }

        var request = URLRequest(url: downloadURL)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw NSError(domain: "Failed to download video", code: -1, userInfo: nil)
        }

        return data
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        VideoGenerationResponse(
            status: .FAILED,
            errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
            errorMessage: "Use makeRequest directly for Veo models"
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        if requiresVeoGeneratedUri {
            let uri: String? = request.sourceMetadata?[G_GOOGLE_VEO_BASE.veoGeneratedUriKey]
            if uri == nil || uri?.isEmpty == true {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Video extension requires a previously generated Veo video URI (veoGeneratedUri)."
                )
            }
        }

        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        var processedReferenceImages: [ProcessedReferenceImage]? = nil
        if let clientReferenceImages: [ReferenceImageData] = request.clientReferenceImages,
           !clientReferenceImages.isEmpty
        {
            processedReferenceImages = processReferenceImages(clientReferenceImages)
        }

        let transformedRequest: G_GOOGLE_VEO_BASE.ServiceRequest = buildServiceRequest(
            request: request,
            processedReferenceImages: processedReferenceImages
        )

        if let requestData: Data = try? JSONEncoder().encode(transformedRequest),
           let _ = String(data: requestData, encoding: .utf8) {}

        do {
            let initialResponse: NetworkResponseData = try await ProviderDependencies.shared.networkProvider
                .performRequest(
                    url: url,
                    method: "POST",
                    body: transformedRequest,
                    headers: [
                        "Content-Type": "application/json",
                        "x-goog-api-key": request.providerSecret,
                    ],
                    attachments: nil
                )

            var operationName: String? = nil

            let rawResponse: String? = extractRawResponse(from: initialResponse)

            switch initialResponse {
            case let .dictionary(_, data):
                if let error: [String: Any] = data["error"] as? [String: Any],
                   let message: String = error["message"] as? String
                {
                    return VideoGenerationResponse(
                        status: .FAILED,
                        errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                        errorMessage: message,

                        rawResponse: rawResponse
                    )
                }

                operationName = data["name"] as? String
            default:
                return createInvalidVideoResponseError(
                    response: initialResponse,

                    modelCode: model.modelCode,
                    customMessage: "Unexpected response"
                )
            }

            guard let opName: String = operationName else {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "No operation name in response",

                    rawResponse: rawResponse
                )
            }

            let statusBaseURL: String = model.modelStatusBaseURL ?? "https://generativelanguage.googleapis.com/v1beta"
            let finalResult: [String: Any] = try await pollForResult(
                operationName: opName,
                baseURL: statusBaseURL,
                apiKey: request.providerSecret
            )

            if let response: [String: Any] = finalResult["response"] as? [String: Any],
               let generateVideoResponse: [String: Any] = response["generateVideoResponse"] as? [String: Any],
               let generatedSamples: [[String: Any]] = generateVideoResponse["generatedSamples"] as? [[String: Any]],
               let firstSample: [String: Any] = generatedSamples.first,
               let video: [String: Any] = firstSample["video"] as? [String: Any],
               let videoURI: String = video["uri"] as? String
            {
                let videoData: Data = try await downloadVideo(uri: videoURI, apiKey: request.providerSecret)
                let base64Video: String = videoData.base64EncodedString()

                let metadata: [String: String] = [G_GOOGLE_VEO_BASE.veoGeneratedUriKey: videoURI]

                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: base64Video,
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
                    modelPrompt: request.prompt,

                    metadata: metadata
                )
            }

            var finalResultRawResponse: String? = nil
            if let jsonData: Data = try? JSONSerialization.data(
                withJSONObject: finalResult,
                options: [.prettyPrinted, .sortedKeys]
            ),
                let jsonString = String(data: jsonData, encoding: .utf8)
            {
                finalResultRawResponse = jsonString
            }

            if let error: [String: Any] = finalResult["error"] as? [String: Any],
               let message: String = error["message"] as? String
            {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message,

                    rawResponse: finalResultRawResponse
                )
            }

            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Failed to extract video from response",

                rawResponse: finalResultRawResponse
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

public class G_GOOGLE_VEO_31: G_GOOGLE_VEO_BASE {
    public init() {
        super.init(modelCode: .GOOGLE_VEO_31)
    }
}

public class G_GOOGLE_VEO_31_EXTEND: G_GOOGLE_VEO_BASE {
    public init() {
        super.init(modelCode: .GOOGLE_VEO_31_EXTEND)
    }
}

public class G_GOOGLE_VEO_31_FAST: G_GOOGLE_VEO_BASE {
    public init() {
        super.init(modelCode: .GOOGLE_VEO_31_FAST)
    }
}

public class G_GOOGLE_VEO_31_FAST_EXTEND: G_GOOGLE_VEO_BASE {
    public init() {
        super.init(modelCode: .GOOGLE_VEO_31_FAST_EXTEND)
    }
}

public class G_GOOGLE_VEO_3: G_GOOGLE_VEO_BASE {
    public init() {
        super.init(modelCode: .GOOGLE_VEO_3)
    }
}

public class G_GOOGLE_VEO_3_FAST: G_GOOGLE_VEO_BASE {
    public init() {
        super.init(modelCode: .GOOGLE_VEO_3_FAST)
    }
}

public class G_GOOGLE_VEO_2: G_GOOGLE_VEO_BASE {
    public init() {
        super.init(modelCode: .GOOGLE_VEO_2)
    }
}

public class G_GOOGLE_VEO_31_LITE: G_GOOGLE_VEO_BASE {
    public init() {
        super.init(modelCode: .GOOGLE_VEO_31_LITE)
    }
}
