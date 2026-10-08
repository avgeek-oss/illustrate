// MARK: - G_KLING_IMAGE_3_0.swift

import Foundation

public final class G_KLING_IMAGE_3_0: ImageGenerationProtocol {
    public let modelCode = EnumProviderModelCode.KLING_IMAGE_3_0
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

    public struct ServiceRequest: Codable, Equatable, Sendable {
        public let model_name: String
        public let prompt: String
        public let negative_prompt: String?
        public let image: String?
        public let resolution: String
        public let n: Int
        public let aspect_ratio: String
        public let watermark: Bool
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let resolution = request.resolution ?? "1K"
        let unitCost = (try? KlingAIClient.imagePrice(omni: false, resolution: resolution)) ?? 0
        return unitCost * Double(max(1, request.numberOfImages ?? 1))
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        (try? validatedServiceRequest(from: request)) ?? ServiceRequest(
            model_name: "kling-v3",
            prompt: request.prompt,
            negative_prompt: request.negativePrompt,
            image: nil,
            resolution: (request.resolution ?? "1K").lowercased(),
            n: 1,
            aspect_ratio: request.dimensions.isEmpty ? "1:1" : request.dimensions,
            watermark: false
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        do {
            let serviceRequest = try validatedServiceRequest(from: request)
            let outputURL = try KlingAIClient.outputURL(from: response, kind: .image)
            return try ImageGenerationResponse(
                generationId: UUID(),
                status: .GENERATED,
                cost: KlingAIClient.imagePrice(
                    omni: false,
                    resolution: serviceRequest.resolution
                ),
                modelPrompt: serviceRequest.prompt,
                rawResponse: response.rawResponseString,
                metadata: ["klingOutputURL": outputURL.absoluteString],
                actualDimensions: serviceRequest.aspect_ratio
            )
        } catch {
            return failure(message: error.localizedDescription, rawResponse: response.rawResponseString)
        }
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        do {
            let credentials = try KlingAIClient.credentials(from: request.providerSecret)
            let serviceRequest = try validatedServiceRequest(from: request)
            let network = ProviderDependencies.shared.networkProvider
            let job = try await KlingAIClient.create(
                body: serviceRequest,
                endpoint: "v1/images/generations",
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
                    kind: .image,
                    network: network
                )
                var metadata = job.metadata
                metadata["klingOutputURL"] = materialized.url.absoluteString
                metadata["klingModelId"] = serviceRequest.model_name
                metadata["klingResolution"] = serviceRequest.resolution
                return try ImageGenerationResponse(
                    generationId: UUID(),
                    status: .GENERATED,
                    base64: materialized.base64,
                    cost: KlingAIClient.imagePrice(
                        omni: false,
                        resolution: serviceRequest.resolution
                    ),
                    modelPrompt: serviceRequest.prompt,
                    rawResponse: final.rawResponseString,
                    metadata: metadata,
                    actualDimensions: serviceRequest.aspect_ratio
                )
            } catch {
                return failure(
                    message: "Kling image request failed: \(error.localizedDescription)",
                    metadata: job.metadata
                )
            }
        } catch {
            return failure(message: "Kling image request failed: \(error.localizedDescription)")
        }
    }

    func validatedServiceRequest(from request: ImageGenerationRequest) throws -> ServiceRequest {
        let prompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            throw KlingAIError.invalidInput("Kling requires a non-empty image prompt.")
        }
        guard prompt.count <= 2500 else {
            throw KlingAIError.invalidInput("Kling image prompts cannot exceed 2500 characters.")
        }
        guard request.numberOfImages == 1 else {
            throw KlingAIError.invalidInput("Kling direct image requests generate exactly one image.")
        }
        let ratio = request.dimensions.isEmpty ? "1:1" : request.dimensions
        let ratios = ["16:9", "9:16", "1:1", "4:3", "3:4", "3:2", "2:3", "21:9"]
        guard ratios.contains(ratio) else {
            throw KlingAIError.invalidInput("Kling Image 3.0 does not support the requested aspect ratio.")
        }
        let resolution = (request.resolution ?? "1K").uppercased()
        _ = try KlingAIClient.imagePrice(omni: false, resolution: resolution)
        guard request.clientMask?.isEmpty != false,
              request.clientReferenceImages?.isEmpty != false
        else {
            throw KlingAIError.invalidInput("Kling classic image accepts only one optional source image.")
        }
        let source = try request.clientImage.map(KlingAIClient.normalizedImageInput)
        let negativePrompt = request.negativePrompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard source == nil || negativePrompt?.isEmpty != false else {
            throw KlingAIError.invalidInput(
                "Kling classic image does not accept a negative prompt with a source image."
            )
        }
        try validateUnsupportedControls(request)
        return ServiceRequest(
            model_name: "kling-v3",
            prompt: prompt,
            negative_prompt: negativePrompt?.isEmpty == false ? negativePrompt : nil,
            image: source,
            resolution: resolution.lowercased(),
            n: 1,
            aspect_ratio: ratio,
            watermark: false
        )
    }

    private func validateUnsupportedControls(_ request: ImageGenerationRequest) throws {
        guard request.searchPrompt?.isEmpty != false,
              request.variant.isEmpty,
              request.quality.isEmpty,
              request.style.isEmpty,
              request.editDirection == nil,
              request.steps == nil,
              request.guidance == nil,
              request.seed == nil,
              request.safetyTolerance == nil,
              request.promptEnhance == nil,
              request.background == nil,
              request.inputFidelity == nil,
              request.moderation == nil,
              request.growMask == nil,
              request.selectedTools == nil,
              request.personGeneration == nil
        else {
            throw KlingAIError.invalidInput(
                "Kling Image 3.0 does not accept the requested advanced image controls."
            )
        }
    }

    private func failure(
        message: String,
        rawResponse: String? = nil,
        metadata: [String: String]? = nil
    ) -> ImageGenerationResponse {
        ImageGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            rawResponse: rawResponse,
            metadata: metadata
        )
    }
}

public final class G_KLING_IMAGE_3_0_OMNI: ImageGenerationProtocol {
    public let modelCode = EnumProviderModelCode.KLING_IMAGE_3_0_OMNI
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

    public struct ImageItem: Codable, Equatable, Sendable {
        public let image: String
    }

    public struct ServiceRequest: Codable, Equatable, Sendable {
        public let model_name: String
        public let prompt: String
        public let image_list: [ImageItem]?
        public let resolution: String
        public let result_type: String
        public let n: Int
        public let aspect_ratio: String
        public let watermark: Bool
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let resolution = request.resolution ?? "1K"
        let unitCost = (try? KlingAIClient.imagePrice(omni: true, resolution: resolution)) ?? 0
        return unitCost * Double(max(1, request.numberOfImages ?? 1))
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        (try? validatedServiceRequest(from: request)) ?? ServiceRequest(
            model_name: "kling-v3-omni",
            prompt: request.prompt,
            image_list: nil,
            resolution: (request.resolution ?? "1K").lowercased(),
            result_type: "single",
            n: 1,
            aspect_ratio: "auto",
            watermark: false
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        do {
            let serviceRequest = try validatedServiceRequest(from: request)
            let outputURL = try KlingAIClient.outputURL(from: response, kind: .image)
            return try ImageGenerationResponse(
                generationId: UUID(),
                status: .GENERATED,
                cost: KlingAIClient.imagePrice(omni: true, resolution: serviceRequest.resolution),
                modelPrompt: serviceRequest.prompt,
                rawResponse: response.rawResponseString,
                metadata: ["klingOutputURL": outputURL.absoluteString],
                actualDimensions: "auto"
            )
        } catch {
            return failure(message: error.localizedDescription, rawResponse: response.rawResponseString)
        }
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        do {
            let credentials = try KlingAIClient.credentials(from: request.providerSecret)
            let serviceRequest = try validatedServiceRequest(from: request)
            let network = ProviderDependencies.shared.networkProvider
            let job = try await KlingAIClient.create(
                body: serviceRequest,
                endpoint: "v1/images/omni-image",
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
                    kind: .image,
                    network: network
                )
                var metadata = job.metadata
                metadata["klingOutputURL"] = materialized.url.absoluteString
                metadata["klingModelId"] = serviceRequest.model_name
                metadata["klingResolution"] = serviceRequest.resolution
                return try ImageGenerationResponse(
                    generationId: UUID(),
                    status: .GENERATED,
                    base64: materialized.base64,
                    cost: KlingAIClient.imagePrice(
                        omni: true,
                        resolution: serviceRequest.resolution
                    ),
                    modelPrompt: serviceRequest.prompt,
                    rawResponse: final.rawResponseString,
                    metadata: metadata,
                    actualDimensions: "auto"
                )
            } catch {
                return failure(
                    message: "Kling image request failed: \(error.localizedDescription)",
                    metadata: job.metadata
                )
            }
        } catch {
            return failure(message: "Kling image request failed: \(error.localizedDescription)")
        }
    }

    func validatedServiceRequest(from request: ImageGenerationRequest) throws -> ServiceRequest {
        let prompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            throw KlingAIError.invalidInput("Kling requires a non-empty Omni image prompt.")
        }
        guard prompt.count <= 2500 else {
            throw KlingAIError.invalidInput("Kling Omni image prompts cannot exceed 2500 characters.")
        }
        guard request.numberOfImages == 1 else {
            throw KlingAIError.invalidInput("Kling direct image requests generate exactly one image.")
        }
        guard request.dimensions.isEmpty || request.dimensions.lowercased() == "auto" else {
            throw KlingAIError.invalidInput("Kling Omni image uses automatic aspect ratio only.")
        }
        let resolution = (request.resolution ?? "1K").uppercased()
        _ = try KlingAIClient.imagePrice(omni: true, resolution: resolution)
        guard request.clientMask?.isEmpty != false,
              request.negativePrompt?.isEmpty != false
        else {
            throw KlingAIError.invalidInput("Kling Omni image does not accept masks or negative prompts.")
        }

        var images: [String] = []
        if let clientImage = request.clientImage {
            try images.append(KlingAIClient.normalizedImageInput(clientImage))
        }
        for reference in request.clientReferenceImages ?? [] {
            try images.append(KlingAIClient.normalizedImageInput(reference.base64Image))
        }
        guard images.count <= 10 else {
            throw KlingAIError.invalidInput("Kling Omni image accepts at most ten input images.")
        }
        try validateUnsupportedControls(request)

        let markers = images.indices.map { "<<<image_\($0 + 1)>>>" }
        let markedPrompt = markers.isEmpty
            ? prompt
            : "\(markers.joined(separator: " ")) \(prompt)"
        return ServiceRequest(
            model_name: "kling-v3-omni",
            prompt: markedPrompt,
            image_list: images.isEmpty ? nil : images.map { ImageItem(image: $0) },
            resolution: resolution.lowercased(),
            result_type: "single",
            n: 1,
            aspect_ratio: "auto",
            watermark: false
        )
    }

    private func validateUnsupportedControls(_ request: ImageGenerationRequest) throws {
        guard request.searchPrompt?.isEmpty != false,
              request.variant.isEmpty,
              request.quality.isEmpty,
              request.style.isEmpty,
              request.editDirection == nil,
              request.steps == nil,
              request.guidance == nil,
              request.seed == nil,
              request.safetyTolerance == nil,
              request.promptEnhance == nil,
              request.background == nil,
              request.inputFidelity == nil,
              request.moderation == nil,
              request.growMask == nil,
              request.selectedTools == nil,
              request.personGeneration == nil
        else {
            throw KlingAIError.invalidInput(
                "Kling Omni image does not accept the requested advanced image controls."
            )
        }
    }

    private func failure(
        message: String,
        rawResponse: String? = nil,
        metadata: [String: String]? = nil
    ) -> ImageGenerationResponse {
        ImageGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            rawResponse: rawResponse,
            metadata: metadata
        )
    }
}
