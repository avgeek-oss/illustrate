// MARK: - G_FAL_BRIA.swift

// Bria models via Fal AI:
// - bria/fibo/generate
// - bria/reimagine/3.2
// - fal-ai/bria/reimagine
// - fal-ai/bria/background/remove

import Foundation

// MARK: - Base Class

public class FalBriaBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var baseCost: Double {
        0.04
    } // $0.04 per image (Bria models), $0.018 for background remove

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
        baseCost * Double(request.numberOfImages ?? 1)
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
            // Common patterns: { image: { url } } or { images: [ { url } ] }
            if let imageObj = data["image"] as? [String: Any],
               let urlStr = imageObj["url"] as? String
            {
                return try downloadAndReturnImage(urlStr: urlStr, request: request)
            }

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

    func performBriaRequest(
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

        // Bria models expect aspect ratios like "1:1", "16:9", etc.
        let candidates: [(label: String, ratio: Double)] = [
            ("1:1", 1.0),
            ("2:3", 2.0 / 3.0),
            ("3:2", 3.0 / 2.0),
            ("3:4", 3.0 / 4.0),
            ("4:3", 4.0 / 3.0),
            ("4:5", 4.0 / 5.0),
            ("5:4", 5.0 / 4.0),
            ("9:16", 9.0 / 16.0),
            ("16:9", 16.0 / 9.0),
        ]

        let r = w / h
        let best = candidates.min(by: { abs($0.ratio - r) < abs($1.ratio - r) })
        return best?.label ?? "1:1"
    }

    func clampInt(_ value: Int?, min: Int, max: Int, defaultValue: Int) -> Int {
        guard let value else { return defaultValue }
        return Swift.max(min, Swift.min(max, value))
    }

    func clampInt(_ value: Int, min: Int, max: Int, defaultValue: Int) -> Int {
        Swift.max(min, Swift.min(max, value))
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

// MARK: - Model Implementations

private struct BriaFiboGenerateRequest: Codable {
    let prompt: String?
    let image_url: String?
    let seed: Int?
    let steps_num: Int?
    let aspect_ratio: String?
    let negative_prompt: String?
    let guidance_scale: Int?
    let sync_mode: Bool
}

public final class G_FAL_BRIA_FIBO_GENERATE: FalBriaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_FIBO_GENERATE
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let steps = clampInt(request.steps, min: 20, max: 50, defaultValue: 50)
        let guidance = clampInt(request.guidance.map { Int($0.rounded()) }, min: 3, max: 5, defaultValue: 5)
        let body = BriaFiboGenerateRequest(
            prompt: request.prompt.isEmpty ? nil : request.prompt,
            image_url: request.clientImage.map { toDataUri($0) },
            seed: request.seed,
            steps_num: steps,
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            negative_prompt: request.negativePrompt,
            guidance_scale: guidance,
            sync_mode: true
        )
        return try await performBriaRequest(request: request, body: body)
    }
}

private struct BriaReimagine32Request: Codable {
    let prompt: String
    let num_inference_steps: Int?
    let seed: Int?
    let aspect_ratio: String?
    let negative_prompt: String?
    let guidance_scale: Double?
    let truncate_prompt: Bool?
    let prompt_enhancer: Bool?
    let canny_image_url: String?
    let canny_preprocess: Bool?
    let canny_scale: Double?
    let sync_mode: Bool
}

public final class G_FAL_BRIA_REIMAGINE_3_2: FalBriaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_REIMAGINE_3_2
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Prompt is required"
            )
        }

        let steps = clampInt(request.steps, min: 20, max: 50, defaultValue: 30)
        let guidance = clampDouble(request.guidance, min: 1, max: 10, defaultValue: 5)

        let body = BriaReimagine32Request(
            prompt: request.prompt,
            num_inference_steps: steps,
            seed: request.seed,
            aspect_ratio: normalizeAspectRatio(from: request.dimensions),
            negative_prompt: request.negativePrompt,
            guidance_scale: guidance,
            truncate_prompt: true,
            prompt_enhancer: request.promptEnhance ?? true,
            canny_image_url: request.clientImage.map { toDataUri($0) },
            canny_preprocess: request.clientImage != nil ? true : nil,
            canny_scale: request.clientImage != nil ? 0.5 : nil,
            sync_mode: true
        )
        return try await performBriaRequest(request: request, body: body)
    }
}

private struct BriaReimagineRequest: Codable {
    let prompt: String
    let structure_image_url: String?
    let structure_ref_influence: Double?
    let num_results: Int?
    let seed: Int?
    let fast: Bool?
    let num_inference_steps: Int?
    let sync_mode: Bool
}

public final class G_FAL_BRIA_REIMAGINE: FalBriaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_REIMAGINE
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Prompt is required"
            )
        }

        let steps = clampInt(request.steps, min: 20, max: 50, defaultValue: 30)
        let numResults = clampInt(request.numberOfImages, min: 1, max: 4, defaultValue: 1)

        let body = BriaReimagineRequest(
            prompt: request.prompt,
            structure_image_url: request.clientImage.map { toDataUri($0) },
            structure_ref_influence: 0.75,
            num_results: numResults,
            seed: request.seed,
            fast: true,
            num_inference_steps: steps,
            sync_mode: true
        )
        return try await performBriaRequest(request: request, body: body)
    }
}

private struct BriaBackgroundRemoveRequest: Codable {
    let image_url: String
    let sync_mode: Bool
}

public final class G_FAL_BRIA_BACKGROUND_REMOVE: FalBriaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_BACKGROUND_REMOVE
    }

    override var baseCost: Double {
        0.018
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = BriaBackgroundRemoveRequest(
            image_url: toDataUri(clientImage),
            sync_mode: true
        )
        return try await performBriaRequest(request: request, body: body)
    }
}
