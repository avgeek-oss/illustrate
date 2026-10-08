// MARK: - G_IDEOGRAM_V4.swift

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public class G_IDEOGRAM_V4: ImageGenerationProtocol {
    static let supportedResolutions: Set = [
        "2048x2048", "1440x2880", "2880x1440", "1664x2496", "2496x1664",
        "1792x2240", "2240x1792", "1440x2560", "2560x1440", "1600x2560", "2560x1600",
        "1728x2304", "2304x1728", "1296x3168", "3168x1296", "1152x2944", "2944x1152",
        "1248x3328", "3328x1248", "1280x3072", "3072x1280",
    ]

    public let modelCode: EnumProviderModelCode
    public let renderingSpeed: String
    public let unitPrice: Double

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(modelCode: EnumProviderModelCode, renderingSpeed: String, unitPrice: Double) {
        self.modelCode = modelCode
        self.renderingSpeed = renderingSpeed
        self.unitPrice = unitPrice
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        unitPrice * Double(max(1, request.numberOfImages ?? 1))
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public struct ServiceRequest: Codable, Sendable {
        public let text_prompt: String
        public let resolution: String
        public let rendering_speed: String
        public let enable_copyright_detection: Bool
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        ServiceRequest(
            text_prompt: request.prompt,
            resolution: Self.mapResolution(request.resolution ?? request.dimensions),
            rendering_speed: renderingSpeed,
            enable_copyright_detection: false
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        guard case let .dictionary(_, data) = response else {
            return createInvalidResponseError(response: response, modelCode: modelCode)
        }

        if let message = Self.errorMessage(from: data) {
            return failure(message: message, response: response)
        }

        guard let image = (data["data"] as? [[String: Any]])?.first,
              let url = image["url"] as? String,
              !url.isEmpty
        else {
            return createInvalidResponseError(response: response, modelCode: modelCode)
        }

        var metadata: [String: String] = [:]
        if let seed = image["seed"] as? Int { metadata["ideogramSeed"] = String(seed) }
        if let resolution = image["resolution"] as? String { metadata["ideogramResolution"] = resolution }
        if let safe = image["is_image_safe"] as? Bool { metadata["ideogramImageSafe"] = String(safe) }

        return ImageGenerationResponse(
            status: .GENERATED,
            cost: unitPrice,
            modelPrompt: (image["prompt"] as? String) ?? request.prompt,
            rawResponse: url,
            metadata: metadata.isEmpty ? nil : metadata
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = model.generateURL else {
            return failure(message: "Invalid Ideogram generation URL")
        }

        do {
            let credentials = try ProviderCredentialConfiguration(secret: request.providerSecret)
            let apiKey = try credentials.requireAPIKey()
            let network = ProviderDependencies.shared.networkProvider
            let envelope = try await network.performSingleAttemptRequest(
                url: url,
                method: "POST",
                body: transformRequest(request: request),
                headers: [
                    "Api-Key": apiKey,
                    "Content-Type": "multipart/form-data",
                    "Accept": "application/json",
                ],
                attachments: nil
            )
            let response = try envelope.requireParsedResponse()
            let transformed = try transformResponse(request: request, response: response)
            guard (200 ... 299).contains(envelope.statusCode) else {
                return transformed.status == .FAILED
                    ? transformed
                    : failure(
                        message: "Ideogram generation failed with HTTP \(envelope.statusCode).",
                        response: response
                    )
            }
            guard transformed.status == .GENERATED,
                  let urlString = transformed.rawResponse,
                  let outputURL = URL(string: urlString)
            else {
                return transformed
            }

            var downloadRequest = URLRequest(url: outputURL)
            downloadRequest.httpMethod = "GET"
            let downloaded = try await network.performRawRequest(downloadRequest)
            guard case let .image(_, base64, _) = downloaded else {
                return failure(
                    message: "Ideogram returned an unsupported image download response",
                    response: downloaded
                )
            }

            var materialized = transformed
            materialized.base64 = base64
            materialized.rawResponse = response.rawResponseString
            return materialized
        } catch {
            return failure(message: "Ideogram request failed: \(error.localizedDescription)")
        }
    }

    public static func mapResolution(_ value: String) -> String {
        if supportedResolutions.contains(value) { return value }
        return switch value.lowercased() {
        case "1:1", "square": "2048x2048"
        case "16:9", "landscape_16_9": "2560x1440"
        case "9:16", "portrait_16_9": "1440x2560"
        case "3:2", "landscape_3_2": "2496x1664"
        case "2:3", "portrait_3_2": "1664x2496"
        case "4:5", "portrait_4_5": "1792x2240"
        case "5:4", "landscape_5_4": "2240x1792"
        case "4:3", "landscape_4_3": "2304x1728"
        case "3:4", "portrait_4_3": "1728x2304"
        default: "2048x2048"
        }
    }

    private static func errorMessage(from data: [String: Any]) -> String? {
        if let message = data["message"] as? String { return message }
        if let detail = data["detail"] as? String { return detail }
        if let error = data["error"] as? String { return error }
        if let error = data["error"] as? [String: Any] { return error["message"] as? String }
        return nil
    }

    private func failure(
        message: String,
        response: NetworkResponseData? = nil
    ) -> ImageGenerationResponse {
        ImageGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            rawResponse: response?.rawResponseString
        )
    }
}

public final class G_IDEOGRAM_V4_TURBO: G_IDEOGRAM_V4 {
    public init() {
        super.init(modelCode: .IDEOGRAM_V4_TURBO, renderingSpeed: "TURBO", unitPrice: 0.03)
    }
}

public final class G_IDEOGRAM_V4_DEFAULT: G_IDEOGRAM_V4 {
    public init() {
        super.init(modelCode: .IDEOGRAM_V4_DEFAULT, renderingSpeed: "DEFAULT", unitPrice: 0.06)
    }
}

public final class G_IDEOGRAM_V4_QUALITY: G_IDEOGRAM_V4 {
    public init() {
        super.init(modelCode: .IDEOGRAM_V4_QUALITY, renderingSpeed: "QUALITY", unitPrice: 0.10)
    }
}
