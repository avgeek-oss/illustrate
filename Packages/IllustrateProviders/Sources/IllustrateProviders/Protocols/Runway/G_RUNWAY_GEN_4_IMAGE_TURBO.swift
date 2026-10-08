// MARK: - G_RUNWAY_GEN_4_IMAGE_TURBO.swift

import Foundation

public final class G_RUNWAY_GEN_4_IMAGE_TURBO: ImageGenerationProtocol, ProviderJobControlProtocol {
    public let modelCode = EnumProviderModelCode.RUNWAY_GEN_4_IMAGE_TURBO
    public let unitPrice = 0.02
    private let pollingPolicy: ProviderPollingPolicy

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        self.pollingPolicy = pollingPolicy
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        unitPrice * Double(max(1, request.numberOfImages ?? 1))
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public struct ContentModeration: Codable, Sendable {
        public let publicFigureThreshold: String

        public init(publicFigureThreshold: String) {
            self.publicFigureThreshold = publicFigureThreshold
        }
    }

    public struct ReferenceImage: Codable, Sendable {
        public let uri: String
        public let tag: String?

        public init(uri: String, tag: String? = nil) {
            self.uri = uri
            self.tag = tag
        }
    }

    public struct ServiceRequest: Codable, Sendable {
        public let model: String
        public let promptText: String
        public let ratio: String
        public let referenceImages: [ReferenceImage]
        public let contentModeration: ContentModeration?
        public let seed: Int?

        public init(
            model: String = "gen4_image_turbo",
            promptText: String,
            ratio: String,
            referenceImages: [ReferenceImage],
            contentModeration: ContentModeration? = nil,
            seed: Int? = nil
        ) {
            self.model = model
            self.promptText = promptText
            self.ratio = ratio
            self.referenceImages = referenceImages
            self.contentModeration = contentModeration
            self.seed = seed
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        (try? serviceRequest(from: request)) ?? ServiceRequest(
            promptText: request.prompt,
            ratio: request.dimensions,
            referenceImages: []
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        guard case let .dictionary(statusCode, data) = response,
              (200 ... 299).contains(statusCode),
              (data["status"] as? String)?.uppercased() == "SUCCEEDED",
              let outputs = data["output"] as? [String],
              let output = outputs.first,
              URL(string: output)?.scheme?.lowercased() == "https"
        else {
            return createInvalidResponseError(
                response: response,
                modelCode: modelCode,
                customMessage: "Runway completed without a valid image URL."
            )
        }

        return ImageGenerationResponse(
            status: .GENERATED,
            cost: unitPrice,
            modelPrompt: request.prompt,
            rawResponse: output,
            actualDimensions: request.dimensions
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = model.generateURL else {
            return failure(message: "Invalid Runway image generation URL.")
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
                    message: "Runway image request failed: \(error.localizedDescription)",
                    metadata: job.metadata
                )
            }
        } catch {
            return failure(message: "Runway image request failed: \(error.localizedDescription)")
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

    private func serviceRequest(from request: ImageGenerationRequest) throws -> ServiceRequest {
        guard Self.supportedRatios.contains(request.dimensions) else {
            throw RunwayAdapterError.invalidInput("Runway Gen-4 Image Turbo does not support the requested ratio.")
        }

        let moderation = try RunwayTaskClient.validatedModeration(request.moderation)
        return try ServiceRequest(
            promptText: RunwayTaskClient.validatedPrompt(request.prompt),
            ratio: request.dimensions,
            referenceImages: Self.referenceImages(from: request),
            contentModeration: moderation.map(ContentModeration.init),
            seed: RunwayTaskClient.validatedSeed(request.seed)
        )
    }

    private static func referenceImages(from request: ImageGenerationRequest) throws -> [ReferenceImage] {
        var images: [ReferenceImage] = []
        if let source = request.clientImage {
            try images.append(ReferenceImage(
                uri: RunwayTaskClient.validatedImageURI(source)
            ))
        }

        for reference in request.clientReferenceImages ?? [] {
            let tag = reference.referenceType.trimmingCharacters(in: .whitespacesAndNewlines)
            try images.append(ReferenceImage(
                uri: RunwayTaskClient.validatedImageURI(
                    reference.base64Image,
                    mimeType: reference.mimeType
                ),
                tag: tag.isEmpty ? nil : tag
            ))
        }

        guard (1 ... 3).contains(images.count) else {
            throw RunwayAdapterError.invalidInput("Runway Gen-4 Image Turbo requires one to three reference images.")
        }
        return images
    }

    private func failure(
        message: String,
        metadata: [String: String]? = nil
    ) -> ImageGenerationResponse {
        ImageGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            metadata: metadata
        )
    }

    private static let supportedRatios: Set = [
        "1024:1024", "1080:1080", "1168:880", "1360:768",
        "1440:1080", "1080:1440", "1808:768", "1920:1080",
        "1080:1920", "2112:912", "1280:720", "720:1280",
        "720:720", "960:720", "720:960", "1680:720",
    ]
}
