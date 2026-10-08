import Foundation

public class G_BYTEPLUS_SEEDREAM_BASE: ImageGenerationProtocol {
    public enum ImageInput: Codable, Equatable, Sendable {
        case one(String)
        case many([String])

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(String.self) {
                self = .one(value)
            } else {
                self = try .many(container.decode([String].self))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .one(value): try container.encode(value)
            case let .many(values): try container.encode(values)
            }
        }
    }

    public struct ServiceRequest: Codable, Equatable, Sendable {
        public let model: String
        public let prompt: String
        public let image: ImageInput?
        public let size: String
        public let responseFormat: String
        public let watermark: Bool
        public let sequentialImageGeneration: String?
        public let stream: Bool?
        public let outputFormat: String?

        enum CodingKeys: String, CodingKey {
            case model
            case prompt
            case image
            case size
            case responseFormat = "response_format"
            case watermark
            case sequentialImageGeneration = "sequential_image_generation"
            case stream
            case outputFormat = "output_format"
        }
    }

    public let modelCode: EnumProviderModelCode
    public let upstreamModel: String
    private let allowedResolutions: Set<String>
    private let defaultResolution: String
    private let maximumInputs: Int
    private let fixedOutputPrice: Double?
    private let supportsSequenceControls: Bool
    private let supportsOutputFormat: Bool

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        modelCode: EnumProviderModelCode,
        upstreamModel: String,
        allowedResolutions: Set<String>,
        defaultResolution: String,
        maximumInputs: Int,
        fixedOutputPrice: Double?,
        supportsSequenceControls: Bool,
        supportsOutputFormat: Bool
    ) {
        self.modelCode = modelCode
        self.upstreamModel = upstreamModel
        self.allowedResolutions = allowedResolutions
        self.defaultResolution = defaultResolution
        self.maximumInputs = maximumInputs
        self.fixedOutputPrice = fixedOutputPrice
        self.supportsSequenceControls = supportsSequenceControls
        self.supportsOutputFormat = supportsOutputFormat
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let count = max(1, request.numberOfImages ?? 1)
        let outputPrice: Double = if let fixedOutputPrice {
            fixedOutputPrice
        } else {
            canonicalResolution(request.resolution) == "1K" ? 0.045 : 0.09
        }
        let inputs = (request.hasSourceImage ? 1 : 0) + request.referenceImageCount
        let inputPrice = modelCode == .BYTEPLUS_DOLA_SEEDREAM_5_0_PRO
            ? Double(max(0, inputs - 1)) * 0.003
            : 0
        return (outputPrice + inputPrice) * Double(count)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        (try? validatedServiceRequest(from: request)) ?? ServiceRequest(
            model: upstreamModel,
            prompt: request.prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            image: nil,
            size: squareSize(for: canonicalResolution(request.resolution)),
            responseFormat: "b64_json",
            watermark: false,
            sequentialImageGeneration: supportsSequenceControls ? "disabled" : nil,
            stream: supportsSequenceControls ? false : nil,
            outputFormat: supportsOutputFormat ? "png" : nil
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        guard case let .dictionary(statusCode, data) = response,
              (200 ... 299).contains(statusCode)
        else {
            return createInvalidResponseError(
                response: response,
                modelCode: modelCode,
                customMessage: "BytePlus returned an invalid image response."
            )
        }
        if let error = BytePlusModelArkClient.providerError(in: data) {
            return failure(message: error, rawResponse: response.rawResponseString)
        }
        guard let items = data["data"] as? [[String: Any]], items.count == 1,
              let item = items.first
        else {
            return failure(
                message: "BytePlus image response was not atomic.",
                rawResponse: response.rawResponseString
            )
        }
        if let error = BytePlusModelArkClient.providerError(in: item) {
            return failure(message: error, rawResponse: response.rawResponseString)
        }
        if let usage = data["usage"] as? [String: Any],
           let generated = usage["generated_images"] as? Int,
           generated != 1
        {
            return failure(
                message: "BytePlus image usage did not report one generated image.",
                rawResponse: response.rawResponseString
            )
        }

        let base64 = (item["b64_json"] as? String).flatMap(BytePlusModelArkClient.normalizedBase64)
        let outputURL = item["url"] as? String
        guard base64 != nil || outputURL != nil else {
            return failure(
                message: "BytePlus image response omitted image data.",
                rawResponse: response.rawResponseString
            )
        }
        var metadata: [String: String] = [:]
        if let outputURL { metadata["bytePlusOutputURL"] = outputURL }
        return ImageGenerationResponse(
            status: .GENERATED,
            base64: base64,
            size: base64.flatMap { Data(base64Encoded: $0)?.count },
            cost: atomicCost(for: request),
            modelPrompt: request.prompt,
            rawResponse: response.rawResponseString,
            metadata: metadata.isEmpty ? nil : metadata,
            actualDimensions: item["size"] as? String ?? request.dimensions
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        do {
            let credentials = try BytePlusModelArkClient.credentials(from: request.providerSecret)
            try BytePlusModelArkClient.validateAvailability(modelCode: modelCode, region: credentials.region)
            let serviceRequest = try validatedServiceRequest(from: request)
            let network = ProviderDependencies.shared.networkProvider
            let envelope = try await network.performSingleAttemptRequest(
                url: BytePlusModelArkClient.imageURL(region: credentials.region),
                method: "POST",
                body: serviceRequest,
                headers: BytePlusModelArkClient.headers(apiKey: credentials.apiKey),
                attachments: nil
            )
            guard (200 ... 299).contains(envelope.statusCode) else {
                return failure(
                    message: BytePlusModelArkClient.httpFailureMessage(
                        envelope: envelope,
                        operation: "image generation"
                    ),
                    rawResponse: envelope.response?.rawResponseString ?? envelope.bodyString
                )
            }
            guard let response = envelope.response else {
                return failure(
                    message: "BytePlus image response could not be decoded.",
                    rawResponse: envelope.bodyString
                )
            }
            var transformed = try transformResponse(request: request, response: response)
            guard transformed.status == .GENERATED, transformed.base64 == nil,
                  let output = transformed.metadata?["bytePlusOutputURL"]
            else {
                return transformed
            }
            let outputURL = try BytePlusModelArkClient.validatedOutputURL(output)
            transformed.base64 = try await ProviderMediaMaterializer.base64(
                from: outputURL,
                network: network
            )
            transformed.size = transformed.base64.flatMap { Data(base64Encoded: $0)?.count }
            transformed.metadata?.removeValue(forKey: "bytePlusOutputURL")
            if transformed.metadata?.isEmpty == true { transformed.metadata = nil }
            return transformed
        } catch {
            return failure(message: "BytePlus image request failed: \(error.localizedDescription)")
        }
    }

    func validatedServiceRequest(from request: ImageGenerationRequest) throws -> ServiceRequest {
        let prompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            throw BytePlusModelArkError.invalidInput("BytePlus image generation requires a prompt.")
        }
        guard prompt.count <= 6000 else {
            throw BytePlusModelArkError.invalidInput("BytePlus image prompts cannot exceed 6000 characters.")
        }
        guard request.clientMask?.isEmpty != false,
              request.negativePrompt?.isEmpty != false,
              request.seed == nil,
              request.guidance == nil
        else {
            throw BytePlusModelArkError.invalidInput(
                "BytePlus Seedream does not accept masks, negative prompts, seeds, or guidance."
            )
        }
        guard request.dimensions.isEmpty || request.dimensions == "1:1" else {
            throw BytePlusModelArkError.invalidInput(
                "BytePlus image generation uses documented square pixel sizes."
            )
        }
        let resolution = canonicalResolution(request.resolution)
        guard allowedResolutions.contains(resolution) else {
            throw BytePlusModelArkError.invalidInput(
                "BytePlus does not support the requested image resolution for this model."
            )
        }

        var inputs: [String] = []
        if let source = request.clientImage, !source.isEmpty {
            try inputs.append(BytePlusModelArkClient.validatedImageURI(source))
        }
        for reference in request.clientReferenceImages ?? [] {
            try inputs.append(BytePlusModelArkClient.validatedImageURI(
                reference.base64Image,
                mimeType: reference.mimeType
            ))
        }
        guard inputs.count <= maximumInputs else {
            throw BytePlusModelArkError.invalidInput(
                "BytePlus accepts at most \(maximumInputs) image inputs for this model."
            )
        }

        let image: ImageInput? = switch inputs.count {
        case 0: nil
        case 1: .one(inputs[0])
        default: .many(inputs)
        }
        return ServiceRequest(
            model: upstreamModel,
            prompt: prompt,
            image: image,
            size: squareSize(for: resolution),
            responseFormat: "b64_json",
            watermark: false,
            sequentialImageGeneration: supportsSequenceControls ? "disabled" : nil,
            stream: supportsSequenceControls ? false : nil,
            outputFormat: supportsOutputFormat ? "png" : nil
        )
    }

    private func canonicalResolution(_ value: String?) -> String {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return normalized?.isEmpty == false ? normalized! : defaultResolution
    }

    private func squareSize(for resolution: String) -> String {
        switch resolution {
        case "1K": "1024x1024"
        case "2K": "2048x2048"
        case "3K": "3072x3072"
        case "4K": "4096x4096"
        default: "2048x2048"
        }
    }

    private func atomicCost(for request: ImageGenerationRequest) -> Double {
        getCostEstimate(request: ImageGenerationCostRequest(
            modelId: request.modelId,
            dimensions: request.dimensions,
            resolution: request.resolution,
            numberOfImages: 1,
            hasSourceImage: request.clientImage?.isEmpty == false,
            referenceImageCount: request.clientReferenceImages?.count ?? 0
        ))
    }

    private func failure(
        message: String,
        rawResponse: String? = nil
    ) -> ImageGenerationResponse {
        ImageGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            rawResponse: rawResponse
        )
    }
}

public final class G_BYTEPLUS_DOLA_SEEDREAM_5_0_PRO: G_BYTEPLUS_SEEDREAM_BASE {
    public init() {
        super.init(
            modelCode: .BYTEPLUS_DOLA_SEEDREAM_5_0_PRO,
            upstreamModel: "dola-seedream-5-0-pro-260628",
            allowedResolutions: ["1K", "2K"],
            defaultResolution: "1K",
            maximumInputs: 10,
            fixedOutputPrice: nil,
            supportsSequenceControls: false,
            supportsOutputFormat: true
        )
    }
}

public final class G_BYTEPLUS_SEEDREAM_5_0_LITE: G_BYTEPLUS_SEEDREAM_BASE {
    public init() {
        super.init(
            modelCode: .BYTEPLUS_SEEDREAM_5_0_LITE,
            upstreamModel: "seedream-5-0-260128",
            allowedResolutions: ["2K", "3K", "4K"],
            defaultResolution: "2K",
            maximumInputs: 14,
            fixedOutputPrice: 0.035,
            supportsSequenceControls: true,
            supportsOutputFormat: true
        )
    }
}

public final class G_BYTEPLUS_SEEDREAM_4_5: G_BYTEPLUS_SEEDREAM_BASE {
    public init() {
        super.init(
            modelCode: .BYTEPLUS_SEEDREAM_4_5,
            upstreamModel: "seedream-4-5-251128",
            allowedResolutions: ["2K", "4K"],
            defaultResolution: "2K",
            maximumInputs: 14,
            fixedOutputPrice: 0.04,
            supportsSequenceControls: true,
            supportsOutputFormat: false
        )
    }
}

public final class G_BYTEPLUS_SEEDREAM_4_0: G_BYTEPLUS_SEEDREAM_BASE {
    public init() {
        super.init(
            modelCode: .BYTEPLUS_SEEDREAM_4_0,
            upstreamModel: "seedream-4-0-250828",
            allowedResolutions: ["1K", "2K", "4K"],
            defaultResolution: "2K",
            maximumInputs: 14,
            fixedOutputPrice: 0.03,
            supportsSequenceControls: true,
            supportsOutputFormat: false
        )
    }
}
