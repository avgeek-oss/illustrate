// MARK: - G_REPLICATE_KREA_2.swift

// Replicate Krea 2 public models:
// - krea/krea-2-medium
// - krea/krea-2-large

import Foundation

// MARK: - Base Class

public class ReplicateKrea2Base: ImageGenerationProtocol {
    static let supportedAspectRatios = [
        "1:1",
        "4:3",
        "3:2",
        "16:9",
        "2.35:1",
        "4:5",
        "2:3",
        "9:16",
    ]

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
        let aspect_ratio: String
        let creativity: String
        let seed: Int?

        init(prompt: String, aspectRatio: String, creativity: String = "medium", seed: Int? = nil) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.creativity = creativity
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

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        ServiceRequest(
            prompt: request.prompt,
            aspectRatio: Self.mapAspectRatio(request.dimensions),
            seed: request.seed
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

        return createInvalidResponseError(response: response, modelCode: modelCode)
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
                    return createInvalidResponseError(response: response, modelCode: modelCode)
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

// MARK: - Krea 2 Medium

public final class G_REPLICATE_KREA_2_MEDIUM: ReplicateKrea2Base {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_KREA_2_MEDIUM
    }

    override var baseCost: Double {
        0.03
    }
}

// MARK: - Krea 2 Large

public final class G_REPLICATE_KREA_2_LARGE: ReplicateKrea2Base {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_KREA_2_LARGE
    }

    override var baseCost: Double {
        0.06
    }
}
