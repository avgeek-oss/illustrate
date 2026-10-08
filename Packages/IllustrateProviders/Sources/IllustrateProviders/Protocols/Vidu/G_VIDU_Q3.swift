// MARK: - G_VIDU_Q3.swift

import Foundation

public class G_VIDU_Q3_BASE: VideoGenerationProtocol, ProviderJobControlProtocol {
    public let modelCode: EnumProviderModelCode
    public let serviceModel: String
    public let pricesByResolution: [String: Double]
    private let pollingPolicy: ProviderPollingPolicy

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        modelCode: EnumProviderModelCode,
        serviceModel: String,
        pricesByResolution: [String: Double],
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        self.modelCode = modelCode
        self.serviceModel = serviceModel
        self.pricesByResolution = pricesByResolution
        self.pollingPolicy = pollingPolicy
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let resolution = request.resolution ?? "720p"
        let price = pricesByResolution[resolution] ?? pricesByResolution["720p"] ?? 0
        return price
            * Double(request.durationSeconds ?? 5)
            * Double(max(1, request.numberOfVideos ?? 1))
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public struct ServiceRequest: Codable, Sendable {
        public let model: String
        public let prompt: String
        public let duration: Int
        public let aspectRatio: String
        public let resolution: String
        public let audio: Bool
        public let seed: Int?

        enum CodingKeys: String, CodingKey {
            case model, prompt, duration, resolution, audio, seed
            case aspectRatio = "aspect_ratio"
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        (try? serviceRequest(from: request)) ?? ServiceRequest(
            model: serviceModel,
            prompt: request.prompt ?? "",
            duration: request.durationSeconds ?? 5,
            aspectRatio: request.dimensions,
            resolution: request.resolution ?? "720p",
            audio: request.generateAudio ?? true,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        guard case let .dictionary(code, data) = response,
              (200 ... 299).contains(code),
              (data["state"] as? String)?.lowercased() == "success",
              let creations = data["creations"] as? [[String: Any]],
              let output = creations.first?["url"] as? String,
              URL(string: output)?.scheme?.lowercased() == "https"
        else {
            return createInvalidVideoResponseError(
                response: response,
                modelCode: modelCode,
                customMessage: "Vidu completed without a valid video URL."
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
            return failure(message: "Invalid Vidu generation URL.")
        }
        do {
            let credentials = try ProviderCredentialConfiguration(secret: request.providerSecret)
            let apiKey = try credentials.requireAPIKey()
            let body = try serviceRequest(from: request)
            let network = ProviderDependencies.shared.networkProvider
            let job = try await ViduTaskClient.create(url: url, body: body, apiKey: apiKey, network: network)
            do {
                let final = try await ViduTaskClient.poll(
                    job: job,
                    apiKey: apiKey,
                    network: network,
                    policy: pollingPolicy
                )
                var transformed = try transformResponse(request: request, response: final)
                guard transformed.status == .GENERATED else { return transformed }
                let materialized = try await ViduTaskClient.materialize(response: final, network: network)
                transformed.base64 = materialized.base64
                var metadata = job.metadata
                metadata["viduOutputURL"] = materialized.outputURL.absoluteString
                transformed.metadata = metadata
                return transformed
            } catch {
                return failure(
                    message: "Vidu video request failed: \(error.localizedDescription)",
                    metadata: job.metadata
                )
            }
        } catch {
            return failure(message: "Vidu video request failed: \(error.localizedDescription)")
        }
    }

    public func cancel(jobId: String, providerSecret: String) async throws {
        let credentials = try ProviderCredentialConfiguration(secret: providerSecret)
        try await ViduTaskClient.cancel(
            jobId: jobId,
            apiKey: credentials.requireAPIKey(),
            network: ProviderDependencies.shared.networkProvider
        )
    }

    private func serviceRequest(from request: VideoGenerationRequest) throws -> ServiceRequest {
        guard request.clientImage?.isEmpty != false,
              request.clientLastFrame?.isEmpty != false,
              request.clientVideo?.isEmpty != false,
              request.clientReferenceImages?.isEmpty != false
        else {
            throw ViduAdapterError.invalidInput("Vidu Q3 text-to-video does not accept source media.")
        }
        let duration = request.durationSeconds ?? 5
        guard (1 ... 16).contains(duration) else {
            throw ViduAdapterError.invalidInput("Vidu Q3 duration must be between 1 and 16 seconds.")
        }
        let ratios = Set(["16:9", "9:16", "3:4", "4:3", "1:1"])
        guard ratios.contains(request.dimensions) else {
            throw ViduAdapterError.invalidInput("Vidu Q3 does not support the requested aspect ratio.")
        }
        let resolution = request.resolution ?? "720p"
        guard pricesByResolution[resolution] != nil else {
            throw ViduAdapterError.invalidInput("Vidu Q3 resolution must be 540p, 720p, or 1080p.")
        }
        return try ServiceRequest(
            model: serviceModel,
            prompt: ViduTaskClient.validatedPrompt(request.prompt ?? ""),
            duration: duration,
            aspectRatio: request.dimensions,
            resolution: resolution,
            audio: request.generateAudio ?? true,
            seed: ViduTaskClient.validatedSeed(request.seed)
        )
    }

    private func atomicCost(_ request: VideoGenerationRequest) -> Double {
        let resolution = request.resolution ?? "720p"
        return (pricesByResolution[resolution] ?? pricesByResolution["720p"] ?? 0)
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

public final class G_VIDU_Q3_PRO: G_VIDU_Q3_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        super.init(
            modelCode: .VIDU_Q3_PRO,
            serviceModel: "viduq3-pro",
            pricesByResolution: ["540p": 0.045, "720p": 0.10, "1080p": 0.12],
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_VIDU_Q3_TURBO: G_VIDU_Q3_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        super.init(
            modelCode: .VIDU_Q3_TURBO,
            serviceModel: "viduq3-turbo",
            pricesByResolution: ["540p": 0.035, "720p": 0.055, "1080p": 0.065],
            pollingPolicy: pollingPolicy
        )
    }
}
