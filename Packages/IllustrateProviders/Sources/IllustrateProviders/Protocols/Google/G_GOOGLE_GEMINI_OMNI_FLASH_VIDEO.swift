// MARK: - G_GOOGLE_GEMINI_OMNI_FLASH_VIDEO.swift

// Implementation for Gemini Omni Flash video generation through the Interactions API.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public typealias GeminiOmniVideoDownloader = @Sendable (_ uri: String, _ apiKey: String) async throws -> Data

/// Shared implementation for Gemini Omni Flash video generation.
public class GeminiOmniFlashVideoBase: VideoGenerationProtocol {
    private let service: GeminiInteractionsService
    private let videoDownloader: GeminiOmniVideoDownloader

    public init(
        service: GeminiInteractionsService = GeminiInteractionsService(),
        videoDownloader: @escaping GeminiOmniVideoDownloader = GeminiOmniFlashVideoBase.downloadVideo
    ) {
        self.service = service
        self.videoDownloader = videoDownloader
    }

    public var model: ProviderModelData {
        fatalError("Subclasses must override model")
    }

    var geminiModelId: String {
        "gemini-omni-flash-preview"
    }

    private var defaultDuration: Int {
        8
    }

    private func validatedDuration(_ duration: Int?) -> Int {
        let resolvedDuration = duration ?? defaultDuration
        let supported = model.modelParams.supportedVideoDurations
        guard let minimum = supported.min(), let maximum = supported.max() else {
            return resolvedDuration
        }
        return min(max(resolvedDuration, minimum), maximum)
    }

    private static let videoTokensPerSecond: Double = 5792
    private static let videoOutputPricePerMillionTokens = 17.50

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let durationSeconds = Double(validatedDuration(request.durationSeconds))
        let numberOfVideos = Double(request.numberOfVideos ?? 1)
        let costPerSecond = (Self.videoTokensPerSecond / 1_000_000) * Self.videoOutputPricePerMillionTokens
        return costPerSecond * durationSeconds * numberOfVideos
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public func transformRequest(request: VideoGenerationRequest) -> GeminiInteractionRequest {
        buildInteractionRequest(request: request)
    }

    func buildInteractionRequest(request: VideoGenerationRequest) -> GeminiInteractionRequest {
        let previousInteractionId = previousInteractionId(from: request)

        return GeminiInteractionRequest(
            model: geminiModelId,
            input: buildInput(request: request),
            previousInteractionId: previousInteractionId,
            responseModalities: ["video"],
            responseFormat: .single(GeminiInteractionResponseFormat(
                type: "video",
                aspectRatio: supportedAspectRatio(for: request.dimensions),
                delivery: "uri"
            )),
            generationConfig: GeminiInteractionGenerationConfig(
                videoConfig: GeminiInteractionVideoConfig(task: task(for: request))
            ),
            background: false,
            store: true,
            stream: false
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        let interaction = try GeminiInteractionsService.decodeInteraction(from: response)
        return transformInteractionResponse(
            request: request,
            interaction: interaction,
            downloadedVideoData: nil
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        if requiresPreviousInteraction, previousInteractionId(from: request) == nil {
            return failedResponse(
                message: "Gemini Omni video editing requires a stored Gemini interaction ID. Generate a new Omni Flash video before editing, or try again before the stored interaction expires."
            )
        }

        do {
            let interaction = try await service.createInteraction(
                request: buildInteractionRequest(request: request),
                apiKey: request.providerSecret
            )

            if let uri = interaction.outputVideo?.uri, interaction.outputVideo?.data?.isEmpty != false {
                do {
                    let downloadedVideo = try await videoDownloader(uri, request.providerSecret)
                    return transformInteractionResponse(
                        request: request,
                        interaction: interaction,
                        downloadedVideoData: downloadedVideo
                    )
                } catch {
                    return failedResponse(
                        message: "Failed to download Gemini Omni video: \(error.localizedDescription)",
                        rawResponse: rawInteractionResponse(interaction),
                        metadata: metadata(for: interaction, outputVideo: interaction.outputVideo)
                    )
                }
            }

            return transformInteractionResponse(
                request: request,
                interaction: interaction,
                downloadedVideoData: nil
            )
        } catch {
            return failedResponse(message: error.localizedDescription)
        }
    }

    private func buildInput(request: VideoGenerationRequest) -> GeminiInteractionInput {
        let prompt = request.prompt ?? ""

        if previousInteractionId(from: request) != nil {
            return .text(prompt)
        }

        if let clientVideo = request.clientVideo, !clientVideo.isEmpty {
            return .blocks([
                .userInput([
                    .video(base64: strippedDataURI(clientVideo), mimeType: "video/mp4"),
                    .text(prompt),
                ]),
            ])
        }

        var blocks: [GeminiInteractionContentBlock] = []

        if let clientImage = request.clientImage, model.modelParams.supportsSourceImage {
            blocks.append(.image(base64: strippedDataURI(clientImage), mimeType: "image/png"))
        }

        if let referenceImages = request.clientReferenceImages, !referenceImages.isEmpty {
            blocks.append(contentsOf: referenceImages.map {
                .image(base64: strippedDataURI($0.base64Image), mimeType: $0.mimeType)
            })
        }

        blocks.append(.text(prompt))

        if blocks.count == 1 {
            return .text(prompt)
        }
        return .blocks(blocks)
    }

    private func task(for request: VideoGenerationRequest) -> String {
        if previousInteractionId(from: request) != nil {
            return "edit"
        }

        if request.clientVideo?.isEmpty == false {
            return "edit"
        }

        let hasSourceImage = request.clientImage?.isEmpty == false && model.modelParams.supportsSourceImage
        let referenceImageCount = request.clientReferenceImages?.count ?? 0

        if hasSourceImage, referenceImageCount == 0 {
            return "image_to_video"
        }

        if referenceImageCount > 0 {
            return "reference_to_video"
        }

        return "text_to_video"
    }

    private var requiresPreviousInteraction: Bool {
        model.modelParams.requiredMetadata.contains(GeminiInteractionMetadataKey.interactionId)
    }

    private func previousInteractionId(from request: VideoGenerationRequest) -> String? {
        guard let value = request.sourceMetadata?[GeminiInteractionMetadataKey.interactionId],
              !value.isEmpty
        else {
            return nil
        }
        return value
    }

    private func transformInteractionResponse(
        request: VideoGenerationRequest,
        interaction: GeminiInteraction,
        downloadedVideoData: Data?
    ) -> VideoGenerationResponse {
        let rawResponse = rawInteractionResponse(interaction)
        let outputVideo = interaction.outputVideo
        let responseMetadata = metadata(for: interaction, outputVideo: outputVideo)

        if interaction.status == "failed" || interaction.status == "cancelled" {
            return failedResponse(
                message: "Gemini interaction \(interaction.status ?? "failed")",
                rawResponse: rawResponse,
                metadata: responseMetadata
            )
        }

        guard let outputVideo else {
            let outputText = interaction.outputText.map { " Response: \($0)" } ?? ""
            return failedResponse(
                message: "No video generated.\(outputText)",
                rawResponse: rawResponse,
                metadata: responseMetadata
            )
        }

        if let videoData = downloadedVideoData {
            return generatedResponse(
                request: request,
                base64Video: videoData.base64EncodedString(),
                rawResponse: rawResponse,
                metadata: responseMetadata
            )
        }

        if let base64Video = outputVideo.data, !base64Video.isEmpty {
            return generatedResponse(
                request: request,
                base64Video: base64Video,
                rawResponse: rawResponse,
                metadata: responseMetadata
            )
        }

        if let uri = outputVideo.uri, !uri.isEmpty {
            return VideoGenerationResponse(
                status: .GENERATED,
                videoUrl: uri,
                cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
                modelPrompt: request.prompt,
                rawResponse: rawResponse,
                metadata: responseMetadata
            )
        }

        return failedResponse(
            message: "Generated video did not include inline data or a URI.",
            rawResponse: rawResponse,
            metadata: responseMetadata
        )
    }

    private func generatedResponse(
        request: VideoGenerationRequest,
        base64Video: String,
        rawResponse: String?,
        metadata: [String: String]
    ) -> VideoGenerationResponse {
        VideoGenerationResponse(
            status: .GENERATED,
            base64: base64Video,
            cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
            modelPrompt: request.prompt,
            rawResponse: rawResponse,
            metadata: metadata
        )
    }

    private func failedResponse(
        message: String,
        rawResponse: String? = nil,
        metadata: [String: String]? = nil
    ) -> VideoGenerationResponse {
        VideoGenerationResponse(
            status: .FAILED,
            errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
            errorMessage: message,
            rawResponse: rawResponse,
            metadata: metadata
        )
    }

    private func metadata(
        for interaction: GeminiInteraction,
        outputVideo: GeminiInteractionContentBlock?
    ) -> [String: String] {
        var metadata = interaction.outputMetadata
        if let uri = outputVideo?.uri, !uri.isEmpty {
            metadata[GeminiInteractionMetadataKey.outputVideoUri] = uri
        }
        return metadata
    }

    private func rawInteractionResponse(_ interaction: GeminiInteraction) -> String? {
        guard let data = try? JSONEncoder().encode(interaction),
              let json = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return json
    }

    private func supportedAspectRatio(for dimensions: String) -> String {
        let ratio = convertToAspectRatio(dimensions)
        if ratio == "9:16" || ratio == "16:9" {
            return ratio
        }

        let parts = ratio.split(separator: ":")
        if parts.count == 2,
           let width = Double(parts[0]),
           let height = Double(parts[1])
        {
            return height > width ? "9:16" : "16:9"
        }

        return "16:9"
    }

    private func strippedDataURI(_ base64: String) -> String {
        base64.replacingOccurrences(
            of: "^data:.*;base64,",
            with: "",
            options: .regularExpression
        )
    }

    public static func downloadVideo(uri: String, apiKey: String) async throws -> Data {
        if let fileId = fileId(from: uri) {
            try await waitForActiveFile(fileId: fileId, apiKey: apiKey)
            let downloadURL = try downloadURL(for: uri, fileId: fileId, apiKey: apiKey)
            return try await fetchData(from: downloadURL, apiKey: apiKey)
        }

        guard let directURL = URL(string: uri) else {
            throw GeminiInteractionsError.invalidURL(uri)
        }

        return try await fetchData(from: appendAPIKey(to: directURL, apiKey: apiKey), apiKey: apiKey)
    }

    private static func waitForActiveFile(
        fileId: String,
        apiKey: String,
        maxAttempts: Int = 120
    ) async throws {
        let statusURL = try fileStatusURL(fileId: fileId, apiKey: apiKey)

        for _ in 0 ..< maxAttempts {
            let (data, response) = try await URLSession.shared.data(from: statusURL)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiInteractionsError.invalidResponse("Invalid Gemini file status response")
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                throw GeminiInteractionsError
                    .providerError("Gemini file status failed with HTTP \(httpResponse.statusCode)")
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let state = json?["state"] as? String
                ?? (json?["state"] as? [String: Any])?["name"] as? String

            if state == "ACTIVE" {
                return
            }

            if state == "FAILED" {
                throw GeminiInteractionsError.providerError("Gemini file processing failed")
            }

            try await Task.sleep(nanoseconds: 5_000_000_000)
        }

        throw GeminiInteractionsError.providerError("Gemini file processing timed out")
    }

    private static func fileStatusURL(fileId: String, apiKey: String) throws -> URL {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/files/\(fileId)") else {
            throw GeminiInteractionsError.invalidURL(fileId)
        }
        return appendAPIKey(to: url, apiKey: apiKey)
    }

    private static func downloadURL(for uri: String, fileId: String, apiKey: String) throws -> URL {
        if let url = URL(string: uri), uri.contains(":download") {
            return appendAPIKey(to: url, apiKey: apiKey)
        }

        guard let url = URL(
            string: "https://generativelanguage.googleapis.com/v1beta/files/\(fileId):download?alt=media"
        ) else {
            throw GeminiInteractionsError.invalidURL(uri)
        }

        return appendAPIKey(to: url, apiKey: apiKey)
    }

    private static func fetchData(from url: URL, apiKey: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiInteractionsError.invalidResponse("Invalid Gemini video download response")
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw GeminiInteractionsError
                .providerError("Gemini video download failed with HTTP \(httpResponse.statusCode)")
        }

        return data
    }

    private static func appendAPIKey(to url: URL, apiKey: String) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        var queryItems = components.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "key" }) {
            queryItems.append(URLQueryItem(name: "key", value: apiKey))
        }
        components.queryItems = queryItems
        return components.url ?? url
    }

    private static func fileId(from uri: String) -> String? {
        guard let range = uri.range(of: "files/") else { return nil }
        let suffix = uri[range.upperBound...]
        let fileId = suffix.prefix { character in
            character != ":" && character != "/" && character != "?"
        }
        return fileId.isEmpty ? nil : String(fileId)
    }
}

/// Gemini Omni Flash video generation.
public class G_GOOGLE_GEMINI_OMNI_FLASH_VIDEO: GeminiOmniFlashVideoBase {
    public init() {
        super.init()
    }

    override public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .GOOGLE_GEMINI_OMNI_FLASH_VIDEO)!
    }
}

/// Gemini Omni Flash conversational video editing.
public class G_GOOGLE_GEMINI_OMNI_FLASH_VIDEO_EDIT: GeminiOmniFlashVideoBase {
    public init() {
        super.init()
    }

    override public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .GOOGLE_GEMINI_OMNI_FLASH_VIDEO_EDIT)!
    }
}
