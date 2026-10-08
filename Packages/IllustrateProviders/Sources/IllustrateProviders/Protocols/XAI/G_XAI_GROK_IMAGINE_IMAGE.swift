import Foundation

public class G_XAI_GROK_IMAGINE_IMAGE_BASE: ImageGenerationProtocol {
    public let modelCode: EnumProviderModelCode
    public let upstreamModel: String
    public let inputImagePrice: Double
    public let output1KPrice: Double
    public let output2KPrice: Double

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        modelCode: EnumProviderModelCode,
        upstreamModel: String,
        inputImagePrice: Double,
        output1KPrice: Double,
        output2KPrice: Double
    ) {
        self.modelCode = modelCode
        self.upstreamModel = upstreamModel
        self.inputImagePrice = inputImagePrice
        self.output1KPrice = output1KPrice
        self.output2KPrice = output2KPrice
    }

    public struct ImageInput: Codable, Equatable, Sendable {
        public let type: String
        public let url: String

        public init(url: String) {
            type = "image_url"
            self.url = url
        }
    }

    public struct ServiceRequest: Codable, Equatable, Sendable {
        public let model: String
        public let prompt: String
        public let n: Int
        public let aspectRatio: String?
        public let resolution: String
        public let responseFormat: String
        public let image: ImageInput?
        public let images: [ImageInput]?

        enum CodingKeys: String, CodingKey {
            case model
            case prompt
            case n
            case aspectRatio = "aspect_ratio"
            case resolution
            case responseFormat = "response_format"
            case image
            case images
        }

        public init(
            model: String,
            prompt: String,
            aspectRatio: String?,
            resolution: String,
            image: ImageInput? = nil,
            images: [ImageInput]? = nil
        ) {
            self.model = model
            self.prompt = prompt
            n = 1
            self.aspectRatio = aspectRatio
            self.resolution = resolution
            responseFormat = "b64_json"
            self.image = image
            self.images = images
        }
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let outputCount = max(1, request.numberOfImages ?? 1)
        let outputPrice = canonicalResolution(request.resolution) == "2k"
            ? output2KPrice
            : output1KPrice
        let inputCount = (request.hasSourceImage ? 1 : 0) + request.referenceImageCount
        return (outputPrice + inputImagePrice * Double(inputCount)) * Double(outputCount)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        (try? validatedServiceRequest(from: request).request) ?? ServiceRequest(
            model: upstreamModel,
            prompt: request.prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            aspectRatio: request.dimensions.isEmpty ? "auto" : request.dimensions,
            resolution: canonicalResolution(request.resolution)
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        guard case let .dictionary(statusCode, data) = response,
              (200 ... 299).contains(statusCode),
              let outputs = data["data"] as? [[String: Any]],
              outputs.count == 1,
              let output = outputs.first
        else {
            return createInvalidResponseError(
                response: response,
                modelCode: modelCode,
                customMessage: "xAI returned an invalid atomic image response."
            )
        }

        if data["respect_moderation"] as? Bool == false
            || output["respect_moderation"] as? Bool == false
        {
            return failure(
                message: "xAI blocked the generated image during moderation.",
                rawResponse: response.rawResponseString
            )
        }

        let base64 = (output["b64_json"] as? String).flatMap(XAIClient.normalizedBase64)
        let outputURLString = output["url"] as? String
        guard base64 != nil || outputURLString != nil else {
            return failure(
                message: "xAI image response omitted image data.",
                rawResponse: response.rawResponseString
            )
        }

        var metadata: [String: String] = [:]
        if let outputURLString { metadata["xaiOutputURL"] = outputURLString }
        if let mimeType = output["mime_type"] as? String, !mimeType.isEmpty {
            metadata["xaiOutputMIMEType"] = mimeType
        }
        if let revisedPrompt = output["revised_prompt"] as? String, !revisedPrompt.isEmpty {
            metadata["xaiRevisedPrompt"] = revisedPrompt
        }

        return ImageGenerationResponse(
            status: .GENERATED,
            base64: base64,
            size: base64.flatMap { Data(base64Encoded: $0)?.count },
            cost: XAIClient.usageCost(from: data) ?? atomicCost(for: request),
            modelPrompt: output["revised_prompt"] as? String ?? request.prompt,
            rawResponse: response.rawResponseString,
            metadata: metadata.isEmpty ? nil : metadata,
            actualDimensions: request.dimensions
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        do {
            let credentials = try ProviderCredentialConfiguration(secret: request.providerSecret)
            let apiKey = try credentials.requireAPIKey()
            let validated = try validatedServiceRequest(from: request)
            let network = ProviderDependencies.shared.networkProvider
            let envelope = try await network.performSingleAttemptRequest(
                url: validated.url,
                method: "POST",
                body: validated.request,
                headers: XAIClient.headers(apiKey: apiKey),
                attachments: nil
            )

            guard (200 ... 299).contains(envelope.statusCode) else {
                return failure(
                    message: XAIClient.httpFailureMessage(envelope: envelope, operation: "image request"),
                    rawResponse: envelope.response?.rawResponseString ?? envelope.bodyString
                )
            }
            guard let response = envelope.response else {
                return failure(
                    message: "xAI image response body could not be decoded.",
                    rawResponse: envelope.bodyString
                )
            }

            var transformed = try transformResponse(request: request, response: response)
            guard transformed.status == .GENERATED, transformed.base64 == nil,
                  let output = transformed.metadata?["xaiOutputURL"]
            else {
                return transformed
            }

            let outputURL = try XAIClient.validatedOutputURL(output)
            transformed.base64 = try await ProviderMediaMaterializer.base64(
                from: outputURL,
                network: network
            )
            transformed.size = transformed.base64.flatMap { Data(base64Encoded: $0)?.count }
            transformed.metadata?.removeValue(forKey: "xaiOutputURL")
            if transformed.metadata?.isEmpty == true {
                transformed.metadata = nil
            }
            return transformed
        } catch {
            return failure(message: "xAI image request failed: \(error.localizedDescription)")
        }
    }

    private func validatedServiceRequest(
        from request: ImageGenerationRequest
    ) throws -> (request: ServiceRequest, url: URL) {
        guard request.clientMask?.isEmpty != false else {
            throw XAIAdapterError.invalidInput("xAI image editing does not accept a mask.")
        }

        let prompt = try XAIClient.validatedPrompt(request.prompt, maxLength: 1024)!
        let aspectRatio = request.dimensions.isEmpty ? "auto" : request.dimensions
        guard Self.supportedAspectRatios.contains(aspectRatio) else {
            throw XAIAdapterError.invalidInput("xAI does not support the requested image aspect ratio.")
        }
        let resolution = canonicalResolution(request.resolution)
        guard Self.supportedResolutions.contains(resolution) else {
            throw XAIAdapterError.invalidInput("xAI image resolution must be 1k or 2k.")
        }

        var inputs: [ImageInput] = []
        if let image = request.clientImage, !image.isEmpty {
            try inputs.append(ImageInput(url: XAIClient.validatedImageURI(image)))
        }
        for reference in request.clientReferenceImages ?? [] {
            try inputs.append(ImageInput(url: XAIClient.validatedImageURI(
                reference.base64Image,
                mimeType: reference.mimeType
            )))
        }
        guard inputs.count <= 3 else {
            throw XAIAdapterError.invalidInput("xAI image editing accepts at most three source images.")
        }

        let serviceRequest: ServiceRequest
        let url: URL
        switch inputs.count {
        case 0:
            guard let generateURL = model.generateURL else {
                throw XAIAdapterError.invalidResponse("Invalid xAI image generation URL.")
            }
            serviceRequest = ServiceRequest(
                model: upstreamModel,
                prompt: prompt,
                aspectRatio: aspectRatio,
                resolution: resolution
            )
            url = generateURL
        case 1:
            serviceRequest = ServiceRequest(
                model: upstreamModel,
                prompt: prompt,
                aspectRatio: nil,
                resolution: resolution,
                image: inputs[0]
            )
            url = XAIClient.imageEditsURL
        default:
            serviceRequest = ServiceRequest(
                model: upstreamModel,
                prompt: prompt,
                aspectRatio: aspectRatio,
                resolution: resolution,
                images: inputs
            )
            url = XAIClient.imageEditsURL
        }
        return (serviceRequest, url)
    }

    private func canonicalResolution(_ value: String?) -> String {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized?.isEmpty == false ? normalized! : "1k"
    }

    private func atomicCost(for request: ImageGenerationRequest) -> Double {
        getCostEstimate(request: ImageGenerationCostRequest(
            modelId: request.modelId,
            quality: request.quality,
            dimensions: request.dimensions,
            resolution: request.resolution,
            numberOfImages: 1,
            hasSourceImage: request.clientImage?.isEmpty == false,
            referenceImageCount: request.clientReferenceImages?.count ?? 0
        ))
    }

    private func failure(message: String, rawResponse: String? = nil) -> ImageGenerationResponse {
        ImageGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            rawResponse: rawResponse
        )
    }

    private static let supportedAspectRatios: Set = [
        "1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3",
        "2:1", "1:2", "19.5:9", "9:19.5", "20:9", "9:20", "auto",
    ]
    private static let supportedResolutions: Set = ["1k", "2k"]
}

public final class G_XAI_GROK_IMAGINE_IMAGE: G_XAI_GROK_IMAGINE_IMAGE_BASE {
    public init() {
        super.init(
            modelCode: .XAI_GROK_IMAGINE_IMAGE,
            upstreamModel: "grok-imagine-image",
            inputImagePrice: 0.002,
            output1KPrice: 0.02,
            output2KPrice: 0.02
        )
    }
}

public final class G_XAI_GROK_IMAGINE_IMAGE_QUALITY: G_XAI_GROK_IMAGINE_IMAGE_BASE {
    public init() {
        super.init(
            modelCode: .XAI_GROK_IMAGINE_IMAGE_QUALITY,
            upstreamModel: "grok-imagine-image-quality",
            inputImagePrice: 0.01,
            output1KPrice: 0.05,
            output2KPrice: 0.07
        )
    }
}
