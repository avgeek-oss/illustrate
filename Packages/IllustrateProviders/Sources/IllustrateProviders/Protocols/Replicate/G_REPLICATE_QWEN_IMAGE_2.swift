// MARK: - G_REPLICATE_QWEN_IMAGE_2.swift

// Qwen Image 2 public Replicate models use the same text/image-edit schema:
// - qwen/qwen-image-2
// - qwen/qwen-image-2-pro

import Foundation

// MARK: - Base Class

public class ReplicateQwenImage2Base: ImageGenerationProtocol {
    private static let supportedAspectRatios = ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3", "2:1", "1:2"]

    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override modelCode")
    }

    var baseCost: Double {
        fatalError("Subclass must override baseCost")
    }

    var maxPollingAttempts: Int {
        60
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let image: String?
        let match_input_image: Bool
        let aspect_ratio: String
        let enable_prompt_expansion: Bool
        let negative_prompt: String
        let seed: Int?

        init(
            prompt: String,
            image: String? = nil,
            matchInputImage: Bool = false,
            aspectRatio: String = "1:1",
            enablePromptExpansion: Bool = true,
            negativePrompt: String = "",
            seed: Int? = nil
        ) {
            self.prompt = prompt
            self.image = image
            match_input_image = matchInputImage
            aspect_ratio = aspectRatio
            enable_prompt_expansion = enablePromptExpansion
            negative_prompt = negativePrompt
            self.seed = seed
        }
    }

    private struct PredictionRequest<Input: Codable & Sendable>: Codable {
        let input: Input
    }

    public init() {}

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public func transformRequest(request: ImageGenerationRequest, imageURL: String? = nil) -> ServiceRequest {
        ServiceRequest(
            prompt: request.prompt,
            image: imageURL,
            matchInputImage: imageURL != nil,
            aspectRatio: Self.mapAspectRatio(request.dimensions),
            enablePromptExpansion: request.promptEnhance ?? true,
            negativePrompt: request.negativePrompt ?? "",
            seed: request.seed
        )
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, imageURL: nil)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let status = data["status"] as? String,
               status == "failed" || status == "canceled"
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: Self.errorMessage(from: data) ?? "Prediction \(status)",
                    rawResponse: response.rawResponseString
                )
            }

            if let imageURL = data["output"] as? String {
                return try imageResponse(from: imageURL, request: request)
            }

            if let output = data["output"] as? [String], let imageURL = output.first {
                return try imageResponse(from: imageURL, request: request)
            }

            if let error = Self.errorMessage(from: data) {
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

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = model.generateURL else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let imageURL: String?
        do {
            imageURL = try await uploadImageIfNeeded(request: request)
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed to upload image: \(error.localizedDescription)"
            )
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        let response = try await ProviderDependencies.shared.networkProvider.performRequest(
            url: url,
            method: "POST",
            body: PredictionRequest(input: transformRequest(request: request, imageURL: imageURL)),
            headers: headers,
            attachments: nil
        )

        guard case let .dictionary(_, data) = response,
              let predictionID = data["id"] as? String
        else {
            if case let .dictionary(_, data) = response, let error = Self.errorMessage(from: data) {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: error,
                    rawResponse: response.rawResponseString
                )
            }
            return createInvalidResponseError(response: response, modelCode: modelCode)
        }

        guard let statusURL = model.statusURL else {
            return createInvalidStatusURLError()
        }

        let finalResponse = try await pollForResult(requestID: predictionID, url: statusURL, headers: headers)
        return try transformResponse(request: request, response: finalResponse)
    }

    func pollForResult(
        requestID: String,
        url: URL,
        headers: [String: String]
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < maxPollingAttempts {
            try await Task.sleep(nanoseconds: 3_000_000_000)

            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url.appendingPathComponent(requestID),
                method: "GET",
                body: nil as String?,
                headers: headers,
                attachments: nil
            )

            if case let .dictionary(_, data) = response,
               let status = data["status"] as? String,
               status == "succeeded" || status == "failed" || status == "canceled"
            {
                return response
            }
            attempts += 1
        }

        throw NSError(domain: "Polling exceeded max attempts", code: -1, userInfo: nil)
    }

    private func uploadImageIfNeeded(request: ImageGenerationRequest) async throws -> String? {
        if let clientImage = request.clientImage {
            return try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
        }

        guard let referenceImage = request.clientReferenceImages?.first else {
            return nil
        }

        return try await ReplicateFileUploader.uploadImage(
            base64Image: referenceImage.base64Image,
            apiToken: request.providerSecret
        )
    }

    private func imageResponse(
        from outputURL: String,
        request: ImageGenerationRequest
    ) throws -> ImageGenerationResponse {
        let base64: String
        if outputURL.hasPrefix("data:") {
            base64 = outputURL.replacingOccurrences(
                of: "^data:.*;base64,",
                with: "",
                options: .regularExpression
            )
        } else {
            guard let url = URL(string: outputURL) else {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Invalid output URL"
                )
            }
            base64 = try Data(contentsOf: url).base64EncodedString()
        }

        return ImageGenerationResponse(
            status: .GENERATED,
            base64: base64,
            cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }

    private static func mapAspectRatio(_ dimensions: String) -> String {
        if supportedAspectRatios.contains(dimensions) {
            return dimensions
        }

        let ratio = getAspectRatio(dimension: dimensions).ratio
        return supportedAspectRatios.contains(ratio) ? ratio : "1:1"
    }

    private static func errorMessage(from data: [String: Any]) -> String? {
        if let error = data["error"] as? String, !error.isEmpty {
            return error
        }
        if let errors = data["error"] as? [String], let error = errors.first, !error.isEmpty {
            return error
        }
        if let logs = data["logs"] as? String, !logs.isEmpty {
            return logs
        }
        return nil
    }
}

// MARK: - Qwen Image 2

public final class G_REPLICATE_QWEN_IMAGE_2: ReplicateQwenImage2Base {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_QWEN_IMAGE_2
    }

    override var baseCost: Double {
        0.035
    }
}

// MARK: - Qwen Image 2 Pro

public final class G_REPLICATE_QWEN_IMAGE_2_PRO: ReplicateQwenImage2Base {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_QWEN_IMAGE_2_PRO
    }

    override var baseCost: Double {
        0.075
    }
}
