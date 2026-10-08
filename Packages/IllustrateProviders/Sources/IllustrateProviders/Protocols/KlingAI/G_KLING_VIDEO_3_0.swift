// MARK: - G_KLING_VIDEO_3_0.swift

import Foundation

public struct KlingVideo30Request: Codable, Equatable, Sendable {
    let model_name: String
    let prompt: String
    let negative_prompt: String?
    let sound: String
    let mode: String
    let aspect_ratio: String
    let duration: String
    let image: String?
    let image_tail: String?
    let watermark: Bool
}

public class G_KLING_VIDEO_3_0_BASE: VideoGenerationProtocol {
    enum Mode: Equatable {
        case textToVideo
        case imageToVideo
    }

    public let modelCode: EnumProviderModelCode
    private let mode: Mode
    private let pollingPolicy: ProviderPollingPolicy

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    init(
        modelCode: EnumProviderModelCode,
        mode: Mode,
        pollingPolicy: ProviderPollingPolicy
    ) {
        self.modelCode = modelCode
        self.mode = mode
        self.pollingPolicy = pollingPolicy
    }

    public typealias ServiceRequest = KlingVideo30Request

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = request.durationSeconds ?? 5
        let resolution = request.resolution ?? "720P"
        let unitCost = (try? KlingAIClient.videoPricePerSecond(
            resolution: resolution,
            audio: request.generateAudio ?? false
        )) ?? 0
        return unitCost * Double(duration * max(1, request.numberOfVideos ?? 1))
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        (try? validatedServiceRequest(from: request)) ?? ServiceRequest(
            model_name: "kling-v3",
            prompt: request.prompt ?? "",
            negative_prompt: request.negativePrompt,
            sound: request.generateAudio == true ? "on" : "off",
            mode: apiMode(for: request.resolution ?? "720P") ?? "std",
            aspect_ratio: request.dimensions.isEmpty ? "16:9" : request.dimensions,
            duration: String(request.durationSeconds ?? 5),
            image: nil,
            image_tail: nil,
            watermark: false
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        do {
            let serviceRequest = try validatedServiceRequest(from: request)
            let outputURL = try KlingAIClient.outputURL(from: response, kind: .video)
            let resolution = canonicalResolution(request.resolution)
            let duration = Int(serviceRequest.duration) ?? 5
            return try VideoGenerationResponse(
                generationId: UUID(),
                status: .GENERATED,
                videoUrl: outputURL.absoluteString,
                cost: KlingAIClient.videoPricePerSecond(
                    resolution: resolution,
                    audio: serviceRequest.sound == "on"
                ) * Double(duration),
                modelPrompt: serviceRequest.prompt,
                rawResponse: response.rawResponseString,
                metadata: ["klingOutputURL": outputURL.absoluteString],
                actualDimensions: serviceRequest.aspect_ratio,
                actualDuration: duration
            )
        } catch {
            return failure(message: error.localizedDescription, rawResponse: response.rawResponseString)
        }
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        do {
            let credentials = try KlingAIClient.credentials(from: request.providerSecret)
            let serviceRequest = try validatedServiceRequest(from: request)
            let endpoint = mode == .textToVideo
                ? "v1/videos/text2video"
                : "v1/videos/image2video"
            let network = ProviderDependencies.shared.networkProvider
            let job = try await KlingAIClient.create(
                body: serviceRequest,
                endpoint: endpoint,
                credentials: credentials,
                network: network
            )

            do {
                let final = try await KlingAIClient.poll(
                    job: job,
                    credentials: credentials,
                    network: network,
                    policy: pollingPolicy
                )
                let materialized = try await KlingAIClient.materialize(
                    response: final,
                    kind: .video,
                    network: network
                )
                let resolution = canonicalResolution(request.resolution)
                let duration = Int(serviceRequest.duration) ?? 5
                var metadata = job.metadata
                metadata["klingOutputURL"] = materialized.url.absoluteString
                metadata["klingModelId"] = serviceRequest.model_name
                metadata["klingResolution"] = resolution
                metadata["klingDurationSeconds"] = serviceRequest.duration
                metadata["klingSound"] = serviceRequest.sound
                return try VideoGenerationResponse(
                    generationId: UUID(),
                    status: .GENERATED,
                    base64: materialized.base64,
                    videoUrl: materialized.url.absoluteString,
                    cost: KlingAIClient.videoPricePerSecond(
                        resolution: resolution,
                        audio: serviceRequest.sound == "on"
                    ) * Double(duration),
                    modelPrompt: serviceRequest.prompt,
                    rawResponse: final.rawResponseString,
                    metadata: metadata,
                    actualDimensions: serviceRequest.aspect_ratio,
                    actualDuration: duration
                )
            } catch {
                return failure(
                    message: "Kling video request failed: \(error.localizedDescription)",
                    metadata: job.metadata
                )
            }
        } catch {
            return failure(message: "Kling video request failed: \(error.localizedDescription)")
        }
    }

    func validatedServiceRequest(from request: VideoGenerationRequest) throws -> ServiceRequest {
        let prompt = request.prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !prompt.isEmpty else {
            throw KlingAIError.invalidInput("Kling requires a non-empty video prompt.")
        }
        guard prompt.count <= 2500 else {
            throw KlingAIError.invalidInput("Kling video prompts cannot exceed 2500 characters.")
        }
        let negativePrompt = request.negativePrompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (negativePrompt?.count ?? 0) <= 2500 else {
            throw KlingAIError.invalidInput("Kling negative prompts cannot exceed 2500 characters.")
        }
        guard request.numberOfVideos == 1 else {
            throw KlingAIError.invalidInput("Kling direct video requests generate exactly one video.")
        }
        let duration = request.durationSeconds ?? 5
        guard (3 ... 15).contains(duration) else {
            throw KlingAIError.invalidInput("Kling Video 3.0 duration must be between 3 and 15 seconds.")
        }
        let ratio = request.dimensions.isEmpty ? "16:9" : request.dimensions
        guard ["16:9", "9:16", "1:1"].contains(ratio) else {
            throw KlingAIError.invalidInput("Kling Video 3.0 does not support the requested aspect ratio.")
        }
        let resolution = canonicalResolution(request.resolution)
        guard let apiMode = apiMode(for: resolution) else {
            throw KlingAIError.invalidInput("Kling video resolution must be 720p, 1080p, or 4K.")
        }
        _ = try KlingAIClient.videoPricePerSecond(
            resolution: resolution,
            audio: request.generateAudio ?? false
        )
        guard request.clientMask?.isEmpty != false,
              request.clientVideo?.isEmpty != false,
              request.clientReferenceImages?.isEmpty != false
        else {
            throw KlingAIError.invalidInput(
                "Kling Video 3.0 does not accept masks, clips, or extra references."
            )
        }
        try validateUnsupportedControls(request)

        let firstFrame: String?
        let finalFrame: String?
        switch mode {
        case .textToVideo:
            guard request.clientImage?.isEmpty != false,
                  request.clientLastFrame?.isEmpty != false
            else {
                throw KlingAIError.invalidInput("Kling text-to-video does not accept source frames.")
            }
            firstFrame = nil
            finalFrame = nil
        case .imageToVideo:
            let image = try request.clientImage.map(KlingAIClient.normalizedImageInput)
            let tail = try request.clientLastFrame.map(KlingAIClient.normalizedImageInput)
            guard image != nil || tail != nil else {
                throw KlingAIError.invalidInput(
                    "Kling image-to-video requires an initial or final frame."
                )
            }
            firstFrame = image
            finalFrame = tail
        }

        return ServiceRequest(
            model_name: "kling-v3",
            prompt: prompt,
            negative_prompt: negativePrompt?.isEmpty == false ? negativePrompt : nil,
            sound: request.generateAudio == true ? "on" : "off",
            mode: apiMode,
            aspect_ratio: ratio,
            duration: String(duration),
            image: firstFrame,
            image_tail: finalFrame,
            watermark: false
        )
    }

    private func validateUnsupportedControls(_ request: VideoGenerationRequest) throws {
        guard request.searchPrompt?.isEmpty != false,
              request.motion == nil,
              request.stickyness == nil,
              request.fps == nil,
              request.steps == nil,
              request.guidance == nil,
              request.seed == nil,
              request.safetyTolerance == nil,
              request.promptEnhance == nil,
              request.moderation == nil,
              request.sourceMetadata == nil,
              request.lumaHDR == nil,
              request.lumaEXRExport == nil,
              request.lumaLoop == nil
        else {
            throw KlingAIError.invalidInput(
                "Kling Video 3.0 does not accept the requested advanced video controls."
            )
        }
    }

    private func canonicalResolution(_ value: String?) -> String {
        let resolution = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "720P"
        return resolution.uppercased()
    }

    private func apiMode(for resolution: String) -> String? {
        switch resolution.uppercased() {
        case "720P": "std"
        case "1080P": "pro"
        case "4K": "4k"
        default: nil
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
}

public final class G_KLING_VIDEO_3_0_T2V: G_KLING_VIDEO_3_0_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        super.init(
            modelCode: .KLING_VIDEO_3_0_T2V,
            mode: .textToVideo,
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_KLING_VIDEO_3_0_I2V: G_KLING_VIDEO_3_0_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        super.init(
            modelCode: .KLING_VIDEO_3_0_I2V,
            mode: .imageToVideo,
            pollingPolicy: pollingPolicy
        )
    }
}
