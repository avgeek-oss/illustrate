// MARK: - G_AZURE_GPT_IMAGE_2.swift

import Foundation

public final class G_AZURE_GPT_IMAGE_2: ImageGenerationProtocol {
    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(
        by: .AZURE_GPT_IMAGE_2
    )!

    public init() {}

    public struct ServiceRequest: Codable, Equatable, Sendable {
        public let model: String
        public let prompt: String
        public let n: Int
        public let size: String
        public let quality: String
        public let moderation: String?
        public let background: String?
        public let output_format: String
        public let input_fidelity: String?
        public let user: String
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let quality = canonicalQuality(request.quality)
        let dimensions = validatedDimensions(request.dimensions ?? "1024x1024") ?? "1024x1024"
        let numberOfImages = max(request.numberOfImages ?? 1, 1)
        return outputCost(quality: quality, dimensions: dimensions) * Double(numberOfImages)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request)) + "+"
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let deployment = (try? AzureAIFoundryConfiguration(secret: request.providerSecret).imageDeployment)
            ?? "gpt-image-2"
        return (try? validatedRequest(from: request, deployment: deployment)) ?? ServiceRequest(
            model: deployment,
            prompt: request.prompt,
            n: 1,
            size: validatedDimensions(request.dimensions) ?? "1024x1024",
            quality: canonicalQuality(request.quality),
            moderation: canonicalModeration(request.moderation),
            background: canonicalBackground(request.background),
            output_format: "png",
            input_fidelity: canonicalInputFidelity(request.inputFidelity),
            user: "illustrate_user"
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        let data = try AzureAIFoundryClient.dictionary(from: response, operation: "image generation")
        guard let outputs = data["data"] as? [[String: Any]],
              outputs.count == 1,
              let output = outputs.first,
              let base64 = output["b64_json"] as? String,
              !base64.isEmpty,
              Data(base64Encoded: base64) != nil
        else {
            throw AzureAIFoundryError.invalidResponse(
                "Azure AI Foundry image response must contain exactly one base64 image."
            )
        }

        var metadata: [String: String] = [
            "azureModel": "gpt-image-2",
            "azureOutputFormat": (data["output_format"] as? String) ?? "png",
        ]
        if let created = data["created"] {
            metadata["azureCreatedAt"] = String(describing: created)
        }
        if let usage = data["usage"],
           JSONSerialization.isValidJSONObject(usage),
           let usageData = try? JSONSerialization.data(withJSONObject: usage),
           let usageString = String(data: usageData, encoding: .utf8)
        {
            metadata["azureUsage"] = usageString
        }

        return ImageGenerationResponse(
            status: .GENERATED,
            base64: base64,
            size: Data(base64Encoded: base64)?.count,
            cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
            modelPrompt: (output["revised_prompt"] as? String) ?? request.prompt,
            rawResponse: response.rawResponseString,
            metadata: metadata,
            actualDimensions: (output["size"] as? String) ?? (data["size"] as? String) ?? request.dimensions
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        do {
            let configuration = try AzureAIFoundryConfiguration(secret: request.providerSecret)
            let serviceRequest = try validatedRequest(from: request, deployment: configuration.imageDeployment)
            let attachments = try imageAttachments(from: request)
            let isEdit = !attachments.isEmpty
            let url = try isEdit ? configuration.imageEditURL() : configuration.imageGenerationURL()
            let envelope = try await ProviderDependencies.shared.networkProvider.performSingleAttemptRequest(
                url: url,
                method: "POST",
                body: serviceRequest,
                headers: AzureAIFoundryClient.headers(
                    configuration: configuration,
                    multipart: isEdit
                ),
                attachments: isEdit ? attachments : nil
            )

            let response: NetworkResponseData
            do {
                response = try AzureAIFoundryClient.response(
                    from: envelope,
                    operation: isEdit ? "image edit" : "image generation"
                )
            } catch {
                return failure(
                    error.localizedDescription,
                    rawResponse: envelope.response?.rawResponseString ?? envelope.bodyString
                )
            }

            do {
                var transformed = try transformResponse(request: request, response: response)
                transformed.metadata?["azureResourceHost"] = configuration.endpoint.host
                transformed.metadata?["azureDeployment"] = configuration.imageDeployment
                transformed.metadata?["azureOperation"] = isEdit ? "edit" : "generate"
                return transformed
            } catch {
                return failure(error.localizedDescription, rawResponse: response.rawResponseString)
            }
        } catch {
            return failure("Azure AI Foundry image request failed: \(error.localizedDescription)")
        }
    }

    func validatedRequest(
        from request: ImageGenerationRequest,
        deployment: String
    ) throws -> ServiceRequest {
        let prompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, prompt.count <= 32000 else {
            throw AzureAIFoundryError.invalidInput(
                "Azure AI Foundry image prompt must contain 1 to 32,000 characters."
            )
        }
        guard request.numberOfImages == 1 else {
            throw AzureAIFoundryError.invalidInput(
                "Azure AI Foundry requests exactly one image per atomic operation."
            )
        }
        guard let size = validatedDimensions(request.dimensions) else {
            throw AzureAIFoundryError.invalidInput("Azure AI Foundry GPT Image 2 dimensions are unsupported.")
        }
        guard request.clientReferenceImages?.count ?? 0 <= 8 else {
            throw AzureAIFoundryError.invalidInput(
                "Azure AI Foundry GPT Image 2 accepts at most eight reference images."
            )
        }
        if request.clientMask?.isEmpty == false, request.clientImage?.isEmpty != false {
            throw AzureAIFoundryError.invalidInput(
                "Azure AI Foundry image masks require a source image."
            )
        }

        return ServiceRequest(
            model: deployment,
            prompt: prompt,
            n: 1,
            size: size,
            quality: canonicalQuality(request.quality),
            moderation: canonicalModeration(request.moderation),
            background: canonicalBackground(request.background),
            output_format: "png",
            input_fidelity: canonicalInputFidelity(request.inputFidelity),
            user: "illustrate_user"
        )
    }

    func imageAttachments(from request: ImageGenerationRequest) throws -> [NetworkRequestAttachment] {
        var attachments: [NetworkRequestAttachment] = []
        if let source = request.clientImage, !source.isEmpty {
            let image = try AzureAIFoundryClient.imageInput(source)
            attachments.append(.init(name: "image[]", mimeType: image.mimeType, data: image.data))
        }
        for reference in request.clientReferenceImages ?? [] {
            let image = try AzureAIFoundryClient.imageInput(
                reference.base64Image,
                defaultMimeType: reference.mimeType
            )
            attachments.append(.init(name: "image[]", mimeType: image.mimeType, data: image.data))
        }
        if let mask = request.clientMask, !mask.isEmpty {
            let image = try AzureAIFoundryClient.imageInput(mask, defaultMimeType: "image/png")
            guard image.mimeType == "image/png" else {
                throw AzureAIFoundryError.invalidInput("Azure AI Foundry image mask must be PNG.")
            }
            attachments.append(.init(name: "mask", mimeType: image.mimeType, data: image.data))
        }
        return attachments
    }

    private func canonicalQuality(_ value: String?) -> String {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "low": "low"
        case "medium": "medium"
        default: "high"
        }
    }

    private func canonicalModeration(_ value: String?) -> String? {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "auto": "auto"
        case "low": "low"
        default: nil
        }
    }

    private func canonicalBackground(_ value: String?) -> String? {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "auto": "auto"
        case "transparent": "transparent"
        case "opaque": "opaque"
        default: nil
        }
    }

    private func canonicalInputFidelity(_ value: String?) -> String? {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "low": "low"
        case "high": "high"
        default: nil
        }
    }

    private func validatedDimensions(_ value: String) -> String? {
        let parts = value.lowercased().split(separator: "x", maxSplits: 1)
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1]),
              width > 0,
              height > 0,
              width % 16 == 0,
              height % 16 == 0,
              max(width, height) <= 3840,
              width * height >= 655_360,
              width * height <= 8_294_400
        else { return nil }
        let ratio = Double(width) / Double(height)
        guard ratio >= 1.0 / 3.0, ratio <= 3.0 else { return nil }
        return "\(width)x\(height)"
    }

    private func outputCost(quality: String, dimensions: String) -> Double {
        let standard: [String: [String: Double]] = [
            "low": ["1024x1024": 0.006, "1024x1536": 0.005, "1536x1024": 0.005],
            "medium": ["1024x1024": 0.053, "1024x1536": 0.041, "1536x1024": 0.041],
            "high": ["1024x1024": 0.211, "1024x1536": 0.165, "1536x1024": 0.165],
        ]
        if let cost = standard[quality]?[dimensions] { return cost }

        let parts = dimensions.split(separator: "x", maxSplits: 1)
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1])
        else { return standard[quality]?["1024x1024"] ?? 0.211 }
        let isSquare = width == height
        let reference = isSquare ? "1024x1024" : "1536x1024"
        let referencePixels = isSquare ? 1024.0 * 1024.0 : 1536.0 * 1024.0
        let referenceCost = standard[quality]?[reference] ?? 0.211
        return max(referenceCost, referenceCost * (width * height / referencePixels))
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
