// MARK: - G_RECRAFT_IMAGE.swift

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public class G_RECRAFT_IMAGE: ImageGenerationProtocol {
    public let modelCode: EnumProviderModelCode
    public let serviceModel: String
    public let unitPrice: Double

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(modelCode: EnumProviderModelCode, serviceModel: String, unitPrice: Double) {
        self.modelCode = modelCode
        self.serviceModel = serviceModel
        self.unitPrice = unitPrice
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        unitPrice * Double(max(1, request.numberOfImages ?? 1))
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String
        public let n: Int
        public let model: String
        public let size: String
        public let random_seed: Int?
        public let response_format: String

        public init(prompt: String, model: String, size: String, randomSeed: Int?) {
            self.prompt = prompt
            n = 1
            self.model = model
            self.size = size
            random_seed = randomSeed
            response_format = "b64_json"
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        ServiceRequest(
            prompt: request.prompt,
            model: serviceModel,
            size: request.dimensions,
            randomSeed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        guard case let .dictionary(_, data) = response else {
            return createInvalidResponseError(response: response, modelCode: modelCode)
        }

        if let error = data["error"] as? [String: Any],
           let message = error["message"] as? String
        {
            return failure(message: message, response: response)
        }

        guard let first = (data["data"] as? [[String: Any]])?.first else {
            return createInvalidResponseError(response: response, modelCode: modelCode)
        }

        if let base64 = first["b64_json"] as? String, !base64.isEmpty {
            return generated(base64: base64, request: request, rawResponse: response.rawResponseString)
        }

        if let url = first["url"] as? String, !url.isEmpty {
            return ImageGenerationResponse(
                status: .GENERATED,
                cost: unitPrice,
                modelPrompt: (first["revised_prompt"] as? String) ?? request.prompt,
                rawResponse: url,
                metadata: responseMetadata(first)
            )
        }

        return createInvalidResponseError(response: response, modelCode: modelCode)
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = model.generateURL else {
            return failure(message: "Invalid Recraft generation URL")
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
                        message: "Recraft generation failed with HTTP \(envelope.statusCode).",
                        response: response
                    )
            }

            guard transformed.status == .GENERATED,
                  transformed.base64 == nil,
                  let remoteURLString = transformed.rawResponse,
                  let remoteURL = URL(string: remoteURLString)
            else {
                return transformed
            }

            var downloadRequest = URLRequest(url: remoteURL)
            downloadRequest.httpMethod = "GET"
            let downloaded = try await ProviderDependencies.shared.networkProvider.performRawRequest(downloadRequest)
            guard case let .image(_, base64, _) = downloaded else {
                return failure(message: "Recraft returned an unsupported image download response", response: downloaded)
            }
            return generated(
                base64: base64,
                request: request,
                rawResponse: response.rawResponseString,
                metadata: transformed.metadata
            )
        } catch {
            return failure(message: "Recraft request failed: \(error.localizedDescription)")
        }
    }

    private func generated(
        base64: String,
        request: ImageGenerationRequest,
        rawResponse: String?,
        metadata: [String: String]? = nil
    ) -> ImageGenerationResponse {
        ImageGenerationResponse(
            status: .GENERATED,
            base64: base64,
            cost: unitPrice,
            modelPrompt: request.prompt,
            rawResponse: rawResponse,
            metadata: metadata
        )
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

    private func responseMetadata(_ data: [String: Any]) -> [String: String]? {
        guard let imageId = data["image_id"] as? String else { return nil }
        return ["recraftImageId": imageId]
    }
}

public final class G_RECRAFT_V4_1: G_RECRAFT_IMAGE {
    public init() {
        super.init(modelCode: .RECRAFT_V4_1, serviceModel: "recraftv4_1", unitPrice: 0.04)
    }
}

public final class G_RECRAFT_V4_1_PRO: G_RECRAFT_IMAGE {
    public init() {
        super.init(modelCode: .RECRAFT_V4_1_PRO, serviceModel: "recraftv4_1_pro", unitPrice: 0.25)
    }
}
