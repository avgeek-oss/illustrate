// MARK: - G_MINIMAX_HAILUO_2_3_VIDEO.swift

import Foundation

public struct MiniMaxHailuoVideoRequest: Codable, Equatable, Sendable {
    let model: String
    let prompt: String
    let prompt_optimizer: Bool
    let fast_pretreatment: Bool
    let duration: Int
    let resolution: String
    let first_frame_image: String?
}

public class G_MINIMAX_HAILUO_2_3_VIDEO_BASE: VideoGenerationProtocol {
    enum Mode: Equatable {
        case textToVideo
        case imageToVideo(fast: Bool)

        var pricingMode: MiniMaxClient.VideoMode {
            switch self {
            case .textToVideo, .imageToVideo(fast: false):
                .standard
            case .imageToVideo(fast: true):
                .fast
            }
        }
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
        pollingPolicy: ProviderPollingPolicy
    ) {
        self.modelCode = modelCode
        self.modelName = modelName
        self.mode = mode
        self.pollingPolicy = pollingPolicy
    }

    public typealias ServiceRequest = MiniMaxHailuoVideoRequest

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = request.durationSeconds ?? 6
        let resolution = request.resolution ?? "768P"
        let unitCost = (try? MiniMaxClient.price(
            mode: mode.pricingMode,
            resolution: resolution,
            duration: duration
        )) ?? 0
        return unitCost * Double(max(1, request.numberOfVideos ?? 1))
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        (try? validatedServiceRequest(from: request)) ?? ServiceRequest(
            model: modelName,
            prompt: request.prompt ?? "",
            prompt_optimizer: request.promptEnhance ?? true,
            fast_pretreatment: false,
            duration: request.durationSeconds ?? 6,
            resolution: (request.resolution ?? "768P").uppercased(),
            first_frame_image: nil
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        do {
            let serviceRequest = try validatedServiceRequest(from: request)
            guard try MiniMaxClient.classify(response) == .succeeded,
                  case let .dictionary(_, data) = response,
                  let fileId = identifier(data["file_id"])
            else {
                throw MiniMaxError.invalidResponse("MiniMax task did not contain a successful file_id.")
            }
            return try VideoGenerationResponse(
                generationId: UUID(),
                status: .GENERATED,
                cost: MiniMaxClient.price(
                    mode: mode.pricingMode,
                    resolution: serviceRequest.resolution,
                    duration: serviceRequest.duration
                ),
                modelPrompt: serviceRequest.prompt,
                rawResponse: response.rawResponseString,
                metadata: ["minimaxFileId": fileId],
                actualDuration: serviceRequest.duration
            )
        } catch {
            return failure(message: error.localizedDescription, rawResponse: response.rawResponseString)
        }
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        do {
            let credentials = try MiniMaxClient.credentials(from: request.providerSecret)
            let serviceRequest = try validatedServiceRequest(from: request)
            let network = ProviderDependencies.shared.networkProvider
            let createResponse = try await MiniMaxClient.performCreate(
                body: serviceRequest,
                path: "v1/video_generation",
                credentials: credentials,
                network: network
            )
            let job = try MiniMaxClient.videoJob(from: createResponse, credentials: credentials)

            do {
                let final = try await MiniMaxClient.poll(
                    job: job,
                    credentials: credentials,
                    network: network,
                    policy: pollingPolicy
                )
                let outputURL = try await MiniMaxClient.retrieveOutputURL(
                    from: final,
                    credentials: credentials,
                    network: network
                )
                let base64 = try await MiniMaxClient.materialize(from: outputURL, network: network)
                var metadata = job.metadata
                metadata["minimaxOutputURL"] = outputURL.absoluteString
                metadata["minimaxModelId"] = serviceRequest.model
                metadata["minimaxResolution"] = serviceRequest.resolution
                metadata["minimaxDurationSeconds"] = String(serviceRequest.duration)
                if case let .dictionary(_, data) = final,
                   let fileId = identifier(data["file_id"])
                {
                    metadata["minimaxFileId"] = fileId
                }

                return try VideoGenerationResponse(
                    generationId: UUID(),
                    status: .GENERATED,
                    base64: base64,
                    videoUrl: outputURL.absoluteString,
                    cost: MiniMaxClient.price(
                        mode: mode.pricingMode,
                        resolution: serviceRequest.resolution,
                        duration: serviceRequest.duration
                    ),
                    modelPrompt: serviceRequest.prompt,
                    rawResponse: final.rawResponseString,
                    metadata: metadata,
                    actualDuration: serviceRequest.duration
                )
            } catch {
                return failure(
                    message: "MiniMax video request failed: \(error.localizedDescription)",
                    metadata: job.metadata
                )
            }
        } catch {
            return failure(message: "MiniMax video request failed: \(error.localizedDescription)")
        }
    }

    func validatedServiceRequest(from request: VideoGenerationRequest) throws -> ServiceRequest {
        let prompt = request.prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !prompt.isEmpty else {
            throw MiniMaxError.invalidInput("MiniMax requires a non-empty video prompt.")
        }
        guard prompt.count <= 2000 else {
            throw MiniMaxError.invalidInput("MiniMax video prompts cannot exceed 2000 characters.")
        }
        guard request.numberOfVideos == 1 else {
            throw MiniMaxError.invalidInput("MiniMax direct video requests generate exactly one video.")
        }
        guard request.dimensions.isEmpty else {
            throw MiniMaxError.invalidInput(
                "MiniMax direct video generation does not accept an aspect-ratio control."
            )
        }
        guard request.negativePrompt?.isEmpty != false,
              request.clientMask?.isEmpty != false,
              request.clientLastFrame?.isEmpty != false,
              request.clientVideo?.isEmpty != false,
              request.clientReferenceImages?.isEmpty != false
        else {
            throw MiniMaxError.invalidInput(
                "MiniMax Hailuo 2.3 does not accept the requested extra media controls."
            )
        }
        guard request.generateAudio == nil,
              request.motion == nil,
              request.stickyness == nil,
              request.fps == nil,
              request.steps == nil,
              request.guidance == nil,
              request.seed == nil,
              request.safetyTolerance == nil,
              request.moderation == nil,
              request.lumaHDR == nil,
              request.lumaEXRExport == nil,
              request.lumaLoop == nil
        else {
            throw MiniMaxError.invalidInput(
                "MiniMax Hailuo 2.3 does not accept the requested advanced video controls."
            )
        }

        let duration = request.durationSeconds ?? 6
        let resolution = (request.resolution ?? "768P")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        _ = try MiniMaxClient.price(
            mode: mode.pricingMode,
            resolution: resolution,
            duration: duration
        )

        let firstFrame: String?
        switch mode {
        case .textToVideo:
            guard request.clientImage?.isEmpty != false else {
                throw MiniMaxError.invalidInput("MiniMax text-to-video does not accept a first frame.")
            }
            firstFrame = nil
        case .imageToVideo:
            guard let image = request.clientImage, !image.isEmpty else {
                throw MiniMaxError.invalidInput("MiniMax image-to-video requires a first frame.")
            }
            firstFrame = try MiniMaxClient.validatedImageInput(image)
        }

        return ServiceRequest(
            model: modelName,
            prompt: prompt,
            prompt_optimizer: request.promptEnhance ?? true,
            fast_pretreatment: false,
            duration: duration,
            resolution: resolution,
            first_frame_image: firstFrame
        )
    }

    private func identifier(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
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

public final class G_MINIMAX_HAILUO_2_3_T2V: G_MINIMAX_HAILUO_2_3_VIDEO_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 10_000_000_000
        )
    ) {
        super.init(
            modelCode: .MINIMAX_HAILUO_2_3_T2V,
            modelName: "MiniMax-Hailuo-2.3",
            mode: .textToVideo,
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_MINIMAX_HAILUO_2_3_I2V: G_MINIMAX_HAILUO_2_3_VIDEO_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 10_000_000_000
        )
    ) {
        super.init(
            modelCode: .MINIMAX_HAILUO_2_3_I2V,
            modelName: "MiniMax-Hailuo-2.3",
            mode: .imageToVideo(fast: false),
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_MINIMAX_HAILUO_2_3_FAST_I2V: G_MINIMAX_HAILUO_2_3_VIDEO_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 10_000_000_000
        )
    ) {
        super.init(
            modelCode: .MINIMAX_HAILUO_2_3_FAST_I2V,
            modelName: "MiniMax-Hailuo-2.3-Fast",
            mode: .imageToVideo(fast: true),
            pollingPolicy: pollingPolicy
        )
    }
}
