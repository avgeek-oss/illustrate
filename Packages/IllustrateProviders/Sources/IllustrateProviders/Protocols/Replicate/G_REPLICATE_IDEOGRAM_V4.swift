// MARK: - G_REPLICATE_IDEOGRAM_V4.swift

// Replicate Ideogram V4 public models use a resolution-based schema:
// - ideogram-ai/ideogram-v4-turbo
// - ideogram-ai/ideogram-v4-balanced
// - ideogram-ai/ideogram-v4-quality

import Foundation

// MARK: - Base Class

public class ReplicateIdeogramV4Base: ImageGenerationProtocol {
    static let supportedResolutions: Set = [
        "2048x2048",
        "1440x2880",
        "2880x1440",
        "1664x2496",
        "2496x1664",
        "1792x2240",
        "2240x1792",
        "1440x2560",
        "2560x1440",
        "1600x2560",
        "2560x1600",
        "1728x2304",
        "2304x1728",
        "1296x3168",
        "3168x1296",
        "1152x2944",
        "2944x1152",
        "1248x3328",
        "3328x1248",
        "1280x3072",
        "3072x1280",
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
        let resolution: String
        let enable_copyright_detection: Bool

        init(prompt: String, resolution: String, enableCopyrightDetection: Bool = false) {
            self.prompt = prompt
            self.resolution = resolution
            enable_copyright_detection = enableCopyrightDetection
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
            resolution: Self.mapResolution(request.resolution ?? request.dimensions)
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

        let response = try await ProviderDependencies.shared.networkProvider.performRequest(
            url: url,
            method: "POST",
            body: PredictionRequest(input: transformRequest(request: request)),
            headers: headers,
            attachments: nil
        )

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

    static func mapResolution(_ value: String?) -> String {
        guard let rawValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty
        else {
            return "2048x2048"
        }

        if supportedResolutions.contains(rawValue) {
            return rawValue
        }

        let normalized = rawValue.lowercased()
        switch normalized {
        case "1:1", "square":
            return "2048x2048"
        case "16:9", "landscape_16_9":
            return "2560x1440"
        case "9:16", "portrait_16_9":
            return "1440x2560"
        case "3:2", "landscape_3_2":
            return "2496x1664"
        case "2:3", "portrait_3_2":
            return "1664x2496"
        case "4:5", "portrait_4_5":
            return "1792x2240"
        case "5:4", "landscape_5_4":
            return "2240x1792"
        case "4:3", "landscape_4_3":
            return "2304x1728"
        case "3:4", "portrait_4_3":
            return "1728x2304"
        default:
            break
        }

        guard let size = parseDimensions(normalized) else {
            return "2048x2048"
        }

        let ratio = Double(size.width) / Double(size.height)
        if ratio >= 2.35 {
            return "3072x1280"
        }
        if ratio >= 1.9 {
            return "2944x1152"
        }
        if ratio >= 1.6 {
            return "2560x1440"
        }
        if ratio >= 1.4 {
            return "2496x1664"
        }
        if ratio >= 1.2 {
            return "2304x1728"
        }
        if ratio > 1.05 {
            return "2240x1792"
        }
        if ratio <= 0.42 {
            return "1280x3072"
        }
        if ratio <= 0.52 {
            return "1152x2944"
        }
        if ratio <= 0.64 {
            return "1440x2560"
        }
        if ratio <= 0.72 {
            return "1664x2496"
        }
        if ratio <= 0.84 {
            return "1728x2304"
        }
        if ratio < 0.95 {
            return "1792x2240"
        }
        return "2048x2048"
    }

    private static func parseDimensions(_ value: String) -> (width: Int, height: Int)? {
        let parts = value.split(separator: "x")
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1]),
              width > 0,
              height > 0
        else {
            return nil
        }
        return (width, height)
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

// MARK: - Ideogram V4 Turbo

public final class G_REPLICATE_IDEOGRAM_V4_TURBO: ReplicateIdeogramV4Base {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_IDEOGRAM_V4_TURBO
    }

    override var baseCost: Double {
        0.03
    }
}

// MARK: - Ideogram V4 Balanced

public final class G_REPLICATE_IDEOGRAM_V4_BALANCED: ReplicateIdeogramV4Base {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_IDEOGRAM_V4_BALANCED
    }

    override var baseCost: Double {
        0.06
    }
}

// MARK: - Ideogram V4 Quality

public final class G_REPLICATE_IDEOGRAM_V4_QUALITY: ReplicateIdeogramV4Base {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_IDEOGRAM_V4_QUALITY
    }

    override var baseCost: Double {
        0.10
    }
}
