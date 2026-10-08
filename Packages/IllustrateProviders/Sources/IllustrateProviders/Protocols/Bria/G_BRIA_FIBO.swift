// MARK: - G_BRIA_FIBO.swift

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Direct Bria FIBO v2 integration.
///
/// Bria accepts one image generation per asynchronous request. The app performs
/// any requested batching by invoking this adapter once for each output.
public final class G_BRIA_FIBO: ImageGenerationProtocol {
    public let modelCode = EnumProviderModelCode.BRIA_FIBO
    public let unitPrice = 0.03
    private let pollingPolicy: ProviderPollingPolicy

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy()) {
        self.pollingPolicy = pollingPolicy
    }

    /// A Bria API request always creates exactly one image.
    public func getCostEstimate(request _: ImageGenerationCostRequest) -> Double {
        unitPrice
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String?
        public let images: [String]?
        public let resolution: String
        public let negative_prompt: String?
        public let model_version: String
        public let aspect_ratio: String
        public let steps_num: Int?
        public let seed: Int?
        public let sync: Bool
        public let output_type: String
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let image = request.clientImage
            ?? request.clientReferenceImages?.first?.base64Image

        return ServiceRequest(
            prompt: Self.nonEmpty(request.prompt),
            images: image.map { [Self.imageInput($0)] },
            resolution: Self.resolution(request.resolution),
            negative_prompt: request.negativePrompt.flatMap(Self.nonEmpty),
            model_version: "FIBO",
            aspect_ratio: Self.aspectRatio(for: request.dimensions),
            steps_num: request.steps.flatMap { (35 ... 50).contains($0) ? $0 : nil },
            seed: request.seed,
            sync: false,
            output_type: "png"
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        guard case let .dictionary(statusCode, data) = response,
              (200 ... 299).contains(statusCode)
        else {
            return failure(
                message: Self.httpFailureMessage(response, operation: "generation"),
                response: response
            )
        }

        if let status = data["status"] as? String,
           ["ERROR", "UNKNOWN"].contains(status.uppercased())
        {
            return failure(
                message: Self.failureMessage(from: data, fallback: "Bria generation failed with status \(status)."),
                response: response
            )
        }

        guard let outputURL = Self.outputURLString(in: data) else {
            return createInvalidResponseError(
                response: response,
                modelCode: modelCode,
                customMessage: "Bria completed without an image URL."
            )
        }

        var metadata = Self.resultMetadata(data)
        metadata["briaOutputURL"] = outputURL

        return ImageGenerationResponse(
            status: .GENERATED,
            cost: unitPrice,
            modelPrompt: request.prompt,
            rawResponse: outputURL,
            metadata: metadata,
            actualDimensions: request.dimensions
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = model.generateURL else {
            return failure(message: "Invalid Bria generation URL")
        }

        do {
            try Self.validateInputSelection(request)
            let credentials = try ProviderCredentialConfiguration(secret: request.providerSecret)
            let apiKey = try credentials.requireAPIKey()
            let network = ProviderDependencies.shared.networkProvider
            let headers = [
                "api_token": apiKey,
                "Accept": "application/json",
                "Content-Type": "application/json",
            ]

            let createdEnvelope = try await network.performSingleAttemptRequest(
                url: url,
                method: "POST",
                body: transformRequest(request: request),
                headers: headers,
                attachments: nil
            )
            let created = try createdEnvelope.requireParsedResponse()
            try Self.requireSuccessfulHTTP(created, operation: "create")

            if Self.containsTerminalError(created) {
                throw BriaAdapterError.provider(
                    Self.failureMessage(from: Self.dictionary(from: created), fallback: "Bria rejected the request.")
                )
            }

            if Self.outputURLString(from: created) != nil {
                return try await materialize(
                    request: request,
                    response: created,
                    network: network,
                    job: nil
                )
            }

            let job = try job(from: created)
            let policy = pollingPolicy
            let final = try await ProviderAsyncJobPoller.poll(
                policy: policy,
                fetch: {
                    try await network.performRequest(
                        url: job.statusURL,
                        method: "GET",
                        body: nil as String?,
                        headers: ["api_token": apiKey, "Accept": "application/json"],
                        attachments: nil
                    )
                },
                classify: Self.classify
            )

            return try await materialize(
                request: request,
                response: final,
                network: network,
                job: job
            )
        } catch {
            return failure(message: "Bria request failed: \(error.localizedDescription)")
        }
    }

    /// Bria reports job-level failures inside an HTTP 200 response, so callers
    /// must classify the body instead of treating the HTTP status as success.
    public static func classify(_ response: NetworkResponseData) throws -> ProviderAsyncJobState {
        guard case let .dictionary(statusCode, data) = response else {
            return .failed("Bria returned a non-JSON status response.")
        }

        guard (200 ... 299).contains(statusCode) else {
            return .failed(httpFailureMessage(response, operation: "status"))
        }

        guard let status = data["status"] as? String else {
            return .failed(failureMessage(from: data, fallback: "Bria status response omitted status."))
        }

        switch status.uppercased() {
        case "IN_PROGRESS":
            return .pending
        case "COMPLETED":
            return .succeeded
        case "ERROR":
            return .failed(failureMessage(from: data, fallback: "Bria generation failed."))
        case "UNKNOWN":
            return .failed(failureMessage(from: data, fallback: "Bria returned an UNKNOWN job state."))
        default:
            return .failed("Unknown Bria status: \(status)")
        }
    }

    public static func aspectRatio(for dimensions: String) -> String {
        let supported: [(label: String, ratio: Double)] = [
            ("1:1", 1),
            ("2:3", 2.0 / 3.0),
            ("3:2", 3.0 / 2.0),
            ("3:4", 3.0 / 4.0),
            ("4:3", 4.0 / 3.0),
            ("4:5", 4.0 / 5.0),
            ("5:4", 5.0 / 4.0),
            ("9:16", 9.0 / 16.0),
            ("16:9", 16.0 / 9.0),
        ]

        if supported.contains(where: { $0.label == dimensions }) {
            return dimensions
        }

        let parts = dimensions.lowercased().split(separator: "x", maxSplits: 1)
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1]),
              width > 0,
              height > 0
        else {
            return "1:1"
        }

        let ratio = width / height
        return supported.min { abs($0.ratio - ratio) < abs($1.ratio - ratio) }?.label ?? "1:1"
    }

    public static func imageInput(_ input: String) -> String {
        guard input.hasPrefix("data:"), let comma = input.firstIndex(of: ",") else {
            return input
        }
        return String(input[input.index(after: comma)...])
    }

    private struct Job {
        let id: String
        let statusURL: URL
    }

    private func job(from response: NetworkResponseData) throws -> Job {
        let data = Self.dictionary(from: response)
        guard let id = (data["request_id"] as? String) ?? (data["id"] as? String),
              !id.isEmpty
        else {
            throw BriaAdapterError.invalidResponse("Bria create response omitted request_id.")
        }

        guard let baseURL = model.statusURL else {
            throw BriaAdapterError.invalidResponse("Bria create response omitted status_url.")
        }

        if let statusURLString = data["status_url"] as? String {
            let statusURL = try Self.validatedStatusURL(statusURLString, baseURL: baseURL)
            return Job(id: id, statusURL: statusURL)
        }

        return Job(id: id, statusURL: baseURL.appendingPathComponent(id))
    }

    private static func validateInputSelection(_ request: ImageGenerationRequest) throws {
        let hasSource = request.clientImage?.isEmpty == false
        let references = (request.clientReferenceImages ?? []).filter { !$0.base64Image.isEmpty }
        guard !(hasSource && !references.isEmpty), references.count <= 1 else {
            throw BriaAdapterError.invalidInput(
                "Bria accepts one source or reference image, not both."
            )
        }
    }

    private static func validatedStatusURL(_ value: String, baseURL: URL) throws -> URL {
        guard let statusURL = URL(string: value),
              statusURL.scheme?.lowercased() == "https",
              statusURL.user == nil,
              statusURL.password == nil,
              statusURL.port == baseURL.port,
              statusURL.host?.lowercased() == baseURL.host?.lowercased()
        else {
            throw BriaAdapterError.invalidResponse("Bria returned an untrusted status URL.")
        }
        return statusURL
    }

    private func materialize(
        request: ImageGenerationRequest,
        response: NetworkResponseData,
        network: any NetworkProvider,
        job: Job?
    ) async throws -> ImageGenerationResponse {
        var transformed = try transformResponse(request: request, response: response)
        guard transformed.status == .GENERATED,
              let output = transformed.rawResponse,
              let outputURL = URL(string: output)
        else {
            return transformed
        }

        var downloadRequest = URLRequest(url: outputURL)
        downloadRequest.httpMethod = "GET"
        let downloaded = try await network.performRawRequest(downloadRequest)
        guard case let .image(statusCode, base64, _) = downloaded,
              (200 ... 299).contains(statusCode)
        else {
            return failure(
                message: "Bria returned an unsupported image download response.",
                response: downloaded
            )
        }

        transformed.base64 = base64
        transformed.rawResponse = response.rawResponseString
        var metadata = transformed.metadata ?? [:]
        if let job {
            metadata[ProviderJobMetadataKey.jobId] = job.id
            metadata[ProviderJobMetadataKey.statusURL] = job.statusURL.absoluteString
        }
        transformed.metadata = metadata
        return transformed
    }

    private static func resolution(_ requested: String?) -> String {
        switch requested?.uppercased() {
        case "4MP": "4MP"
        default: "1MP"
        }
    }

    private static func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func dictionary(from response: NetworkResponseData) -> [String: Any] {
        guard case let .dictionary(_, data) = response else { return [:] }
        return data
    }

    private static func requireSuccessfulHTTP(
        _ response: NetworkResponseData,
        operation: String
    ) throws {
        let statusCode: Int = switch response {
        case let .dictionary(code, _), let .array(code, _), let .image(code, _, _):
            code
        }
        guard (200 ... 299).contains(statusCode) else {
            throw BriaAdapterError.provider(httpFailureMessage(response, operation: operation))
        }
    }

    private static func containsTerminalError(_ response: NetworkResponseData) -> Bool {
        let data = dictionary(from: response)
        guard let status = data["status"] as? String else { return false }
        return ["ERROR", "UNKNOWN"].contains(status.uppercased())
    }

    private static func outputURLString(from response: NetworkResponseData) -> String? {
        outputURLString(in: dictionary(from: response))
    }

    private static func outputURLString(in data: [String: Any]) -> String? {
        for key in ["image_url", "result_url"] {
            if let value = data[key] as? String, !value.isEmpty {
                return value
            }
        }

        for key in ["result", "data", "output"] {
            if let nested = data[key] as? [String: Any],
               let value = outputURLString(in: nested)
            {
                return value
            }
            if let nested = data[key] as? [[String: Any]] {
                for item in nested {
                    if let value = outputURLString(in: item) { return value }
                }
            }
        }
        return nil
    }

    private static func resultMetadata(_ data: [String: Any]) -> [String: String] {
        var metadata: [String: String] = [:]
        let result = data["result"] as? [String: Any]

        if let requestId = data["request_id"] as? String {
            metadata[ProviderJobMetadataKey.jobId] = requestId
        }
        if let seed = result?["seed"] ?? data["seed"] {
            metadata["briaSeed"] = String(describing: seed)
        }
        if let structuredPrompt = result?["structured_prompt"] as? String
            ?? data["structured_prompt"] as? String
        {
            metadata["briaStructuredPrompt"] = structuredPrompt
        }
        if let warning = data["warning"] as? String {
            metadata["briaWarning"] = warning
        }
        return metadata
    }

    private static func failureMessage(from data: [String: Any], fallback: String) -> String {
        if let message = data["message"] as? String, !message.isEmpty { return message }
        if let detail = data["detail"] as? String, !detail.isEmpty { return detail }
        if let error = data["error"] as? String, !error.isEmpty { return error }
        if let error = data["error"] as? [String: Any] {
            if let message = error["message"] as? String, !message.isEmpty { return message }
            if let details = error["details"] as? String, !details.isEmpty { return details }
            if let code = error["code"] { return "Bria error \(code)" }
        }
        return fallback
    }

    private static func httpFailureMessage(
        _ response: NetworkResponseData,
        operation: String
    ) -> String {
        guard case let .dictionary(statusCode, data) = response else {
            return "Bria \(operation) request returned an unsupported response."
        }
        let fallback = "Bria \(operation) request failed with HTTP \(statusCode)."
        let detail = failureMessage(from: data, fallback: fallback)
        return detail == fallback ? fallback : "\(fallback) \(detail)"
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

private enum BriaAdapterError: LocalizedError {
    case invalidInput(String)
    case invalidResponse(String)
    case provider(String)

    var errorDescription: String? {
        switch self {
        case let .invalidInput(message), let .invalidResponse(message), let .provider(message):
            message
        }
    }
}
