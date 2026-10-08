// MARK: - G_VERTEX_GEMINI_3_1_FLASH_IMAGE.swift

import Foundation

public final class G_VERTEX_GEMINI_3_1_FLASH_IMAGE: ImageGenerationProtocol {
    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(
        by: .VERTEX_GEMINI_3_1_FLASH_IMAGE
    )!

    public init() {}

    public struct ServiceRequest: Codable, Equatable, Sendable {
        public let contents: [Content]
        public let generationConfig: GenerationConfig

        public struct Content: Codable, Equatable, Sendable {
            public let role: String
            public let parts: [Part]
        }

        public struct Part: Codable, Equatable, Sendable {
            public let text: String?
            public let inlineData: InlineData?

            public init(text: String? = nil, inlineData: InlineData? = nil) {
                self.text = text
                self.inlineData = inlineData
            }
        }

        public struct InlineData: Codable, Equatable, Sendable {
            public let mimeType: String
            public let data: String
        }

        public struct GenerationConfig: Codable, Equatable, Sendable {
            public let responseModalities: [String]
            public let candidateCount: Int
            public let imageConfig: ImageConfig
        }

        public struct ImageConfig: Codable, Equatable, Sendable {
            public let aspectRatio: String
            public let imageSize: String
            public let imageOutputOptions: ImageOutputOptions
        }

        public struct ImageOutputOptions: Codable, Equatable, Sendable {
            public let mimeType: String
        }
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let output = switch canonicalResolution(request.resolution ?? request.quality) {
        case "512": 0.045
        case "2K": 0.101
        case "4K": 0.15
        default: 0.067
        }
        let inputImages = request.referenceImageCount + (request.hasSourceImage ? 1 : 0)
        return output + Double(inputImages) * 0.0006
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        (try? validatedRequest(from: request)) ?? ServiceRequest(
            contents: [
                .init(role: "user", parts: [.init(text: request.prompt)]),
            ],
            generationConfig: .init(
                responseModalities: ["TEXT", "IMAGE"],
                candidateCount: 1,
                imageConfig: .init(
                    aspectRatio: request.dimensions,
                    imageSize: canonicalResolution(request.resolution ?? request.quality),
                    imageOutputOptions: .init(mimeType: "image/png")
                )
            )
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        do {
            let data = try VertexAIClient.response(from: response, operation: "image generation")
            let candidates = try requiredArray(data["candidates"], field: "candidates")
            guard candidates.count == 1,
                  let candidate = candidates.first,
                  let content = candidate["content"] as? [String: Any]
            else {
                throw VertexAIError.invalidResponse("Vertex AI image response must contain one candidate.")
            }

            let parts = try requiredArray(content["parts"], field: "content.parts")
            let images = parts.compactMap { part -> (String, String)? in
                guard let inline = part["inlineData"] as? [String: Any],
                      let base64 = inline["data"] as? String,
                      !base64.isEmpty,
                      Data(base64Encoded: base64) != nil,
                      let mimeType = inline["mimeType"] as? String,
                      mimeType.hasPrefix("image/")
                else { return nil }
                return (base64, mimeType)
            }
            guard images.count == 1, let image = images.first else {
                let finishReason = candidate["finishReason"] as? String ?? "unknown"
                throw VertexAIError.invalidResponse(
                    "Vertex AI image response contained \(images.count) images (finishReason: \(finishReason))."
                )
            }

            let serviceRequest = try validatedRequest(from: request)
            let text = parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
            return ImageGenerationResponse(
                status: .GENERATED,
                base64: image.0,
                cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
                modelPrompt: text.isEmpty ? request.prompt : text,
                rawResponse: response.rawResponseString,
                metadata: [
                    "vertexModelId": "gemini-3.1-flash-image",
                    "vertexMimeType": image.1,
                    "vertexResolution": serviceRequest.generationConfig.imageConfig.imageSize,
                ],
                actualDimensions: serviceRequest.generationConfig.imageConfig.aspectRatio
            )
        } catch {
            return failure(error.localizedDescription, rawResponse: response.rawResponseString)
        }
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        do {
            let configuration = try VertexAIConfiguration(secret: request.providerSecret)
            let serviceRequest = try validatedRequest(from: request)
            let url = try configuration.modelURL(
                modelId: "gemini-3.1-flash-image",
                method: "generateContent"
            )
            let envelope = try await ProviderDependencies.shared.networkProvider.performSingleAttemptRequest(
                url: url,
                method: "POST",
                body: serviceRequest,
                headers: VertexAIClient.headers(configuration: configuration),
                attachments: nil
            )
            let response = try VertexAIClient.response(from: envelope, operation: "image generation")
            var transformed = try transformResponse(request: request, response: response)
            if transformed.status == .GENERATED {
                transformed.metadata?["vertexProjectId"] = configuration.projectId
                transformed.metadata?["vertexLocation"] = configuration.location
            }
            return transformed
        } catch {
            return failure("Vertex AI image request failed: \(error.localizedDescription)")
        }
    }

    func validatedRequest(from request: ImageGenerationRequest) throws -> ServiceRequest {
        let prompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            throw VertexAIError.invalidInput("Vertex AI requires a non-empty image prompt.")
        }
        guard request.numberOfImages == 1 else {
            throw VertexAIError.invalidInput("Vertex AI requests exactly one image per atomic operation.")
        }
        guard request.clientMask?.isEmpty != false else {
            throw VertexAIError.invalidInput("Vertex Gemini image generation does not accept a mask.")
        }

        let aspectRatio = request.dimensions.trimmingCharacters(in: .whitespacesAndNewlines)
        let ratios: Set = [
            "1:1", "2:3", "3:2", "3:4", "4:3",
            "4:5", "5:4", "9:16", "16:9", "21:9",
        ]
        guard ratios.contains(aspectRatio) else {
            throw VertexAIError.invalidInput("Vertex Gemini image aspect ratio is unsupported.")
        }
        let resolution = canonicalResolution(request.resolution ?? request.quality)

        var parts: [ServiceRequest.Part] = [.init(text: prompt)]
        if let source = request.clientImage {
            let input = try VertexAIClient.imageInput(source)
            parts.append(.init(inlineData: .init(mimeType: input.mimeType, data: input.data)))
        }
        for reference in request.clientReferenceImages ?? [] {
            let input = try VertexAIClient.imageInput(reference.base64Image, defaultMimeType: reference.mimeType)
            parts.append(.init(inlineData: .init(mimeType: input.mimeType, data: input.data)))
        }
        guard parts.count - 1 <= 14 else {
            throw VertexAIError.invalidInput("Vertex Gemini image generation accepts at most 14 images.")
        }

        return ServiceRequest(
            contents: [.init(role: "user", parts: parts)],
            generationConfig: .init(
                responseModalities: ["TEXT", "IMAGE"],
                candidateCount: 1,
                imageConfig: .init(
                    aspectRatio: aspectRatio,
                    imageSize: resolution,
                    imageOutputOptions: .init(mimeType: "image/png")
                )
            )
        )
    }

    private func canonicalResolution(_ value: String?) -> String {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "512", "512P": "512"
        case "2K": "2K"
        case "4K": "4K"
        default: "1K"
        }
    }

    private func requiredArray(_ value: Any?, field: String) throws -> [[String: Any]] {
        guard let array = value as? [[String: Any]] else {
            throw VertexAIError.invalidResponse("Vertex AI image response omitted \(field).")
        }
        return array
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
