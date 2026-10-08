// MARK: - G_LUMA_IMAGE_BASE.swift

// Base implementation for Luma AI image generation models.
//
// Luma AI's image API uses async polling:
// 1. POST /dream-machine/v1/generations/image → get generation ID
// 2. GET /dream-machine/v1/generations/{id} to poll until completed
// 3. On completion, download from assets.image URL
//
// Models: photon-1, photon-flash-1

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public class G_LUMA_IMAGE_BASE: ImageGenerationProtocol {
    let modelCode: EnumProviderModelCode
    let modelName: String
    let pricePerImage: Double

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(modelCode: EnumProviderModelCode, modelName: String, pricePerImage: Double) {
        self.modelCode = modelCode
        self.modelName = modelName
        self.pricePerImage = pricePerImage
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        pricePerImage * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let model: String
        let prompt: String?
        let aspect_ratio: String?
        let image_ref: [ImageRef]?
        let modify_image_ref: ModifyImageRef?

        public init(
            model: String,
            prompt: String? = nil,
            aspectRatio: String? = nil,
            imageRef: [ImageRef]? = nil,
            modifyImageRef: ModifyImageRef? = nil
        ) {
            self.model = model
            self.prompt = prompt
            aspect_ratio = aspectRatio
            image_ref = imageRef
            modify_image_ref = modifyImageRef
        }
    }

    public struct ImageRef: Codable, Sendable {
        let url: String
        let weight: Double?

        public init(url: String, weight: Double? = nil) {
            self.url = url
            self.weight = weight
        }
    }

    public struct ModifyImageRef: Codable, Sendable {
        let url: String
        let weight: Double?

        public init(url: String, weight: Double? = nil) {
            self.url = url
            self.weight = weight
        }
    }

    func normalizeAspectRatio(from dimensions: String) -> String {
        if dimensions.contains(":") { return dimensions }

        let parts = dimensions.split(separator: "x")
        guard parts.count == 2,
              let w = Double(parts[0]),
              let h = Double(parts[1]),
              w > 0, h > 0
        else {
            return "1:1"
        }

        let candidates: [(label: String, ratio: Double)] = [
            ("1:1", 1.0),
            ("16:9", 16.0 / 9.0),
            ("9:16", 9.0 / 16.0),
            ("4:3", 4.0 / 3.0),
            ("3:4", 3.0 / 4.0),
            ("21:9", 21.0 / 9.0),
            ("9:21", 9.0 / 21.0),
        ]

        let r = w / h
        let best = candidates.min(by: { abs($0.ratio - r) < abs($1.ratio - r) })
        return best?.label ?? "1:1"
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        var imageRef: [ImageRef]? = nil
        var modifyRef: ModifyImageRef? = nil

        if let clientImage = request.clientImage {
            let cleanBase64 = clientImage.replacingOccurrences(
                of: "^data:.*;base64,",
                with: "",
                options: .regularExpression
            )
            let dataUri = "data:image/png;base64,\(cleanBase64)"
            imageRef = [ImageRef(url: dataUri)]
            modifyRef = ModifyImageRef(url: dataUri)
        }

        return ServiceRequest(
            model: modelName,
            prompt: request.prompt,
            aspectRatio: normalizeAspectRatio(from: request.dimensions),
            imageRef: imageRef,
            modifyImageRef: modifyRef
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let assets = data["assets"] as? [String: Any],
               let imageUrl = assets["image"] as? String
            {
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: nil,
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
                    rawResponse: imageUrl
                )
            }

            if let error = data["detail"] as? String {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: error,
                    rawResponse: response.rawResponseString
                )
            }
        default:
            break
        }

        return createInvalidResponseError(response: response, modelCode: modelCode)
    }

    func pollForResult(
        generationId: String,
        apiKey: String,
        maxAttempts: Int = 120
    ) async throws -> [String: Any] {
        var attempts = 0

        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 5_000_000_000)

            guard let statusURL = URL(
                string: "https://api.lumalabs.ai/dream-machine/v1/generations/\(generationId)"
            ) else {
                throw NSError(domain: "Invalid status URL", code: -1, userInfo: nil)
            }

            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: statusURL,
                method: "GET",
                body: nil as String?,
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                ],
                attachments: nil
            )

            switch response {
            case let .dictionary(_, data):
                if let state = data["state"] as? String {
                    if state == "completed" {
                        return data
                    } else if state == "failed" {
                        let reason = data["failure_reason"] as? String ?? "Image generation failed"
                        throw NSError(domain: reason, code: -1, userInfo: nil)
                    }
                }
            default:
                break
            }

            attempts += 1
        }

        throw NSError(domain: "Polling exceeded max attempts", code: -1, userInfo: nil)
    }

    func downloadImage(url: String) async throws -> Data {
        guard let downloadURL = URL(string: url) else {
            throw NSError(domain: "Invalid download URL", code: -1, userInfo: nil)
        }

        var request = URLRequest(url: downloadURL)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw NSError(domain: "Failed to download image", code: -1, userInfo: nil)
        }

        return data
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let transformedRequest = transformRequest(request: request)

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: transformedRequest,
                headers: [
                    "Authorization": "Bearer \(request.providerSecret)",
                    "Content-Type": "application/json",
                ],
                attachments: nil
            )

            var generationId: String?

            switch initialResponse {
            case let .dictionary(_, data):
                if let error = data["detail"] as? String {
                    return ImageGenerationResponse(
                        status: .FAILED,
                        errorCode: .MODEL_ERROR,
                        errorMessage: error,
                        rawResponse: initialResponse.rawResponseString
                    )
                }
                generationId = data["id"] as? String
            default:
                return createInvalidResponseError(
                    response: initialResponse,
                    modelCode: modelCode,
                    customMessage: "Unexpected response from image creation"
                )
            }

            guard let id = generationId else {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "No generation ID in response",
                    rawResponse: initialResponse.rawResponseString
                )
            }

            let finalResult = try await pollForResult(
                generationId: id,
                apiKey: request.providerSecret
            )

            guard let assets = finalResult["assets"] as? [String: Any],
                  let imageUrl = assets["image"] as? String
            else {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "No image URL in completed response"
                )
            }

            let imageData = try await downloadImage(url: imageUrl)

            return ImageGenerationResponse(
                status: .GENERATED,
                base64: imageData.base64EncodedString(),
                cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
                modelPrompt: request.prompt,
                metadata: ["lumaGenerationId": id]
            )
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed with error: \(error.localizedDescription)",
                rawResponse: "Error: \(error.localizedDescription)"
            )
        }
    }
}

public class G_LUMA_PHOTON: G_LUMA_IMAGE_BASE {
    public init() {
        super.init(modelCode: .LUMA_PHOTON, modelName: "photon-1", pricePerImage: 0.08)
    }
}

public class G_LUMA_PHOTON_FLASH: G_LUMA_IMAGE_BASE {
    public init() {
        super.init(modelCode: .LUMA_PHOTON_FLASH, modelName: "photon-flash-1", pricePerImage: 0.02)
    }
}

public class G_LUMA_AGENTS_IMAGE_BASE: ImageGenerationProtocol {
    let modelCode: EnumProviderModelCode
    let modelName: String
    let textToImagePrice: Double
    let referencedImagePrice: Double

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        modelCode: EnumProviderModelCode,
        modelName: String,
        textToImagePrice: Double,
        referencedImagePrice: Double
    ) {
        self.modelCode = modelCode
        self.modelName = modelName
        self.textToImagePrice = textToImagePrice
        self.referencedImagePrice = referencedImagePrice
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let inputImageCount = min(
            9,
            (request.hasSourceImage ? 1 : 0) + max(0, request.referenceImageCount)
        )
        let perImageCost: Double = if inputImageCount == 0 {
            textToImagePrice
        } else {
            referencedImagePrice + (Double(inputImageCount - 1) * 0.003)
        }

        return perImageCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let model: String
        let type: String
        let prompt: String
        let aspect_ratio: String?
        let source: ImageRef?
        let image_ref: [ImageRef]?

        public init(
            model: String,
            type: String,
            prompt: String,
            aspectRatio: String?,
            source: ImageRef?,
            imageRef: [ImageRef]?
        ) {
            self.model = model
            self.type = type
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.source = source
            image_ref = imageRef
        }
    }

    public struct ImageRef: Codable, Sendable {
        let data: String
        let media_type: String

        public init(data: String, mediaType: String) {
            self.data = data
            media_type = mediaType
        }
    }

    func normalizeAspectRatio(from dimensions: String) -> String {
        if supportedAspectRatios.contains(dimensions) { return dimensions }

        let parts = dimensions.split(separator: "x")
        guard parts.count == 2,
              let w = Double(parts[0]),
              let h = Double(parts[1]),
              w > 0, h > 0
        else {
            return "1:1"
        }

        let ratio = w / h
        let best = supportedAspectRatios.min { lhs, rhs in
            abs(aspectRatioValue(lhs) - ratio) < abs(aspectRatioValue(rhs) - ratio)
        }
        return best ?? "1:1"
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let source = request.clientImage.flatMap {
            imageRef(fromBase64: $0)
        }
        let maxReferenceImages = source == nil ? 9 : 8
        let imageRefs = request.clientReferenceImages?
            .prefix(maxReferenceImages)
            .compactMap { imageRef(fromBase64: $0.base64Image, mimeType: $0.mimeType) }

        return ServiceRequest(
            model: modelName,
            type: source == nil ? "image" : "image_edit",
            prompt: request.prompt,
            aspectRatio: source == nil ? normalizeAspectRatio(from: request.dimensions) : nil,
            source: source,
            imageRef: imageRefs?.isEmpty == false ? imageRefs : nil
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let errorMessage = errorMessage(from: data) {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: errorMessage,
                    rawResponse: response.rawResponseString
                )
            }

            if state(from: data) == "failed" {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: failureMessage(from: data),
                    rawResponse: response.rawResponseString
                )
            }

            if let imageURL = outputImageURL(from: data) {
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: nil,
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
                    rawResponse: imageURL,
                    metadata: generationMetadata(from: data)
                )
            }
        default:
            break
        }

        return createInvalidResponseError(response: response, modelCode: modelCode)
    }

    func pollForResult(
        generationId: String,
        apiKey: String,
        maxDurationSeconds: Double = 120,
        initialDelaySeconds: UInt64 = 5,
        pollIntervalSeconds: UInt64 = 2
    ) async throws -> [String: Any] {
        let deadline = Date().addingTimeInterval(maxDurationSeconds)
        try await sleep(seconds: initialDelaySeconds)

        while Date() < deadline {
            guard let statusURL =
                URL(string: "\(model.modelStatusBaseURL ?? model.modelGenerateBaseURL)/\(generationId)")
            else {
                throw NSError(domain: "Invalid status URL", code: -1, userInfo: nil)
            }

            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: statusURL,
                method: "GET",
                body: nil as String?,
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                ],
                attachments: nil
            )

            switch response {
            case let .dictionary(_, data):
                if state(from: data) == "completed" {
                    return data
                }
                if state(from: data) == "failed" {
                    throw NSError(domain: failureMessage(from: data), code: -1, userInfo: nil)
                }
            default:
                break
            }

            try await sleep(seconds: pollIntervalSeconds)
        }

        throw NSError(domain: "Polling exceeded max duration", code: -1, userInfo: nil)
    }

    func downloadImage(url: String) async throws -> Data {
        guard let downloadURL = URL(string: url) else {
            throw NSError(domain: "Invalid download URL", code: -1, userInfo: nil)
        }

        var request = URLRequest(url: downloadURL)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw NSError(domain: "Failed to download image", code: -1, userInfo: nil)
        }

        return data
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let transformedRequest = transformRequest(request: request)

        do {
            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: transformedRequest,
                headers: [
                    "Authorization": "Bearer \(request.providerSecret)",
                    "Content-Type": "application/json",
                ],
                attachments: nil
            )

            switch initialResponse {
            case let .dictionary(_, data):
                if let errorMessage = errorMessage(from: data) {
                    return ImageGenerationResponse(
                        status: .FAILED,
                        errorCode: .MODEL_ERROR,
                        errorMessage: errorMessage,
                        rawResponse: initialResponse.rawResponseString
                    )
                }
                if state(from: data) == "failed" {
                    return ImageGenerationResponse(
                        status: .FAILED,
                        errorCode: .MODEL_ERROR,
                        errorMessage: failureMessage(from: data),
                        rawResponse: initialResponse.rawResponseString
                    )
                }

                let finalResult: [String: Any]
                if state(from: data) == "completed" {
                    finalResult = data
                } else {
                    guard let id = data["id"] as? String else {
                        return ImageGenerationResponse(
                            status: .FAILED,
                            errorCode: .MODEL_ERROR,
                            errorMessage: "No generation ID in response",
                            rawResponse: initialResponse.rawResponseString
                        )
                    }
                    finalResult = try await pollForResult(
                        generationId: id,
                        apiKey: request.providerSecret
                    )
                }

                guard let imageURL = outputImageURL(from: finalResult) else {
                    return ImageGenerationResponse(
                        status: .FAILED,
                        errorCode: .MODEL_ERROR,
                        errorMessage: "No image URL in completed response"
                    )
                }

                let imageData = try await downloadImage(url: imageURL)

                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData.base64EncodedString(),
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
                    modelPrompt: request.prompt,
                    metadata: generationMetadata(from: finalResult)
                )
            default:
                return createInvalidResponseError(
                    response: initialResponse,
                    modelCode: modelCode,
                    customMessage: "Unexpected response from image creation"
                )
            }
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed with error: \(error.localizedDescription)",
                rawResponse: "Error: \(error.localizedDescription)"
            )
        }
    }

    private let supportedAspectRatios: [String] = [
        "3:1",
        "2:1",
        "16:9",
        "3:2",
        "1:1",
        "2:3",
        "9:16",
        "1:2",
        "1:3",
    ]

    private func aspectRatioValue(_ aspectRatio: String) -> Double {
        let parts = aspectRatio.split(separator: ":")
        guard parts.count == 2,
              let w = Double(parts[0]),
              let h = Double(parts[1]),
              h > 0
        else {
            return 1
        }
        return w / h
    }

    private func imageRef(fromBase64 base64: String, mimeType: String? = nil) -> ImageRef? {
        let payload = parseBase64Payload(from: base64)
        guard !payload.data.isEmpty else { return nil }
        return ImageRef(data: payload.data, mediaType: payload.mimeType ?? mimeType ?? "image/png")
    }

    private func parseBase64Payload(from base64: String) -> (data: String, mimeType: String?) {
        guard base64.hasPrefix("data:"),
              let commaIndex = base64.firstIndex(of: ",")
        else {
            return (base64, nil)
        }

        let header = String(base64[..<commaIndex])
        guard header.lowercased().contains(";base64") else {
            return (base64, nil)
        }

        let mimeTypeCandidate = header
            .dropFirst("data:".count)
            .split(separator: ";")
            .first
            .map(String.init)
        let mimeType = mimeTypeCandidate?.contains("/") == true ? mimeTypeCandidate : nil
        let dataStart = base64.index(after: commaIndex)
        return (String(base64[dataStart...]), mimeType)
    }

    private func state(from data: [String: Any]) -> String? {
        data["state"] as? String ?? data["status"] as? String
    }

    private func outputImageURL(from data: [String: Any]) -> String? {
        guard let output = data["output"] as? [[String: Any]] else { return nil }
        return output.first { ($0["type"] as? String) == "image" }?["url"] as? String
            ?? output.compactMap { $0["url"] as? String }.first
    }

    private func errorMessage(from data: [String: Any]) -> String? {
        if let detail = data["detail"] as? String { return detail }
        if let error = data["error"] as? String { return error }
        if let detail = data["detail"] as? [String: Any],
           let message = detail["message"] as? String
        {
            return message
        }
        if let error = data["error"] as? [String: Any],
           let message = error["message"] as? String
        {
            return message
        }
        return nil
    }

    private func failureMessage(from data: [String: Any]) -> String {
        data["failure_reason"] as? String
            ?? data["failure_message"] as? String
            ?? data["message"] as? String
            ?? "Image generation failed"
    }

    private func generationMetadata(from data: [String: Any]) -> [String: String]? {
        guard let id = data["id"] as? String else { return nil }
        return ["lumaGenerationId": id]
    }

    private func sleep(seconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
    }
}

public final class G_LUMA_UNI_1: G_LUMA_AGENTS_IMAGE_BASE {
    public init() {
        super.init(
            modelCode: .LUMA_UNI_1,
            modelName: "uni-1",
            textToImagePrice: 0.0404,
            referencedImagePrice: 0.0434
        )
    }
}

public final class G_LUMA_UNI_1_MAX: G_LUMA_AGENTS_IMAGE_BASE {
    public init() {
        super.init(
            modelCode: .LUMA_UNI_1_MAX,
            modelName: "uni-1-max",
            textToImagePrice: 0.1,
            referencedImagePrice: 0.103
        )
    }
}
