// MARK: - G_TOGETHER_VIDEO_BASE.swift

// Base implementation for Together AI video generation models.
//
// Together AI's video API uses async polling:
// 1. POST /v2/videos to create a job → get job ID
// 2. GET /v2/videos/{id} to poll status (in_progress → completed/failed)
// 3. On completion, download from outputs.video_url
//
// Pricing is per video (varies by model).

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public class G_TOGETHER_VIDEO_BASE: VideoGenerationProtocol {
    let modelCode: EnumProviderModelCode
    let modelName: String
    let pricePerVideo: Double
    let priceIsPublished: Bool

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    var defaultDuration: Int {
        model.modelParams.supportedVideoDurations.first ?? 5
    }

    public init(
        modelCode: EnumProviderModelCode,
        modelName: String,
        pricePerVideo: Double,
        priceIsPublished: Bool = true
    ) {
        self.modelCode = modelCode
        self.modelName = modelName
        self.pricePerVideo = pricePerVideo
        self.priceIsPublished = priceIsPublished
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let numberOfVideos = request.numberOfVideos ?? 1
        if isSeedance20Model {
            let duration = seedanceDuration(from: request.durationSeconds)
            return seedanceCostPerSecond(for: request.resolution) * Double(duration) * Double(numberOfVideos)
        }
        return pricePerVideo * Double(numberOfVideos)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        if !priceIsPublished { return "Pricing unavailable" }
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public struct FrameImage: Codable, Sendable {
        let input_image: String
        let frame: Int?

        public init(inputImage: String, frame: Int? = nil) {
            input_image = inputImage
            self.frame = frame
        }
    }

    public struct MediaFrameImage: Codable, Sendable {
        let input_image: String
        let frame: String

        public init(inputImage: String, frame: String) {
            input_image = inputImage
            self.frame = frame
        }
    }

    public struct MediaReferenceVideo: Codable, Sendable {
        let video: String

        public init(video: String) {
            self.video = video
        }
    }

    public struct MediaInput: Codable, Sendable {
        let frame_images: [MediaFrameImage]?
        let reference_images: [String]?
        let reference_videos: [MediaReferenceVideo]?

        public init(
            frameImages: [MediaFrameImage]? = nil,
            referenceImages: [String]? = nil,
            referenceVideos: [MediaReferenceVideo]? = nil
        ) {
            frame_images = frameImages
            reference_images = referenceImages
            reference_videos = referenceVideos
        }
    }

    public struct Settings: Codable, Sendable {
        let audio: Bool?

        public init(audio: Bool?) {
            self.audio = audio
        }
    }

    public struct ServiceRequest: Codable, Sendable {
        let model: String
        let prompt: String?
        let width: Int?
        let height: Int?
        let resolution: String?
        let ratio: String?
        let seconds: String?
        let fps: Int?
        let seed: Int?
        let negative_prompt: String?
        let guidance_scale: Double?
        let generate_audio: Bool?
        let frame_images: [FrameImage]?
        let media: MediaInput?
        let settings: Settings?

        public init(
            model: String,
            prompt: String? = nil,
            width: Int? = nil,
            height: Int? = nil,
            resolution: String? = nil,
            ratio: String? = nil,
            seconds: String? = nil,
            fps: Int? = nil,
            seed: Int? = nil,
            negativePrompt: String? = nil,
            guidanceScale: Double? = nil,
            generateAudio: Bool? = nil,
            frameImages: [FrameImage]? = nil,
            media: MediaInput? = nil,
            settings: Settings? = nil
        ) {
            self.model = model
            self.prompt = prompt
            self.width = width
            self.height = height
            self.resolution = resolution
            self.ratio = ratio
            self.seconds = seconds
            self.fps = fps
            self.seed = seed
            negative_prompt = negativePrompt
            guidance_scale = guidanceScale
            generate_audio = generateAudio
            frame_images = frameImages
            self.media = media
            self.settings = settings
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        if isVeo31Model {
            return ServiceRequest(model: modelName, prompt: request.prompt)
        }
        if isWan27Model {
            return transformWan27Request(request: request)
        }
        if isSeedance20Model {
            return transformSeedance20Request(request: request)
        }

        let parts = request.dimensions.split(separator: "x")
        let width = Int(parts.first ?? "1280") ?? 1280
        let height = Int(parts.last ?? "720") ?? 720

        var frameImages: [FrameImage]? = nil
        if let clientImage = request.clientImage {
            let cleanBase64 = clientImage.replacingOccurrences(
                of: "^data:.*;base64,",
                with: "",
                options: .regularExpression
            )
            frameImages = [FrameImage(inputImage: cleanBase64, frame: 0)]
        }

        return ServiceRequest(
            model: modelName,
            prompt: request.prompt,
            width: width,
            height: height,
            seconds: String(request.durationSeconds ?? defaultDuration),
            fps: request.fps,
            seed: request.seed,
            negativePrompt: request.negativePrompt,
            guidanceScale: request.guidance,
            generateAudio: request.generateAudio,
            frameImages: frameImages
        )
    }

    func transformWan27Request(request: VideoGenerationRequest) -> ServiceRequest {
        ServiceRequest(
            model: modelName,
            prompt: request.prompt,
            resolution: wanResolution(from: request.resolution),
            ratio: wanRatio(from: request.dimensions),
            seconds: String(wanDuration(from: request.durationSeconds)),
            seed: request.seed,
            negativePrompt: request.negativePrompt,
            generateAudio: request.generateAudio,
            media: wanMediaInput(from: request)
        )
    }

    func transformSeedance20Request(request: VideoGenerationRequest) -> ServiceRequest {
        ServiceRequest(
            model: modelName,
            prompt: request.prompt,
            resolution: seedanceResolution(from: request.resolution),
            ratio: seedanceRatio(from: request.dimensions),
            seconds: String(seedanceDuration(from: request.durationSeconds)),
            seed: request.seed,
            negativePrompt: request.negativePrompt,
            guidanceScale: request.guidance,
            media: seedanceMediaInput(from: request),
            settings: seedanceSettings(from: request.generateAudio)
        )
    }

    private var isSeedance20Model: Bool {
        modelCode == .TOGETHER_SEEDANCE_2
    }

    private var isVeo31Model: Bool {
        modelCode == .TOGETHER_VEO_31 || modelCode == .TOGETHER_VEO_31_LITE
    }

    var isWan27Model: Bool {
        isWan27T2V || isWan27I2V || isWan27R2V
    }

    private var isWan27T2V: Bool {
        modelCode == .TOGETHER_WAN_27_T2V
    }

    private var isWan27I2V: Bool {
        modelCode == .TOGETHER_WAN_27_I2V
    }

    private var isWan27R2V: Bool {
        modelCode == .TOGETHER_WAN_27_R2V
    }

    private func wanDuration(from durationSeconds: Int?) -> Int {
        let requestedDuration = durationSeconds ?? 5
        let maxDuration = isWan27R2V ? 10 : 15
        return min(max(requestedDuration, 2), maxDuration)
    }

    private func seedanceDuration(from durationSeconds: Int?) -> Int {
        let requestedDuration = durationSeconds ?? 5
        return min(max(requestedDuration, 4), 15)
    }

    private func wanResolution(from resolution: String?) -> String {
        switch resolution?.lowercased() {
        case "720p":
            "720P"
        case "1080p":
            "1080P"
        default:
            "1080P"
        }
    }

    private func seedanceResolution(from resolution: String?) -> String {
        switch resolution?.lowercased() {
        case "480p":
            "480p"
        case "1080p":
            "1080p"
        case "4k":
            "4k"
        case "720p":
            "720p"
        default:
            "720p"
        }
    }

    private func seedanceCostPerSecond(for resolution: String?) -> Double {
        switch seedanceResolution(from: resolution) {
        case "480p":
            0.07
        case "1080p":
            0.40
        case "4k":
            0.836
        default:
            0.16
        }
    }

    private func wanRatio(from dimensions: String) -> String {
        let supportedRatios: Set = ["16:9", "9:16", "1:1", "4:3", "3:4"]
        if supportedRatios.contains(dimensions) {
            return dimensions
        }

        let parts = dimensions.lowercased().split(separator: "x")
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1]),
              width > 0,
              height > 0
        else {
            return "16:9"
        }

        let target = width / height
        let candidates: [(ratio: String, value: Double)] = [
            ("16:9", 16.0 / 9.0),
            ("9:16", 9.0 / 16.0),
            ("1:1", 1.0),
            ("4:3", 4.0 / 3.0),
            ("3:4", 3.0 / 4.0),
        ]

        return candidates.min { lhs, rhs in
            abs(lhs.value - target) < abs(rhs.value - target)
        }?.ratio ?? "16:9"
    }

    private func seedanceRatio(from dimensions: String) -> String {
        let supportedRatios: Set = ["16:9", "9:16", "1:1", "4:3", "3:4", "21:9"]
        if supportedRatios.contains(dimensions) {
            return dimensions
        }

        let parts = dimensions.lowercased().split(separator: "x")
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1]),
              width > 0,
              height > 0
        else {
            return "16:9"
        }

        let target = width / height
        let candidates: [(ratio: String, value: Double)] = [
            ("16:9", 16.0 / 9.0),
            ("9:16", 9.0 / 16.0),
            ("1:1", 1.0),
            ("4:3", 4.0 / 3.0),
            ("3:4", 3.0 / 4.0),
            ("21:9", 21.0 / 9.0),
        ]

        return candidates.min { lhs, rhs in
            abs(lhs.value - target) < abs(rhs.value - target)
        }?.ratio ?? "16:9"
    }

    private func wanMediaInput(from request: VideoGenerationRequest) -> MediaInput? {
        var frameImages: [MediaFrameImage]?
        if isWan27I2V {
            frameImages = wanFrameImages(from: request)
        }

        var referenceImages: [String]?
        if isWan27R2V {
            referenceImages = wanReferenceImages(from: request.clientReferenceImages)
        }

        guard frameImages?.isEmpty == false || referenceImages?.isEmpty == false else {
            return nil
        }

        return MediaInput(frameImages: frameImages, referenceImages: referenceImages)
    }

    private func seedanceMediaInput(from request: VideoGenerationRequest) -> MediaInput? {
        if let frameImages = seedanceFrameImages(from: request), !frameImages.isEmpty {
            return MediaInput(frameImages: frameImages)
        }

        if let referenceImages = seedanceReferenceImages(from: request.clientReferenceImages),
           !referenceImages.isEmpty
        {
            return MediaInput(referenceImages: referenceImages)
        }

        return nil
    }

    private func wanFrameImages(from request: VideoGenerationRequest) -> [MediaFrameImage]? {
        var images: [MediaFrameImage] = []

        if let clientImage = request.clientImage {
            images.append(MediaFrameImage(inputImage: cleanImageInput(clientImage), frame: "first"))
        }

        if let clientLastFrame = request.clientLastFrame {
            images.append(MediaFrameImage(inputImage: cleanImageInput(clientLastFrame), frame: "last"))
        }

        return images.isEmpty ? nil : images
    }

    private func seedanceFrameImages(from request: VideoGenerationRequest) -> [MediaFrameImage]? {
        var images: [MediaFrameImage] = []

        if let clientImage = request.clientImage {
            images.append(MediaFrameImage(inputImage: cleanImageInput(clientImage), frame: "first"))
        }

        if let clientLastFrame = request.clientLastFrame {
            images.append(MediaFrameImage(inputImage: cleanImageInput(clientLastFrame), frame: "last"))
        }

        return images.isEmpty ? nil : images
    }

    private func wanReferenceImages(from referenceImages: [ReferenceImageData]?) -> [String]? {
        let images = referenceImages?
            .prefix(4)
            .map { cleanImageInput($0.base64Image) } ?? []

        return images.isEmpty ? nil : images
    }

    private func seedanceReferenceImages(from referenceImages: [ReferenceImageData]?) -> [String]? {
        let images = referenceImages?
            .prefix(9)
            .map { cleanImageInput($0.base64Image) } ?? []

        return images.isEmpty ? nil : images
    }

    private func seedanceSettings(from generateAudio: Bool?) -> Settings? {
        guard let generateAudio else { return nil }
        return Settings(audio: generateAudio)
    }

    private func cleanImageInput(_ image: String) -> String {
        image.replacingOccurrences(
            of: "^data:.*;base64,",
            with: "",
            options: .regularExpression
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        VideoGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: "Use makeRequest directly for Together AI video models"
        )
    }

    func pollForResult(
        videoId: String,
        apiKey: String,
        maxAttempts: Int = 120
    ) async throws -> [String: Any] {
        var attempts = 0

        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 10_000_000_000)

            guard let statusURL = URL(string: "https://api.together.ai/v2/videos/\(videoId)") else {
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
                if let status = data["status"] as? String {
                    if status == "completed" {
                        return data
                    } else if status == "failed" {
                        let errorMessage = extractErrorMessage(from: data) ?? "Video generation failed"
                        throw NSError(domain: errorMessage, code: -1, userInfo: nil)
                    }
                }

                if let message = extractErrorMessage(from: data) {
                    throw NSError(domain: message, code: -1, userInfo: nil)
                }
            default:
                break
            }

            attempts += 1
        }

        throw NSError(domain: "Polling exceeded max attempts (20 minutes)", code: -1, userInfo: nil)
    }

    func extractCompletedVideoURL(from finalResult: [String: Any]) -> String? {
        guard let outputs = finalResult["outputs"] as? [String: Any] else {
            return nil
        }

        return outputs["video_url"] as? String
    }

    func extractCompletedCost(from finalResult: [String: Any]) -> Double? {
        guard let outputs = finalResult["outputs"] as? [String: Any],
              let cost = outputs["cost"]
        else {
            return nil
        }

        if let doubleCost = cost as? Double {
            return doubleCost
        }
        if let intCost = cost as? Int {
            return Double(intCost)
        }
        if let stringCost = cost as? String {
            return Double(stringCost)
        }

        return nil
    }

    func extractErrorMessage(from data: [String: Any]) -> String? {
        if let errorPayload = data["error"] as? [String: Any] {
            return errorPayload["message"] as? String
        }

        return data["error"] as? String
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

        let transformedRequest = transformRequest(request: request)

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: transformedRequest,
                headers: [
                    "Authorization": "Bearer \(request.providerSecret)",
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                ],
                attachments: nil
            )

            var videoId: String? = nil

            switch initialResponse {
            case let .dictionary(_, data):
                if let error = data["error"] as? [String: Any],
                   let message = error["message"] as? String
                {
                    return VideoGenerationResponse(
                        status: .FAILED,
                        errorCode: .MODEL_ERROR,
                        errorMessage: message,
                        rawResponse: initialResponse.rawResponseString
                    )
                }

                videoId = data["id"] as? String
            default:
                return createInvalidVideoResponseError(
                    response: initialResponse,
                    modelCode: modelCode,
                    customMessage: "Unexpected response"
                )
            }

            guard let id = videoId else {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "No video ID in response",
                    rawResponse: initialResponse.rawResponseString
                )
            }

            let finalResult = try await pollForResult(
                videoId: id,
                apiKey: request.providerSecret
            )

            guard let videoURL = extractCompletedVideoURL(from: finalResult) else {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "No video URL in completed response",
                    rawResponse: initialResponse.rawResponseString
                )
            }

            let videoData = try await downloadVideo(url: videoURL)
            let base64Video = videoData.base64EncodedString()
            let costRequest = VideoGenerationCostRequest(from: request)

            return VideoGenerationResponse(
                status: .GENERATED,
                base64: base64Video,
                cost: extractCompletedCost(from: finalResult) ?? getCostEstimate(request: costRequest),
                modelPrompt: request.prompt,
                metadata: ["togetherVideoId": id]
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

public class G_TOGETHER_MINIMAX_DIRECTOR: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_MINIMAX_DIRECTOR, modelName: "minimax/video-01-director", pricePerVideo: 0.28)
    }
}

public class G_TOGETHER_HAILUO_02: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_HAILUO_02, modelName: "minimax/hailuo-02", pricePerVideo: 0.49)
    }
}

public class G_TOGETHER_VEO_2: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_VEO_2, modelName: "google/veo-2.0", pricePerVideo: 2.50)
    }
}

public class G_TOGETHER_VEO_3_FAST: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_VEO_3_FAST, modelName: "google/veo-3.0-fast", pricePerVideo: 0.80)
    }
}

public class G_TOGETHER_SEEDANCE_LITE: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_SEEDANCE_LITE, modelName: "ByteDance/Seedance-1.0-lite", pricePerVideo: 0.14)
    }
}

public class G_TOGETHER_SEEDANCE_PRO: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_SEEDANCE_PRO, modelName: "ByteDance/Seedance-1.0-pro", pricePerVideo: 0.57)
    }
}

public class G_TOGETHER_SEEDANCE_2: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_SEEDANCE_2, modelName: "ByteDance/Seedance-2.0", pricePerVideo: 0.16)
    }
}

public class G_TOGETHER_KLING_21_PRO: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_KLING_21_PRO, modelName: "kwaivgI/kling-2.1-pro", pricePerVideo: 0.32)
    }
}

public class G_TOGETHER_WAN_27_T2V: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_WAN_27_T2V, modelName: "Wan-AI/wan2.7-t2v", pricePerVideo: 0.10)
    }
}

public class G_TOGETHER_WAN_27_I2V: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_WAN_27_I2V, modelName: "Wan-AI/wan2.7-i2v", pricePerVideo: 0.10)
    }
}

public class G_TOGETHER_PIXVERSE_V6: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_PIXVERSE_V6, modelName: "pixverse/pixverse-v6", pricePerVideo: 0.09)
    }
}

public class G_TOGETHER_SORA_2: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_SORA_2, modelName: "openai/sora-2", pricePerVideo: 0.80)
    }
}

public class G_TOGETHER_VEO_3: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_VEO_3, modelName: "google/veo-3.0", pricePerVideo: 1.60)
    }
}

public class G_TOGETHER_VEO_31: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(
            modelCode: .TOGETHER_VEO_31,
            modelName: "google/veo-3.1",
            pricePerVideo: 0,
            priceIsPublished: false
        )
    }
}

public class G_TOGETHER_VEO_31_LITE: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(
            modelCode: .TOGETHER_VEO_31_LITE,
            modelName: "google/veo-3.1-lite",
            pricePerVideo: 0,
            priceIsPublished: false
        )
    }
}

public class G_TOGETHER_VEO_3_AUDIO: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_VEO_3_AUDIO, modelName: "google/veo-3.0-audio", pricePerVideo: 3.20)
    }
}

public class G_TOGETHER_VEO_3_FAST_AUDIO: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_VEO_3_FAST_AUDIO, modelName: "google/veo-3.0-fast-audio", pricePerVideo: 1.20)
    }
}

public class G_TOGETHER_KLING_21_MASTER: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_KLING_21_MASTER, modelName: "kwaivgI/kling-2.1-master", pricePerVideo: 0.92)
    }
}

public class G_TOGETHER_KLING_21_STD: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_KLING_21_STD, modelName: "kwaivgI/kling-2.1-standard", pricePerVideo: 0.18)
    }
}

public class G_TOGETHER_KLING_20_MASTER: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_KLING_20_MASTER, modelName: "kwaivgI/kling-2.0-master", pricePerVideo: 0.92)
    }
}

public class G_TOGETHER_KLING_16_PRO: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_KLING_16_PRO, modelName: "kwaivgI/kling-1.6-pro", pricePerVideo: 0.32)
    }
}

public class G_TOGETHER_KLING_16_STD: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_KLING_16_STD, modelName: "kwaivgI/kling-1.6-standard", pricePerVideo: 0.19)
    }
}

public class G_TOGETHER_WAN_22_T2V: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_WAN_22_T2V, modelName: "Wan-AI/Wan2.2-T2V-A14B", pricePerVideo: 0.66)
    }
}

public class G_TOGETHER_WAN_22_I2V: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_WAN_22_I2V, modelName: "Wan-AI/Wan2.2-I2V-A14B", pricePerVideo: 0.31)
    }
}

public class G_TOGETHER_WAN_27_R2V: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_WAN_27_R2V, modelName: "Wan-AI/wan2.7-r2v", pricePerVideo: 0.10)
    }
}

public class G_TOGETHER_VIDU_20: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_VIDU_20, modelName: "vidu/vidu-2.0", pricePerVideo: 0.80)
    }
}

public class G_TOGETHER_VIDU_Q1: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_VIDU_Q1, modelName: "vidu/vidu-q1", pricePerVideo: 0.22)
    }
}

public class G_TOGETHER_VIDU_Q3: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_VIDU_Q3, modelName: "vidu/vidu-q3", pricePerVideo: 0.0975)
    }
}

public class G_TOGETHER_VIDU_Q3_TURBO: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_VIDU_Q3_TURBO, modelName: "vidu/vidu-q3-turbo", pricePerVideo: 0.195)
    }
}

public class G_TOGETHER_PIXVERSE_V5: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_PIXVERSE_V5, modelName: "pixverse/pixverse-v5", pricePerVideo: 0.30)
    }
}

public class G_TOGETHER_PIXVERSE_V56: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_PIXVERSE_V56, modelName: "pixverse/pixverse-v5.6", pricePerVideo: 0.1326)
    }
}

public class G_TOGETHER_SORA_2_PRO: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_SORA_2_PRO, modelName: "openai/sora-2-pro", pricePerVideo: 2.40)
    }
}

public class G_TOGETHER_HAPPY_HORSE: G_TOGETHER_VIDEO_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_HAPPY_HORSE, modelName: "alibaba/happyhorse-1.0-t2v", pricePerVideo: 0.24)
    }
}
