// MARK: - G_ALIBABA_WAN_2_7_VIDEO.swift

import Foundation

public struct AlibabaWanVideoTaskRequest: Codable, Equatable, Sendable {
    struct Input: Codable, Equatable {
        struct Media: Codable, Equatable {
            let type: String
            let url: String
        }

        let prompt: String
        let negative_prompt: String?
        let media: [Media]?
    }

    struct Parameters: Codable, Equatable {
        let resolution: String
        let ratio: String?
        let duration: Int
        let prompt_extend: Bool
        let watermark: Bool
        let seed: Int?
    }

    let model: String
    let input: Input
    let parameters: Parameters
}

public class G_ALIBABA_WAN_2_7_VIDEO_BASE: VideoGenerationProtocol {
    enum Mode: Equatable {
        case textToVideo
        case imageToVideo
    }

    public let modelCode: EnumProviderModelCode
    public let modelName: String
    private let mode: Mode
    private let pollingPolicy: ProviderPollingPolicy

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    init(
        modelCode: EnumProviderModelCode,
        modelName: String,
        mode: Mode,
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 40,
            intervalNanoseconds: 15_000_000_000
        )
    ) {
        self.modelCode = modelCode
        self.modelName = modelName
        self.mode = mode
        self.pollingPolicy = pollingPolicy
    }

    public typealias ServiceRequest = AlibabaWanVideoTaskRequest

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let resolution = canonicalResolution(request.resolution)
        let duration = request.durationSeconds ?? 5
        let count = max(1, request.numberOfVideos ?? 1)
        return AlibabaModelStudioClient.pricePerVideoSecond(
            resolution: resolution,
            region: pricingRegion(for: request.providerSecret)
        ) * Double(duration * count)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    private func pricingRegion(for providerSecret: String?) -> AlibabaModelStudioClient.Region {
        guard let providerSecret,
              let credentials = try? AlibabaModelStudioClient.credentials(from: providerSecret)
        else {
            return .singapore
        }
        return credentials.region
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        (try? validatedServiceRequest(from: request)) ?? ServiceRequest(
            model: modelName,
            input: .init(
                prompt: request.prompt ?? "",
                negative_prompt: request.negativePrompt,
                media: nil
            ),
            parameters: .init(
                resolution: "1080P",
                ratio: mode == .textToVideo ? "16:9" : nil,
                duration: request.durationSeconds ?? 5,
                prompt_extend: request.promptEnhance ?? true,
                watermark: false,
                seed: request.seed
            )
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        do {
            let serviceRequest = try validatedServiceRequest(from: request)
            let outputURL = try AlibabaModelStudioClient.outputURL(from: response, kind: .video)
            return VideoGenerationResponse(
                generationId: UUID(),
                status: .GENERATED,
                videoUrl: outputURL.absoluteString,
                cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
                modelPrompt: serviceRequest.input.prompt,
                rawResponse: response.rawResponseString,
                metadata: ["alibabaOutputURL": outputURL.absoluteString],
                actualDimensions: request.dimensions,
                actualDuration: serviceRequest.parameters.duration
            )
        } catch {
            return failure(message: error.localizedDescription, rawResponse: response.rawResponseString)
        }
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        do {
            let credentials = try AlibabaModelStudioClient.credentials(from: request.providerSecret)
            let serviceRequest = try validatedServiceRequest(from: request)
            let network = ProviderDependencies.shared.networkProvider
            let job = try await AlibabaModelStudioClient.create(
                body: serviceRequest,
                path: "api/v1/services/aigc/video-generation/video-synthesis",
                credentials: credentials,
                network: network
            )

            do {
                let final = try await AlibabaModelStudioClient.poll(
                    job: job,
                    credentials: credentials,
                    network: network,
                    policy: pollingPolicy
                )
                let materialized = try await AlibabaModelStudioClient.materialize(
                    response: final,
                    kind: .video,
                    network: network
                )
                var metadata = job.metadata
                metadata["alibabaOutputURL"] = materialized.url.absoluteString
                metadata["alibabaModelId"] = serviceRequest.model
                metadata["alibabaResolution"] = serviceRequest.parameters.resolution
                metadata["alibabaDurationSeconds"] = String(serviceRequest.parameters.duration)
                metadata["alibabaPromptExtend"] = String(serviceRequest.parameters.prompt_extend)

                let price = AlibabaModelStudioClient.pricePerVideoSecond(
                    resolution: serviceRequest.parameters.resolution,
                    region: credentials.region
                ) * Double(serviceRequest.parameters.duration)
                return VideoGenerationResponse(
                    generationId: UUID(),
                    status: .GENERATED,
                    base64: materialized.base64,
                    videoUrl: materialized.url.absoluteString,
                    cost: price,
                    modelPrompt: serviceRequest.input.prompt,
                    rawResponse: final.rawResponseString,
                    metadata: metadata,
                    actualDimensions: request.dimensions,
                    actualDuration: serviceRequest.parameters.duration
                )
            } catch {
                return failure(
                    message: "Alibaba video request failed: \(error.localizedDescription)",
                    metadata: job.metadata
                )
            }
        } catch {
            return failure(message: "Alibaba video request failed: \(error.localizedDescription)")
        }
    }

    func validatedServiceRequest(from request: VideoGenerationRequest) throws -> ServiceRequest {
        let prompt = request.prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !prompt.isEmpty else {
            throw AlibabaModelStudioError.invalidInput("Alibaba requires a non-empty video prompt.")
        }
        guard prompt.count <= 5000 else {
            throw AlibabaModelStudioError.invalidInput("Alibaba video prompts cannot exceed 5000 characters.")
        }
        let negativePrompt = request.negativePrompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (negativePrompt?.count ?? 0) <= 500 else {
            throw AlibabaModelStudioError.invalidInput(
                "Alibaba negative prompts cannot exceed 500 characters."
            )
        }
        guard request.numberOfVideos == 1 else {
            throw AlibabaModelStudioError.invalidInput("Alibaba generates exactly one video per request.")
        }
        guard request.clientMask?.isEmpty != false,
              request.clientReferenceImages?.isEmpty != false
        else {
            throw AlibabaModelStudioError.invalidInput(
                "Alibaba Wan 2.7 video does not accept masks or extra reference images."
            )
        }
        guard request.generateAudio != false else {
            throw AlibabaModelStudioError.invalidInput(
                "Alibaba Wan 2.7 automatically generates audio and has no silent-output control."
            )
        }
        guard request.fps == nil,
              request.motion == nil,
              request.stickyness == nil,
              request.steps == nil,
              request.guidance == nil,
              request.safetyTolerance == nil,
              request.moderation == nil
        else {
            throw AlibabaModelStudioError.invalidInput(
                "Alibaba Wan 2.7 does not accept the requested advanced video controls."
            )
        }

        let duration = request.durationSeconds ?? 5
        guard (2 ... 15).contains(duration) else {
            throw AlibabaModelStudioError.invalidInput(
                "Alibaba Wan 2.7 duration must be between 2 and 15 seconds."
            )
        }
        let resolution = canonicalResolution(request.resolution)
        guard ["720P", "1080P"].contains(resolution) else {
            throw AlibabaModelStudioError.invalidInput("Alibaba video resolution must be 720p or 1080p.")
        }
        if let seed = request.seed, !(0 ... 2_147_483_647).contains(seed) {
            throw AlibabaModelStudioError.invalidInput(
                "Alibaba seed must be between 0 and 2147483647."
            )
        }

        let media: [ServiceRequest.Input.Media]?
        let ratio: String?
        switch mode {
        case .textToVideo:
            guard request.clientImage?.isEmpty != false,
                  request.clientLastFrame?.isEmpty != false,
                  request.clientVideo?.isEmpty != false
            else {
                throw AlibabaModelStudioError.invalidInput(
                    "Alibaba text-to-video does not accept source media."
                )
            }
            let requestedRatio = request.dimensions.isEmpty ? "16:9" : request.dimensions
            guard ["16:9", "9:16", "1:1", "4:3", "3:4"].contains(requestedRatio) else {
                throw AlibabaModelStudioError.invalidInput(
                    "Alibaba text-to-video does not support the requested aspect ratio."
                )
            }
            media = nil
            ratio = requestedRatio

        case .imageToVideo:
            let hasImage = request.clientImage?.isEmpty == false
            let hasVideo = request.clientVideo?.isEmpty == false
            guard hasImage != hasVideo else {
                throw AlibabaModelStudioError.invalidInput(
                    "Alibaba image-to-video requires one first frame or one first clip."
                )
            }
            var values: [ServiceRequest.Input.Media] = []
            if let image = request.clientImage, hasImage {
                try values.append(.init(
                    type: "first_frame",
                    url: AlibabaModelStudioClient.validatedImageInput(image)
                ))
            }
            if let video = request.clientVideo, hasVideo {
                try values.append(.init(
                    type: "first_clip",
                    url: AlibabaModelStudioClient.validatedVideoURL(video)
                ))
            }
            if let lastFrame = request.clientLastFrame, !lastFrame.isEmpty {
                try values.append(.init(
                    type: "last_frame",
                    url: AlibabaModelStudioClient.validatedImageInput(lastFrame)
                ))
            }
            media = values
            ratio = nil
        }

        return ServiceRequest(
            model: modelName,
            input: .init(
                prompt: prompt,
                negative_prompt: negativePrompt?.isEmpty == false ? negativePrompt : nil,
                media: media
            ),
            parameters: .init(
                resolution: resolution,
                ratio: ratio,
                duration: duration,
                prompt_extend: request.promptEnhance ?? true,
                watermark: false,
                seed: request.seed
            )
        )
    }

    private func canonicalResolution(_ value: String?) -> String {
        guard let value else { return "1080P" }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
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

public final class G_ALIBABA_WAN_2_7_T2V: G_ALIBABA_WAN_2_7_VIDEO_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 40,
            intervalNanoseconds: 15_000_000_000
        )
    ) {
        super.init(
            modelCode: .ALIBABA_WAN_2_7_T2V,
            modelName: "wan2.7-t2v",
            mode: .textToVideo,
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_ALIBABA_WAN_2_7_I2V: G_ALIBABA_WAN_2_7_VIDEO_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 40,
            intervalNanoseconds: 15_000_000_000
        )
    ) {
        super.init(
            modelCode: .ALIBABA_WAN_2_7_I2V,
            modelName: "wan2.7-i2v",
            mode: .imageToVideo,
            pollingPolicy: pollingPolicy
        )
    }
}
