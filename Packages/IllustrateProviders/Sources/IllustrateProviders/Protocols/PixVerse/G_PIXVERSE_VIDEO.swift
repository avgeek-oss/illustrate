// MARK: - G_PIXVERSE_VIDEO.swift

import Foundation

public class G_PIXVERSE_VIDEO_BASE: VideoGenerationProtocol {
    public let modelCode: EnumProviderModelCode
    public let serviceModel: String
    public let silentCredits: [String: Double]
    public let audioCredits: [String: Double]
    private let pollingPolicy: ProviderPollingPolicy

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        modelCode: EnumProviderModelCode,
        serviceModel: String,
        silentCredits: [String: Double],
        audioCredits: [String: Double],
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        self.modelCode = modelCode
        self.serviceModel = serviceModel
        self.silentCredits = silentCredits
        self.audioCredits = audioCredits
        self.pollingPolicy = pollingPolicy
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let table = request.generateAudio == true ? audioCredits : silentCredits
        let resolution = request.resolution ?? "720p"
        let credits = table[resolution] ?? table["720p"] ?? 0
        return credits
            * Double(request.durationSeconds ?? 5)
            * Double(max(1, request.numberOfVideos ?? 1))
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let value = getCostEstimate(request: request)
        return String(format: value == floor(value) ? "%.0f credits" : "%.1f credits", value)
    }

    public struct ServiceRequest: Codable, Sendable {
        public let model: String
        public let prompt: String
        public let duration: Int
        public let aspectRatio: String
        public let quality: String
        public let generateAudio: Bool
        public let seed: Int?

        enum CodingKeys: String, CodingKey {
            case model, prompt, duration, quality, seed
            case aspectRatio = "aspect_ratio"
            case generateAudio = "generate_audio_switch"
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        (try? serviceRequest(from: request)) ?? ServiceRequest(
            model: serviceModel,
            prompt: request.prompt ?? "",
            duration: request.durationSeconds ?? 5,
            aspectRatio: request.dimensions,
            quality: request.resolution ?? "720p",
            generateAudio: request.generateAudio ?? false,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        guard case let .dictionary(code, data) = response,
              (200 ... 299).contains(code),
              data["ErrCode"] as? Int == 0,
              let payload = data["Resp"] as? [String: Any],
              payload["status"] as? Int == 1,
              let output = payload["url"] as? String,
              URL(string: output)?.scheme?.lowercased() == "https"
        else {
            return createInvalidVideoResponseError(
                response: response,
                modelCode: modelCode,
                customMessage: "PixVerse completed without a valid video URL."
            )
        }
        return VideoGenerationResponse(
            status: .GENERATED,
            videoUrl: output,
            cost: atomicCost(request),
            modelPrompt: request.prompt,
            rawResponse: response.rawResponseString,
            actualDimensions: request.dimensions,
            actualDuration: request.durationSeconds ?? 5
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = model.generateURL else {
            return failure(message: "Invalid PixVerse generation URL.")
        }
        do {
            let credentials = try ProviderCredentialConfiguration(secret: request.providerSecret)
            let apiKey = try credentials.requireAPIKey()
            let body = try serviceRequest(from: request)
            let network = ProviderDependencies.shared.networkProvider
            let job = try await PixVerseTaskClient.create(
                url: url,
                body: body,
                apiKey: apiKey,
                network: network
            )
            do {
                let final = try await PixVerseTaskClient.poll(
                    job: job,
                    apiKey: apiKey,
                    network: network,
                    policy: pollingPolicy
                )
                var transformed = try transformResponse(request: request, response: final)
                guard transformed.status == .GENERATED else { return transformed }
                let materialized = try await PixVerseTaskClient.materialize(response: final, network: network)
                transformed.base64 = materialized.base64
                var metadata = job.metadata
                metadata["pixVerseOutputURL"] = materialized.outputURL.absoluteString
                transformed.metadata = metadata
                return transformed
            } catch {
                return failure(
                    message: "PixVerse video request failed: \(error.localizedDescription)",
                    metadata: job.metadata
                )
            }
        } catch {
            return failure(message: "PixVerse video request failed: \(error.localizedDescription)")
        }
    }

    private func serviceRequest(from request: VideoGenerationRequest) throws -> ServiceRequest {
        guard request.clientImage?.isEmpty != false,
              request.clientLastFrame?.isEmpty != false,
              request.clientVideo?.isEmpty != false,
              request.clientReferenceImages?.isEmpty != false
        else {
            throw PixVerseAdapterError.invalidInput("PixVerse text-to-video does not accept source media.")
        }
        let duration = request.durationSeconds ?? 5
        guard (1 ... 15).contains(duration) else {
            throw PixVerseAdapterError.invalidInput("PixVerse duration must be between 1 and 15 seconds.")
        }
        let ratios = Set(["16:9", "4:3", "1:1", "3:4", "9:16", "2:3", "3:2", "21:9"])
        guard ratios.contains(request.dimensions) else {
            throw PixVerseAdapterError.invalidInput("PixVerse does not support the requested aspect ratio.")
        }
        let quality = request.resolution ?? "720p"
        guard silentCredits[quality] != nil else {
            throw PixVerseAdapterError.invalidInput("PixVerse quality must be 360p, 540p, 720p, or 1080p.")
        }
        return try ServiceRequest(
            model: serviceModel,
            prompt: PixVerseTaskClient.validatedPrompt(request.prompt ?? ""),
            duration: duration,
            aspectRatio: request.dimensions,
            quality: quality,
            generateAudio: request.generateAudio ?? false,
            seed: PixVerseTaskClient.validatedSeed(request.seed)
        )
    }

    private func atomicCost(_ request: VideoGenerationRequest) -> Double {
        let table = request.generateAudio == true ? audioCredits : silentCredits
        return (table[request.resolution ?? "720p"] ?? table["720p"] ?? 0)
            * Double(request.durationSeconds ?? 5)
    }

    private func failure(message: String, metadata: [String: String]? = nil) -> VideoGenerationResponse {
        VideoGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            metadata: metadata
        )
    }
}

public final class G_PIXVERSE_C1: G_PIXVERSE_VIDEO_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        super.init(
            modelCode: .PIXVERSE_C1,
            serviceModel: "c1",
            silentCredits: ["360p": 6, "540p": 8, "720p": 10, "1080p": 19],
            audioCredits: ["360p": 8, "540p": 10, "720p": 13, "1080p": 24],
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_PIXVERSE_V6: G_PIXVERSE_VIDEO_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        super.init(
            modelCode: .PIXVERSE_V6,
            serviceModel: "v6",
            silentCredits: ["360p": 5, "540p": 7, "720p": 9, "1080p": 18],
            audioCredits: ["360p": 7, "540p": 9, "720p": 12, "1080p": 23],
            pollingPolicy: pollingPolicy
        )
    }
}
