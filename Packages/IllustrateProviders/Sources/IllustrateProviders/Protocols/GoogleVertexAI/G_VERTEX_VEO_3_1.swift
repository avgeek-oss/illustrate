// MARK: - G_VERTEX_VEO_3_1.swift

import Foundation

public class G_VERTEX_VEO_3_1_BASE: VideoGenerationProtocol {
    public let modelCode: EnumProviderModelCode
    public let upstreamModelId: String
    private let pollingPolicy: ProviderPollingPolicy

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        modelCode: EnumProviderModelCode,
        upstreamModelId: String,
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        self.modelCode = modelCode
        self.upstreamModelId = upstreamModelId
        self.pollingPolicy = pollingPolicy
    }

    public struct ServiceRequest: Codable, Equatable, Sendable {
        public let instances: [Instance]
        public let parameters: Parameters

        public struct Instance: Codable, Equatable, Sendable {
            public let prompt: String
            public let image: Media?
            public let lastFrame: Media?
        }

        public struct Media: Codable, Equatable, Sendable {
            public let bytesBase64Encoded: String
            public let mimeType: String
        }

        public struct Parameters: Codable, Equatable, Sendable {
            public let aspectRatio: String
            public let durationSeconds: Int
            public let enhancePrompt: Bool
            public let generateAudio: Bool
            public let negativePrompt: String?
            public let personGeneration: String
            public let resolution: String
            public let sampleCount: Int
            public let seed: Int?
        }
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = request.durationSeconds ?? 8
        let count = max(1, request.numberOfVideos ?? 1)
        let resolution = canonicalResolution(request.resolution)
        let audio = request.generateAudio ?? true
        return pricePerSecond(resolution: resolution, audio: audio) * Double(duration * count)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        (try? validatedRequest(from: request)) ?? ServiceRequest(
            instances: [.init(prompt: request.prompt ?? "", image: nil, lastFrame: nil)],
            parameters: .init(
                aspectRatio: request.dimensions,
                durationSeconds: request.durationSeconds ?? 8,
                enhancePrompt: request.promptEnhance ?? true,
                generateAudio: request.generateAudio ?? true,
                negativePrompt: request.negativePrompt,
                personGeneration: "allow_adult",
                resolution: canonicalResolution(request.resolution),
                sampleCount: 1,
                seed: request.seed
            )
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        do {
            let data = try VertexAIClient.response(from: response, operation: "video status")
            guard data["done"] as? Bool == true else {
                throw VertexAIError.invalidResponse("Vertex AI video operation is not complete.")
            }
            let media = try VertexVeoTaskClient.video(from: data)
            let serviceRequest = try validatedRequest(from: request)
            return VideoGenerationResponse(
                status: .GENERATED,
                base64: media.base64,
                cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
                modelPrompt: serviceRequest.instances[0].prompt,
                rawResponse: response.rawResponseString,
                metadata: [
                    "vertexModelId": upstreamModelId,
                    "vertexMimeType": media.mimeType,
                    "vertexGenerateAudio": String(serviceRequest.parameters.generateAudio),
                ],
                actualDimensions: serviceRequest.parameters.resolution,
                actualDuration: serviceRequest.parameters.durationSeconds
            )
        } catch {
            return failure(error.localizedDescription, rawResponse: response.rawResponseString)
        }
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        do {
            let configuration = try VertexAIConfiguration(secret: request.providerSecret)
            let serviceRequest = try validatedRequest(from: request)
            let network = ProviderDependencies.shared.networkProvider
            let job = try await VertexVeoTaskClient.create(
                modelId: upstreamModelId,
                body: serviceRequest,
                configuration: configuration,
                network: network
            )
            do {
                let final = try await VertexVeoTaskClient.poll(
                    job: job,
                    configuration: configuration,
                    network: network,
                    policy: pollingPolicy
                )
                var transformed = try transformResponse(request: request, response: final)
                var metadata = transformed.metadata ?? [:]
                metadata.merge(job.metadata) { current, _ in current }
                metadata["vertexProjectId"] = configuration.projectId
                metadata["vertexLocation"] = configuration.location
                transformed.metadata = metadata
                return transformed
            } catch {
                return failure(
                    "Vertex AI video request failed: \(error.localizedDescription)",
                    metadata: job.metadata
                )
            }
        } catch {
            return failure("Vertex AI video request failed: \(error.localizedDescription)")
        }
    }

    func validatedRequest(from request: VideoGenerationRequest) throws -> ServiceRequest {
        let prompt = request.prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !prompt.isEmpty else {
            throw VertexAIError.invalidInput("Vertex AI requires a non-empty video prompt.")
        }
        guard request.numberOfVideos == 1 else {
            throw VertexAIError.invalidInput("Vertex AI requests exactly one video per atomic operation.")
        }
        guard request.clientVideo?.isEmpty != false else {
            throw VertexAIError.invalidInput("Vertex Veo 3.1 does not accept source-video extension here.")
        }
        guard request.clientMask?.isEmpty != false else {
            throw VertexAIError.invalidInput("Vertex Veo 3.1 does not accept a mask.")
        }
        guard request.clientReferenceImages?.isEmpty != false else {
            throw VertexAIError.invalidInput("Vertex Veo 3.1 direct GA models exclude reference-image mode.")
        }
        guard request.fps == nil || request.fps == 24 else {
            throw VertexAIError.invalidInput("Vertex Veo 3.1 outputs 24 fps.")
        }

        let duration = request.durationSeconds ?? 8
        guard [4, 6, 8].contains(duration) else {
            throw VertexAIError.invalidInput("Vertex Veo 3.1 duration must be 4, 6, or 8 seconds.")
        }
        let ratio = request.dimensions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ["16:9", "9:16"].contains(ratio) else {
            throw VertexAIError.invalidInput("Vertex Veo 3.1 aspect ratio must be 16:9 or 9:16.")
        }
        let resolution = canonicalResolution(request.resolution)
        if let seed = request.seed, seed < 0 || UInt64(seed) > UInt64(UInt32.max) {
            throw VertexAIError.invalidInput("Vertex Veo seed must fit an unsigned 32-bit integer.")
        }

        let firstFrame = try request.clientImage.map(media)
        let lastFrame: ServiceRequest.Media?
        if let value = request.clientLastFrame {
            guard firstFrame != nil else {
                throw VertexAIError.invalidInput("Vertex Veo last-frame control requires a first frame.")
            }
            lastFrame = try media(value)
        } else {
            lastFrame = nil
        }

        return ServiceRequest(
            instances: [.init(prompt: prompt, image: firstFrame, lastFrame: lastFrame)],
            parameters: .init(
                aspectRatio: ratio,
                durationSeconds: duration,
                enhancePrompt: request.promptEnhance ?? true,
                generateAudio: request.generateAudio ?? true,
                negativePrompt: request.negativePrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
                personGeneration: request.moderation == "disallow_people" ? "disallow" : "allow_adult",
                resolution: resolution,
                sampleCount: 1,
                seed: request.seed
            )
        )
    }

    private func media(_ value: String) throws -> ServiceRequest.Media {
        let input = try VertexAIClient.imageInput(value)
        return .init(bytesBase64Encoded: input.data, mimeType: input.mimeType)
    }

    private func canonicalResolution(_ value: String?) -> String {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1080p", "1080": "1080p"
        default: "720p"
        }
    }

    private func pricePerSecond(resolution: String, audio: Bool) -> Double {
        if modelCode == .VERTEX_VEO_3_1_FAST {
            return switch (resolution, audio) {
            case ("1080p", true): 0.12
            case ("1080p", false): 0.10
            case (_, true): 0.10
            default: 0.08
            }
        }
        return audio ? 0.40 : 0.20
    }

    private func failure(
        _ message: String,
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

public final class G_VERTEX_VEO_3_1: G_VERTEX_VEO_3_1_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        super.init(
            modelCode: .VERTEX_VEO_3_1,
            upstreamModelId: "veo-3.1-generate-001",
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_VERTEX_VEO_3_1_FAST: G_VERTEX_VEO_3_1_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        super.init(
            modelCode: .VERTEX_VEO_3_1_FAST,
            upstreamModelId: "veo-3.1-fast-generate-001",
            pollingPolicy: pollingPolicy
        )
    }
}
