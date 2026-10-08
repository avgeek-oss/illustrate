// MARK: - G_OPENAI_GPT_IMAGE_BASE.swift

// Base implementation for OpenAI GPT Image models (1, 1.5, 2, Mini).
//
// This class implements ImageGenerationProtocol for the GPT Image family.
// It handles request transformation, API communication, and response parsing.
//
// ## Supported Models
// - GPT Image 1: Standard quality
// - GPT Image 1.5: Improved quality with more dimensions
// - GPT Image 2: State-of-the-art image generation
// - GPT Image 1 Mini: Compact, efficient model
//
// ## Features
// - Reference image support (up to 8 images)
// - Transparent background option
// - Source image editing (inpainting with mask)
// - Quality tiers (low, medium, high)
// - Moderation control (auto, low)
//
// ## Request Flow
// 1. transformRequest(): Convert to OpenAI API format
// 2. makeRequest(): Send to API and await response
// 3. transformResponse(): Parse base64 image from response

import Foundation

/// Base implementation for OpenAI GPT Image models.
public class G_OPENAI_GPT_IMAGE_BASE: ImageGenerationProtocol {
    let modelCode: EnumProviderModelCode
    let modelName: String

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(modelCode: EnumProviderModelCode, modelName: String) {
        self.modelCode = modelCode
        self.modelName = modelName
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let quality = request.quality ?? ""
        let dimensions = request.dimensions ?? "1024x1024"
        let numberOfImages = request.numberOfImages ?? 1

        if modelCode == .OPENAI_GPT_IMAGE_2 {
            return getGPTImage2CostEstimate(quality: quality, dimensions: dimensions) * Double(numberOfImages)
        }

        let baseCost = switch (modelCode, quality.lowercased(), dimensions) {
        // GPT Image 1 pricing
        case (.OPENAI_GPT_IMAGE_1, "high", _):
            0.17
        case (.OPENAI_GPT_IMAGE_1, "medium", _):
            0.07
        case (.OPENAI_GPT_IMAGE_1, "low", _):
            0.04
        // GPT Image 1 Mini pricing
        case (.OPENAI_GPT_IMAGE_1_MINI, "low", "1024x1024"):
            0.005
        case (.OPENAI_GPT_IMAGE_1_MINI, "medium", "1024x1024"):
            0.011
        case (.OPENAI_GPT_IMAGE_1_MINI, "high", "1024x1024"):
            0.036
        case (.OPENAI_GPT_IMAGE_1_MINI, "low", "1024x1536"), (.OPENAI_GPT_IMAGE_1_MINI, "low", "1536x1024"):
            0.006
        case (.OPENAI_GPT_IMAGE_1_MINI, "medium", "1024x1536"), (.OPENAI_GPT_IMAGE_1_MINI, "medium", "1536x1024"):
            0.015
        case (.OPENAI_GPT_IMAGE_1_MINI, "high", "1024x1536"), (.OPENAI_GPT_IMAGE_1_MINI, "high", "1536x1024"):
            0.052
        // GPT Image 1.5 pricing
        case (.OPENAI_GPT_IMAGE_1_5, "low", "1024x1024"):
            0.009
        case (.OPENAI_GPT_IMAGE_1_5, "medium", "1024x1024"):
            0.034
        case (.OPENAI_GPT_IMAGE_1_5, "high", "1024x1024"):
            0.133
        case (.OPENAI_GPT_IMAGE_1_5, "low", "1024x1536"), (.OPENAI_GPT_IMAGE_1_5, "low", "1536x1024"):
            0.013
        case (.OPENAI_GPT_IMAGE_1_5, "medium", "1024x1536"), (.OPENAI_GPT_IMAGE_1_5, "medium", "1536x1024"):
            0.05
        case (.OPENAI_GPT_IMAGE_1_5, "high", "1024x1536"), (.OPENAI_GPT_IMAGE_1_5, "high", "1536x1024"):
            0.2
        // Default pricing
        default:
            0.04
        }

        return baseCost * Double(numberOfImages)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        if modelCode == .OPENAI_GPT_IMAGE_2 { return formatEstimatedCost(cost) + "+" }
        return formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let model: String
        let prompt: String
        let n: Int?
        let size: String
        let quality: String
        let moderation: String?
        let input_fidelity: String?
        let background: String?
        let user: String

        init(
            model: String,
            prompt: String,
            n: Int? = nil,
            size: String,
            quality: String,
            moderation: String? = nil,
            inputFidelity: String? = nil,
            background: String? = nil
        ) {
            self.model = model
            self.prompt = prompt
            self.n = n
            self.size = size
            self.quality = quality
            self.moderation = moderation
            input_fidelity = inputFidelity
            self.background = background
            user = "illustrate_user"
        }
    }

    func getImageDimensions(dimensions: String) -> String {
        if modelCode == .OPENAI_GPT_IMAGE_2 {
            return isValidGPTImage2Dimension(dimensions) ? dimensions : "1024x1024"
        }

        return switch dimensions {
        case "1536x1024":
            "1536x1024"
        case "1024x1536":
            "1024x1536"
        case "1024x1024":
            "1024x1024"
        default:
            "1024x1024"
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let size = getImageDimensions(dimensions: request.dimensions)

        let quality = getImageQuality(quality: request.quality)

        let moderation = nonEmpty(request.moderation)
        let inputFidelity = modelCode == .OPENAI_GPT_IMAGE_2 ? nil : nonEmpty(request.inputFidelity)
        let background = getBackground(background: request.background)
        let n: Int? = 1

        return ServiceRequest(
            model: modelName,
            prompt: request.prompt,
            n: n,
            size: size,
            quality: quality,
            moderation: moderation,
            inputFidelity: inputFidelity,
            background: background
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        let rawResponse = extractRawResponse(from: response)

        switch response {
        case let .dictionary(_, data):
            if let nestedData = data["data"] as? [[String: Any]],
               let imageData = nestedData.first?["b64_json"] as? String
            {
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData,
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
                    modelPrompt: request.prompt,
                    metadata: getResponseMetadata(data: data, imageData: nestedData.first),
                    actualDimensions: getActualDimensions(data: data, imageData: nestedData.first, request: request)
                )
            } else if let errors = data["errors"] as? [String],
                      let message = errors.first
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message,

                    rawResponse: rawResponse
                )
            } else if let message = data["message"] as? String {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message,

                    rawResponse: rawResponse
                )
            } else if let error = data["error"] as? [String: Any],
                      let message = error["message"] as? String
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message,

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

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let transformedRequest = transformRequest(request: request)

        // Check if we have images to send (reference images or source image)
        let hasReferenceImages = request.clientReferenceImages != nil && !request.clientReferenceImages!.isEmpty
        let hasSourceImage = request.clientImage != nil
        let hasImages = hasReferenceImages || hasSourceImage

        if hasImages {
            let editsURL = "https://api.openai.com/v1/images/edits"
            guard let url = URL(string: editsURL) else {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Invalid URL"
                )
            }

            let headers: [String: String] = [
                "Authorization": "Bearer \(request.providerSecret)",
                "Content-Type": "multipart/form-data",
                "Accept": "application/json",
            ]

            var attachments: [NetworkRequestAttachment] = []

            // Add source image first if present
            if let clientImage = request.clientImage {
                let cleanBase64 = clientImage.replacingOccurrences(
                    of: "^data:.*;base64,",
                    with: "",
                    options: .regularExpression
                )
                if let imageData = Data(base64Encoded: cleanBase64) {
                    attachments.append(
                        NetworkRequestAttachment(
                            name: "image[]",
                            mimeType: "image/png",
                            data: imageData
                        )
                    )
                }
            }

            // Add reference images if present (limit to 16 total images including source)
            if hasReferenceImages {
                let maxReferenceImages = hasSourceImage ? 15 : 16
                for referenceImage in request.clientReferenceImages!.prefix(maxReferenceImages) {
                    let cleanBase64 = referenceImage.base64Image.replacingOccurrences(
                        of: "^data:.*;base64,",
                        with: "",
                        options: .regularExpression
                    )
                    if let imageData = Data(base64Encoded: cleanBase64) {
                        attachments.append(
                            NetworkRequestAttachment(
                                name: "image[]",
                                mimeType: "image/png",
                                data: imageData
                            )
                        )
                    }
                }
            }

            // Add mask if provided (for inpainting)
            if let clientMask = request.clientMask {
                let cleanBase64 = clientMask.replacingOccurrences(
                    of: "^data:.*;base64,",
                    with: "",
                    options: .regularExpression
                )
                if let maskData = Data(base64Encoded: cleanBase64) {
                    attachments.append(
                        NetworkRequestAttachment(
                            name: "mask",
                            mimeType: "image/png",
                            data: maskData
                        )
                    )
                }
            }

            do {
                let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                    url: url,
                    method: "POST",
                    body: transformedRequest,
                    headers: headers,
                    attachments: attachments
                )

                do {
                    let result = try transformResponse(request: request, response: response)
                    if result.status == .GENERATED {}
                    return result
                } catch {
                    let rawResponse = extractRawResponse(from: response)
                    return ImageGenerationResponse(
                        status: EnumGenerationStatus.FAILED,
                        errorCode: EnumGenerationAdapterErrorCode.TRANSFORM_RESPONSE_ERROR,
                        errorMessage: "Failed with error: \(error.localizedDescription)",
                        rawResponse: rawResponse
                    )
                }
            } catch {
                return ImageGenerationResponse(
                    status: EnumGenerationStatus.FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Failed with error: \(error.localizedDescription)",
                    rawResponse: "Error: \(error.localizedDescription)"
                )
            }
        } else {
            guard let url = URL(string: model.modelGenerateBaseURL) else {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Invalid URL"
                )
            }

            do {
                let generation = try await ProviderDependencies.shared.networkProvider.performRequest(
                    url: url,
                    method: "POST",
                    body: transformedRequest,
                    headers: [
                        "Authorization": "Bearer \(request.providerSecret)",
                        "Content-Type": "application/json",
                        "Accept": "application/json",
                    ],
                    attachments: nil
                )

                do {
                    let result = try transformResponse(request: request, response: generation)
                    if result.status == .GENERATED {}
                    return result
                } catch {
                    let rawResponse = extractRawResponse(from: generation)
                    return ImageGenerationResponse(
                        status: EnumGenerationStatus.FAILED,
                        errorCode: EnumGenerationAdapterErrorCode.TRANSFORM_RESPONSE_ERROR,
                        errorMessage: "Failed with error: \(error.localizedDescription)",
                        rawResponse: rawResponse
                    )
                }
            } catch {
                return ImageGenerationResponse(
                    status: EnumGenerationStatus.FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Failed with error: \(error.localizedDescription)",
                    rawResponse: "Error: \(error.localizedDescription)"
                )
            }
        }
    }

    private func getImageQuality(quality: String) -> String {
        if !quality.isEmpty { return quality }
        return modelCode == .OPENAI_GPT_IMAGE_2 ? "auto" : "medium"
    }

    private func getBackground(background: String?) -> String? {
        guard let background = nonEmpty(background) else { return nil }
        if modelCode == .OPENAI_GPT_IMAGE_2, background == "transparent" { return nil }
        return background
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }

    private func isValidGPTImage2Dimension(_ dimensions: String) -> Bool {
        if dimensions == "auto" { return true }

        guard let parsed = parseDimensions(dimensions) else { return false }
        let width = parsed.width
        let height = parsed.height
        let maxPixels = 3840 * 2160
        let ratio = Double(width) / Double(height)

        return width > 0
            && height > 0
            && width % 16 == 0
            && height % 16 == 0
            && ratio >= 1.0 / 3.0
            && ratio <= 3.0
            && max(width, height) <= 3840
            && width * height <= maxPixels
    }

    private func parseDimensions(_ dimensions: String) -> (width: Int, height: Int)? {
        let parts = dimensions.lowercased().split(separator: "x")
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1])
        else {
            return nil
        }
        return (width, height)
    }

    private func getGPTImage2CostEstimate(quality: String, dimensions: String) -> Double {
        let normalizedQuality = switch quality.lowercased() {
        case "", "auto":
            "medium"
        case "low", "medium", "high":
            quality.lowercased()
        default:
            "medium"
        }

        if let standardCost = getGPTImage2StandardCost(quality: normalizedQuality, dimensions: dimensions) {
            return standardCost
        }

        guard let parsed = parseDimensions(dimensions) else {
            return getGPTImage2StandardCost(quality: normalizedQuality, dimensions: "1024x1024") ?? 0.053
        }

        let isSquare = parsed.width == parsed.height
        let referenceDimensions = isSquare ? "1024x1024" : "1536x1024"
        let referencePixels = isSquare ? 1024.0 * 1024.0 : 1536.0 * 1024.0
        let referenceCost = getGPTImage2StandardCost(quality: normalizedQuality, dimensions: referenceDimensions) ??
            0.053
        let pixelScale = Double(parsed.width * parsed.height) / referencePixels

        return max(referenceCost, referenceCost * pixelScale)
    }

    private func getGPTImage2StandardCost(quality: String, dimensions: String) -> Double? {
        switch (quality, dimensions) {
        case ("low", "1024x1024"):
            0.006
        case ("medium", "1024x1024"):
            0.053
        case ("high", "1024x1024"):
            0.211
        case ("low", "1024x1536"), ("low", "1536x1024"):
            0.005
        case ("medium", "1024x1536"), ("medium", "1536x1024"):
            0.041
        case ("high", "1024x1536"), ("high", "1536x1024"):
            0.165
        default:
            nil
        }
    }

    private func getResponseMetadata(data: [String: Any], imageData: [String: Any]?) -> [String: String]? {
        var metadata: [String: String] = [:]

        for key in ["background", "output_format", "quality", "size"] {
            if let value = imageData?[key] ?? data[key] {
                appendMetadataValue(value, key: key, into: &metadata)
            }
        }

        if let usage = imageData?["usage"] ?? data["usage"] {
            appendMetadataValue(usage, key: "usage", into: &metadata)
        }

        return metadata.isEmpty ? nil : metadata
    }

    private func getActualDimensions(
        data: [String: Any],
        imageData: [String: Any]?,
        request: ImageGenerationRequest
    ) -> String {
        if let size = imageData?["size"] as? String ?? data["size"] as? String {
            return size
        }
        return request.dimensions
    }

    private func appendMetadataValue(_ value: Any, key: String, into metadata: inout [String: String]) {
        switch value {
        case let value as String:
            metadata[key] = value
        case let value as Int:
            metadata[key] = String(value)
        case let value as Double:
            metadata[key] = String(value)
        case let value as Bool:
            metadata[key] = String(value)
        case let value as [String: Any]:
            for nestedKey in value.keys.sorted() {
                if let nestedValue = value[nestedKey] {
                    appendMetadataValue(nestedValue, key: "\(key).\(nestedKey)", into: &metadata)
                }
            }
        case let value as [Any]:
            if JSONSerialization.isValidJSONObject(value),
               let data = try? JSONSerialization.data(withJSONObject: value),
               let string = String(data: data, encoding: .utf8)
            {
                metadata[key] = string
            }
        default:
            metadata[key] = String(describing: value)
        }
    }
}

public class G_OPENAI_GPT_IMAGE_1: G_OPENAI_GPT_IMAGE_BASE {
    public init() {
        super.init(modelCode: .OPENAI_GPT_IMAGE_1, modelName: "gpt-image-1")
    }
}

public class G_OPENAI_GPT_IMAGE_1_MINI: G_OPENAI_GPT_IMAGE_BASE {
    public init() {
        super.init(modelCode: .OPENAI_GPT_IMAGE_1_MINI, modelName: "gpt-image-1-mini")
    }
}

public class G_OPENAI_GPT_IMAGE_1_5: G_OPENAI_GPT_IMAGE_BASE {
    public init() {
        super.init(modelCode: .OPENAI_GPT_IMAGE_1_5, modelName: "gpt-image-1.5")
    }
}

public class G_OPENAI_GPT_IMAGE_2: G_OPENAI_GPT_IMAGE_BASE {
    public init() {
        super.init(modelCode: .OPENAI_GPT_IMAGE_2, modelName: "gpt-image-2")
    }
}
