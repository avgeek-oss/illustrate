// MARK: - GeminiInteractions.swift

// Production Interactions API primitives for newer Gemini models.

import Foundation

public enum GeminiInteractionMetadataKey {
    public static let interactionId = "geminiInteractionId"
    public static let previousInteractionId = "geminiPreviousInteractionId"
    public static let outputVideoUri = "geminiOutputVideoUri"
}

public enum GeminiInteractionsError: LocalizedError {
    case invalidURL(String)
    case invalidResponse(String)
    case providerError(String)
    case missingAPIKey

    public var errorDescription: String? {
        switch self {
        case let .invalidURL(url):
            "Invalid Gemini Interactions URL: \(url)"
        case let .invalidResponse(message):
            message
        case let .providerError(message):
            message
        case .missingAPIKey:
            "Missing Gemini API key"
        }
    }
}

public struct GeminiInteractionContentBlock: Codable, Equatable, Sendable {
    public var type: String
    public var text: String?
    public var data: String?
    public var mimeType: String?
    public var uri: String?
    public var content: [GeminiInteractionContentBlock]?

    public init(
        type: String,
        text: String? = nil,
        data: String? = nil,
        mimeType: String? = nil,
        uri: String? = nil,
        content: [GeminiInteractionContentBlock]? = nil
    ) {
        self.type = type
        self.text = text
        self.data = data
        self.mimeType = mimeType
        self.uri = uri
        self.content = content
    }

    public static func text(_ text: String) -> GeminiInteractionContentBlock {
        GeminiInteractionContentBlock(type: "text", text: text)
    }

    public static func image(base64: String, mimeType: String = "image/png") -> GeminiInteractionContentBlock {
        GeminiInteractionContentBlock(type: "image", data: base64, mimeType: mimeType)
    }

    public static func video(base64: String, mimeType: String = "video/mp4") -> GeminiInteractionContentBlock {
        GeminiInteractionContentBlock(type: "video", data: base64, mimeType: mimeType)
    }

    public static func file(type: String, uri: String, mimeType: String) -> GeminiInteractionContentBlock {
        GeminiInteractionContentBlock(type: type, mimeType: mimeType, uri: uri)
    }

    public static func userInput(_ content: [GeminiInteractionContentBlock]) -> GeminiInteractionContentBlock {
        GeminiInteractionContentBlock(type: "user_input", content: content)
    }

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case data
        case mimeType = "mime_type"
        case uri
        case content
    }
}

public enum GeminiInteractionInput: Codable, Equatable, Sendable {
    case text(String)
    case blocks([GeminiInteractionContentBlock])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
            return
        }

        let blocks = try container.decode([GeminiInteractionContentBlock].self)
        self = .blocks(blocks)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .text(text):
            try container.encode(text)
        case let .blocks(blocks):
            try container.encode(blocks)
        }
    }
}

public struct GeminiInteractionResponseFormat: Codable, Equatable, Sendable {
    public var type: String
    public var mimeType: String?
    public var aspectRatio: String?
    public var imageSize: String?
    public var delivery: String?

    public init(
        type: String,
        mimeType: String? = nil,
        aspectRatio: String? = nil,
        imageSize: String? = nil,
        delivery: String? = nil
    ) {
        self.type = type
        self.mimeType = mimeType
        self.aspectRatio = aspectRatio
        self.imageSize = imageSize
        self.delivery = delivery
    }

    enum CodingKeys: String, CodingKey {
        case type
        case mimeType = "mime_type"
        case aspectRatio = "aspect_ratio"
        case imageSize = "image_size"
        case delivery
    }
}

public enum GeminiInteractionResponseFormatValue: Codable, Equatable, Sendable {
    case single(GeminiInteractionResponseFormat)
    case multiple([GeminiInteractionResponseFormat])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(GeminiInteractionResponseFormat.self) {
            self = .single(single)
            return
        }

        let multiple = try container.decode([GeminiInteractionResponseFormat].self)
        self = .multiple(multiple)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .single(format):
            try container.encode(format)
        case let .multiple(formats):
            try container.encode(formats)
        }
    }
}

public struct GeminiInteractionTool: Codable, Equatable, Sendable {
    public var type: String

    public init(type: String) {
        self.type = type
    }

    public static let googleSearch = GeminiInteractionTool(type: "google_search")
}

public struct GeminiInteractionVideoConfig: Codable, Equatable, Sendable {
    public var task: String?

    public init(task: String? = nil) {
        self.task = task
    }
}

public struct GeminiInteractionGenerationConfig: Codable, Equatable, Sendable {
    public var temperature: Double?
    public var topP: Double?
    public var seed: Int?
    public var stopSequences: [String]?
    public var videoConfig: GeminiInteractionVideoConfig?

    public init(
        temperature: Double? = nil,
        topP: Double? = nil,
        seed: Int? = nil,
        stopSequences: [String]? = nil,
        videoConfig: GeminiInteractionVideoConfig? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.seed = seed
        self.stopSequences = stopSequences
        self.videoConfig = videoConfig
    }

    enum CodingKeys: String, CodingKey {
        case temperature
        case topP = "top_p"
        case seed
        case stopSequences = "stop_sequences"
        case videoConfig = "video_config"
    }
}

public struct GeminiInteractionRequest: Codable, Equatable, Sendable {
    public var model: String?
    public var agent: String?
    public var input: GeminiInteractionInput
    public var systemInstruction: String?
    public var previousInteractionId: String?
    public var responseModalities: [String]?
    public var responseFormat: GeminiInteractionResponseFormatValue?
    public var generationConfig: GeminiInteractionGenerationConfig?
    public var tools: [GeminiInteractionTool]?
    public var environment: String?
    public var serviceTier: String?
    public var background: Bool?
    public var store: Bool?
    public var stream: Bool?

    public init(
        model: String? = nil,
        agent: String? = nil,
        input: GeminiInteractionInput,
        systemInstruction: String? = nil,
        previousInteractionId: String? = nil,
        responseModalities: [String]? = nil,
        responseFormat: GeminiInteractionResponseFormatValue? = nil,
        generationConfig: GeminiInteractionGenerationConfig? = nil,
        tools: [GeminiInteractionTool]? = nil,
        environment: String? = nil,
        serviceTier: String? = nil,
        background: Bool? = nil,
        store: Bool? = nil,
        stream: Bool? = nil
    ) {
        self.model = model
        self.agent = agent
        self.input = input
        self.systemInstruction = systemInstruction
        self.previousInteractionId = previousInteractionId
        self.responseModalities = responseModalities
        self.responseFormat = responseFormat
        self.generationConfig = generationConfig
        self.tools = tools
        self.environment = environment
        self.serviceTier = serviceTier
        self.background = background
        self.store = store
        self.stream = stream
    }

    enum CodingKeys: String, CodingKey {
        case model
        case agent
        case input
        case systemInstruction = "system_instruction"
        case previousInteractionId = "previous_interaction_id"
        case responseModalities = "response_modalities"
        case responseFormat = "response_format"
        case generationConfig = "generation_config"
        case tools
        case environment
        case serviceTier = "service_tier"
        case background
        case store
        case stream
    }
}

public struct GeminiInteractionModalityTokens: Codable, Equatable, Sendable {
    public var modality: String
    public var tokens: Int

    public init(modality: String, tokens: Int) {
        self.modality = modality
        self.tokens = tokens
    }
}

public struct GeminiInteractionUsage: Codable, Equatable, Sendable {
    public var totalTokens: Int?
    public var totalInputTokens: Int?
    public var totalOutputTokens: Int?
    public var totalCachedTokens: Int?
    public var totalToolUseTokens: Int?
    public var totalThoughtTokens: Int?
    public var inputTokensByModality: [GeminiInteractionModalityTokens]?
    public var outputTokensByModality: [GeminiInteractionModalityTokens]?
    public var cachedTokensByModality: [GeminiInteractionModalityTokens]?
    public var toolUseTokensByModality: [GeminiInteractionModalityTokens]?

    enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case totalCachedTokens = "total_cached_tokens"
        case totalToolUseTokens = "total_tool_use_tokens"
        case totalThoughtTokens = "total_thought_tokens"
        case inputTokensByModality = "input_tokens_by_modality"
        case outputTokensByModality = "output_tokens_by_modality"
        case cachedTokensByModality = "cached_tokens_by_modality"
        case toolUseTokensByModality = "tool_use_tokens_by_modality"
    }
}

public struct GeminiInteractionStep: Codable, Equatable, Sendable {
    public var type: String
    public var content: [GeminiInteractionContentBlock]?
    public var signature: String?

    public init(type: String, content: [GeminiInteractionContentBlock]? = nil, signature: String? = nil) {
        self.type = type
        self.content = content
        self.signature = signature
    }
}

public struct GeminiInteraction: Codable, Equatable, Sendable {
    public var id: String?
    public var status: String?
    public var model: String?
    public var agent: String?
    public var object: String?
    public var created: String?
    public var updated: String?
    public var environmentId: String?
    public var usage: GeminiInteractionUsage?
    public var steps: [GeminiInteractionStep]

    public init(
        id: String? = nil,
        status: String? = nil,
        model: String? = nil,
        agent: String? = nil,
        object: String? = nil,
        created: String? = nil,
        updated: String? = nil,
        environmentId: String? = nil,
        usage: GeminiInteractionUsage? = nil,
        steps: [GeminiInteractionStep] = []
    ) {
        self.id = id
        self.status = status
        self.model = model
        self.agent = agent
        self.object = object
        self.created = created
        self.updated = updated
        self.environmentId = environmentId
        self.usage = usage
        self.steps = steps
    }

    public var outputText: String? {
        for step in steps.reversed() where step.type == "model_output" {
            guard let content = step.content else { continue }

            var textBlocks: [String] = []
            var foundTextRun = false
            for block in content.reversed() {
                if block.type == "text", let text = block.text {
                    textBlocks.append(text)
                    foundTextRun = true
                } else if foundTextRun {
                    break
                }
            }

            if !textBlocks.isEmpty {
                return textBlocks.reversed().joined()
            }
        }
        return nil
    }

    public var outputImage: GeminiInteractionContentBlock? {
        lastOutputContent(where: { $0.type == "image" })
    }

    public var outputVideo: GeminiInteractionContentBlock? {
        lastOutputContent(where: { $0.type == "video" })
    }

    public var outputMetadata: [String: String] {
        guard let id, !id.isEmpty else { return [:] }
        return [GeminiInteractionMetadataKey.interactionId: id]
    }

    private func lastOutputContent(where predicate: (GeminiInteractionContentBlock) -> Bool)
        -> GeminiInteractionContentBlock?
    {
        for step in steps.reversed() where step.type == "model_output" {
            if let content = step.content?.last(where: predicate) {
                return content
            }
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case model
        case agent
        case object
        case created
        case updated
        case environmentId = "environment_id"
        case usage
        case steps
    }
}

public final class GeminiInteractionsService: @unchecked Sendable {
    public static let defaultBaseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!
    public static let apiRevision = "2026-05-20"

    private let networkProvider: (any NetworkProvider)?
    private let baseURL: URL

    public init(
        networkProvider: (any NetworkProvider)? = nil,
        baseURL: URL = GeminiInteractionsService.defaultBaseURL
    ) {
        self.networkProvider = networkProvider
        self.baseURL = baseURL
    }

    public func createInteraction(
        request: GeminiInteractionRequest,
        apiKey: String
    ) async throws -> GeminiInteraction {
        guard !apiKey.isEmpty else {
            throw GeminiInteractionsError.missingAPIKey
        }

        let response = try await provider.performRequest(
            url: baseURL,
            method: "POST",
            body: request,
            headers: headers(apiKey: apiKey),
            attachments: nil
        )

        return try Self.decodeInteraction(from: response)
    }

    public func getInteraction(id: String, apiKey: String) async throws -> GeminiInteraction {
        guard !apiKey.isEmpty else {
            throw GeminiInteractionsError.missingAPIKey
        }

        let url = baseURL.appendingPathComponent(id)

        let response = try await provider.performRequest(
            url: url,
            method: "GET",
            body: nil as String?,
            headers: headers(apiKey: apiKey),
            attachments: nil
        )

        return try Self.decodeInteraction(from: response)
    }

    public static func decodeInteraction(from response: NetworkResponseData) throws -> GeminiInteraction {
        guard case let .dictionary(statusCode, data) = response else {
            throw GeminiInteractionsError.invalidResponse(response.rawResponseString ?? "Invalid Interactions response")
        }

        if let error = data["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Gemini Interactions API returned an error"
            throw GeminiInteractionsError.providerError(message)
        }

        guard (200 ... 299).contains(statusCode) else {
            throw GeminiInteractionsError.providerError(response.rawResponseString ?? "HTTP \(statusCode)")
        }

        guard JSONSerialization.isValidJSONObject(data),
              let jsonData = try? JSONSerialization.data(withJSONObject: data)
        else {
            throw GeminiInteractionsError.invalidResponse("Unable to serialize Interactions response")
        }

        do {
            return try JSONDecoder().decode(GeminiInteraction.self, from: jsonData)
        } catch {
            throw GeminiInteractionsError
                .invalidResponse("Unable to decode Interactions response: \(error.localizedDescription)")
        }
    }

    private var provider: any NetworkProvider {
        networkProvider ?? ProviderDependencies.shared.networkProvider
    }

    private func headers(apiKey: String) -> [String: String] {
        [
            "Content-Type": "application/json",
            "Api-Revision": Self.apiRevision,
            "x-goog-api-key": apiKey,
        ]
    }
}
