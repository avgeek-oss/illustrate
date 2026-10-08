// MARK: - G_REPLICATE_DREAMINA_3_1.swift

// Implementation for ByteDance Dreamina 3.1 via Replicate.
// Creative image generation model with artistic capabilities.

import Foundation

/// ByteDance Dreamina 3.1 via Replicate.
public class G_REPLICATE_DREAMINA_3_1: ImageGenerationProtocol {
    public init() {}
    static let baseCost = 0.03

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        Self.baseCost * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(by: .REPLICATE_DREAMINA_3_1)!

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String
        public let aspect_ratio: String
        public let resolution: String
        public let use_pre_llm: Bool
        public let seed: Int?

        public init(
            prompt: String,
            aspectRatio: String,
            resolution: String = "2K",
            usePreLlm: Bool = true,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            aspect_ratio = aspectRatio
            self.resolution = resolution
            use_pre_llm = usePreLlm
            self.seed = seed
        }
    }

    private func mapToDreaminaAspectRatio(dimension: String) -> String {
        let aspectRatio = getAspectRatio(dimension: dimension)
        let ratio = aspectRatio.ratio

        let supportedRatios = ["1:1", "4:3", "3:4", "3:2", "2:3", "16:9", "9:16", "21:9", "9:21"]

        if supportedRatios.contains(ratio) {
            return ratio
        }

        let width = aspectRatio.width
        let height = aspectRatio.height
        let aspectValue = Double(width) / Double(height)

        let ratioValues: [(String, Double)] = [
            ("1:1", 1.0),
            ("4:3", 1.333),
            ("3:4", 0.75),
            ("3:2", 1.5),
            ("2:3", 0.667),
            ("16:9", 1.778),
            ("9:16", 0.5625),
            ("21:9", 2.333),
            ("9:21", 0.429),
        ]

        var closestRatio = "1:1"
        var minDiff = Double.greatestFiniteMagnitude

        for (ratioStr, ratioVal) in ratioValues {
            let diff = abs(aspectValue - ratioVal)
            if diff < minDiff {
                minDiff = diff
                closestRatio = ratioStr
            }
        }

        return closestRatio
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let aspectRatio = mapToDreaminaAspectRatio(dimension: request.dimensions)

        return ServiceRequest(
            prompt: request.variant != "Normal" ? "\(request.variant) - \(request.prompt)" : request.prompt,
            aspectRatio: aspectRatio,
            resolution: request.resolution ?? "2K",
            usePreLlm: request.promptEnhance ?? true,
            seed: request.seed
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let output = data["output"] as? [String],
               let pngUrl = output.first
            {
                let url = URL(string: pngUrl)!
                let pngData = try Data(contentsOf: url)
                let base64 = pngData.base64EncodedString()

                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
            }
            if let pngUrl = data["output"] as? String {
                let url = URL(string: pngUrl)!
                let pngData = try Data(contentsOf: url)
                let base64 = pngData.base64EncodedString()

                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
                )
            }
            if let errorList = data["error"] as? [String],
               let error = errorList.first
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: error
                )
            }
            if let error = data["error"] as? String {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: error
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

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String],
        maxAttempts: Int = 20
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 4_000_000_000)

            do {
                let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                    url: url.appendingPathComponent("/\(requestId)"),
                    method: "GET",
                    body: nil as String?,
                    headers: headers,
                    attachments: nil
                )

                switch response {
                case let .dictionary(_, data):
                    if let status = data["status"] as? String,
                       status == "succeeded" || status == "failed" || status == "canceled"
                    {
                        return response
                    }
                default:
                    break
                }
            } catch {
                throw NSError(domain: "Polling failed", code: -1, userInfo: nil)
            }

            attempts += 1
        }

        throw NSError(domain: "Polling exceeded max attempts", code: -1, userInfo: nil)
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let transformedRequest = transformRequest(request: request)

        do {
            let headers: [String: String] = [
                "Authorization": "Bearer \(request.providerSecret)",
                "Content-Type": "application/json",
            ]

            let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: [
                    "input": transformedRequest,
                ],
                headers: headers,
                attachments: nil
            )

            do {
                var requestId: String? = nil
                switch initialResponse {
                case let .dictionary(_, data):
                    if data["id"] as? String != nil {
                        requestId = data["id"] as? String
                    }
                default:
                    return createInvalidResponseError(
                        response: initialResponse,

                        modelCode: model.modelCode,
                        customMessage: "Unexpected response"
                    )
                }

                guard let requestId else {
                    return ImageGenerationResponse(
                        status: .FAILED,
                        errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                        errorMessage: "Failed to initiate request"
                    )
                }

                guard let statusUrl = model.statusURL else {
                    return createInvalidStatusURLError()
                }

                let finalResponse = try await pollForResult(requestId: requestId, url: statusUrl, headers: headers)

                return try transformResponse(request: request, response: finalResponse)
            } catch {
                return ImageGenerationResponse(
                    status: EnumGenerationStatus.FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.TRANSFORM_RESPONSE_ERROR,
                    errorMessage: "Failed with error: \(error.localizedDescription)",
                    rawResponse: "Error: \(error.localizedDescription)"
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
