// MARK: - G_AZURE_SORA_2.swift

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class G_AZURE_SORA_2: VideoGenerationProtocol {
    public let model: ProviderModelData = ProviderDependencies.shared.modelProvider.model(
        by: .AZURE_SORA_2
    )!

    private let pollingPolicy: ProviderPollingPolicy

    public init(pollingPolicy: ProviderPollingPolicy = .init(maxAttempts: 120, intervalNanoseconds: 2_000_000_000)) {
        self.pollingPolicy = pollingPolicy
    }

    public struct ServiceRequest: Codable, Equatable, Sendable {
        public let model: String
        public let prompt: String
        public let seconds: Int
        public let size: String
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let seconds = request.durationSeconds ?? 4
        let videos = max(request.numberOfVideos ?? 1, 1)
        return 0.10 * Double(seconds) * Double(videos)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        let deployment = (try? AzureAIFoundryConfiguration(secret: request.providerSecret).videoDeployment)
            ?? "sora-2"
        return (try? validatedRequest(from: request, deployment: deployment)) ?? ServiceRequest(
            model: deployment,
            prompt: request.prompt ?? "",
            seconds: request.durationSeconds ?? 4,
            size: request.dimensions
        )
    }

    public func transformResponse(
        request _: VideoGenerationRequest,
        response _: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        throw AzureAIFoundryError.invalidResponse(
            "Azure AI Foundry Sora 2 uses an asynchronous create, poll, and download flow."
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        do {
            let configuration = try AzureAIFoundryConfiguration(secret: request.providerSecret)
            let serviceRequest = try validatedRequest(from: request, deployment: configuration.videoDeployment)
            let attachments = try sourceAttachments(from: request)
            let isMultipart = !attachments.isEmpty
            let createEnvelope = try await ProviderDependencies.shared.networkProvider.performSingleAttemptRequest(
                url: configuration.videoCreateURL(),
                method: "POST",
                body: serviceRequest,
                headers: AzureAIFoundryClient.headers(
                    configuration: configuration,
                    multipart: isMultipart
                ),
                attachments: isMultipart ? attachments : nil
            )

            let createResponse: NetworkResponseData
            do {
                createResponse = try AzureAIFoundryClient.response(
                    from: createEnvelope,
                    operation: "video creation"
                )
            } catch {
                return failure(
                    error.localizedDescription,
                    rawResponse: createEnvelope.response?.rawResponseString ?? createEnvelope.bodyString
                )
            }
            let createData = try AzureAIFoundryClient.dictionary(
                from: createResponse,
                operation: "video creation"
            )
            let videoId = try requiredVideoId(from: createData, configuration: configuration)

            let finalResponse = try await ProviderAsyncJobPoller.poll(
                policy: pollingPolicy,
                fetch: {
                    try await ProviderDependencies.shared.networkProvider.performRequest(
                        url: configuration.videoStatusURL(videoId: videoId),
                        method: "GET",
                        body: ServiceRequest?.none,
                        headers: AzureAIFoundryClient.headers(configuration: configuration),
                        attachments: nil
                    )
                },
                classify: { response in
                    try Self.classify(response)
                }
            )
            let finalData = try AzureAIFoundryClient.dictionary(
                from: finalResponse,
                operation: "video status"
            )

            var downloadRequest = try URLRequest(url: configuration.videoContentURL(videoId: videoId))
            downloadRequest.httpMethod = "GET"
            downloadRequest.setValue(configuration.apiKey, forHTTPHeaderField: "api-key")
            downloadRequest.setValue("video/mp4", forHTTPHeaderField: "Accept")
            let media = try await ProviderDependencies.shared.networkProvider.performDataRequest(downloadRequest)
            guard (200 ... 299).contains(media.statusCode), !media.data.isEmpty else {
                let detail = String(data: media.data, encoding: .utf8)
                throw AzureAIFoundryError.provider(
                    "Azure AI Foundry video download failed with HTTP \(media.statusCode)"
                        + (detail?.isEmpty == false ? ": \(detail!)" : ".")
                )
            }
            if let contentType = media.contentType?.lowercased(), !contentType.hasPrefix("video/") {
                throw AzureAIFoundryError.invalidResponse(
                    "Azure AI Foundry video download returned \(contentType) instead of video content."
                )
            }

            var metadata: [String: String] = [
                ProviderJobMetadataKey.jobId: videoId,
                "azureVideoId": videoId,
                "azureDeployment": configuration.videoDeployment,
                "azureResourceHost": configuration.endpoint.host ?? "",
                "azureStatus": (finalData["status"] as? String) ?? "completed",
            ]
            if let expiresAt = finalData["expires_at"] {
                metadata["azureExpiresAt"] = String(describing: expiresAt)
            }

            return VideoGenerationResponse(
                status: .GENERATED,
                base64: media.data.base64EncodedString(),
                size: media.data.count,
                cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
                modelPrompt: request.prompt,
                rawResponse: finalResponse.rawResponseString,
                metadata: metadata,
                actualDimensions: (finalData["size"] as? String) ?? serviceRequest.size,
                actualDuration: intValue(finalData["seconds"]) ?? serviceRequest.seconds
            )
        } catch {
            return failure("Azure AI Foundry video request failed: \(error.localizedDescription)")
        }
    }

    func validatedRequest(
        from request: VideoGenerationRequest,
        deployment: String
    ) throws -> ServiceRequest {
        let prompt = request.prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !prompt.isEmpty, prompt.count <= 32000 else {
            throw AzureAIFoundryError.invalidInput(
                "Azure AI Foundry Sora 2 prompt must contain 1 to 32,000 characters."
            )
        }
        guard request.numberOfVideos == 1 else {
            throw AzureAIFoundryError.invalidInput(
                "Azure AI Foundry requests exactly one video per atomic operation."
            )
        }
        guard ["1280x720", "720x1280"].contains(request.dimensions) else {
            throw AzureAIFoundryError.invalidInput(
                "Azure AI Foundry Sora 2 supports 1280x720 or 720x1280 output."
            )
        }
        let seconds = request.durationSeconds ?? 4
        guard [4, 8, 12].contains(seconds) else {
            throw AzureAIFoundryError.invalidInput(
                "Azure AI Foundry Sora 2 supports 4, 8, or 12 second videos."
            )
        }
        guard request.clientVideo?.isEmpty != false,
              request.clientMask?.isEmpty != false,
              request.clientLastFrame?.isEmpty != false,
              request.clientReferenceImages?.isEmpty != false
        else {
            throw AzureAIFoundryError.invalidInput(
                "Azure AI Foundry Sora 2 accepts at most one first-frame source image."
            )
        }
        return ServiceRequest(
            model: deployment,
            prompt: prompt,
            seconds: seconds,
            size: request.dimensions
        )
    }

    func sourceAttachments(from request: VideoGenerationRequest) throws -> [NetworkRequestAttachment] {
        guard let source = request.clientImage, !source.isEmpty else { return [] }
        let image = try AzureAIFoundryClient.imageInput(source, allowWebP: true)
        return [.init(name: "input_reference", mimeType: image.mimeType, data: image.data)]
    }

    static func classify(_ response: NetworkResponseData) throws -> ProviderAsyncJobState {
        guard case let .dictionary(statusCode, data) = response else {
            throw AzureAIFoundryError.invalidResponse(
                "Azure AI Foundry video status did not return a JSON object."
            )
        }
        guard (200 ... 299).contains(statusCode) else {
            _ = try AzureAIFoundryClient.dictionary(from: response, operation: "video status")
            throw AzureAIFoundryError.provider(
                "Azure AI Foundry video status failed with HTTP \(statusCode)."
            )
        }
        guard let status = (data["status"] as? String)?.lowercased() else {
            throw AzureAIFoundryError.invalidResponse(
                "Azure AI Foundry video status response omitted status."
            )
        }
        switch status {
        case "queued", "in_progress":
            return .pending
        case "completed":
            return .succeeded
        case "cancelled", "canceled":
            return .cancelled
        case "failed":
            let error = data["error"] as? [String: Any]
            let message = error?["message"] as? String
                ?? data["failure_reason"] as? String
                ?? "Azure AI Foundry video generation failed."
            return .failed(message)
        default:
            throw AzureAIFoundryError.invalidResponse(
                "Azure AI Foundry returned unknown video status: \(status)."
            )
        }
    }

    private func requiredVideoId(
        from data: [String: Any],
        configuration: AzureAIFoundryConfiguration
    ) throws -> String {
        guard let videoId = data["id"] as? String else {
            throw AzureAIFoundryError.invalidResponse(
                "Azure AI Foundry video creation response omitted id."
            )
        }
        _ = try configuration.videoStatusURL(videoId: videoId)
        return videoId
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? String { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private func failure(_ message: String, rawResponse: String? = nil) -> VideoGenerationResponse {
        VideoGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            rawResponse: rawResponse
        )
    }
}
