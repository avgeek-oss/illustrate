// MARK: - G_LTX_2_3.swift

import Foundation

public class G_LTX_2_3_BASE: VideoGenerationProtocol {
    public let modelCode: EnumProviderModelCode
    public let modelName: String
    private let pollingPolicy: ProviderPollingPolicy

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        modelCode: EnumProviderModelCode,
        modelName: String,
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        self.modelCode = modelCode
        self.modelName = modelName
        self.pollingPolicy = pollingPolicy
    }

    public struct ServiceRequest: Codable, Equatable, Sendable {
        public let prompt: String
        public let model: String
        public let duration: Int
        public let fps: Int
        public let resolution: String
        public let generate_audio: Bool
        public let image_uri: String?
        public let last_frame_uri: String?

        public init(
            prompt: String,
            model: String,
            duration: Int,
            fps: Int,
            resolution: String,
            generateAudio: Bool,
            imageURI: String? = nil,
            lastFrameURI: String? = nil
        ) {
            self.prompt = prompt
            self.model = model
            self.duration = duration
            self.fps = fps
            self.resolution = resolution
            generate_audio = generateAudio
            image_uri = imageURI
            last_frame_uri = lastFrameURI
        }
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let resolution = canonicalPricingResolution(
            resolution: request.resolution,
            dimensions: request.dimensions
        )
        let duration = request.durationSeconds ?? 6
        let count = max(1, request.numberOfVideos ?? 1)
        return pricePerSecond(for: resolution) * Double(duration) * Double(count)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        (try? validatedServiceRequest(from: request)) ?? ServiceRequest(
            prompt: request.prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            model: modelName,
            duration: request.durationSeconds ?? 6,
            fps: request.fps ?? 24,
            resolution: "1920x1080",
            generateAudio: request.generateAudio ?? true
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        let serviceRequest = try validatedServiceRequest(from: request)
        do {
            let outputURL = try LTXJobClient.completedVideoURL(from: response)
            return VideoGenerationResponse(
                status: .GENERATED,
                videoUrl: outputURL.absoluteString,
                cost: pricePerSecond(for: serviceRequest.resolution) * Double(serviceRequest.duration),
                modelPrompt: serviceRequest.prompt,
                rawResponse: response.rawResponseString,
                actualDimensions: serviceRequest.resolution,
                actualDuration: serviceRequest.duration
            )
        } catch {
            return failure(message: error.localizedDescription, rawResponse: response.rawResponseString)
        }
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        do {
            let credentials = try ProviderCredentialConfiguration(secret: request.providerSecret)
            let apiKey = try credentials.requireAPIKey()
            let serviceRequest = try validatedServiceRequest(from: request)
            let endpoint: LTXJobClient.EndpointFamily = serviceRequest.image_uri == nil
                ? .textToVideo
                : .imageToVideo
            let network = ProviderDependencies.shared.networkProvider
            let job = try await LTXJobClient.create(
                endpoint: endpoint,
                body: serviceRequest,
                apiKey: apiKey,
                network: network
            )

            do {
                let final = try await LTXJobClient.poll(
                    job: job,
                    apiKey: apiKey,
                    network: network,
                    policy: pollingPolicy
                )
                var transformed = try transformResponse(request: request, response: final)
                guard transformed.status == .GENERATED else {
                    transformed.metadata = job.metadata
                    return transformed
                }

                let materialized = try await LTXJobClient.materialize(
                    response: final,
                    network: network
                )
                transformed.base64 = materialized.base64
                transformed.rawResponse = final.rawResponseString
                var metadata = job.metadata
                metadata["ltxOutputURL"] = materialized.outputURL.absoluteString
                metadata["ltxModelId"] = serviceRequest.model
                metadata["ltxResolution"] = serviceRequest.resolution
                metadata["ltxFPS"] = String(serviceRequest.fps)
                metadata["ltxDurationSeconds"] = String(serviceRequest.duration)
                metadata["ltxGenerateAudio"] = String(serviceRequest.generate_audio)
                if case let .dictionary(_, data) = final,
                   let completedAt = data["completed_at"] as? String,
                   !completedAt.isEmpty
                {
                    metadata["ltxCompletedAt"] = completedAt
                }
                transformed.metadata = metadata
                return transformed
            } catch {
                return failure(
                    message: "LTX video request failed: \(error.localizedDescription)",
                    metadata: job.metadata
                )
            }
        } catch {
            return failure(message: "LTX video request failed: \(error.localizedDescription)")
        }
    }

    func validatedServiceRequest(from request: VideoGenerationRequest) throws -> ServiceRequest {
        let prompt = request.prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !prompt.isEmpty else {
            throw LTXAdapterError.invalidInput("LTX requires a non-empty prompt.")
        }
        guard request.numberOfVideos == 1 else {
            throw LTXAdapterError.invalidInput("LTX supports one video per request.")
        }
        guard request.clientVideo?.isEmpty != false else {
            throw LTXAdapterError.invalidInput("LTX text and image generation do not accept a source video.")
        }
        guard request.clientMask?.isEmpty != false else {
            throw LTXAdapterError.invalidInput("LTX video generation does not accept an image mask.")
        }
        guard request.clientReferenceImages?.isEmpty != false else {
            throw LTXAdapterError.invalidInput("LTX accepts one source image and one optional last frame.")
        }

        let resolution = try resolvedResolution(request: request)
        let fps = request.fps ?? 24
        let duration = request.durationSeconds ?? 6
        try validateCombination(resolution: resolution, fps: fps, duration: duration)

        let imageURI = try request.clientImage.map(LTXJobClient.validatedImageURI)
        let lastFrameURI: String?
        if let lastFrame = request.clientLastFrame {
            guard imageURI != nil else {
                throw LTXAdapterError.invalidInput("LTX last-frame control requires a source image.")
            }
            lastFrameURI = try LTXJobClient.validatedImageURI(lastFrame)
        } else {
            lastFrameURI = nil
        }

        return ServiceRequest(
            prompt: prompt,
            model: modelName,
            duration: duration,
            fps: fps,
            resolution: resolution,
            generateAudio: request.generateAudio ?? true,
            imageURI: imageURI,
            lastFrameURI: lastFrameURI
        )
    }

    private func resolvedResolution(request: VideoGenerationRequest) throws -> String {
        let dimensions = request.dimensions.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedResolution = request.resolution?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let requested = normalizedResolution?.isEmpty == false ? normalizedResolution : nil

        if let requested, Self.exactResolutions.contains(requested) {
            try validateOrientationCompatibility(dimensions: dimensions, resolution: requested)
            return requested
        }

        if let requested, let tier = Self.resolutionTier(of: requested) {
            if Self.exactResolutions.contains(dimensions), Self.resolutionTier(of: dimensions) != tier {
                throw LTXAdapterError.invalidInput(
                    "LTX resolution tier conflicts with the requested output dimensions."
                )
            }
            let portrait = try isPortrait(dimensions: dimensions)
            return Self.resolution(tier: tier, portrait: portrait)
        }

        if requested != nil {
            throw LTXAdapterError.invalidInput("LTX resolution must be 1080p, 1440p, or 4K.")
        }
        if Self.exactResolutions.contains(dimensions) {
            return dimensions
        }
        return try Self.resolution(tier: "1080p", portrait: isPortrait(dimensions: dimensions))
    }

    private func validateOrientationCompatibility(dimensions: String, resolution: String) throws {
        if dimensions == "16:9", Self.isPortraitResolution(resolution) {
            throw LTXAdapterError.invalidInput("LTX output resolution conflicts with landscape orientation.")
        }
        if dimensions == "9:16", !Self.isPortraitResolution(resolution) {
            throw LTXAdapterError.invalidInput("LTX output resolution conflicts with portrait orientation.")
        }
        if Self.exactResolutions.contains(dimensions), dimensions != resolution {
            throw LTXAdapterError.invalidInput("LTX output dimensions conflict with the requested resolution.")
        }
        if dimensions != "16:9", dimensions != "9:16", !Self.exactResolutions.contains(dimensions) {
            throw LTXAdapterError.invalidInput("LTX supports 16:9 and 9:16 output orientations.")
        }
    }

    private func isPortrait(dimensions: String) throws -> Bool {
        if dimensions == "9:16" { return true }
        if dimensions == "16:9" { return false }
        if Self.exactResolutions.contains(dimensions) { return Self.isPortraitResolution(dimensions) }
        throw LTXAdapterError.invalidInput("LTX supports 16:9 and 9:16 output orientations.")
    }

    private func validateCombination(resolution: String, fps: Int, duration: Int) throws {
        guard [24, 25, 48, 50].contains(fps) else {
            throw LTXAdapterError.invalidInput("LTX frame rate must be 24, 25, 48, or 50 fps.")
        }

        let tier = Self.resolutionTier(of: resolution) ?? "1080p"
        let allowedDurations: Set<Int> = if modelCode == .LTX_2_3_FAST, tier == "1080p", fps == 24 || fps == 25 {
            [6, 8, 10, 12, 14, 16, 18, 20]
        } else {
            [6, 8, 10]
        }
        guard allowedDurations.contains(duration) else {
            let values = allowedDurations.sorted().map(String.init).joined(separator: ", ")
            throw LTXAdapterError.invalidInput(
                "LTX \(modelName) at \(tier)/\(fps) fps supports durations: \(values) seconds."
            )
        }
    }

    private func canonicalPricingResolution(resolution: String?, dimensions: String?) -> String {
        if let resolution, let tier = Self.resolutionTier(of: resolution) { return tier }
        if let dimensions, let tier = Self.resolutionTier(of: dimensions) { return tier }
        return "1080p"
    }

    private func pricePerSecond(for resolution: String) -> Double {
        let tier = Self.resolutionTier(of: resolution) ?? "1080p"
        return switch (modelCode, tier) {
        case (.LTX_2_3_FAST, "1440p"):
            0.12
        case (.LTX_2_3_FAST, "4K"):
            0.24
        case (.LTX_2_3_PRO, "1440p"):
            0.16
        case (.LTX_2_3_PRO, "4K"):
            0.32
        case (.LTX_2_3_PRO, _):
            0.08
        default:
            0.06
        }
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

    private static let exactResolutions: Set = [
        "1920x1080", "1080x1920",
        "2560x1440", "1440x2560",
        "3840x2160", "2160x3840",
    ]

    private static func resolutionTier(of value: String) -> String? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1080p", "1920x1080", "1080x1920":
            "1080p"
        case "1440p", "2560x1440", "1440x2560":
            "1440p"
        case "4k", "3840x2160", "2160x3840":
            "4K"
        default:
            nil
        }
    }

    private static func resolution(tier: String, portrait: Bool) -> String {
        switch (tier, portrait) {
        case ("1440p", false): "2560x1440"
        case ("1440p", true): "1440x2560"
        case ("4K", false): "3840x2160"
        case ("4K", true): "2160x3840"
        case (_, true): "1080x1920"
        default: "1920x1080"
        }
    }

    private static func isPortraitResolution(_ resolution: String) -> Bool {
        ["1080x1920", "1440x2560", "2160x3840"].contains(resolution)
    }
}

public final class G_LTX_2_3_FAST: G_LTX_2_3_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        super.init(
            modelCode: .LTX_2_3_FAST,
            modelName: "ltx-2-3-fast",
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_LTX_2_3_PRO: G_LTX_2_3_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        super.init(
            modelCode: .LTX_2_3_PRO,
            modelName: "ltx-2-3-pro",
            pollingPolicy: pollingPolicy
        )
    }
}
