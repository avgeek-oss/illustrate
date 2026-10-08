// MARK: - G_RUNWAY_GEN_4_5.swift

import Foundation

public class G_RUNWAY_GEN_4_5_BASE: VideoGenerationProtocol, ProviderJobControlProtocol {
    public enum Mode: Sendable {
        case textToVideo
        case imageToVideo
    }

    public let modelCode: EnumProviderModelCode
    public let mode: Mode
    public let pricePerSecond = 0.12
    private let pollingPolicy: ProviderPollingPolicy

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        modelCode: EnumProviderModelCode,
        mode: Mode,
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        self.modelCode = modelCode
        self.mode = mode
        self.pollingPolicy = pollingPolicy
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        pricePerSecond
            * Double(request.durationSeconds ?? 5)
            * Double(max(1, request.numberOfVideos ?? 1))
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public struct ContentModeration: Codable, Sendable {
        public let publicFigureThreshold: String

        public init(publicFigureThreshold: String) {
            self.publicFigureThreshold = publicFigureThreshold
        }
    }

    public struct ServiceRequest: Codable, Sendable {
        public let model: String
        public let promptText: String
        public let ratio: String
        public let duration: Int
        public let promptImage: String?
        public let contentModeration: ContentModeration?
        public let seed: Int?

        public init(
            model: String = "gen4.5",
            promptText: String,
            ratio: String,
            duration: Int,
            promptImage: String? = nil,
            contentModeration: ContentModeration? = nil,
            seed: Int? = nil
        ) {
            self.model = model
            self.promptText = promptText
            self.ratio = ratio
            self.duration = duration
            self.promptImage = promptImage
            self.contentModeration = contentModeration
            self.seed = seed
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        (try? serviceRequest(from: request)) ?? ServiceRequest(
            promptText: request.prompt ?? "",
            ratio: request.dimensions,
            duration: request.durationSeconds ?? 5
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        guard case let .dictionary(statusCode, data) = response,
              (200 ... 299).contains(statusCode),
              (data["status"] as? String)?.uppercased() == "SUCCEEDED",
              let outputs = data["output"] as? [String],
              let output = outputs.first,
              URL(string: output)?.scheme?.lowercased() == "https"
        else {
            return createInvalidVideoResponseError(
                response: response,
                modelCode: modelCode,
                customMessage: "Runway completed without a valid video URL."
            )
        }

        return VideoGenerationResponse(
            status: .GENERATED,
            videoUrl: output,
            cost: atomicCost(request),
            modelPrompt: request.prompt,
            rawResponse: output,
            actualDimensions: request.dimensions,
            actualDuration: request.durationSeconds ?? 5
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = model.generateURL else {
            return failure(message: "Invalid Runway video generation URL.")
        }

        do {
            let credentials = try ProviderCredentialConfiguration(secret: request.providerSecret)
            let apiKey = try credentials.requireAPIKey()
            let serviceRequest = try serviceRequest(from: request)
            let network = ProviderDependencies.shared.networkProvider
            let job = try await RunwayTaskClient.create(
                url: url,
                body: serviceRequest,
                apiKey: apiKey,
                network: network
            )

            do {
                let final = try await RunwayTaskClient.poll(
                    job: job,
                    apiKey: apiKey,
                    network: network,
                    policy: pollingPolicy
                )
                var transformed = try transformResponse(request: request, response: final)
                guard transformed.status == .GENERATED else { return transformed }

                let materialized = try await RunwayTaskClient.materialize(
                    response: final,
                    network: network
                )
                transformed.base64 = materialized.base64
                transformed.rawResponse = final.rawResponseString
                var metadata = job.metadata
                metadata["runwayOutputURL"] = materialized.outputURL.absoluteString
                transformed.metadata = metadata
                return transformed
            } catch {
                return failure(
                    message: "Runway video request failed: \(error.localizedDescription)",
                    metadata: job.metadata
                )
            }
        } catch {
            return failure(message: "Runway video request failed: \(error.localizedDescription)")
        }
    }

    public func cancel(jobId: String, providerSecret: String) async throws {
        let credentials = try ProviderCredentialConfiguration(secret: providerSecret)
        try await RunwayTaskClient.cancel(
            jobId: jobId,
            apiKey: credentials.requireAPIKey(),
            network: ProviderDependencies.shared.networkProvider
        )
    }

    private func serviceRequest(from request: VideoGenerationRequest) throws -> ServiceRequest {
        let prompt = try RunwayTaskClient.validatedPrompt(request.prompt ?? "")
        let duration = request.durationSeconds ?? 5
        guard (2 ... 10).contains(duration) else {
            throw RunwayAdapterError.invalidInput("Runway Gen-4.5 duration must be between 2 and 10 seconds.")
        }
        guard supportedRatios.contains(request.dimensions) else {
            throw RunwayAdapterError.invalidInput("Runway Gen-4.5 does not support the requested ratio for this mode.")
        }
        guard request.clientReferenceImages?.isEmpty != false else {
            throw RunwayAdapterError.invalidInput("Runway Gen-4.5 does not accept additional reference images.")
        }

        let promptImage: String?
        switch mode {
        case .textToVideo:
            guard request.clientImage?.isEmpty != false else {
                throw RunwayAdapterError.invalidInput(
                    "Runway Gen-4.5 text-to-video does not accept an input image; select the image-to-video model."
                )
            }
            promptImage = nil
        case .imageToVideo:
            guard let image = request.clientImage else {
                throw RunwayAdapterError.invalidInput("Runway Gen-4.5 image-to-video requires an input image.")
            }
            promptImage = try RunwayTaskClient.validatedImageURI(image)
        }

        let moderation = try RunwayTaskClient.validatedModeration(request.moderation)
        return try ServiceRequest(
            promptText: prompt,
            ratio: request.dimensions,
            duration: duration,
            promptImage: promptImage,
            contentModeration: moderation.map(ContentModeration.init),
            seed: RunwayTaskClient.validatedSeed(request.seed)
        )
    }

    private var supportedRatios: Set<String> {
        switch mode {
        case .textToVideo:
            ["1280:720", "720:1280"]
        case .imageToVideo:
            ["1280:720", "720:1280", "1104:832", "832:1104", "960:960", "1584:672"]
        }
    }

    private func atomicCost(_ request: VideoGenerationRequest) -> Double {
        pricePerSecond * Double(request.durationSeconds ?? 5)
    }

    private func failure(
        message: String,
        metadata: [String: String]? = nil
    ) -> VideoGenerationResponse {
        VideoGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            metadata: metadata
        )
    }
}

public final class G_RUNWAY_GEN_4_5: G_RUNWAY_GEN_4_5_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        super.init(
            modelCode: .RUNWAY_GEN_4_5,
            mode: .textToVideo,
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_RUNWAY_GEN_4_5_I2V: G_RUNWAY_GEN_4_5_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        super.init(
            modelCode: .RUNWAY_GEN_4_5_I2V,
            mode: .imageToVideo,
            pollingPolicy: pollingPolicy
        )
    }
}
