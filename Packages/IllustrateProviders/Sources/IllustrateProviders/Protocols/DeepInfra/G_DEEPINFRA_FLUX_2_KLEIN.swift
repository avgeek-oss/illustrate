// MARK: - G_DEEPINFRA_FLUX_2_KLEIN.swift

import Foundation

public class G_DEEPINFRA_FLUX_2_KLEIN: ImageGenerationProtocol {
    public let modelCode: EnumProviderModelCode
    public let serviceModel: String
    public let normalizedUnitPrice: Double

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        modelCode: EnumProviderModelCode,
        serviceModel: String,
        normalizedUnitPrice: Double
    ) {
        self.modelCode = modelCode
        self.serviceModel = serviceModel
        self.normalizedUnitPrice = normalizedUnitPrice
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        guard let dimensions = Self.parseDimensions(request.dimensions ?? "1024x1024") else {
            return normalizedUnitPrice
        }
        return normalizedUnitPrice
            * Double(dimensions.width) / 1024.0
            * Double(dimensions.height) / 1024.0
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public struct ServiceRequest: Codable, Sendable {
        public let model: String
        public let prompt: String
        public let n: Int
        public let response_format: String
        public let size: String

        public init(model: String, prompt: String, size: String) {
            self.model = model
            self.prompt = prompt
            n = 1
            response_format = "b64_json"
            self.size = size
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        ServiceRequest(model: serviceModel, prompt: request.prompt, size: request.dimensions)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        guard case let .dictionary(_, data) = response else {
            return createInvalidResponseError(response: response, modelCode: modelCode)
        }

        if let message = Self.providerError(in: data) {
            return failure(message: message, response: response)
        }

        guard let images = data["data"] as? [[String: Any]], images.count == 1,
              let image = images.first,
              let base64 = image["b64_json"] as? String,
              !base64.isEmpty
        else {
            return createInvalidResponseError(response: response, modelCode: modelCode)
        }

        return ImageGenerationResponse(
            status: .GENERATED,
            base64: base64,
            cost: getCostEstimate(request: .init(from: request)),
            modelPrompt: (image["revised_prompt"] as? String) ?? request.prompt,
            rawResponse: response.rawResponseString
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = model.generateURL else {
            return failure(message: "Invalid DeepInfra generation URL")
        }
        guard Self.isSupportedDimensions(request.dimensions) else {
            return failure(message: "DeepInfra dimensions must be between 128 and 1920 pixels per side.")
        }
        guard request.clientImage?.isEmpty != false,
              request.clientMask?.isEmpty != false,
              request.clientReferenceImages?.isEmpty != false
        else {
            return failure(message: "DeepInfra source images are not supported by this text-to-image adapter.")
        }

        do {
            let credentials = try ProviderCredentialConfiguration(secret: request.providerSecret)
            let apiKey = try credentials.requireAPIKey()
            let envelope = try await ProviderDependencies.shared.networkProvider.performSingleAttemptRequest(
                url: url,
                method: "POST",
                body: transformRequest(request: request),
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": "application/json",
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
                        message: "DeepInfra generation failed with HTTP \(envelope.statusCode).",
                        response: response
                    )
            }
            return transformed
        } catch {
            return failure(message: "DeepInfra request failed: \(error.localizedDescription)")
        }
    }

    public static func parseDimensions(_ value: String) -> (width: Int, height: Int)? {
        let parts = value.lowercased().split(separator: "x", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1])
        else {
            return nil
        }
        return (width, height)
    }

    private static func isSupportedDimensions(_ value: String) -> Bool {
        guard let dimensions = parseDimensions(value) else { return false }
        return (128 ... 1920).contains(dimensions.width)
            && (128 ... 1920).contains(dimensions.height)
    }

    private static func providerError(in data: [String: Any]) -> String? {
        if let error = data["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        if let detail = data["detail"] as? [String: Any], let message = detail["error"] as? String {
            return message
        }
        if let detail = data["detail"] as? String {
            return detail
        }
        if let details = data["detail"] as? [[String: Any]],
           let message = details.compactMap({ $0["msg"] as? String }).first
        {
            return message
        }
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

public final class G_DEEPINFRA_FLUX_2_KLEIN_4B: G_DEEPINFRA_FLUX_2_KLEIN {
    public init() {
        super.init(
            modelCode: .DEEPINFRA_FLUX_2_KLEIN_4B,
            serviceModel: "black-forest-labs/FLUX-2-klein-4b",
            normalizedUnitPrice: 0.014
        )
    }
}

public final class G_DEEPINFRA_FLUX_2_KLEIN_9B: G_DEEPINFRA_FLUX_2_KLEIN {
    public init() {
        super.init(
            modelCode: .DEEPINFRA_FLUX_2_KLEIN_9B,
            serviceModel: "black-forest-labs/FLUX-2-klein-9b",
            normalizedUnitPrice: 0.015
        )
    }
}
