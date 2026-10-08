// MARK: - G_FAL_LUMA.swift

// Luma Photon models via Fal AI:
// - fal-ai/luma-photon (text-to-image)
// - fal-ai/luma-photon/flash (text-to-image)
// - fal-ai/luma-photon/modify (image-to-image)
// - fal-ai/luma-photon/flash/modify (image-to-image)
// - fal-ai/luma-photon/reframe (outpainting)
// - fal-ai/luma-photon/flash/reframe (outpainting)

import Foundation

// MARK: - Base Class

public class FalLumaBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var costPerMegapixel: Double {
        0.019
    } // $0.019/megapixel, flash variants are $0.005

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    /// Required by protocol - placeholder
    public struct ServiceRequest: Codable, Sendable {
        let placeholder: Bool
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        ServiceRequest(placeholder: true)
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let megapixels = falParseMegapixels(from: request.dimensions)
        return costPerMegapixel * megapixels * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            // Luma models return: { images: [ { url } ] }
            if let images = data["images"] as? [[String: Any]],
               let urlStr = images.first?["url"] as? String
            {
                return try downloadAndReturnImage(urlStr: urlStr, request: request)
            }

            if let error = data["detail"] as? String {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: error,
                    rawResponse: extractRawResponse(from: response)
                )
            }
            if let errorObj = data["error"] as? [String: Any],
               let message = errorObj["message"] as? String
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: message,
                    rawResponse: extractRawResponse(from: response)
                )
            }
        default:
            break
        }

        return createInvalidResponseError(response: response, modelCode: modelCode)
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        fatalError("Subclass must override makeRequest")
    }

    // MARK: - Helpers

    func performLumaRequest(
        request: ImageGenerationRequest,
        body: some Codable & Sendable
    ) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        do {
            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: body,
                headers: [
                    "Authorization": "Key \(request.providerSecret)",
                    "Content-Type": "application/json",
                ],
                attachments: nil
            )
            return try transformResponse(request: request, response: response)
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }

    func toDataUri(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:image/png;base64,\(base64)"
    }

    /// Normalizes dimensions to aspect ratio format required by Luma models.
    /// Luma supports: "1:1", "16:9", "9:16", "4:3", "3:4", "21:9", "9:21"
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

        // Luma models expect specific aspect ratios
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

    func clampDouble(_ value: Double?, min: Double, max: Double, defaultValue: Double) -> Double {
        guard let value else { return defaultValue }
        return Swift.max(min, Swift.min(max, value))
    }

    private func downloadAndReturnImage(
        urlStr: String,
        request: ImageGenerationRequest
    ) throws -> ImageGenerationResponse {
        // Handle base64 data URIs
        if urlStr.contains("base64") {
            let base64 = urlStr.replacingOccurrences(
                of: "^data:.*;base64,",
                with: "",
                options: .regularExpression
            )
            return ImageGenerationResponse(
                status: .GENERATED,
                base64: base64,
                cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
            )
        }

        let url = URL(string: urlStr)!
        let imageData = try Data(contentsOf: url)
        return ImageGenerationResponse(
            status: .GENERATED,
            base64: imageData.base64EncodedString(),
            cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }
}

// MARK: - Text-to-Image Models

/// Request body for text-to-image models (luma-photon, luma-photon/flash)
private struct LumaPhotonTextRequest: Codable {
    let prompt: String
    let aspect_ratio: String?
}

/// Luma Photon - Full quality text-to-image
public final class G_FAL_LUMA_PHOTON: FalLumaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_LUMA_PHOTON
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Prompt is required"
            )
        }

        let body = LumaPhotonTextRequest(
            prompt: request.prompt,
            aspect_ratio: normalizeAspectRatio(from: request.dimensions)
        )
        return try await performLumaRequest(request: request, body: body)
    }
}

/// Luma Photon Flash - Fast text-to-image
public final class G_FAL_LUMA_PHOTON_FLASH: FalLumaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_LUMA_PHOTON_FLASH
    }

    override var costPerMegapixel: Double {
        0.005
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Prompt is required"
            )
        }

        let body = LumaPhotonTextRequest(
            prompt: request.prompt,
            aspect_ratio: normalizeAspectRatio(from: request.dimensions)
        )
        return try await performLumaRequest(request: request, body: body)
    }
}

// MARK: - Image-to-Image (Modify) Models

/// Request body for modify models (luma-photon/modify, luma-photon/flash/modify)
private struct LumaPhotonModifyRequest: Codable {
    let image_url: String
    let strength: Double
    let aspect_ratio: String
    let prompt: String?
}

/// Luma Photon Modify - Full quality image editing
public final class G_FAL_LUMA_PHOTON_MODIFY: FalLumaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_LUMA_PHOTON_MODIFY
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        // Map guidance (typically 1-10) to strength (0-1), defaulting to 0.8
        let strength = clampDouble(request.guidance.map { $0 / 10.0 }, min: 0, max: 1, defaultValue: 0.8)

        let body = LumaPhotonModifyRequest(
            image_url: toDataUri(clientImage),
            strength: strength,
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            prompt: request.prompt.isEmpty ? nil : request.prompt
        )
        return try await performLumaRequest(request: request, body: body)
    }
}

/// Luma Photon Flash Modify - Fast image editing
public final class G_FAL_LUMA_PHOTON_FLASH_MODIFY: FalLumaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_LUMA_PHOTON_FLASH_MODIFY
    }

    override var costPerMegapixel: Double {
        0.005
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        // Map guidance (typically 1-10) to strength (0-1), defaulting to 0.8
        let strength = clampDouble(request.guidance.map { $0 / 10.0 }, min: 0, max: 1, defaultValue: 0.8)

        let body = LumaPhotonModifyRequest(
            image_url: toDataUri(clientImage),
            strength: strength,
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            prompt: request.prompt.isEmpty ? nil : request.prompt
        )
        return try await performLumaRequest(request: request, body: body)
    }
}

// MARK: - Reframe (Outpainting) Models

/// Request body for reframe models (luma-photon/reframe, luma-photon/flash/reframe)
private struct LumaPhotonReframeRequest: Codable {
    let image_url: String
    let aspect_ratio: String
    let prompt: String?
}

/// Luma Photon Reframe - Full quality outpainting
public final class G_FAL_LUMA_PHOTON_REFRAME: FalLumaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_LUMA_PHOTON_REFRAME
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = LumaPhotonReframeRequest(
            image_url: toDataUri(clientImage),
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            prompt: request.prompt.isEmpty ? nil : request.prompt
        )
        return try await performLumaRequest(request: request, body: body)
    }
}

/// Luma Photon Flash Reframe - Fast outpainting
public final class G_FAL_LUMA_PHOTON_FLASH_REFRAME: FalLumaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_LUMA_PHOTON_FLASH_REFRAME
    }

    override var costPerMegapixel: Double {
        0.005
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = LumaPhotonReframeRequest(
            image_url: toDataUri(clientImage),
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            prompt: request.prompt.isEmpty ? nil : request.prompt
        )
        return try await performLumaRequest(request: request, body: body)
    }
}
