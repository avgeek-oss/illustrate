// MARK: - G_FAL_XAI.swift

// xAI Grok Imagine image generation models via Fal AI:
// - xai/grok-imagine-image (standard text-to-image)
// - xai/grok-imagine-image/edit (standard edit)
// - xai/grok-imagine-image/quality/text-to-image (quality text-to-image)
// - xai/grok-imagine-image/quality/edit (quality edit)
//
// Pricing: Standard ~$0.03/image, Quality ~$0.05/image

import Foundation

// MARK: - Request Structs

private struct GrokImagineTextRequest: Codable {
    let prompt: String
    let num_images: Int?
    let aspect_ratio: String?
    let resolution: String?
    let output_format: String?
}

private struct GrokImagineEditRequest: Codable {
    let prompt: String
    let image_urls: [String]
    let num_images: Int?
    let aspect_ratio: String?
    let resolution: String?
    let output_format: String?
}

// MARK: - Base Class

public class FalXaiBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var baseCost: Double {
        0.03
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public struct ServiceRequest: Codable, Sendable { let placeholder: Bool }

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

    func performXaiRequest(
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

    func normalizeGrokAspectRatio(from dimensions: String) -> String {
        let normalized = dimensions.replacingOccurrences(of: "x", with: ":").lowercased()
        switch normalized {
        case "1:1", "1024:1024", "512:512":
            return "1:1"
        case "16:9", "1920:1080", "1536:864":
            return "16:9"
        case "9:16", "1080:1920", "864:1536":
            return "9:16"
        case "4:3", "1024:768":
            return "4:3"
        case "3:4", "768:1024":
            return "3:4"
        case "3:2", "1536:1024":
            return "3:2"
        case "2:3", "1024:1536":
            return "2:3"
        case "2:1":
            return "2:1"
        case "20:9":
            return "20:9"
        default:
            return "1:1"
        }
    }

    private func downloadAndReturnImage(
        urlStr: String,
        request: ImageGenerationRequest
    ) throws -> ImageGenerationResponse {
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

// MARK: - Grok Imagine Standard (Text-to-Image)

public final class G_FAL_XAI_GROK_IMAGINE_IMAGE: FalXaiBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_XAI_GROK_IMAGINE_IMAGE
    }

    override var baseCost: Double {
        0.03
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = GrokImagineTextRequest(
            prompt: request.prompt,
            num_images: request.numberOfImages ?? 1,
            aspect_ratio: normalizeGrokAspectRatio(from: request.dimensions),
            resolution: "1k",
            output_format: "png"
        )
        return try await performXaiRequest(request: request, body: body)
    }
}

// MARK: - Grok Imagine Standard Edit

public final class G_FAL_XAI_GROK_IMAGINE_IMAGE_EDIT: FalXaiBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_XAI_GROK_IMAGINE_IMAGE_EDIT
    }

    override var baseCost: Double {
        0.04
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = GrokImagineEditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: request.numberOfImages ?? 1,
            aspect_ratio: normalizeGrokAspectRatio(from: request.dimensions),
            resolution: "1k",
            output_format: "png"
        )
        return try await performXaiRequest(request: request, body: body)
    }
}

// MARK: - Grok Imagine Quality (Text-to-Image)

public final class G_FAL_XAI_GROK_IMAGINE_IMAGE_QUALITY: FalXaiBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_XAI_GROK_IMAGINE_IMAGE_QUALITY
    }

    override var baseCost: Double {
        0.05
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }

        let body = GrokImagineTextRequest(
            prompt: request.prompt,
            num_images: request.numberOfImages ?? 1,
            aspect_ratio: normalizeGrokAspectRatio(from: request.dimensions),
            resolution: "2k",
            output_format: "png"
        )
        return try await performXaiRequest(request: request, body: body)
    }
}

// MARK: - Grok Imagine Quality Edit

public final class G_FAL_XAI_GROK_IMAGINE_IMAGE_QUALITY_EDIT: FalXaiBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_XAI_GROK_IMAGINE_IMAGE_QUALITY_EDIT
    }

    override var baseCost: Double {
        0.06
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Prompt is required")
        }
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }

        let body = GrokImagineEditRequest(
            prompt: request.prompt,
            image_urls: [toDataUri(clientImage)],
            num_images: request.numberOfImages ?? 1,
            aspect_ratio: normalizeGrokAspectRatio(from: request.dimensions),
            resolution: "2k",
            output_format: "png"
        )
        return try await performXaiRequest(request: request, body: body)
    }
}
