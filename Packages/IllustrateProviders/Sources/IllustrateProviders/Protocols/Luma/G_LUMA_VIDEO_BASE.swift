// MARK: - G_LUMA_VIDEO_BASE.swift

// Base implementation for Luma AI video generation models.
//
// Luma AI's video API uses async polling:
// 1. POST /dream-machine/v1/generations/video → get generation ID
// 2. GET /dream-machine/v1/generations/{id} to poll until completed
// 3. On completion, download from assets.video URL
//
// Models: ray-2, ray-flash-2
// Supports: text-to-video, image-to-video (via keyframes.frame0)

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public class G_LUMA_VIDEO_BASE: VideoGenerationProtocol {
    let modelCode: EnumProviderModelCode
    let modelName: String
    let pricePerVideo: Double
    let isI2V: Bool

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(modelCode: EnumProviderModelCode, modelName: String, pricePerVideo: Double, isI2V: Bool = false) {
        self.modelCode = modelCode
        self.modelName = modelName
        self.pricePerVideo = pricePerVideo
        self.isI2V = isI2V
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        pricePerVideo * Double(request.numberOfVideos ?? 1)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public struct KeyframeImage: Codable, Sendable {
        let type: String
        let url: String

        public init(url: String) {
            type = "image"
            self.url = url
        }
    }

    public struct Keyframes: Codable, Sendable {
        let frame0: KeyframeImage?

        public init(frame0: KeyframeImage? = nil) {
            self.frame0 = frame0
        }
    }

    public struct ServiceRequest: Codable, Sendable {
        let model: String
        let prompt: String?
        let aspect_ratio: String?
        let loop: Bool?
        let keyframes: Keyframes?
        let resolution: String?
        let duration: String?

        public init(
            model: String,
            prompt: String? = nil,
            aspectRatio: String? = nil,
            loop: Bool? = nil,
            keyframes: Keyframes? = nil,
            resolution: String? = nil,
            duration: String? = nil
        ) {
            self.model = model
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.loop = loop
            self.keyframes = keyframes
            self.resolution = resolution
            self.duration = duration
        }
    }

    func normalizeAspectRatio(from dimensions: String) -> String {
        if dimensions.contains(":") { return dimensions }

        let parts = dimensions.split(separator: "x")
        guard parts.count == 2,
              let w = Double(parts[0]),
              let h = Double(parts[1]),
              w > 0, h > 0
        else {
            return "16:9"
        }

        let candidates: [(label: String, ratio: Double)] = [
            ("1:1", 1.0),
            ("16:9", 16.0 / 9.0),
            ("9:16", 9.0 / 16.0),
            ("4:3", 4.0 / 3.0),
            ("3:4", 3.0 / 4.0),
            ("21:9", 21.0 / 9.0),
            ("9:21", 9.0 / 21.0),
        ]

        let r = w / h
        let best = candidates.min(by: { abs($0.ratio - r) < abs($1.ratio - r) })
        return best?.label ?? "16:9"
    }

    func mapResolution(_ resolution: String?) -> String? {
        guard let resolution else { return nil }
        switch resolution {
        case "540p": return "540p"
        case "720p": return "720p"
        case "1080p": return "1080p"
        case "4k": return "4k"
        default: return nil
        }
    }

    func mapDuration(_ durationSeconds: Int?) -> String? {
        guard let durationSeconds else { return nil }
        switch durationSeconds {
        case 5: return "5s"
        case 9: return "9s"
        default: return "5s"
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        var keyframes: Keyframes? = nil

        if let clientImage = request.clientImage {
            let cleanBase64 = clientImage.replacingOccurrences(
                of: "^data:.*;base64,",
                with: "",
                options: .regularExpression
            )
            let dataUri = "data:image/png;base64,\(cleanBase64)"
            keyframes = Keyframes(frame0: KeyframeImage(url: dataUri))
        }

        return ServiceRequest(
            model: modelName,
            prompt: request.prompt,
            aspectRatio: normalizeAspectRatio(from: request.dimensions),
            keyframes: keyframes,
            resolution: mapResolution(request.resolution),
            duration: mapDuration(request.durationSeconds)
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        VideoGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: "Use makeRequest directly for Luma AI video models"
        )
    }

    func pollForResult(
        generationId: String,
        apiKey: String,
        maxAttempts: Int = 120
    ) async throws -> [String: Any] {
        var attempts = 0

        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 10_000_000_000)

            guard let statusURL = URL(
                string: "https://api.lumalabs.ai/dream-machine/v1/generations/\(generationId)"
            ) else {
                throw NSError(domain: "Invalid status URL", code: -1, userInfo: nil)
            }

            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: statusURL,
                method: "GET",
                body: nil as String?,
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                ],
                attachments: nil
            )

            switch response {
            case let .dictionary(_, data):
                if let state = data["state"] as? String {
                    if state == "completed" {
                        return data
                    } else if state == "failed" {
                        let reason = data["failure_reason"] as? String ?? "Video generation failed"
                        throw NSError(domain: reason, code: -1, userInfo: nil)
                    }
                }
            default:
                break
            }

            attempts += 1
        }

        throw NSError(domain: "Polling exceeded max attempts (20 minutes)", code: -1, userInfo: nil)
    }

    func downloadVideo(url: String) async throws -> Data {
        guard let downloadURL = URL(string: url) else {
            throw NSError(domain: "Invalid download URL", code: -1, userInfo: nil)
        }

        var request = URLRequest(url: downloadURL)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw NSError(domain: "Failed to download video", code: -1, userInfo: nil)
        }

        return data
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        if isI2V, request.clientImage == nil {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let transformedRequest = transformRequest(request: request)

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: transformedRequest,
                headers: [
                    "Authorization": "Bearer \(request.providerSecret)",
                    "Content-Type": "application/json",
                ],
                attachments: nil
            )

            var generationId: String?

            switch initialResponse {
            case let .dictionary(_, data):
                if let error = data["detail"] as? String {
                    return VideoGenerationResponse(
                        status: .FAILED,
                        errorCode: .MODEL_ERROR,
                        errorMessage: error,
                        rawResponse: initialResponse.rawResponseString
                    )
                }
                generationId = data["id"] as? String
            default:
                return createInvalidVideoResponseError(
                    response: initialResponse,
                    modelCode: modelCode,
                    customMessage: "Unexpected response"
                )
            }

            guard let id = generationId else {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "No generation ID in response",
                    rawResponse: initialResponse.rawResponseString
                )
            }

            let finalResult = try await pollForResult(
                generationId: id,
                apiKey: request.providerSecret
            )

            guard let assets = finalResult["assets"] as? [String: Any],
                  let videoUrl = assets["video"] as? String
            else {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "No video URL in completed response"
                )
            }

            let videoData = try await downloadVideo(url: videoUrl)
            let base64Video = videoData.base64EncodedString()

            return VideoGenerationResponse(
                status: .GENERATED,
                base64: base64Video,
                cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
                modelPrompt: request.prompt,
                metadata: ["lumaGenerationId": id]
            )
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed with error: \(error.localizedDescription)",
                rawResponse: "Error: \(error.localizedDescription)"
            )
        }
    }
}

public class G_LUMA_RAY_2: G_LUMA_VIDEO_BASE {
    public init() {
        super.init(modelCode: .LUMA_RAY_2, modelName: "ray-2", pricePerVideo: 0.40)
    }
}

public class G_LUMA_RAY_FLASH_2: G_LUMA_VIDEO_BASE {
    public init() {
        super.init(modelCode: .LUMA_RAY_FLASH_2, modelName: "ray-flash-2", pricePerVideo: 0.10)
    }
}

public class G_LUMA_RAY_2_I2V: G_LUMA_VIDEO_BASE {
    public init() {
        super.init(modelCode: .LUMA_RAY_2_I2V, modelName: "ray-2", pricePerVideo: 0.60, isI2V: true)
    }
}

public class G_LUMA_RAY_FLASH_2_I2V: G_LUMA_VIDEO_BASE {
    public init() {
        super.init(modelCode: .LUMA_RAY_FLASH_2_I2V, modelName: "ray-flash-2", pricePerVideo: 0.15, isI2V: true)
    }
}

public class G_LUMA_AGENTS_VIDEO_BASE: VideoGenerationProtocol {
    static let lumaGenerationIdKey = "lumaGenerationId"

    public enum Operation: Sendable {
        case generate
        case keyframes
        case extend
        case edit
        case reframe
    }

    let modelCode: EnumProviderModelCode
    let modelName: String
    let operation: Operation

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(modelCode: EnumProviderModelCode, modelName: String, operation: Operation = .generate) {
        self.modelCode = modelCode
        self.modelName = modelName
        self.operation = operation
    }

    public struct ServiceRequest: Codable, Sendable {
        let model: String
        let type: String
        let prompt: String
        let aspect_ratio: String?
        let source: ImageRef?
        let video: VideoOptions

        public init(
            model: String,
            type: String,
            prompt: String,
            aspectRatio: String?,
            source: ImageRef? = nil,
            video: VideoOptions
        ) {
            self.model = model
            self.type = type
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.source = source
            self.video = video
        }
    }

    public struct EditOptions: Codable, Sendable {
        let auto_controls: Bool

        public init(autoControls: Bool) {
            auto_controls = autoControls
        }
    }

    public struct VideoOptions: Codable, Sendable {
        let resolution: String
        let duration: String?
        let start_frame: ImageRef?
        let end_frame: ImageRef?
        let keyframes: [ImageRef]?
        let keyframe_indexes: [Int]?
        let edit: EditOptions?
        let hdr: Bool?
        let exr_export: Bool?
        let loop: Bool?

        public init(
            resolution: String,
            duration: String? = nil,
            startFrame: ImageRef? = nil,
            endFrame: ImageRef? = nil,
            keyframes: [ImageRef]? = nil,
            keyframeIndexes: [Int]? = nil,
            edit: EditOptions? = nil,
            hdr: Bool? = nil,
            exrExport: Bool? = nil,
            loop: Bool? = nil
        ) {
            self.resolution = resolution
            self.duration = duration
            start_frame = startFrame
            end_frame = endFrame
            self.keyframes = keyframes
            keyframe_indexes = keyframeIndexes
            self.edit = edit
            self.hdr = hdr
            exr_export = exrExport
            self.loop = loop
        }
    }

    public struct ImageRef: Codable, Sendable {
        let data: String?
        let media_type: String?
        let generation_id: String?

        public init(data: String, mediaType: String) {
            self.data = data
            media_type = mediaType
            generation_id = nil
        }

        public init(generationId: String) {
            data = nil
            media_type = nil
            generation_id = generationId
        }
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        if operation == .extend {
            let resolution = supportedValue(
                request.resolution,
                supported: ["540p", "720p", "1080p"],
                defaultValue: "720p"
            )

            let cost = switch resolution {
            case "540p":
                0.15
            case "1080p":
                1.20
            default:
                0.30
            }

            return cost * Double(request.numberOfVideos ?? 1)
        }

        if operation == .reframe {
            let resolution = supportedValue(
                request.resolution,
                supported: ["360p", "540p", "720p", "1080p"],
                defaultValue: "720p"
            )
            let duration = boundedDuration(request.durationSeconds, min: 1, max: 30, defaultValue: 5)

            let rate = switch resolution {
            case "360p":
                0.03
            case "540p":
                0.06
            case "1080p":
                0.36
            default:
                0.12
            }

            return rate * Double(duration) * Double(request.numberOfVideos ?? 1)
        }

        if operation == .edit {
            let resolution = supportedValue(
                request.resolution,
                supported: ["360p", "540p", "720p", "1080p"],
                defaultValue: "720p"
            )
            let duration = supportedDuration(request.durationSeconds, supported: [5, 10], defaultValue: 5)
            let isHDR = request.lumaHDR == true
            let isEXR = request.lumaEXRExport == true

            let cost = if isHDR, isEXR {
                switch (resolution, duration) {
                case ("360p", 5): 1.62
                case ("360p", 10): 3.24
                case ("540p", 5): 2.16
                case ("540p", 10): 4.32
                case ("720p", 10): 6.48
                case ("1080p", 5): 6.48
                case ("1080p", 10): 12.96
                default: 3.24
                }
            } else if isHDR {
                switch (resolution, duration) {
                case ("360p", 5): 1.08
                case ("360p", 10): 2.16
                case ("540p", 5): 1.44
                case ("540p", 10): 2.88
                case ("720p", 10): 4.32
                case ("1080p", 5): 4.32
                case ("1080p", 10): 8.64
                default: 2.16
                }
            } else {
                switch (resolution, duration) {
                case ("360p", 5): 0.54
                case ("360p", 10): 1.08
                case ("540p", 5): 0.72
                case ("540p", 10): 1.44
                case ("720p", 10): 2.16
                case ("1080p", 5): 2.16
                case ("1080p", 10): 4.32
                default: 1.08
                }
            }

            return cost * Double(request.numberOfVideos ?? 1)
        }

        let resolution = supportedValue(
            request.resolution,
            supported: ["360p", "540p", "720p", "1080p"],
            defaultValue: "720p"
        )
        let duration = supportedDuration(request.durationSeconds, supported: [5, 10], defaultValue: 5)
        let isHDR = request.lumaHDR == true
        let isEXR = request.lumaEXRExport == true

        let cost: Double = if isHDR, isEXR {
            resolution == "1080p" ? 3.60 : 0.90
        } else if isHDR {
            resolution == "1080p" ? 2.40 : 0.60
        } else {
            switch (resolution, duration) {
            case ("360p", 5): 0.06
            case ("360p", 10): 0.18
            case ("540p", 5): 0.15
            case ("540p", 10): 0.45
            case ("720p", 10): 0.90
            case ("1080p", 5): 1.20
            case ("1080p", 10): 3.60
            default: 0.30
            }
        }

        return cost * Double(request.numberOfVideos ?? 1)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        if operation == .extend {
            let startFrame = sourceGenerationId(from: request).map(ImageRef.init(generationId:))

            return ServiceRequest(
                model: modelName,
                type: "video",
                prompt: request.prompt ?? "",
                aspectRatio: nil,
                video: VideoOptions(
                    resolution: supportedValue(
                        request.resolution,
                        supported: ["540p", "720p", "1080p"],
                        defaultValue: "720p"
                    ),
                    duration: "5s",
                    startFrame: startFrame
                )
            )
        }

        if operation == .edit {
            let source = sourceGenerationId(from: request).map(ImageRef.init(generationId:))

            return ServiceRequest(
                model: modelName,
                type: "video_edit",
                prompt: request.prompt ?? "",
                aspectRatio: nil,
                source: source,
                video: VideoOptions(
                    resolution: supportedValue(
                        request.resolution,
                        supported: ["360p", "540p", "720p", "1080p"],
                        defaultValue: "720p"
                    ),
                    duration: "\(supportedDuration(request.durationSeconds, supported: [5, 10], defaultValue: 5))s",
                    edit: EditOptions(autoControls: true),
                    hdr: boolIfTrue(request.lumaHDR),
                    exrExport: boolIfTrue(request.lumaEXRExport)
                )
            )
        }

        if operation == .reframe {
            let source = sourceGenerationId(from: request).map(ImageRef.init(generationId:))

            return ServiceRequest(
                model: modelName,
                type: "video_reframe",
                prompt: request.prompt ?? "",
                aspectRatio: normalizeAspectRatio(from: request.dimensions),
                source: source,
                video: VideoOptions(
                    resolution: supportedValue(
                        request.resolution,
                        supported: ["360p", "540p", "720p", "1080p"],
                        defaultValue: "720p"
                    )
                )
            )
        }

        if operation == .keyframes {
            let keyframes = keyframeImageRefs(from: request)
            let duration = supportedDuration(request.durationSeconds, supported: [5, 10], defaultValue: 5)

            return ServiceRequest(
                model: modelName,
                type: "video",
                prompt: request.prompt ?? "",
                aspectRatio: normalizeAspectRatio(from: request.dimensions),
                video: VideoOptions(
                    resolution: supportedValue(
                        request.resolution,
                        supported: ["360p", "540p", "720p", "1080p"],
                        defaultValue: "720p"
                    ),
                    duration: "\(duration)s",
                    keyframes: keyframes.map(\.imageRef),
                    keyframeIndexes: keyframes.map(\.frameIndex),
                    hdr: boolIfTrue(request.lumaHDR),
                    exrExport: boolIfTrue(request.lumaEXRExport)
                )
            )
        }

        let startFrame = request.clientImage.flatMap { imageRef(fromBase64: $0) }
        let endFrame = request.clientLastFrame.flatMap { imageRef(fromBase64: $0) }
        let hasAnchorFrame = startFrame != nil || endFrame != nil

        return ServiceRequest(
            model: modelName,
            type: "video",
            prompt: request.prompt ?? "",
            aspectRatio: normalizeAspectRatio(from: request.dimensions),
            video: VideoOptions(
                resolution: supportedValue(
                    request.resolution,
                    supported: ["360p", "540p", "720p", "1080p"],
                    defaultValue: "720p"
                ),
                duration: durationString(for: request.durationSeconds, hasAnchorFrame: hasAnchorFrame),
                startFrame: startFrame,
                endFrame: endFrame,
                hdr: boolIfTrue(request.lumaHDR),
                exrExport: boolIfTrue(request.lumaEXRExport),
                loop: boolIfTrue(request.lumaLoop)
            )
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let errorMessage = errorMessage(from: data) {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: errorMessage,
                    rawResponse: response.rawResponseString
                )
            }

            if state(from: data) == "failed" {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: failureMessage(from: data),
                    rawResponse: response.rawResponseString
                )
            }

            if let videoURL = outputVideoURL(from: data) {
                let costRequest = effectiveCostRequest(from: request)
                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: nil,
                    videoUrl: videoURL,
                    cost: getCostEstimate(request: costRequest),
                    modelPrompt: request.prompt,
                    rawResponse: videoURL,
                    metadata: generationMetadata(from: data),
                    actualDuration: costRequest.durationSeconds
                )
            }
        default:
            break
        }

        return createInvalidVideoResponseError(response: response, modelCode: modelCode)
    }

    func pollForResult(
        generationId: String,
        apiKey: String,
        maxDurationSeconds: Double = 600,
        initialDelaySeconds: UInt64 = 30,
        pollIntervalSeconds: UInt64 = 5
    ) async throws -> [String: Any] {
        let deadline = Date().addingTimeInterval(maxDurationSeconds)
        try await sleep(seconds: initialDelaySeconds)

        while Date() < deadline {
            let statusURLString = "\(model.modelStatusBaseURL ?? model.modelGenerateBaseURL)/\(generationId)"
            guard let statusURL = URL(string: statusURLString)
            else {
                throw NSError(domain: "Invalid status URL", code: -1, userInfo: nil)
            }

            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: statusURL,
                method: "GET",
                body: nil as String?,
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                ],
                attachments: nil
            )

            switch response {
            case let .dictionary(_, data):
                if state(from: data) == "completed" {
                    return data
                }
                if state(from: data) == "failed" {
                    throw NSError(domain: failureMessage(from: data), code: -1, userInfo: nil)
                }
            default:
                break
            }

            try await sleep(seconds: pollIntervalSeconds)
        }

        throw NSError(domain: "Polling exceeded max duration", code: -1, userInfo: nil)
    }

    func downloadVideo(url: String) async throws -> Data {
        guard let downloadURL = URL(string: url) else {
            throw NSError(domain: "Invalid download URL", code: -1, userInfo: nil)
        }

        var request = URLRequest(url: downloadURL)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw NSError(domain: "Failed to download video", code: -1, userInfo: nil)
        }

        return data
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        if operation == .extend, sourceGenerationId(from: request) == nil {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "No Luma generation ID provided for extension"
            )
        }

        if operation == .edit, sourceGenerationId(from: request) == nil {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "No Luma generation ID provided for video edit"
            )
        }

        if operation == .reframe, sourceGenerationId(from: request) == nil {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "No Luma generation ID provided for video reframe"
            )
        }

        if operation == .reframe, usesUnsupportedVerticalReframeResolution(request: request) {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Luma reframe does not support 1080p for vertical target aspect ratios. Choose 720p or lower."
            )
        }

        if operation == .keyframes, let error = keyframeValidationError(from: request) {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: error
            )
        }

        if let error = lumaOutputValidationError(from: request) {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: error
            )
        }

        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let transformedRequest = transformRequest(request: request)

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: transformedRequest,
                headers: [
                    "Authorization": "Bearer \(request.providerSecret)",
                    "Content-Type": "application/json",
                ],
                attachments: nil
            )

            let finalResult: [String: Any]
            switch initialResponse {
            case let .dictionary(_, data):
                if let errorMessage = errorMessage(from: data) {
                    return VideoGenerationResponse(
                        status: .FAILED,
                        errorCode: .MODEL_ERROR,
                        errorMessage: errorMessage,
                        rawResponse: initialResponse.rawResponseString
                    )
                }

                if state(from: data) == "failed" {
                    return VideoGenerationResponse(
                        status: .FAILED,
                        errorCode: .MODEL_ERROR,
                        errorMessage: failureMessage(from: data),
                        rawResponse: initialResponse.rawResponseString
                    )
                }

                if state(from: data) == "completed" {
                    finalResult = data
                } else {
                    guard let id = data["id"] as? String else {
                        return VideoGenerationResponse(
                            status: .FAILED,
                            errorCode: .MODEL_ERROR,
                            errorMessage: "No generation ID in response",
                            rawResponse: initialResponse.rawResponseString
                        )
                    }

                    finalResult = try await pollForResult(
                        generationId: id,
                        apiKey: request.providerSecret
                    )
                }
            default:
                return createInvalidVideoResponseError(
                    response: initialResponse,
                    modelCode: modelCode,
                    customMessage: "Unexpected response from video creation"
                )
            }

            guard let videoURL = outputVideoURL(from: finalResult) else {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "No video URL in completed response"
                )
            }

            let videoData = try await downloadVideo(url: videoURL)
            let costRequest = effectiveCostRequest(from: request)

            return VideoGenerationResponse(
                status: .GENERATED,
                base64: videoData.base64EncodedString(),
                videoUrl: videoURL,
                cost: getCostEstimate(request: costRequest),
                modelPrompt: request.prompt,
                metadata: generationMetadata(from: finalResult),
                actualDuration: costRequest.durationSeconds
            )
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed with error: \(error.localizedDescription)",
                rawResponse: "Error: \(error.localizedDescription)"
            )
        }
    }

    private let supportedAspectRatios = ["9:16", "3:4", "1:1", "4:3", "16:9", "21:9"]

    private func normalizeAspectRatio(from dimensions: String) -> String {
        if supportedAspectRatios.contains(dimensions) { return dimensions }

        let parts = dimensions.split(separator: "x")
        guard parts.count == 2,
              let w = Double(parts[0]),
              let h = Double(parts[1]),
              w > 0, h > 0
        else {
            return "16:9"
        }

        let ratio = w / h
        let best = supportedAspectRatios.min { lhs, rhs in
            abs(aspectRatioValue(lhs) - ratio) < abs(aspectRatioValue(rhs) - ratio)
        }
        return best ?? "16:9"
    }

    private func aspectRatioValue(_ aspectRatio: String) -> Double {
        let parts = aspectRatio.split(separator: ":")
        guard parts.count == 2,
              let w = Double(parts[0]),
              let h = Double(parts[1]),
              h > 0
        else {
            return 16.0 / 9.0
        }
        return w / h
    }

    private func supportedValue(_ value: String?, supported: [String], defaultValue: String) -> String {
        guard let value, supported.contains(value) else { return defaultValue }
        return value
    }

    private func supportedDuration(_ durationSeconds: Int?, supported: [Int], defaultValue: Int) -> Int {
        guard let durationSeconds, supported.contains(durationSeconds) else { return defaultValue }
        return durationSeconds
    }

    private func boolIfTrue(_ value: Bool?) -> Bool? {
        value == true ? true : nil
    }

    private func boundedDuration(_ durationSeconds: Int?, min: Int, max: Int, defaultValue: Int) -> Int {
        guard let durationSeconds else { return defaultValue }
        return Swift.max(min, Swift.min(max, durationSeconds))
    }

    private func durationString(for durationSeconds: Int?, hasAnchorFrame: Bool) -> String {
        let duration = hasAnchorFrame ? 5 : supportedDuration(durationSeconds, supported: [5, 10], defaultValue: 5)
        return "\(duration)s"
    }

    private func effectiveCostRequest(from request: VideoGenerationRequest) -> VideoGenerationCostRequest {
        var costRequest = VideoGenerationCostRequest(from: request)
        if operation == .extend || request.clientImage?.isEmpty == false || request.clientLastFrame?.isEmpty == false {
            costRequest.durationSeconds = 5
        }
        if operation == .generate || operation == .keyframes, request.lumaHDR == true {
            costRequest.durationSeconds = 5
        }
        if operation == .generate, request.lumaLoop == true {
            costRequest.durationSeconds = 5
        }
        if operation == .reframe {
            costRequest.durationSeconds = sourceDurationSeconds(from: request)
                ?? boundedDuration(request.durationSeconds, min: 1, max: 30, defaultValue: 5)
        }
        return costRequest
    }

    private func sourceGenerationId(from request: VideoGenerationRequest) -> String? {
        guard let generationId = request.sourceMetadata?[Self.lumaGenerationIdKey],
              !generationId.isEmpty
        else {
            return nil
        }
        return generationId
    }

    private func sourceDurationSeconds(from request: VideoGenerationRequest) -> Int? {
        guard let value = request.sourceMetadata?["duration_seconds"],
              let duration = Int(value)
        else {
            return nil
        }
        return boundedDuration(duration, min: 1, max: 30, defaultValue: 5)
    }

    private func usesUnsupportedVerticalReframeResolution(request: VideoGenerationRequest) -> Bool {
        let resolution = supportedValue(
            request.resolution,
            supported: ["360p", "540p", "720p", "1080p"],
            defaultValue: "720p"
        )
        return resolution == "1080p" && isVerticalAspectRatio(normalizeAspectRatio(from: request.dimensions))
    }

    private func isVerticalAspectRatio(_ aspectRatio: String) -> Bool {
        aspectRatioValue(aspectRatio) < 1.0
    }

    private func keyframeImageRefs(from request: VideoGenerationRequest) -> [(imageRef: ImageRef, frameIndex: Int)] {
        let keyframes = request.clientReferenceImages ?? []
        return keyframes.compactMap { reference in
            guard let frameIndex = reference.frameIndex,
                  let imageRef = imageRef(from: reference)
            else {
                return nil
            }
            return (imageRef, frameIndex)
        }
        .sorted { lhs, rhs in lhs.frameIndex < rhs.frameIndex }
    }

    private func keyframeValidationError(from request: VideoGenerationRequest) -> String? {
        if request.clientImage?.isEmpty == false || request.clientLastFrame?.isEmpty == false {
            return "Luma multi-keyframe generation cannot be combined with start or end frame images."
        }

        let references = request.clientReferenceImages ?? []
        if references.isEmpty {
            return "Luma multi-keyframe generation requires at least one keyframe image."
        }

        if references.count > 64 {
            return "Luma multi-keyframe generation supports up to 64 keyframe images."
        }

        if references.contains(where: { $0.frameIndex == nil }) {
            return "Every Luma keyframe image requires a timeline frame index."
        }

        let frameIndexes = references.compactMap(\.frameIndex)
        if Set(frameIndexes).count != frameIndexes.count {
            return "Luma keyframe frame indexes must be unique."
        }

        let duration = supportedDuration(request.durationSeconds, supported: [5, 10], defaultValue: 5)
        let maxFrameIndex = duration * 24
        if frameIndexes.contains(where: { $0 < 0 || $0 > maxFrameIndex }) {
            return "Luma keyframe frame indexes must be between 0 and \(maxFrameIndex) for a \(duration)s clip."
        }

        if keyframeImageRefs(from: request).count != references.count {
            return "Every Luma keyframe image requires valid image data."
        }

        return nil
    }

    private func lumaOutputValidationError(from request: VideoGenerationRequest) -> String? {
        let isHDR = request.lumaHDR == true
        let isEXR = request.lumaEXRExport == true
        let isLoop = request.lumaLoop == true

        if isEXR, !isHDR {
            return "Luma EXR export requires HDR output."
        }

        if operation == .extend || operation == .reframe, isHDR || isEXR {
            return "Luma HDR and EXR output are not supported for this Ray 3.2 workflow."
        }

        if operation != .generate, isLoop {
            return "Luma loop output is only supported for Ray 3.2 generation."
        }

        if isHDR, operation == .generate || operation == .keyframes || operation == .edit {
            let resolution = supportedValue(
                request.resolution,
                supported: ["360p", "540p", "720p", "1080p"],
                defaultValue: "720p"
            )
            if resolution == "360p" || resolution == "540p" {
                return "Luma HDR output requires 720p or 1080p."
            }
        }

        if isHDR, operation == .generate || operation == .keyframes {
            let duration = effectiveGenerationDuration(from: request)
            if duration == 10 {
                return "Luma HDR output is only supported for 5s generation."
            }
        }

        if isLoop {
            if effectiveGenerationDuration(from: request) == 10 {
                return "Luma loop output is only supported for 5s generation."
            }
            if request.clientLastFrame?.isEmpty == false {
                return "Luma loop output cannot be combined with an end frame."
            }
            if isHDR {
                return "Luma loop output cannot be combined with HDR."
            }
            if request.clientReferenceImages?.isEmpty == false {
                return "Luma loop output cannot be combined with keyframes."
            }
        }

        return nil
    }

    private func effectiveGenerationDuration(from request: VideoGenerationRequest) -> Int {
        let hasAnchorFrame = request.clientImage?.isEmpty == false || request.clientLastFrame?.isEmpty == false
        return hasAnchorFrame ? 5 : supportedDuration(request.durationSeconds, supported: [5, 10], defaultValue: 5)
    }

    private func imageRef(from referenceImage: ReferenceImageData) -> ImageRef? {
        let payload = parseBase64Payload(from: referenceImage.base64Image)
        let data = payload.data
        guard !data.isEmpty else { return nil }
        let mediaType = payload.mimeType ?? referenceImage.mimeType
        return ImageRef(data: data, mediaType: mediaType.isEmpty ? "image/png" : mediaType)
    }

    private func imageRef(fromBase64 base64: String) -> ImageRef? {
        let payload = parseBase64Payload(from: base64)
        guard !payload.data.isEmpty else { return nil }
        return ImageRef(data: payload.data, mediaType: payload.mimeType ?? "image/png")
    }

    private func parseBase64Payload(from base64: String) -> (data: String, mimeType: String?) {
        guard base64.hasPrefix("data:"),
              let commaIndex = base64.firstIndex(of: ",")
        else {
            return (base64, nil)
        }

        let header = String(base64[..<commaIndex])
        guard header.lowercased().contains(";base64") else {
            return (base64, nil)
        }

        let mimeTypeCandidate = header
            .dropFirst("data:".count)
            .split(separator: ";")
            .first
            .map(String.init)
        let mimeType = mimeTypeCandidate?.contains("/") == true ? mimeTypeCandidate : nil
        let dataStart = base64.index(after: commaIndex)
        return (String(base64[dataStart...]), mimeType)
    }

    private func state(from data: [String: Any]) -> String? {
        data["state"] as? String ?? data["status"] as? String
    }

    private func outputVideoURL(from data: [String: Any]) -> String? {
        outputURL(from: data, matchingTypes: ["video"], fallbackToFirstURL: true)
    }

    private func outputEXRURL(from data: [String: Any]) -> String? {
        outputURL(from: data, matchingTypes: ["exr"], fallbackToFirstURL: false)
            ?? outputEntries(from: data)
            .compactMap { $0["url"] as? String }
            .first { $0.lowercased().contains(".exr") }
    }

    private func outputURL(
        from data: [String: Any],
        matchingTypes types: Set<String>,
        fallbackToFirstURL: Bool
    ) -> String? {
        let output = outputEntries(from: data)
        let matchingURL = output.first {
            guard let type = $0["type"] as? String else { return false }
            return types.contains(type.lowercased())
        }?["url"] as? String

        if let matchingURL {
            return matchingURL
        }

        guard fallbackToFirstURL else { return nil }
        return output.compactMap { $0["url"] as? String }.first
    }

    private func outputEntries(from data: [String: Any]) -> [[String: Any]] {
        guard let output = data["output"] as? [[String: Any]] else { return [] }
        return output
    }

    private func errorMessage(from data: [String: Any]) -> String? {
        if let detail = data["detail"] as? String { return detail }
        if let error = data["error"] as? String { return error }
        if let detail = data["detail"] as? [String: Any],
           let message = detail["message"] as? String
        {
            return message
        }
        if let error = data["error"] as? [String: Any],
           let message = error["message"] as? String
        {
            return message
        }
        return nil
    }

    private func failureMessage(from data: [String: Any]) -> String {
        data["failure_reason"] as? String
            ?? data["failure_message"] as? String
            ?? data["message"] as? String
            ?? "Video generation failed"
    }

    private func generationMetadata(from data: [String: Any]) -> [String: String]? {
        guard let id = data["id"] as? String else { return nil }
        var metadata = [Self.lumaGenerationIdKey: id]
        if let exrURL = outputEXRURL(from: data) {
            metadata["lumaExrUrl"] = exrURL
        }
        return metadata
    }

    private func sleep(seconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
    }
}

public final class G_LUMA_RAY_3_2: G_LUMA_AGENTS_VIDEO_BASE {
    public init() {
        super.init(modelCode: .LUMA_RAY_3_2, modelName: "ray-3.2")
    }
}

public final class G_LUMA_RAY_3_2_KEYFRAMES: G_LUMA_AGENTS_VIDEO_BASE {
    public init() {
        super.init(modelCode: .LUMA_RAY_3_2_KEYFRAMES, modelName: "ray-3.2", operation: .keyframes)
    }
}

public final class G_LUMA_RAY_3_2_EXTEND: G_LUMA_AGENTS_VIDEO_BASE {
    public init() {
        super.init(modelCode: .LUMA_RAY_3_2_EXTEND, modelName: "ray-3.2", operation: .extend)
    }
}

public final class G_LUMA_RAY_3_2_EDIT: G_LUMA_AGENTS_VIDEO_BASE {
    public init() {
        super.init(modelCode: .LUMA_RAY_3_2_EDIT, modelName: "ray-3.2", operation: .edit)
    }
}

public final class G_LUMA_RAY_3_2_REFRAME: G_LUMA_AGENTS_VIDEO_BASE {
    public init() {
        super.init(modelCode: .LUMA_RAY_3_2_REFRAME, modelName: "ray-3.2", operation: .reframe)
    }
}
