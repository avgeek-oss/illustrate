// MARK: - G_MINIMAX_IMAGE_01.swift

import Foundation

public final class G_MINIMAX_IMAGE_01: ImageGenerationProtocol {
    public let modelCode = EnumProviderModelCode.MINIMAX_IMAGE_01
    public let unitPrice = 0.0035

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init() {}

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        unitPrice * Double(max(1, request.numberOfImages ?? 1))
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public struct ServiceRequest: Codable, Equatable, Sendable {
        public let model: String
        public let prompt: String
        public let aspect_ratio: String
        public let response_format: String
        public let seed: Int?
        public let n: Int
        public let prompt_optimizer: Bool

        public init(
            model: String,
            prompt: String,
            aspect_ratio: String,
            response_format: String,
            seed: Int?,
            n: Int,
            prompt_optimizer: Bool
        ) {
            self.model = model
            self.prompt = prompt
            self.aspect_ratio = aspect_ratio
            self.response_format = response_format
            self.seed = seed
            self.n = n
            self.prompt_optimizer = prompt_optimizer
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        (try? validatedServiceRequest(from: request)) ?? ServiceRequest(
            model: "image-01",
            prompt: request.prompt,
            aspect_ratio: request.dimensions.isEmpty ? "1:1" : request.dimensions,
            response_format: "base64",
            seed: request.seed,
            n: 1,
            prompt_optimizer: request.promptEnhance ?? true
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        do {
            let base64 = try MiniMaxClient.imageBase64(from: response)
            return ImageGenerationResponse(
                generationId: UUID(),
                status: .GENERATED,
                base64: base64,
                cost: unitPrice,
                modelPrompt: request.prompt,
                rawResponse: response.rawResponseString,
                actualDimensions: request.dimensions
            )
        } catch {
            return failure(message: error.localizedDescription, rawResponse: response.rawResponseString)
        }
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        do {
            let credentials = try MiniMaxClient.credentials(from: request.providerSecret)
            let serviceRequest = try validatedServiceRequest(from: request)
            let response = try await MiniMaxClient.performCreate(
                body: serviceRequest,
                path: "v1/image_generation",
                credentials: credentials,
                network: ProviderDependencies.shared.networkProvider
            )
            let base64 = try MiniMaxClient.imageBase64(from: response)
            return ImageGenerationResponse(
                generationId: UUID(),
                status: .GENERATED,
                base64: base64,
                cost: unitPrice,
                modelPrompt: request.prompt,
                rawResponse: response.rawResponseString,
                metadata: [
                    "minimaxModelId": serviceRequest.model,
                    "minimaxRegion": credentials.region.rawValue,
                    "minimaxSuccessCount": String(successCount(from: response) ?? 1),
                    "minimaxFailedCount": String(failedCount(from: response) ?? 0),
                ],
                actualDimensions: request.dimensions
            )
        } catch {
            return failure(message: "MiniMax image request failed: \(error.localizedDescription)")
        }
    }

    func validatedServiceRequest(from request: ImageGenerationRequest) throws -> ServiceRequest {
        let prompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            throw MiniMaxError.invalidInput("MiniMax requires a non-empty image prompt.")
        }
        guard prompt.count <= 1500 else {
            throw MiniMaxError.invalidInput("MiniMax image prompts cannot exceed 1500 characters.")
        }
        guard request.numberOfImages == 1 else {
            throw MiniMaxError.invalidInput("MiniMax direct image requests generate exactly one image.")
        }
        let ratios = ["16:9", "4:3", "1:1", "3:4", "9:16", "21:9"]
        let ratio = request.dimensions.isEmpty ? "1:1" : request.dimensions
        guard ratios.contains(ratio) else {
            throw MiniMaxError.invalidInput("MiniMax Image-01 does not support the requested aspect ratio.")
        }
        guard request.clientImage?.isEmpty != false,
              request.clientMask?.isEmpty != false,
              request.clientReferenceImages?.isEmpty != false
        else {
            throw MiniMaxError.invalidInput("MiniMax Image-01 direct API is text-to-image only.")
        }
        guard request.negativePrompt?.isEmpty != false else {
            throw MiniMaxError.invalidInput("MiniMax Image-01 does not accept negative prompts.")
        }
        guard request.resolution?.isEmpty != false,
              request.searchPrompt?.isEmpty != false,
              request.variant.isEmpty,
              request.quality.isEmpty,
              request.style.isEmpty,
              request.editDirection == nil,
              request.steps == nil,
              request.guidance == nil,
              request.safetyTolerance == nil,
              request.background == nil,
              request.inputFidelity == nil,
              request.moderation == nil,
              request.growMask == nil,
              request.selectedTools == nil,
              request.personGeneration == nil
        else {
            throw MiniMaxError.invalidInput(
                "MiniMax Image-01 does not accept the requested advanced image controls."
            )
        }
        if let seed = request.seed, !(0 ... 2_147_483_647).contains(seed) {
            throw MiniMaxError.invalidInput("MiniMax seed must be between 0 and 2147483647.")
        }

        return ServiceRequest(
            model: "image-01",
            prompt: prompt,
            aspect_ratio: ratio,
            response_format: "base64",
            seed: request.seed,
            n: 1,
            prompt_optimizer: request.promptEnhance ?? true
        )
    }

    private func successCount(from response: NetworkResponseData) -> Int? {
        guard case let .dictionary(_, data) = response,
              let metadata = data["metadata"] as? [String: Any]
        else { return nil }
        return count(metadata["success_count"])
    }

    private func failedCount(from response: NetworkResponseData) -> Int? {
        guard case let .dictionary(_, data) = response,
              let metadata = data["metadata"] as? [String: Any]
        else { return nil }
        return count(metadata["failed_count"])
    }

    private func count(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private func failure(message: String, rawResponse: String? = nil) -> ImageGenerationResponse {
        ImageGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            rawResponse: rawResponse
        )
    }
}
