import Foundation

public class G_BYTEPLUS_SEEDANCE_BASE: VideoGenerationProtocol, ProviderJobControlProtocol {
    public struct ImageURL: Codable, Equatable, Sendable {
        public let url: String
    }

    public struct ContentItem: Codable, Equatable, Sendable {
        public let type: String
        public let text: String?
        public let imageURL: ImageURL?
        public let role: String?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
            case role
        }

        public init(text: String) {
            type = "text"
            self.text = text
            imageURL = nil
            role = nil
        }

        public init(imageURL: String, role: String) {
            type = "image_url"
            text = nil
            self.imageURL = ImageURL(url: imageURL)
            self.role = role
        }
    }

    public struct ServiceRequest: Codable, Equatable, Sendable {
        public let model: String
        public let content: [ContentItem]
        public let resolution: String
        public let ratio: String
        public let duration: Int
        public let generateAudio: Bool?
        public let seed: Int?
        public let cameraFixed: Bool?
        public let watermark: Bool
        public let returnLastFrame: Bool
        public let serviceTier: String?
        public let executionExpiresAfter: Int

        enum CodingKeys: String, CodingKey {
            case model
            case content
            case resolution
            case ratio
            case duration
            case generateAudio = "generate_audio"
            case seed
            case cameraFixed = "camera_fixed"
            case watermark
            case returnLastFrame = "return_last_frame"
            case serviceTier = "service_tier"
            case executionExpiresAfter = "execution_expires_after"
        }
    }

    public let modelCode: EnumProviderModelCode
    public let upstreamModel: String
    private let allowedDurations: ClosedRange<Int>
    private let allowedResolutions: Set<String>
    private let defaultResolution: String
    private let defaultDuration: Int
    private let maximumReferences: Int
    private let supportsAudioOutput: Bool
    private let supportsLastFrameInput: Bool
    private let supportsSeedControl: Bool
    private let pollingPolicy: ProviderPollingPolicy

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        modelCode: EnumProviderModelCode,
        upstreamModel: String,
        allowedDurations: ClosedRange<Int>,
        allowedResolutions: Set<String>,
        defaultResolution: String,
        defaultDuration: Int,
        maximumReferences: Int,
        supportsAudioOutput: Bool,
        supportsLastFrameInput: Bool,
        supportsSeedControl: Bool,
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        self.modelCode = modelCode
        self.upstreamModel = upstreamModel
        self.allowedDurations = allowedDurations
        self.allowedResolutions = allowedResolutions
        self.defaultResolution = defaultResolution
        self.defaultDuration = defaultDuration
        self.maximumReferences = maximumReferences
        self.supportsAudioOutput = supportsAudioOutput
        self.supportsLastFrameInput = supportsLastFrameInput
        self.supportsSeedControl = supportsSeedControl
        self.pollingPolicy = pollingPolicy
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let resolution = canonicalResolution(request.resolution)
        let duration = request.durationSeconds ?? defaultDuration
        let count = max(1, request.numberOfVideos ?? 1)
        let audio = request.generateAudio ?? supportsAudioOutput
        let dimensions = outputDimensions(resolution: resolution, ratio: request.dimensions ?? "16:9")
        let tokens = Double(dimensions.width * dimensions.height * 24 * duration) / 1024.0
        return tokens / 1_000_000.0 * pricePerMillionTokens(resolution: resolution, audio: audio)
            * Double(count)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        (try? validatedServiceRequest(from: request)) ?? ServiceRequest(
            model: upstreamModel,
            content: request.prompt.map { [ContentItem(text: $0)] } ?? [],
            resolution: canonicalResolution(request.resolution),
            ratio: request.dimensions,
            duration: request.durationSeconds ?? defaultDuration,
            generateAudio: supportsAudioOutput ? (request.generateAudio ?? true) : nil,
            seed: supportsSeedControl ? request.seed : nil,
            cameraFixed: supportsSeedControl ? false : nil,
            watermark: false,
            returnLastFrame: false,
            serviceTier: supportsSeedControl ? "default" : nil,
            executionExpiresAfter: 3600
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        guard case let .dictionary(statusCode, data) = response,
              (200 ... 299).contains(statusCode),
              (data["status"] as? String)?.lowercased() == "succeeded",
              let content = data["content"] as? [String: Any],
              let rawURL = content["video_url"] as? String,
              let usage = data["usage"] as? [String: Any],
              let completionTokens = BytePlusModelArkClient.numericDouble(usage["completion_tokens"]),
              completionTokens >= 0
        else {
            return createInvalidVideoResponseError(
                response: response,
                modelCode: modelCode,
                customMessage: "BytePlus completed without a valid billable video response."
            )
        }
        if let error = BytePlusModelArkClient.providerError(in: data) {
            return failure(message: error, rawResponse: response.rawResponseString)
        }
        do {
            let outputURL = try BytePlusModelArkClient.validatedOutputURL(rawURL)
            let resolution = (data["resolution"] as? String) ?? canonicalResolution(request.resolution)
            let audio = (data["generate_audio"] as? Bool) ?? request.generateAudio ?? supportsAudioOutput
            let duration = (data["duration"] as? Int) ?? request.durationSeconds ?? defaultDuration
            return VideoGenerationResponse(
                status: .GENERATED,
                videoUrl: outputURL.absoluteString,
                cost: completionTokens / 1_000_000.0
                    * pricePerMillionTokens(resolution: resolution, audio: audio),
                modelPrompt: request.prompt,
                rawResponse: response.rawResponseString,
                actualDimensions: (data["ratio"] as? String) ?? request.dimensions,
                actualDuration: duration
            )
        } catch {
            return failure(message: error.localizedDescription, rawResponse: response.rawResponseString)
        }
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        do {
            let credentials = try BytePlusModelArkClient.credentials(from: request.providerSecret)
            try BytePlusModelArkClient.validateAvailability(modelCode: modelCode, region: credentials.region)
            let serviceRequest = try validatedServiceRequest(from: request)
            let network = ProviderDependencies.shared.networkProvider
            let job = try await BytePlusModelArkClient.createVideoJob(
                body: serviceRequest,
                credentials: credentials,
                network: network
            )
            do {
                let final = try await BytePlusModelArkClient.poll(
                    job: job,
                    credentials: credentials,
                    network: network,
                    policy: pollingPolicy
                )
                var transformed = try transformResponse(request: request, response: final)
                guard transformed.status == .GENERATED, let rawURL = transformed.videoUrl else {
                    transformed.metadata = job.metadata
                    return transformed
                }
                let outputURL = try BytePlusModelArkClient.validatedOutputURL(rawURL)
                transformed.base64 = try await ProviderMediaMaterializer.base64(
                    from: outputURL,
                    network: network
                )
                transformed.metadata = job.metadata
                return transformed
            } catch {
                return failure(
                    message: "BytePlus video request failed: \(error.localizedDescription)",
                    metadata: job.metadata
                )
            }
        } catch {
            return failure(message: "BytePlus video request failed: \(error.localizedDescription)")
        }
    }

    public func cancel(jobId: String, providerSecret: String) async throws {
        let credentials = try BytePlusModelArkClient.credentials(from: providerSecret)
        try await BytePlusModelArkClient.cancel(
            jobId: jobId,
            credentials: credentials,
            network: ProviderDependencies.shared.networkProvider
        )
    }

    func validatedServiceRequest(from request: VideoGenerationRequest) throws -> ServiceRequest {
        guard request.clientMask?.isEmpty != false,
              request.clientVideo?.isEmpty != false,
              request.negativePrompt?.isEmpty != false,
              request.motion == nil,
              request.stickyness == nil,
              request.steps == nil,
              request.guidance == nil,
              request.safetyTolerance == nil,
              request.moderation == nil
        else {
            throw BytePlusModelArkError.invalidInput(
                "BytePlus Seedance does not accept the requested advanced controls."
            )
        }
        guard request.fps == nil || request.fps == 24 else {
            throw BytePlusModelArkError.invalidInput("BytePlus Seedance video frame rate is fixed at 24 fps.")
        }

        let prompt = request.prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (prompt?.count ?? 0) <= 6000 else {
            throw BytePlusModelArkError.invalidInput("BytePlus video prompts cannot exceed 6000 characters.")
        }
        let duration = request.durationSeconds ?? defaultDuration
        guard allowedDurations.contains(duration) else {
            throw BytePlusModelArkError.invalidInput(
                "BytePlus does not support the requested video duration for this model."
            )
        }
        let resolution = canonicalResolution(request.resolution)
        guard allowedResolutions.contains(resolution) else {
            throw BytePlusModelArkError.invalidInput(
                "BytePlus does not support the requested video resolution for this model."
            )
        }
        let source = try request.clientImage.map { try BytePlusModelArkClient.validatedImageURI($0) }
        let lastFrame = try request.clientLastFrame.map { try BytePlusModelArkClient.validatedImageURI($0) }
        let references = try (request.clientReferenceImages ?? []).map {
            try BytePlusModelArkClient.validatedImageURI($0.base64Image, mimeType: $0.mimeType)
        }
        let ratio = request.dimensions.isEmpty ? "16:9" : request.dimensions
        guard Self.supportedRatios.contains(ratio) else {
            throw BytePlusModelArkError.invalidInput("BytePlus does not support the requested video ratio.")
        }
        guard source == nil || references.isEmpty else {
            throw BytePlusModelArkError.invalidInput(
                "BytePlus frame mode cannot be combined with reference-image mode."
            )
        }
        guard lastFrame == nil || source != nil else {
            throw BytePlusModelArkError.invalidInput(
                "BytePlus last-frame generation also requires a first frame."
            )
        }
        guard supportsLastFrameInput || lastFrame == nil else {
            throw BytePlusModelArkError.invalidInput(
                "This BytePlus model does not support a last frame."
            )
        }
        guard references.count <= maximumReferences else {
            throw BytePlusModelArkError.invalidInput(
                "This BytePlus model accepts at most \(maximumReferences) reference images."
            )
        }

        let audio: Bool?
        if supportsAudioOutput {
            audio = request.generateAudio ?? true
        } else {
            guard request.generateAudio != true else {
                throw BytePlusModelArkError.invalidInput(
                    "This BytePlus model does not generate synchronized audio."
                )
            }
            audio = nil
        }
        if supportsSeedControl {
            if let seed = request.seed, !(-1 ... 4_294_967_295).contains(seed) {
                throw BytePlusModelArkError.invalidInput(
                    "BytePlus video seed must be between -1 and 4294967295."
                )
            }
        } else if request.seed != nil {
            throw BytePlusModelArkError.invalidInput(
                "Dreamina Seedance 2.0 does not support seed control."
            )
        }

        guard prompt?.isEmpty == false || source != nil || !references.isEmpty else {
            throw BytePlusModelArkError.invalidInput(
                "BytePlus video generation requires a prompt or image input."
            )
        }
        var content: [ContentItem] = []
        if let prompt, !prompt.isEmpty { content.append(ContentItem(text: prompt)) }
        if let source { content.append(ContentItem(imageURL: source, role: "first_frame")) }
        if let lastFrame { content.append(ContentItem(imageURL: lastFrame, role: "last_frame")) }
        content.append(contentsOf: references.map { ContentItem(imageURL: $0, role: "reference_image") })

        return ServiceRequest(
            model: upstreamModel,
            content: content,
            resolution: resolution,
            ratio: ratio,
            duration: duration,
            generateAudio: audio,
            seed: supportsSeedControl ? request.seed : nil,
            cameraFixed: supportsSeedControl ? false : nil,
            watermark: false,
            returnLastFrame: false,
            serviceTier: supportsSeedControl ? "default" : nil,
            executionExpiresAfter: 3600
        )
    }

    private func canonicalResolution(_ value: String?) -> String {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized?.isEmpty == false ? normalized! : defaultResolution
    }

    private func pricePerMillionTokens(resolution: String, audio: Bool) -> Double {
        switch modelCode {
        case .BYTEPLUS_DREAMINA_SEEDANCE_2_0:
            if resolution.lowercased() == "4k" { return 4.0 }
            if resolution.lowercased() == "1080p" { return 7.7 }
            return 7.0
        case .BYTEPLUS_DREAMINA_SEEDANCE_2_0_FAST:
            return 5.6
        case .BYTEPLUS_DREAMINA_SEEDANCE_2_0_MINI:
            return 3.5
        case .BYTEPLUS_SEEDANCE_1_5_PRO:
            return audio ? 2.4 : 1.2
        case .BYTEPLUS_SEEDANCE_1_0_PRO:
            return 2.5
        case .BYTEPLUS_SEEDANCE_1_0_PRO_FAST:
            return 1.0
        default:
            return 0
        }
    }

    private func outputDimensions(resolution: String, ratio: String) -> (width: Int, height: Int) {
        let normalizedRatio = ratio == "adaptive" ? "16:9" : ratio
        let usesSeedance10Table = modelCode == .BYTEPLUS_SEEDANCE_1_0_PRO
            || modelCode == .BYTEPLUS_SEEDANCE_1_0_PRO_FAST
        let table = usesSeedance10Table ? Self.seedance10Pixels : Self.seedance20And15Pixels
        return table[resolution.lowercased()]?[normalizedRatio]
            ?? table[defaultResolution]!["16:9"]!
    }

    private func failure(
        message: String,
        rawResponse: String? = nil,
        metadata: [String: String]? = nil
    ) -> VideoGenerationResponse {
        VideoGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            rawResponse: rawResponse,
            metadata: metadata
        )
    }

    private static let supportedRatios: Set = [
        "16:9", "9:16", "1:1", "4:3", "3:4", "21:9",
    ]

    private static let seedance20And15Pixels: [String: [String: (width: Int, height: Int)]] = [
        "480p": [
            "16:9": (864, 496), "4:3": (752, 560), "1:1": (640, 640),
            "3:4": (560, 752), "9:16": (496, 864), "21:9": (992, 432),
        ],
        "720p": [
            "16:9": (1280, 720), "4:3": (1112, 834), "1:1": (960, 960),
            "3:4": (834, 1112), "9:16": (720, 1280), "21:9": (1470, 630),
        ],
        "1080p": [
            "16:9": (1920, 1080), "4:3": (1664, 1248), "1:1": (1440, 1440),
            "3:4": (1248, 1664), "9:16": (1080, 1920), "21:9": (2206, 946),
        ],
        "4k": [
            "16:9": (3840, 2160), "4:3": (3326, 2494), "1:1": (2880, 2880),
            "3:4": (2494, 3326), "9:16": (2160, 3840), "21:9": (4398, 1886),
        ],
    ]

    private static let seedance10Pixels: [String: [String: (width: Int, height: Int)]] = [
        "480p": [
            "16:9": (864, 480), "4:3": (736, 544), "1:1": (640, 640),
            "3:4": (544, 736), "9:16": (480, 864), "21:9": (960, 416),
        ],
        "720p": [
            "16:9": (1248, 704), "4:3": (1120, 832), "1:1": (960, 960),
            "3:4": (832, 1120), "9:16": (704, 1248), "21:9": (1504, 640),
        ],
        "1080p": [
            "16:9": (1920, 1088), "4:3": (1664, 1248), "1:1": (1440, 1440),
            "3:4": (1248, 1664), "9:16": (1088, 1920), "21:9": (2176, 928),
        ],
    ]
}

public final class G_BYTEPLUS_DREAMINA_SEEDANCE_2_0: G_BYTEPLUS_SEEDANCE_BASE {
    public init(pollingPolicy: ProviderPollingPolicy = .init(maxAttempts: 120, intervalNanoseconds: 5_000_000_000)) {
        super.init(
            modelCode: .BYTEPLUS_DREAMINA_SEEDANCE_2_0,
            upstreamModel: "dreamina-seedance-2-0-260128",
            allowedDurations: 4 ... 15,
            allowedResolutions: ["480p", "720p", "1080p", "4k"],
            defaultResolution: "720p",
            defaultDuration: 5,
            maximumReferences: 9,
            supportsAudioOutput: true,
            supportsLastFrameInput: true,
            supportsSeedControl: false,
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_BYTEPLUS_DREAMINA_SEEDANCE_2_0_FAST: G_BYTEPLUS_SEEDANCE_BASE {
    public init(pollingPolicy: ProviderPollingPolicy = .init(maxAttempts: 120, intervalNanoseconds: 5_000_000_000)) {
        super.init(
            modelCode: .BYTEPLUS_DREAMINA_SEEDANCE_2_0_FAST,
            upstreamModel: "dreamina-seedance-2-0-fast-260128",
            allowedDurations: 4 ... 15,
            allowedResolutions: ["480p", "720p"],
            defaultResolution: "720p",
            defaultDuration: 5,
            maximumReferences: 9,
            supportsAudioOutput: true,
            supportsLastFrameInput: true,
            supportsSeedControl: false,
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_BYTEPLUS_DREAMINA_SEEDANCE_2_0_MINI: G_BYTEPLUS_SEEDANCE_BASE {
    public init(pollingPolicy: ProviderPollingPolicy = .init(maxAttempts: 120, intervalNanoseconds: 5_000_000_000)) {
        super.init(
            modelCode: .BYTEPLUS_DREAMINA_SEEDANCE_2_0_MINI,
            upstreamModel: "dreamina-seedance-2-0-mini-260615",
            allowedDurations: 4 ... 15,
            allowedResolutions: ["480p", "720p"],
            defaultResolution: "720p",
            defaultDuration: 5,
            maximumReferences: 9,
            supportsAudioOutput: true,
            supportsLastFrameInput: true,
            supportsSeedControl: false,
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_BYTEPLUS_SEEDANCE_1_5_PRO: G_BYTEPLUS_SEEDANCE_BASE {
    public init(pollingPolicy: ProviderPollingPolicy = .init(maxAttempts: 120, intervalNanoseconds: 5_000_000_000)) {
        super.init(
            modelCode: .BYTEPLUS_SEEDANCE_1_5_PRO,
            upstreamModel: "seedance-1-5-pro-251215",
            allowedDurations: 4 ... 12,
            allowedResolutions: ["480p", "720p", "1080p"],
            defaultResolution: "720p",
            defaultDuration: 5,
            maximumReferences: 0,
            supportsAudioOutput: true,
            supportsLastFrameInput: true,
            supportsSeedControl: true,
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_BYTEPLUS_SEEDANCE_1_0_PRO: G_BYTEPLUS_SEEDANCE_BASE {
    public init(pollingPolicy: ProviderPollingPolicy = .init(maxAttempts: 120, intervalNanoseconds: 5_000_000_000)) {
        super.init(
            modelCode: .BYTEPLUS_SEEDANCE_1_0_PRO,
            upstreamModel: "seedance-1-0-pro-250528",
            allowedDurations: 2 ... 12,
            allowedResolutions: ["480p", "720p", "1080p"],
            defaultResolution: "1080p",
            defaultDuration: 5,
            maximumReferences: 0,
            supportsAudioOutput: false,
            supportsLastFrameInput: true,
            supportsSeedControl: true,
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_BYTEPLUS_SEEDANCE_1_0_PRO_FAST: G_BYTEPLUS_SEEDANCE_BASE {
    public init(pollingPolicy: ProviderPollingPolicy = .init(maxAttempts: 120, intervalNanoseconds: 5_000_000_000)) {
        super.init(
            modelCode: .BYTEPLUS_SEEDANCE_1_0_PRO_FAST,
            upstreamModel: "seedance-1-0-pro-fast-251015",
            allowedDurations: 2 ... 12,
            allowedResolutions: ["480p", "720p", "1080p"],
            defaultResolution: "1080p",
            defaultDuration: 5,
            maximumReferences: 0,
            supportsAudioOutput: false,
            supportsLastFrameInput: false,
            supportsSeedControl: true,
            pollingPolicy: pollingPolicy
        )
    }
}
