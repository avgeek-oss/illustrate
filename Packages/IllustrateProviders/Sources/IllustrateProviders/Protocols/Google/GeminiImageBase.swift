// MARK: - GeminiImageBase.swift

// Shared types and base implementation for Google Gemini image models.
//
// This file defines the request/response structures used by all Gemini
// image generation models (Flash, Pro). The Gemini API uses a unique
// content-based format different from other providers.
//
// ## Content Structure
// Gemini uses a "parts" array for multi-modal input:
// - text: Text prompt
// - inlineData: Base64 image with MIME type
// - fileData: Google Cloud Storage URI
//
// ## Response Format
// Responses include "candidates" array with generated content.
// Images are returned as base64 in inlineData parts.
//
// ## Tools Support
// Gemini can use tools like Google Search and URL Context
// for enhanced generation capabilities.

import Foundation

// MARK: - Shared Types for Gemini Image Models

/// Shared types for Gemini image model API interactions.
enum GeminiImageTypes {
    struct ContentPart: Codable {
        var text: String?
        var inlineData: InlineData?
        var fileData: FileData?

        struct InlineData: Codable {
            var mimeType: String
            var data: String
        }

        struct FileData: Codable {
            var mimeType: String
            var fileUri: String
        }
    }

    struct Content: Codable {
        var parts: [ContentPart]
    }

    struct ImageConfig: Codable {
        var aspectRatio: String?
        var imageSize: String?
    }

    struct GenerationConfig: Codable {
        var responseModalities: [String]?
        var imageConfig: ImageConfig?

        init(responseModalities: [String]? = nil, imageConfig: ImageConfig? = nil) {
            self.responseModalities = responseModalities
            self.imageConfig = imageConfig
        }
    }

    struct Tool: Codable {
        var googleSearch: GoogleSearchTool?
        var urlContext: UrlContextTool?

        enum CodingKeys: String, CodingKey {
            case googleSearch = "google_search"
            case urlContext = "url_context"
        }

        struct GoogleSearchTool: Codable {}
        struct UrlContextTool: Codable {}

        static func googleSearch() -> Tool {
            Tool(googleSearch: GoogleSearchTool())
        }

        static func urlContext() -> Tool {
            Tool(urlContext: UrlContextTool())
        }
    }
}

// MARK: - Base Class for Gemini Image Generation

public class GeminiImageBase: ImageGenerationProtocol {
    public init() {}
    public var model: ProviderModelData {
        fatalError("Subclasses must override model")
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        fatalError("Subclasses must override getCostEstimate")
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        var contents: [GeminiImageTypes.Content]
        var tools: [GeminiImageTypes.Tool]?
        var generationConfig: GeminiImageTypes.GenerationConfig?

        init(
            prompt: String,
            sourceImage: GeminiImageTypes.ContentPart.FileData? = nil,
            referenceImages: [GeminiImageTypes.ContentPart.FileData]? = nil,
            aspectRatio: String?,
            imageSize: String? = nil,
            selectedTools: [String]? = nil
        ) {
            var parts: [GeminiImageTypes.ContentPart] = [GeminiImageTypes.ContentPart(text: prompt)]

            if let sourceImage {
                parts.append(GeminiImageTypes.ContentPart(text: nil, inlineData: nil, fileData: sourceImage))
            }

            if let referenceImages {
                for refImage in referenceImages {
                    parts.append(GeminiImageTypes.ContentPart(text: nil, inlineData: nil, fileData: refImage))
                }
            }

            contents = [GeminiImageTypes.Content(parts: parts)]

            var toolsList: [GeminiImageTypes.Tool] = []
            if let selectedTools, !selectedTools.isEmpty {
                for tool in selectedTools {
                    if tool == "google_search" {
                        toolsList.append(.googleSearch())
                    }
                    if tool == "url_context" {
                        toolsList.append(.urlContext())
                    }
                }
                if !toolsList.isEmpty {
                    tools = toolsList
                }
            }

            let hasTools = !toolsList.isEmpty
            let isEditMode = sourceImage != nil
            if aspectRatio != nil || imageSize != nil || hasTools {
                let modalities: [String]? = hasTools ? (isEditMode ? ["TEXT", "IMAGE"] : ["IMAGE"]) : ["IMAGE"]
                generationConfig = GeminiImageTypes.GenerationConfig(
                    responseModalities: modalities,
                    imageConfig: GeminiImageTypes.ImageConfig(aspectRatio: aspectRatio, imageSize: imageSize)
                )
            }
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        fatalError("Subclasses must override transformRequest")
    }

    // MARK: - Helper Methods

    func uploadReferenceImages(
        _ clientReferenceImages: [ReferenceImageData],
        apiKey: String
    ) async throws -> [GeminiImageTypes.ContentPart.FileData] {
        var uploadedFiles: [GeminiImageTypes.ContentPart.FileData] = []

        for (index, refImage) in clientReferenceImages.enumerated() {
            let uploaded = try await GeminiFileUriCache.shared.getOrUploadBase64(
                cacheKey: refImage.cacheKey,
                base64Image: refImage.base64Image,
                mimeType: refImage.mimeType,
                apiKey: apiKey,
                displayName: "reference_\(index)"
            )
            uploadedFiles.append(GeminiImageTypes.ContentPart.FileData(
                mimeType: uploaded.mimeType,
                fileUri: uploaded.uri
            ))
        }

        return uploadedFiles
    }

    func uploadSourceAndReferenceImages(
        sourceImage: String,
        referenceImages: [ReferenceImageData]?,
        apiKey: String
    ) async throws
        -> (source: GeminiImageTypes.ContentPart.FileData, references: [GeminiImageTypes.ContentPart.FileData]?)
    {
        // Source images are typically unique per request, use content hash for caching
        let uploadedSource = try await GeminiFileUriCache.shared.getOrUploadBase64(
            cacheKey: nil,
            base64Image: sourceImage,
            mimeType: "image/png",
            apiKey: apiKey,
            displayName: "source_image"
        )
        let sourceFileData = GeminiImageTypes.ContentPart.FileData(
            mimeType: uploadedSource.mimeType,
            fileUri: uploadedSource.uri
        )

        var uploadedReferences: [GeminiImageTypes.ContentPart.FileData]? = nil
        if let referenceImages, !referenceImages.isEmpty {
            uploadedReferences = []
            for (index, refImage) in referenceImages.enumerated() {
                let uploaded = try await GeminiFileUriCache.shared.getOrUploadBase64(
                    cacheKey: refImage.cacheKey,
                    base64Image: refImage.base64Image,
                    mimeType: refImage.mimeType,
                    apiKey: apiKey,
                    displayName: "reference_\(index)"
                )
                uploadedReferences?.append(GeminiImageTypes.ContentPart.FileData(
                    mimeType: uploaded.mimeType,
                    fileUri: uploaded.uri
                ))
            }
        }

        return (source: sourceFileData, references: uploadedReferences)
    }

    // MARK: - Response Transformation

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        let rawResponse = extractRawResponse(from: response)

        switch response {
        case let .dictionary(_, data):
            if let candidates = data["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first
            {
                // Check for finishReason errors first
                if let finishReasonStr = firstCandidate["finishReason"] as? String,
                   let finishReason = GeminiFinishReason.from(finishReasonStr),
                   finishReason.isError
                {
                    return ImageGenerationResponse(
                        status: .FAILED,
                        errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                        errorMessage: finishReason.userDescription,

                        rawResponse: rawResponse
                    )
                }

                // Try to extract image data
                if let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]]
                {
                    for part in parts {
                        if let inlineData = part["inlineData"] as? [String: Any],
                           let imageData = inlineData["data"] as? String
                        {
                            return ImageGenerationResponse(
                                status: .GENERATED,
                                base64: imageData,
                                cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
                                modelPrompt: request.prompt
                            )
                        }
                    }

                    for part in parts {
                        if let text = part["text"] as? String {
                            return ImageGenerationResponse(
                                status: .FAILED,
                                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                                errorMessage: "No image generated. Response: \(text)",

                                rawResponse: rawResponse
                            )
                        }
                    }
                }
            }

            if let error = data["error"] as? [String: Any],
               let message = error["message"] as? String
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message,

                    rawResponse: rawResponse
                )
            }

            if let promptFeedback = data["promptFeedback"] as? [String: Any],
               let blockReason = promptFeedback["blockReason"] as? String
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Prompt blocked: \(blockReason)",

                    rawResponse: rawResponse
                )
            }

        default:
            return createInvalidResponseError(
                response: response,

                modelCode: model.modelCode,
                customMessage: "Unexpected response"
            )
        }

        return createInvalidResponseError(
            response: response,

            modelCode: model.modelCode
        )
    }

    // MARK: - Request Execution

    enum URLBuildResult {
        case success(URL)
        case failure(ImageGenerationResponse)
    }

    func buildURL(request: ImageGenerationRequest) -> URLBuildResult {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return .failure(ImageGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Invalid URL"
            ))
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "key", value: request.providerSecret)]

        guard let finalURL = components.url else {
            return .failure(ImageGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Failed to construct URL with API key"
            ))
        }

        return .success(finalURL)
    }

    func executeRequest(
        url: URL,
        body: ServiceRequest,
        request: ImageGenerationRequest
    ) async -> ImageGenerationResponse {
        do {
            let generation = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: body,
                headers: [
                    "Content-Type": "application/json",
                ],
                attachments: nil
            )

            do {
                let response = try transformResponse(request: request, response: generation)
                if response.status == .GENERATED {}
                return response
            } catch {
                return ImageGenerationResponse(
                    status: EnumGenerationStatus.FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.TRANSFORM_RESPONSE_ERROR,
                    errorMessage: "Failed with error: \(error.localizedDescription)",
                    rawResponse: extractRawResponse(from: generation)
                )
            }
        } catch {
            return ImageGenerationResponse(
                status: EnumGenerationStatus.FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Failed with error: \(error.localizedDescription)",
                rawResponse: "Network error: \(error.localizedDescription)"
            )
        }
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        fatalError("Subclasses must override makeRequest")
    }
}

// MARK: - Flash Cost Calculation

public class GeminiFlashImageBase: GeminiImageBase {
    override public init() {}
    static let tokensPerImage: Double = 1290
    static let baseCost: Double = (tokensPerImage / 1_000_000) * 30

    override public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }
}

// MARK: - Interactions Image Generation

public class GeminiInteractionsImageBase: GeminiImageBase {
    private let service: GeminiInteractionsService

    public init(service: GeminiInteractionsService = GeminiInteractionsService()) {
        self.service = service
        super.init()
    }

    var geminiModelId: String {
        fatalError("Subclasses must override geminiModelId")
    }

    func imageSize(for request: ImageGenerationRequest) -> String? {
        let quality = request.quality.trimmingCharacters(in: .whitespacesAndNewlines)
        return quality.isEmpty ? nil : quality
    }

    func buildInteractionRequest(request: ImageGenerationRequest) -> GeminiInteractionRequest {
        var inputBlocks: [GeminiInteractionContentBlock] = [.text(request.prompt)]

        if let clientImage = request.clientImage, model.modelParams.supportsSourceImage {
            inputBlocks.append(.image(base64: clientImage, mimeType: "image/png"))
        }

        if let clientReferenceImages = request.clientReferenceImages, !clientReferenceImages.isEmpty {
            inputBlocks.append(contentsOf: clientReferenceImages.map {
                .image(base64: $0.base64Image, mimeType: $0.mimeType)
            })
        }

        let tools = buildTools(selectedTools: request.selectedTools)

        return GeminiInteractionRequest(
            model: geminiModelId,
            input: .blocks(inputBlocks),
            responseFormat: .single(GeminiInteractionResponseFormat(
                type: "image",
                aspectRatio: convertToAspectRatio(request.dimensions),
                imageSize: imageSize(for: request)
            )),
            tools: tools,
            store: false
        )
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        do {
            let interaction = try await service.createInteraction(
                request: buildInteractionRequest(request: request),
                apiKey: request.providerSecret
            )
            return transformInteractionResponse(request: request, interaction: interaction)
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func buildTools(selectedTools: [String]?) -> [GeminiInteractionTool]? {
        guard let selectedTools, !selectedTools.isEmpty else { return nil }

        let supportedTools = Set(model.modelParams.supportedTools)
        let tools = selectedTools.compactMap { tool -> GeminiInteractionTool? in
            guard supportedTools.contains(tool) else { return nil }
            switch tool {
            case "google_search":
                return .googleSearch
            default:
                return nil
            }
        }

        return tools.isEmpty ? nil : tools
    }

    private func transformInteractionResponse(
        request: ImageGenerationRequest,
        interaction: GeminiInteraction
    ) -> ImageGenerationResponse {
        let rawResponse = rawInteractionResponse(interaction)

        if interaction.status == "failed" || interaction.status == "cancelled" {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Gemini interaction \(interaction.status ?? "failed")",
                rawResponse: rawResponse,
                metadata: interaction.outputMetadata
            )
        }

        guard let outputImage = interaction.outputImage else {
            let outputText = interaction.outputText.map { " Response: \($0)" } ?? ""
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "No image generated.\(outputText)",
                rawResponse: rawResponse,
                metadata: interaction.outputMetadata
            )
        }

        guard let imageData = outputImage.data, !imageData.isEmpty else {
            let uriMessage = outputImage.uri.map { " Returned URI: \($0)" } ?? ""
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Generated image did not include inline image data.\(uriMessage)",
                rawResponse: rawResponse,
                metadata: interaction.outputMetadata
            )
        }

        return ImageGenerationResponse(
            status: .GENERATED,
            base64: imageData,
            cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
            modelPrompt: request.prompt,
            rawResponse: rawResponse,
            metadata: interaction.outputMetadata
        )
    }

    private func rawInteractionResponse(_ interaction: GeminiInteraction) -> String? {
        guard let data = try? JSONEncoder().encode(interaction),
              let json = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return json
    }
}

public class Gemini31FlashImageBase: GeminiInteractionsImageBase {
    override public init(service: GeminiInteractionsService = GeminiInteractionsService()) {
        super.init(service: service)
    }

    static let imageTokenPricePerMillion: Double = 60

    override public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let tokensPerImage = switch (request.quality ?? "1K").uppercased() {
        case "0.5K", "512PX":
            747.0
        case "2K":
            1680.0
        case "4K":
            2520.0
        default:
            1120.0
        }

        return (tokensPerImage / 1_000_000) * Self.imageTokenPricePerMillion * Double(request.numberOfImages ?? 1)
    }
}

public class Gemini31FlashLiteImageBase: GeminiInteractionsImageBase {
    override public init(service: GeminiInteractionsService = GeminiInteractionsService()) {
        super.init(service: service)
    }

    static let tokensPerImage: Double = 1120
    static let imageTokenPricePerMillion: Double = 30

    override func imageSize(for request: ImageGenerationRequest) -> String? {
        "1K"
    }

    override public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        (Self.tokensPerImage / 1_000_000) * Self.imageTokenPricePerMillion * Double(request.numberOfImages ?? 1)
    }
}

// MARK: - Pro Cost Calculation

public class GeminiProImageBase: GeminiInteractionsImageBase {
    override public init(service: GeminiInteractionsService = GeminiInteractionsService()) {
        super.init(service: service)
    }

    override func imageSize(for request: ImageGenerationRequest) -> String? {
        let quality = request.quality.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch quality {
        case "1K", "2K", "4K":
            return quality
        default:
            return "2K"
        }
    }

    override public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let quality = request.quality ?? ""
        let numberOfImages = request.numberOfImages ?? 1

        let tokensPerImage: Double = switch quality.uppercased() {
        case "4K":
            2000
        default:
            1120
        }
        let baseCost = (tokensPerImage / 1_000_000) * 120
        return baseCost * Double(numberOfImages)
    }
}
