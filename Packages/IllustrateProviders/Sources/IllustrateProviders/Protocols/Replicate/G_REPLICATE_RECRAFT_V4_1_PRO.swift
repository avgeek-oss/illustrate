// MARK: - G_REPLICATE_RECRAFT_V4_1_PRO.swift

// Replicate Recraft V4.1 Pro public model:
// - recraft-ai/recraft-v4.1-pro

import Foundation

public final class G_REPLICATE_RECRAFT_V4_1_PRO: ImageGenerationProtocol {
    static let baseCost = 0.25

    static let supportedAspectRatios = [
        "1:1",
        "4:3",
        "3:4",
        "3:2",
        "2:3",
        "16:9",
        "9:16",
        "1:2",
        "2:1",
        "4:5",
        "5:4",
        "6:10",
        "14:10",
        "10:14",
    ]

    static let supportedSizes = [
        "2048x2048",
        "3072x1536",
        "1536x3072",
        "2560x1664",
        "1664x2560",
        "2432x1792",
        "1792x2432",
        "2304x1792",
        "1792x2304",
        "1664x2688",
        "2560x1792",
        "1792x2560",
        "2688x1536",
        "1536x2688",
    ]

    var maxPollingAttempts: Int {
        60
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_RECRAFT_V4_1_PRO)!
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let aspect_ratio: String?
        let size: String?

        init(prompt: String, aspectRatio: String? = nil, size: String? = nil) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.size = size
        }
    }

    private struct PredictionRequest<Input: Codable & Sendable>: Codable {
        let input: Input
    }

    public init() {}

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let dimensions = request.dimensions.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if Self.supportedSizes.contains(dimensions) {
            return ServiceRequest(prompt: request.prompt, aspectRatio: nil, size: dimensions)
        }

        return ServiceRequest(
            prompt: request.prompt,
            aspectRatio: Self.mapAspectRatio(dimensions),
            size: nil
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let status = data["status"] as? String, status == "failed" || status == "canceled" {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: Self.errorMessage(from: data) ?? "Prediction \(status)"
                )
            }

            if let imageURL = data["output"] as? String {
                return try imageResponse(from: imageURL, request: request)
            }

            if let output = data["output"] as? [String], let imageURL = output.first {
                return try imageResponse(from: imageURL, request: request)
            }

            if let error = Self.errorMessage(from: data) {
                return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
            }
        default:
            break
        }

        return createInvalidResponseError(response: response, modelCode: model.modelCode)
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = model.generateURL else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        do {
            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: PredictionRequest(input: transformRequest(request: request)),
                headers: headers,
                attachments: nil
            )

            do {
                guard case let .dictionary(_, data) = response,
                      let predictionID = data["id"] as? String
                else {
                    if case let .dictionary(_, data) = response, let error = Self.errorMessage(from: data) {
                        return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
                    }
                    return createInvalidResponseError(
                        response: response,
                        modelCode: model.modelCode,
                        customMessage: "Failed to create prediction"
                    )
                }

                guard let statusURL = model.statusURL else {
                    return createInvalidStatusURLError()
                }

                let finalResponse = try await pollForResult(requestID: predictionID, url: statusURL, headers: headers)
                return try transformResponse(request: request, response: finalResponse)
            } catch {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .TRANSFORM_RESPONSE_ERROR,
                    errorMessage: "Failed with error: \(error.localizedDescription)",
                    rawResponse: "Error: \(error.localizedDescription)"
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

    static func mapAspectRatio(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if supportedAspectRatios.contains(normalized) {
            return normalized
        }

        let ratio = parsedRatio(normalized) ?? parsedRatio(getAspectRatio(normalized)) ?? 1
        return closestSupportedAspectRatio(to: ratio)
    }

    private static func parsedRatio(_ value: String) -> Double? {
        if value.contains(":") {
            let parts = value.split(separator: ":")
            guard parts.count == 2,
                  let width = Double(parts[0]),
                  let height = Double(parts[1]),
                  width > 0,
                  height > 0
            else {
                return nil
            }
            return width / height
        }

        let parts = value.split(separator: "x")
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1]),
              width > 0,
              height > 0
        else {
            return nil
        }
        return width / height
    }

    private static func closestSupportedAspectRatio(to ratio: Double) -> String {
        supportedAspectRatios.min { lhs, rhs in
            let lhsDistance = abs(log((parsedRatio(lhs) ?? 1) / ratio))
            let rhsDistance = abs(log((parsedRatio(rhs) ?? 1) / ratio))
            return lhsDistance < rhsDistance
        } ?? "1:1"
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
