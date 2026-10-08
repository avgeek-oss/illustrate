// MARK: - G_STABILITY_IMAGE_TO_VIDEO.swift

// Implementation for Stability AI Image to Video.
// Animates still images into short video clips.

import Foundation

/// Stability AI image-to-video generation.
public class G_STABILITY_IMAGE_TO_VIDEO: VideoGenerationProtocol {
    public init() {}
    static let costPerSecond = 5.0

    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider
        .model(by: .STABILITY_IMAGE_TO_VIDEO)!

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = request.durationSeconds ?? model.modelParams.supportedVideoDurations.first!
        let numberOfVideos = request.numberOfVideos ?? 1
        return Self.costPerSecond * Double(duration) * Double(numberOfVideos)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return cost == floor(cost) ? String(format: "%.0f credits", cost) : String(format: "%.1f credits", cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String?
        let negative_prompt: String?
        let cfg_scale: Int?
        let motion_bucket_id: Int?
        let user: String

        public init(prompt: String?, negativePrompt: String?, motion: Int?, stickyness: Int?) {
            self.prompt = prompt
            negative_prompt = negativePrompt
            cfg_scale = stickyness
            motion_bucket_id = motion
            user = "illustrate_user"
        }
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        ServiceRequest(
            prompt: request.prompt,
            negativePrompt: request.negativePrompt,
            motion: request.motion,
            stickyness: request.stickyness
        )
    }

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String],
        maxAttempts: Int = 10
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 8_000_000_000)

            do {
                let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                    url: url.appendingPathComponent("/result/\(requestId)"),
                    method: "GET",
                    body: nil as String?,
                    headers: headers,
                    attachments: nil
                )

                switch response {
                case let .dictionary(statusCode, _):
                    if statusCode == 200 {
                        return response
                    }
                case let .array(statusCode, _):
                    if statusCode == 200 {
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

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        let rawResponse = extractRawResponse(from: response)

        switch response {
        case let .dictionary(_, data):
            if let videoData = data["video"] as? String {
                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: videoData,
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
                    modelPrompt: request.prompt
                )
            } else if let errors = data["errors"] as? [String],
                      let message = errors.first
            {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message,

                    rawResponse: rawResponse
                )
            } else if let message = data["message"] as? String {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message,

                    rawResponse: rawResponse
                )
            }
        default:
            return createInvalidVideoResponseError(
                response: response,

                modelCode: model.modelCode,
                customMessage: "Unexpected response"
            )
        }

        return createInvalidVideoResponseError(
            response: response,

            modelCode: model.modelCode
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }
        guard request.clientImage != nil else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Reference Image Missing"
            )
        }

        let transformedRequest = transformRequest(request: request)

        let headers: [String: String] = [
            "Authorization": "\(request.providerSecret)",
            "Content-Type": "multipart/form-data",
            "Accept": "application/json",
        ]

        let initialResponse = try await ProviderDependencies.shared.networkProvider.performRequest(
            url: url,
            method: "POST",
            body: transformedRequest,
            headers: headers,
            attachments: [
                NetworkRequestAttachment(
                    name: "image",
                    mimeType: "jpeg",
                    data: Data(
                        base64Encoded: request.clientImage!.replacingOccurrences(
                            of: "^data:.*;base64,",
                            with: "",
                            options: .regularExpression
                        )
                    )!
                ),
            ]
        )

        var requestId: String? = nil
        switch initialResponse {
        case let .dictionary(_, data):
            if let errors = data["errors"] as? [String],
               let message = errors.first
            {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message
                )
            } else if data["id"] as? String != nil {
                requestId = data["id"] as? String
            }
        case let .array(_, data):
            if let errors = data[0]["errors"] as? [String],
               let message = errors.first
            {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: message
                )
            } else if data[0]["id"] as? String != nil {
                requestId = data[0]["id"] as? String
            }
        default:
            return createInvalidVideoResponseError(
                response: initialResponse,
                modelCode: model.modelCode
            )
        }

        guard let requestId else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Failed to initiate request"
            )
        }

        let finalResponse = try await pollForResult(requestId: requestId, url: url, headers: headers)

        return try transformResponse(request: request, response: finalResponse)
    }
}
