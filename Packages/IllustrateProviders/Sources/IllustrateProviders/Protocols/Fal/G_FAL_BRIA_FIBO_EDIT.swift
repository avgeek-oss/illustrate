// MARK: - G_FAL_BRIA_FIBO_EDIT.swift

// Consolidated implementation for Bria Fibo Edit models via Fal AI.
// All models cost $0.04 per image.

import Foundation

// MARK: - Base Class

/// Base class for all Bria Fibo Edit models with shared functionality.
public class FiboEditBase: ImageGenerationProtocol {
    static let costPerImage = 0.04

    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    /// Required by protocol - using a simple placeholder struct
    public struct ServiceRequest: Codable, Sendable {
        let placeholder: Bool
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        ServiceRequest(placeholder: true)
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.costPerImage * Double(request.numberOfImages ?? 1)
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
            if let imageObj = data["image"] as? [String: Any],
               let imageUrl = imageObj["url"] as? String
            {
                let url = URL(string: imageUrl)!
                let imageData = try Data(contentsOf: url)
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageData.base64EncodedString(),
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
            }
            if let error = data["detail"] as? String {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: error
                )
            }
            if let errorObj = data["error"] as? [String: Any],
               let message = errorObj["message"] as? String
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: message
                )
            }
        default:
            break
        }
        return createInvalidResponseError(response: response, modelCode: modelCode)
    }

    /// Whether this model requires a client image (most do)
    var requiresClientImage: Bool {
        true
    }

    /// Helper to perform request with a Codable body
    func performFiboRequest(
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

    /// Default implementation - subclasses must override
    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        fatalError("Subclass must override makeRequest")
    }

    /// Converts base64 to data URI for Fal.ai
    func toDataUri(_ base64: String) -> String {
        base64.hasPrefix("data:") ? base64 : "data:image/png;base64,\(base64)"
    }
}

// MARK: - Request Body Types

private struct ImageOnlyRequest: Codable {
    let image_url: String
}

private struct ImageInstructionRequest: Codable {
    let image_url: String
    let instruction: String
}

private struct ImageStyleRequest: Codable {
    let image_url: String
    let style: String
}

private struct ImageSeasonRequest: Codable {
    let image_url: String
    let season: String
}

private struct ImageColorRequest: Codable {
    let image_url: String
    let color: String
}

private struct ImageTextRequest: Codable {
    let image_url: String
    let new_text: String
}

private struct ImageObjectRequest: Codable {
    let image_url: String
    let object_name: String
}

private struct ImageRelightRequest: Codable {
    let image_url: String
    let light_direction: String
    let light_type: String
}

private struct EditRequest: Codable {
    let image_url: String?
    let mask_url: String?
    let instruction: String?
    let seed: Int?
    let steps_num: Int?
    let negative_prompt: String?
    let guidance_scale: Double?
}

// MARK: - Model Implementations

/// Replace Object by Text - Natural object swapping with plain language
public final class G_FAL_BRIA_FIBO_EDIT_REPLACE_OBJECT: FiboEditBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_FIBO_EDIT_REPLACE_OBJECT
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = ImageInstructionRequest(
            image_url: toDataUri(clientImage),
            instruction: request.prompt
        )
        return try await performFiboRequest(request: request, body: body)
    }
}

/// Sketch to Image - Converts sketches to photorealistic images
public final class G_FAL_BRIA_FIBO_EDIT_SKETCH_TO_IMAGE: FiboEditBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_FIBO_EDIT_SKETCH_TO_IMAGE
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = ImageOnlyRequest(image_url: toDataUri(clientImage))
        return try await performFiboRequest(request: request, body: body)
    }
}

/// Restore - Cleans noisy or degraded images
public final class G_FAL_BRIA_FIBO_EDIT_RESTORE: FiboEditBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_FIBO_EDIT_RESTORE
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = ImageOnlyRequest(image_url: toDataUri(clientImage))
        return try await performFiboRequest(request: request, body: body)
    }
}

/// Reseason - Transforms seasonal atmosphere
public final class G_FAL_BRIA_FIBO_EDIT_RESEASON: FiboEditBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_FIBO_EDIT_RESEASON
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = ImageSeasonRequest(
            image_url: toDataUri(clientImage),
            season: request.style.isEmpty ? "winter" : request.style
        )
        return try await performFiboRequest(request: request, body: body)
    }
}

/// Relight - Controllable lighting changes
public final class G_FAL_BRIA_FIBO_EDIT_RELIGHT: FiboEditBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_FIBO_EDIT_RELIGHT
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = ImageRelightRequest(
            image_url: toDataUri(clientImage),
            light_direction: request.variant.isEmpty ? "front" : request.variant,
            light_type: request.style.isEmpty ? "soft overcast daylight lighting" : request.style
        )
        return try await performFiboRequest(request: request, body: body)
    }
}

/// Restyle - Artistic style transformation
public final class G_FAL_BRIA_FIBO_EDIT_RESTYLE: FiboEditBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_FIBO_EDIT_RESTYLE
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = ImageStyleRequest(
            image_url: toDataUri(clientImage),
            style: request.style.isEmpty ? "3D Render" : request.style
        )
        return try await performFiboRequest(request: request, body: body)
    }
}

/// Rewrite Text - Modifies text inside images
public final class G_FAL_BRIA_FIBO_EDIT_REWRITE_TEXT: FiboEditBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_FIBO_EDIT_REWRITE_TEXT
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = ImageTextRequest(
            image_url: toDataUri(clientImage),
            new_text: request.prompt
        )
        return try await performFiboRequest(request: request, body: body)
    }
}

/// Erase by Text - Removes unwanted elements
public final class G_FAL_BRIA_FIBO_EDIT_ERASE_BY_TEXT: FiboEditBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_FIBO_EDIT_ERASE_BY_TEXT
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = ImageObjectRequest(
            image_url: toDataUri(clientImage),
            object_name: request.prompt
        )
        return try await performFiboRequest(request: request, body: body)
    }
}

/// Edit - Flexible editing with mask support
public final class G_FAL_BRIA_FIBO_EDIT_EDIT: FiboEditBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_FIBO_EDIT_EDIT
    }

    override var requiresClientImage: Bool {
        false
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let body = EditRequest(
            image_url: request.clientImage.map { toDataUri($0) },
            mask_url: request.clientMask.map { toDataUri($0) },
            instruction: request.prompt.isEmpty ? nil : request.prompt,
            seed: request.seed,
            steps_num: request.steps.flatMap { $0 > 0 ? $0 : nil },
            negative_prompt: request.negativePrompt?.isEmpty == false ? request.negativePrompt : nil,
            guidance_scale: request.guidance.flatMap { $0 > 0 ? $0 : nil }
        )
        return try await performFiboRequest(request: request, body: body)
    }
}

/// Add Object - Context-aware object insertion
public final class G_FAL_BRIA_FIBO_EDIT_ADD_OBJECT: FiboEditBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_FIBO_EDIT_ADD_OBJECT
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = ImageInstructionRequest(
            image_url: toDataUri(clientImage),
            instruction: request.prompt
        )
        return try await performFiboRequest(request: request, body: body)
    }
}

/// Blend - Multi-step visual composition
public final class G_FAL_BRIA_FIBO_EDIT_BLEND: FiboEditBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_FIBO_EDIT_BLEND
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = ImageInstructionRequest(
            image_url: toDataUri(clientImage),
            instruction: request.prompt
        )
        return try await performFiboRequest(request: request, body: body)
    }
}

/// Colorize - Color treatment transformation
public final class G_FAL_BRIA_FIBO_EDIT_COLORIZE: FiboEditBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .FAL_BRIA_FIBO_EDIT_COLORIZE
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        let body = ImageColorRequest(
            image_url: toDataUri(clientImage),
            color: request.style.isEmpty ? "contemporary color" : request.style
        )
        return try await performFiboRequest(request: request, body: body)
    }
}
