// MARK: - G_BEDROCK_STABLE_IMAGE.swift

import Foundation

public class G_BEDROCK_STABLE_IMAGE_BASE: ImageGenerationProtocol {
    let modelCode: EnumProviderModelCode
    let upstreamId: String
    let unitCost: Double

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(modelCode: EnumProviderModelCode, upstreamId: String, unitCost: Double) {
        self.modelCode = modelCode
        self.upstreamId = upstreamId
        self.unitCost = unitCost
    }

    public struct ServiceRequest: Codable, Equatable, Sendable {
        public let prompt: String
        public let mode: String
        public let aspect_ratio: String
        public let output_format: String
        public let seed: Int?
        public let negative_prompt: String?
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        unitCost * Double(max(request.numberOfImages ?? 1, 1))
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        (try? validatedRequest(from: request)) ?? ServiceRequest(
            prompt: request.prompt,
            mode: "text-to-image",
            aspect_ratio: supportedRatios.contains(request.dimensions) ? request.dimensions : "1:1",
            output_format: "png",
            seed: request.seed,
            negative_prompt: nonEmpty(request.negativePrompt)
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        let data = try AmazonBedrockClient.dictionary(from: response, operation: "image generation")
        if let reasons = data["finish_reasons"] as? [Any],
           let reason = reasons.first(where: { !($0 is NSNull) })
        {
            throw AmazonBedrockError.provider(
                "Amazon Bedrock image generation was rejected: \(String(describing: reason))."
            )
        }
        guard let images = data["images"] as? [String],
              images.count == 1,
              let base64 = images.first,
              !base64.isEmpty,
              let imageData = Data(base64Encoded: base64),
              !imageData.isEmpty
        else {
            throw AmazonBedrockError.invalidResponse(
                "Amazon Bedrock image response must contain exactly one base64 image."
            )
        }

        var metadata: [String: String] = [
            "bedrockModelId": upstreamId,
            "bedrockOutputFormat": "png",
        ]
        if let seed = (data["seeds"] as? [Any])?.first {
            metadata["bedrockSeed"] = String(describing: seed)
        }

        return ImageGenerationResponse(
            status: .GENERATED,
            base64: base64,
            size: imageData.count,
            cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
            modelPrompt: request.prompt,
            rawResponse: response.rawResponseString,
            metadata: metadata,
            actualDimensions: request.dimensions
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        do {
            let configuration = try AmazonBedrockConfiguration(secret: request.providerSecret)
            let serviceRequest = try validatedRequest(from: request)
            let envelope = try await ProviderDependencies.shared.networkProvider.performSingleAttemptRequest(
                url: configuration.invokeURL(modelId: upstreamId),
                method: "POST",
                body: serviceRequest,
                headers: AmazonBedrockClient.headers(configuration: configuration),
                attachments: nil
            )
            let response: NetworkResponseData
            do {
                response = try AmazonBedrockClient.response(
                    from: envelope,
                    operation: "image generation"
                )
            } catch {
                return failure(
                    error.localizedDescription,
                    rawResponse: envelope.response?.rawResponseString ?? envelope.bodyString
                )
            }

            do {
                var transformed = try transformResponse(request: request, response: response)
                transformed.metadata?["bedrockRegion"] = configuration.region
                return transformed
            } catch {
                return failure(error.localizedDescription, rawResponse: response.rawResponseString)
            }
        } catch {
            return failure("Amazon Bedrock image request failed: \(error.localizedDescription)")
        }
    }

    func validatedRequest(from request: ImageGenerationRequest) throws -> ServiceRequest {
        let prompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, prompt.count <= 10000 else {
            throw AmazonBedrockError.invalidInput(
                "Amazon Bedrock Stable Image prompt must contain 1 to 10,000 characters."
            )
        }
        guard request.numberOfImages == 1 else {
            throw AmazonBedrockError.invalidInput(
                "Amazon Bedrock requests exactly one image per atomic operation."
            )
        }
        guard supportedRatios.contains(request.dimensions) else {
            throw AmazonBedrockError.invalidInput("Amazon Bedrock Stable Image aspect ratio is unsupported.")
        }
        guard request.clientImage?.isEmpty != false,
              request.clientMask?.isEmpty != false,
              request.clientReferenceImages?.isEmpty != false
        else {
            throw AmazonBedrockError.invalidInput(
                "Amazon Bedrock Stable Image 1.1 adapters currently support text-to-image requests."
            )
        }
        let negativePrompt = nonEmpty(request.negativePrompt)
        guard negativePrompt?.count ?? 0 <= 10000 else {
            throw AmazonBedrockError.invalidInput(
                "Amazon Bedrock Stable Image negative prompt exceeds 10,000 characters."
            )
        }
        if let seed = request.seed, !(0 ... 4_294_967_295).contains(seed) {
            throw AmazonBedrockError.invalidInput(
                "Amazon Bedrock Stable Image seed must be between 0 and 4,294,967,295."
            )
        }

        return ServiceRequest(
            prompt: prompt,
            mode: "text-to-image",
            aspect_ratio: request.dimensions,
            output_format: "png",
            seed: request.seed,
            negative_prompt: negativePrompt
        )
    }

    private let supportedRatios: Set = [
        "16:9", "1:1", "21:9", "2:3", "3:2", "4:5", "5:4", "9:16", "9:21",
    ]

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private func failure(_ message: String, rawResponse: String? = nil) -> ImageGenerationResponse {
        ImageGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            rawResponse: rawResponse
        )
    }
}

public final class G_BEDROCK_STABLE_IMAGE_ULTRA_1_1: G_BEDROCK_STABLE_IMAGE_BASE {
    public init() {
        super.init(
            modelCode: .BEDROCK_STABLE_IMAGE_ULTRA_1_1,
            upstreamId: "stability.stable-image-ultra-v1:1",
            unitCost: 0.14
        )
    }
}

public final class G_BEDROCK_STABLE_IMAGE_CORE_1_1: G_BEDROCK_STABLE_IMAGE_BASE {
    public init() {
        super.init(
            modelCode: .BEDROCK_STABLE_IMAGE_CORE_1_1,
            upstreamId: "stability.stable-image-core-v1:1",
            unitCost: 0.04
        )
    }
}
