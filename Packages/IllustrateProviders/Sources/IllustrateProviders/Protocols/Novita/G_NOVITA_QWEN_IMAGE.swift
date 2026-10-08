// MARK: - G_NOVITA_QWEN_IMAGE.swift

import Foundation

public final class G_NOVITA_QWEN_IMAGE: ImageGenerationProtocol {
    public let modelCode = EnumProviderModelCode.NOVITA_QWEN_IMAGE
    public let unitPrice = 0.02
    private let pollingPolicy: ProviderPollingPolicy

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy()) {
        self.pollingPolicy = pollingPolicy
    }

    public func getCostEstimate(request _: ImageGenerationCostRequest) -> Double {
        unitPrice
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String
        public let size: String

        public init(prompt: String, size: String) {
            self.prompt = prompt
            self.size = size
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        ServiceRequest(
            prompt: request.prompt,
            size: request.dimensions.replacingOccurrences(of: "x", with: "*")
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        guard case let .dictionary(statusCode, data) = response,
              (200 ... 299).contains(statusCode),
              let task = data["task"] as? [String: Any],
              (task["status"] as? String)?.uppercased() == "TASK_STATUS_SUCCEED"
        else {
            return failure(
                message: Self.failureMessage(response, fallback: "Novita AI returned an invalid task response."),
                response: response
            )
        }

        guard !Self.hasExplicitNSFWResult(data),
              let images = data["images"] as? [[String: Any]],
              images.count == 1,
              let image = images.first,
              let value = image["image_url"] as? String,
              let outputURL = URL(string: value),
              outputURL.scheme?.lowercased() == "https",
              outputURL.host?.isEmpty == false
        else {
            return failure(
                message: Self.hasExplicitNSFWResult(data)
                    ? "Novita AI blocked the generated image as NSFW."
                    : "Novita AI completed without exactly one valid HTTPS image URL.",
                response: response
            )
        }

        var metadata: [String: String] = ["novitaOutputURL": outputURL.absoluteString]
        if let taskId = task["task_id"] as? String, !taskId.isEmpty {
            metadata[ProviderJobMetadataKey.jobId] = taskId
        }
        if let ttl = image["image_url_ttl"] {
            metadata["novitaImageURLTTL"] = String(describing: ttl)
        }
        if let imageType = image["image_type"] as? String, !imageType.isEmpty {
            metadata["novitaImageType"] = imageType
        }

        return ImageGenerationResponse(
            status: .GENERATED,
            cost: unitPrice,
            modelPrompt: request.prompt,
            rawResponse: outputURL.absoluteString,
            metadata: metadata,
            actualDimensions: request.dimensions
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let createURL = model.generateURL, let statusBaseURL = model.statusURL else {
            return failure(message: "Invalid Novita AI generation URL")
        }
        guard Self.isSupportedDimensions(request.dimensions) else {
            return failure(message: "Novita AI dimensions must be between 256 and 1536 pixels per side.")
        }
        guard request.clientImage?.isEmpty != false,
              request.clientMask?.isEmpty != false,
              request.clientReferenceImages?.isEmpty != false
        else {
            return failure(message: "Novita AI Qwen-Image supports text-to-image only.")
        }

        do {
            let credentials = try ProviderCredentialConfiguration(secret: request.providerSecret)
            let apiKey = try credentials.requireAPIKey()
            let network = ProviderDependencies.shared.networkProvider
            let headers = [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json",
                "Accept": "application/json",
            ]
            let createdEnvelope = try await network.performSingleAttemptRequest(
                url: createURL,
                method: "POST",
                body: transformRequest(request: request),
                headers: headers,
                attachments: nil
            )
            let created = try createdEnvelope.requireParsedResponse()
            guard (200 ... 299).contains(createdEnvelope.statusCode) else {
                return failure(
                    message: Self.failureMessage(
                        created,
                        fallback: "Novita AI create failed with HTTP \(createdEnvelope.statusCode)."
                    ),
                    response: created
                )
            }
            let taskId = try Self.taskId(from: created)
            let statusURL = try Self.statusURL(baseURL: statusBaseURL, taskId: taskId)
            let final = try await ProviderAsyncJobPoller.poll(
                policy: pollingPolicy,
                fetch: {
                    try await network.performRequest(
                        url: statusURL,
                        method: "GET",
                        body: nil as String?,
                        headers: ["Authorization": "Bearer \(apiKey)", "Accept": "application/json"],
                        attachments: nil
                    )
                },
                classify: Self.classify
            )
            var transformed = try transformResponse(request: request, response: final)
            guard transformed.status == .GENERATED,
                  let rawURL = transformed.rawResponse,
                  let outputURL = URL(string: rawURL)
            else {
                return transformed
            }
            transformed.base64 = try await ProviderMediaMaterializer.base64(
                from: outputURL,
                network: network
            )
            transformed.rawResponse = final.rawResponseString
            var metadata = transformed.metadata ?? [:]
            metadata[ProviderJobMetadataKey.jobId] = taskId
            metadata[ProviderJobMetadataKey.statusURL] = statusURL.absoluteString
            transformed.metadata = metadata
            return transformed
        } catch {
            return failure(message: "Novita AI request failed: \(error.localizedDescription)")
        }
    }

    public static func classify(_ response: NetworkResponseData) throws -> ProviderAsyncJobState {
        guard case let .dictionary(statusCode, data) = response else {
            return .failed("Novita AI returned a non-JSON status response.")
        }
        guard (200 ... 299).contains(statusCode) else {
            return .failed(failureMessage(response, fallback: "Novita AI status failed with HTTP \(statusCode)."))
        }
        guard let task = data["task"] as? [String: Any],
              let status = task["status"] as? String
        else {
            return .failed(failureMessage(response, fallback: "Novita AI status response omitted task.status."))
        }

        switch status.uppercased() {
        case "TASK_STATUS_QUEUED", "TASK_STATUS_PROCESSING":
            return .pending
        case "TASK_STATUS_SUCCEED":
            return .succeeded
        case "TASK_STATUS_FAILED":
            return .failed(failureMessage(response, fallback: "Novita AI generation failed."))
        case "TASK_STATUS_UNKNOWN":
            return .failed("Novita AI returned an unknown task state.")
        default:
            return .failed("Unknown Novita AI task status: \(status)")
        }
    }

    private static func taskId(from response: NetworkResponseData) throws -> String {
        guard case let .dictionary(_, data) = response,
              let taskId = data["task_id"] as? String,
              !taskId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              taskId.count <= 256
        else {
            throw NovitaAIError.invalidResponse("Novita AI create response omitted task_id.")
        }
        return taskId
    }

    private static func statusURL(baseURL: URL, taskId: String) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw NovitaAIError.invalidResponse("Novita AI status URL is invalid.")
        }
        components.queryItems = [URLQueryItem(name: "task_id", value: taskId)]
        guard let url = components.url else {
            throw NovitaAIError.invalidResponse("Novita AI task ID cannot form a status URL.")
        }
        return url
    }

    private static func isSupportedDimensions(_ value: String) -> Bool {
        let parts = value.lowercased().split(separator: "x", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1])
        else {
            return false
        }
        return (256 ... 1536).contains(width) && (256 ... 1536).contains(height)
    }

    private static func hasExplicitNSFWResult(_ data: [String: Any]) -> Bool {
        if let extra = data["extra"] as? [String: Any],
           let flags = extra["has_nsfw_contents"] as? [Bool],
           flags.contains(true)
        {
            return true
        }
        guard let images = data["images"] as? [[String: Any]] else { return false }
        return images.contains { image in
            if let flag = image["nsfw_detection_result"] as? Bool { return flag }
            if let value = image["nsfw_detection_result"] as? String {
                return ["true", "nsfw", "blocked"].contains(value.lowercased())
            }
            return false
        }
    }

    private static func failureMessage(_ response: NetworkResponseData, fallback: String) -> String {
        guard case let .dictionary(_, data) = response else { return fallback }
        if let message = data["message"] as? String, !message.isEmpty { return message }
        if let reason = data["reason"] as? String, !reason.isEmpty { return reason }
        if let task = data["task"] as? [String: Any],
           let reason = task["reason"] as? String,
           !reason.isEmpty
        {
            return reason
        }
        if let error = data["error"] as? [String: Any],
           let message = error["message"] as? String,
           !message.isEmpty
        {
            return message
        }
        return fallback
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

private enum NovitaAIError: LocalizedError {
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case let .invalidResponse(message): message
        }
    }
}
