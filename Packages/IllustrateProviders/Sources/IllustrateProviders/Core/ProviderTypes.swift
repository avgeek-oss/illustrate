// MARK: - ProviderTypes.swift

// Core types for provider implementations.
// These types define the interfaces for image and video generation.

import Foundation

// MARK: - Network Response Types

/// Discriminated union for API response types.
///
/// Each case includes the HTTP status code for debugging.
public enum NetworkResponseData: @unchecked Sendable {
    /// JSON object response (most common)
    case dictionary(statusCode: Int, data: [String: Any])
    /// JSON array response (some APIs return arrays)
    case array(statusCode: Int, data: [[String: Any]])
    /// Binary image response (Stability fast upscale, etc.)
    case image(statusCode: Int, base64: String, mimeType: String)

    /// HTTP status carried by every parsed response shape.
    public var statusCode: Int {
        switch self {
        case let .dictionary(statusCode, _),
             let .array(statusCode, _),
             let .image(statusCode, _, _):
            statusCode
        }
    }

    /// Extracts a human-readable response string for debugging and error reporting.
    ///
    /// Returns a formatted string containing the HTTP status code and:
    /// - For `.dictionary`: Pretty-printed JSON object
    /// - For `.array`: Pretty-printed JSON array
    /// - For `.image`: MIME type information (not the binary data)
    ///
    /// ## Example
    /// ```swift
    /// let response = NetworkResponseData.dictionary(statusCode: 200, data: ["key": "value"])
    /// print(response.rawResponseString ?? "No response")
    /// // Output:
    /// // HTTP Status: 200
    /// //
    /// // {
    /// //   "key" : "value"
    /// // }
    /// ```
    public var rawResponseString: String? {
        switch self {
        case let .dictionary(statusCode, data):
            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]),
               let jsonString = String(data: jsonData, encoding: .utf8)
            {
                return "HTTP Status: \(statusCode)\n\n\(jsonString)"
            }
            return "HTTP Status: \(statusCode)\n\nUnable to serialize response"
        case let .array(statusCode, data):
            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]),
               let jsonString = String(data: jsonData, encoding: .utf8)
            {
                return "HTTP Status: \(statusCode)\n\n\(jsonString)"
            }
            return "HTTP Status: \(statusCode)\n\nUnable to serialize response"
        case let .image(statusCode, _, mimeType):
            return "HTTP Status: \(statusCode)\n\nBinary image response (mimeType: \(mimeType))"
        }
    }
}

/// Response returned by a single-attempt HTTP operation.
///
/// Paid generation requests must not be retried automatically because a
/// retry can create a second billable job. This envelope preserves the exact
/// status, headers, and raw response bytes even when the server returns a
/// non-2xx status or a body that is not valid JSON. `response` contains the
/// existing parsed representation when decoding succeeds.
public struct NetworkResponseEnvelope: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data
    public let response: NetworkResponseData?

    public init(
        statusCode: Int,
        headers: [String: String] = [:],
        body: Data = Data(),
        response: NetworkResponseData? = nil
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.response = response
    }

    /// Convenience initializer for deterministic provider fixtures.
    public init(
        response: NetworkResponseData,
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        self.init(
            statusCode: response.statusCode,
            headers: headers,
            body: body,
            response: response
        )
    }

    public var bodyString: String? {
        String(data: body, encoding: .utf8)
    }

    public func headerValue(for field: String) -> String? {
        headers.first { key, _ in
            key.caseInsensitiveCompare(field) == .orderedSame
        }?.value
    }

    public func requireParsedResponse() throws -> NetworkResponseData {
        guard let response else {
            throw NetworkResponseEnvelopeError.unparseableBody(statusCode: statusCode)
        }
        return response
    }
}

public enum NetworkResponseEnvelopeError: Error, Equatable, LocalizedError {
    case unparseableBody(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case let .unparseableBody(statusCode):
            "HTTP \(statusCode) response body could not be decoded."
        }
    }
}

/// Unparsed response bytes for generated media downloads.
///
/// Provider status APIs use `NetworkResponseData`, while temporary image and
/// video URLs use this type so adapters can materialize any media MIME type
/// without bypassing the injected network dependency.
public struct NetworkDataResponse: Sendable {
    public let statusCode: Int
    public let data: Data
    public let headers: [String: String]

    public init(statusCode: Int, data: Data, headers: [String: String] = [:]) {
        self.statusCode = statusCode
        self.data = data
        self.headers = headers
    }

    public var contentType: String? {
        headers.first { key, _ in
            key.caseInsensitiveCompare("Content-Type") == .orderedSame
        }?.value
    }
}

/// File attachment for multipart form requests.
public struct NetworkRequestAttachment: Sendable {
    /// Form field name
    public var name: String
    /// MIME type (e.g., "image/png")
    public var mimeType: String
    /// Binary file data
    public var data: Data

    public init(name: String, mimeType: String, data: Data) {
        self.name = name
        self.mimeType = mimeType
        self.data = data
    }
}

// MARK: - Reference Image Data

/// Data for a reference image used in generation.
public struct ReferenceImageData: Codable, Sendable {
    public var base64Image: String
    public var referenceType: String
    public var cacheKey: String?
    public var mimeType: String
    public var frameIndex: Int?

    public init(
        base64Image: String,
        referenceType: String = "",
        cacheKey: String? = nil,
        mimeType: String = "image/png",
        frameIndex: Int? = nil
    ) {
        self.base64Image = base64Image
        self.referenceType = referenceType
        self.cacheKey = cacheKey
        self.mimeType = mimeType
        self.frameIndex = frameIndex
    }
}

// MARK: - Image Edit Direction

/// Directional parameters for outpainting operations.
public struct ImageEditDirection: Codable, Sendable {
    public var left: Int
    public var right: Int
    public var up: Int
    public var down: Int

    public init(left: Int, right: Int, up: Int, down: Int) {
        self.left = left
        self.right = right
        self.up = up
        self.down = down
    }
}

// MARK: - Image Generation Types

/// Unified request format for image generation across all providers.
public struct ImageGenerationRequest: Codable, Sendable {
    public var modelId: String
    public var prompt: String
    public var searchPrompt: String?
    public var negativePrompt: String?
    public var variant: String
    public var quality: String
    public var style: String
    public var dimensions: String
    public var clientImage: String?
    public var clientMask: String?
    public var clientReferenceImages: [ReferenceImageData]?
    public var providerKey: ProviderKeyInfo
    public var providerSecret: String
    public var numberOfImages: Int
    public var editDirection: ImageEditDirection?
    public var resolution: String?
    public var steps: Int?
    public var guidance: Double?
    public var seed: Int?
    public var safetyTolerance: Int?
    public var promptEnhance: Bool?
    public var background: String?
    public var inputFidelity: String?
    public var moderation: String?
    public var growMask: Int?
    public var selectedTools: [String]?
    public var personGeneration: String?

    public init(
        modelId: String,
        prompt: String,
        searchPrompt: String? = nil,
        negativePrompt: String? = nil,
        variant: String = "",
        quality: String = "",
        style: String = "",
        dimensions: String,
        clientImage: String? = nil,
        clientMask: String? = nil,
        clientReferenceImages: [ReferenceImageData]? = nil,
        providerKey: ProviderKeyInfo,
        providerSecret: String,
        numberOfImages: Int = 1,
        editDirection: ImageEditDirection? = nil,
        resolution: String? = nil,
        steps: Int? = nil,
        guidance: Double? = nil,
        seed: Int? = nil,
        safetyTolerance: Int? = nil,
        promptEnhance: Bool? = nil,
        background: String? = nil,
        inputFidelity: String? = nil,
        moderation: String? = nil,
        growMask: Int? = nil,
        selectedTools: [String]? = nil,
        personGeneration: String? = nil
    ) {
        self.modelId = modelId
        self.prompt = prompt
        self.searchPrompt = searchPrompt
        self.negativePrompt = negativePrompt
        self.variant = variant
        self.quality = quality
        self.style = style
        self.dimensions = dimensions
        self.clientImage = clientImage
        self.clientMask = clientMask
        self.clientReferenceImages = clientReferenceImages
        self.providerKey = providerKey
        self.providerSecret = providerSecret
        self.numberOfImages = numberOfImages
        self.editDirection = editDirection
        self.resolution = resolution
        self.steps = steps
        self.guidance = guidance
        self.seed = seed
        self.safetyTolerance = safetyTolerance
        self.promptEnhance = promptEnhance
        self.background = background
        self.inputFidelity = inputFidelity
        self.moderation = moderation
        self.growMask = growMask
        self.selectedTools = selectedTools
        self.personGeneration = personGeneration
    }
}

/// Cost calculation request for image generation.
public struct ImageGenerationCostRequest: Sendable {
    public var modelId: String?
    public var quality: String?
    public var dimensions: String?
    public var resolution: String?
    public var numberOfImages: Int?
    public var hasSourceImage: Bool
    public var referenceImageCount: Int
    public var providerSecret: String?

    public init(
        modelId: String? = nil,
        quality: String? = nil,
        dimensions: String? = nil,
        resolution: String? = nil,
        numberOfImages: Int? = nil,
        hasSourceImage: Bool = false,
        referenceImageCount: Int = 0,
        providerSecret: String? = nil
    ) {
        self.modelId = modelId
        self.quality = quality
        self.dimensions = dimensions
        self.resolution = resolution
        self.numberOfImages = numberOfImages
        self.hasSourceImage = hasSourceImage
        self.referenceImageCount = referenceImageCount
        self.providerSecret = providerSecret
    }

    public init(from request: ImageGenerationRequest) {
        modelId = request.modelId
        quality = request.quality
        dimensions = request.dimensions
        resolution = request.resolution
        numberOfImages = request.numberOfImages
        hasSourceImage = request.clientImage?.isEmpty == false
        referenceImageCount = request.clientReferenceImages?.count ?? 0
        providerSecret = request.providerSecret
    }
}

/// Response from image generation.
public struct ImageGenerationResponse: Codable, Sendable {
    public var generationId: UUID?
    public var status: EnumGenerationStatus
    public var base64: String?
    public var size: Int?
    public var cost: Double?
    public var modelPrompt: String?
    public var colorPalette: [String]?
    public var errorCode: EnumGenerationAdapterErrorCode?
    public var errorMessage: String?
    public var rawResponse: String?
    public var metadata: [String: String]?
    public var actualDimensions: String?

    public init(
        generationId: UUID? = nil,
        status: EnumGenerationStatus,
        base64: String? = nil,
        size: Int? = nil,
        cost: Double? = nil,
        modelPrompt: String? = nil,
        colorPalette: [String]? = nil,
        errorCode: EnumGenerationAdapterErrorCode? = nil,
        errorMessage: String? = nil,
        rawResponse: String? = nil,
        metadata: [String: String]? = nil,
        actualDimensions: String? = nil
    ) {
        self.generationId = generationId
        self.status = status
        self.base64 = base64
        self.size = size
        self.cost = cost
        self.modelPrompt = modelPrompt
        self.colorPalette = colorPalette
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.rawResponse = rawResponse
        self.metadata = metadata
        self.actualDimensions = actualDimensions
    }
}

// MARK: - Video Generation Types

/// Request for video generation cost calculation.
public struct VideoGenerationCostRequest: Sendable {
    public var dimensions: String?
    public var durationSeconds: Int?
    public var numberOfVideos: Int?
    public var resolution: String?
    public var generateAudio: Bool?
    public var hasSourceImage: Bool
    public var hasReferenceImages: Bool
    public var referenceImageCount: Int
    public var lumaHDR: Bool?
    public var lumaEXRExport: Bool?
    public var lumaLoop: Bool?
    public var providerSecret: String?

    public init(
        dimensions: String? = nil,
        durationSeconds: Int? = nil,
        numberOfVideos: Int? = nil,
        resolution: String? = nil,
        generateAudio: Bool? = nil,
        hasSourceImage: Bool = false,
        hasReferenceImages: Bool = false,
        referenceImageCount: Int = 0,
        lumaHDR: Bool? = nil,
        lumaEXRExport: Bool? = nil,
        lumaLoop: Bool? = nil,
        providerSecret: String? = nil
    ) {
        self.dimensions = dimensions
        self.durationSeconds = durationSeconds
        self.numberOfVideos = numberOfVideos
        self.resolution = resolution
        self.generateAudio = generateAudio
        self.hasSourceImage = hasSourceImage
        self.hasReferenceImages = hasReferenceImages
        self.referenceImageCount = referenceImageCount
        self.lumaHDR = lumaHDR
        self.lumaEXRExport = lumaEXRExport
        self.lumaLoop = lumaLoop
        self.providerSecret = providerSecret
    }

    public init(from request: VideoGenerationRequest) {
        dimensions = request.dimensions
        durationSeconds = request.durationSeconds
        numberOfVideos = request.numberOfVideos
        resolution = request.resolution
        generateAudio = request.generateAudio
        hasSourceImage = request.clientImage?.isEmpty == false
        hasReferenceImages = request.clientReferenceImages?.isEmpty == false
        referenceImageCount = request.clientReferenceImages?.count ?? 0
        lumaHDR = request.lumaHDR
        lumaEXRExport = request.lumaEXRExport
        lumaLoop = request.lumaLoop
        providerSecret = request.providerSecret
    }
}

/// Unified request format for video generation across all providers.
///
/// Captures all parameters for video generation including duration,
/// resolution, audio, and video extension data.
public struct VideoGenerationRequest: Codable, Sendable {
    public var modelId: String
    public var prompt: String?
    public var searchPrompt: String?
    public var negativePrompt: String?
    public var dimensions: String
    public var clientImage: String?
    public var clientMask: String?
    public var clientLastFrame: String?
    public var clientVideo: String?
    public var clientReferenceImages: [ReferenceImageData]?
    public var providerKey: ProviderKeyInfo
    public var providerSecret: String
    public var numberOfVideos: Int
    public var motion: Int?
    public var stickyness: Int?
    public var durationSeconds: Int?
    public var resolution: String?
    public var fps: Int?
    public var generateAudio: Bool?
    public var steps: Int?
    public var guidance: Double?
    public var seed: Int?
    public var safetyTolerance: Int?
    public var promptEnhance: Bool?
    public var moderation: String?
    public var sourceMetadata: [String: String]?
    public var lumaHDR: Bool?
    public var lumaEXRExport: Bool?
    public var lumaLoop: Bool?

    public init(
        modelId: String,
        prompt: String? = nil,
        searchPrompt: String? = nil,
        negativePrompt: String? = nil,
        dimensions: String,
        clientImage: String? = nil,
        clientMask: String? = nil,
        clientLastFrame: String? = nil,
        clientVideo: String? = nil,
        clientReferenceImages: [ReferenceImageData]? = nil,
        providerKey: ProviderKeyInfo,
        providerSecret: String,
        numberOfVideos: Int = 1,
        motion: Int? = nil,
        stickyness: Int? = nil,
        durationSeconds: Int? = nil,
        resolution: String? = nil,
        fps: Int? = nil,
        generateAudio: Bool? = nil,
        steps: Int? = nil,
        guidance: Double? = nil,
        seed: Int? = nil,
        safetyTolerance: Int? = nil,
        promptEnhance: Bool? = nil,
        moderation: String? = nil,
        sourceMetadata: [String: String]? = nil,
        lumaHDR: Bool? = nil,
        lumaEXRExport: Bool? = nil,
        lumaLoop: Bool? = nil
    ) {
        self.modelId = modelId
        self.prompt = prompt
        self.searchPrompt = searchPrompt
        self.negativePrompt = negativePrompt
        self.dimensions = dimensions
        self.clientImage = clientImage
        self.clientMask = clientMask
        self.clientLastFrame = clientLastFrame
        self.clientVideo = clientVideo
        self.clientReferenceImages = clientReferenceImages
        self.providerKey = providerKey
        self.providerSecret = providerSecret
        self.numberOfVideos = numberOfVideos
        self.motion = motion
        self.stickyness = stickyness
        self.durationSeconds = durationSeconds
        self.resolution = resolution
        self.fps = fps
        self.generateAudio = generateAudio
        self.steps = steps
        self.guidance = guidance
        self.seed = seed
        self.safetyTolerance = safetyTolerance
        self.promptEnhance = promptEnhance
        self.moderation = moderation
        self.sourceMetadata = sourceMetadata
        self.lumaHDR = lumaHDR
        self.lumaEXRExport = lumaEXRExport
        self.lumaLoop = lumaLoop
    }
}

/// Response from video generation.
public struct VideoGenerationResponse: Codable, Sendable {
    public var generationId: UUID?
    public var status: EnumGenerationStatus
    public var base64: String?
    public var videoUrl: String?
    public var size: Int?
    public var cost: Double?
    public var modelPrompt: String?
    public var colorPalette: [String]?
    public var errorCode: EnumGenerationAdapterErrorCode?
    public var errorMessage: String?
    public var rawResponse: String?
    public var metadata: [String: String]?
    public var actualDimensions: String?
    public var actualDuration: Int?

    public init(
        generationId: UUID? = nil,
        status: EnumGenerationStatus,
        base64: String? = nil,
        videoUrl: String? = nil,
        size: Int? = nil,
        cost: Double? = nil,
        modelPrompt: String? = nil,
        colorPalette: [String]? = nil,
        errorCode: EnumGenerationAdapterErrorCode? = nil,
        errorMessage: String? = nil,
        rawResponse: String? = nil,
        metadata: [String: String]? = nil,
        actualDimensions: String? = nil,
        actualDuration: Int? = nil
    ) {
        self.generationId = generationId
        self.status = status
        self.base64 = base64
        self.videoUrl = videoUrl
        self.size = size
        self.cost = cost
        self.modelPrompt = modelPrompt
        self.colorPalette = colorPalette
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.rawResponse = rawResponse
        self.metadata = metadata
        self.actualDimensions = actualDimensions
        self.actualDuration = actualDuration
    }
}

// MARK: - Provider Key Info

/// Minimal provider key information needed for API requests.
public struct ProviderKeyInfo: Codable, Sendable {
    public var providerId: UUID
    public var providerCode: EnumProviderCode
    public var projectId: UUID

    public init(providerId: UUID, providerCode: EnumProviderCode, projectId: UUID) {
        self.providerId = providerId
        self.providerCode = providerCode
        self.projectId = projectId
    }
}
