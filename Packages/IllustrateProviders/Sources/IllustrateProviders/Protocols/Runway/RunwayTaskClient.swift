// MARK: - RunwayTaskClient.swift

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum RunwayTaskClient {
    static let apiVersion = "2024-11-06"
    static let tasksURL = URL(string: "https://api.dev.runwayml.com/v1/tasks")!
    static let defaultPollingPolicy = ProviderPollingPolicy(
        maxAttempts: 120,
        intervalNanoseconds: 5_000_000_000
    )

    struct Job: Equatable {
        let id: String
        let statusURL: URL
        let cancelURL: URL

        var metadata: [String: String] {
            [
                ProviderJobMetadataKey.jobId: id,
                ProviderJobMetadataKey.statusURL: statusURL.absoluteString,
                ProviderJobMetadataKey.cancelURL: cancelURL.absoluteString,
            ]
        }
    }

    static func headers(apiKey: String, includesJSONBody: Bool = true) -> [String: String] {
        var headers = [
            "Authorization": "Bearer \(apiKey)",
            "X-Runway-Version": apiVersion,
            "Accept": "application/json",
        ]
        if includesJSONBody {
            headers["Content-Type"] = "application/json"
        }
        return headers
    }

    static func create(
        url: URL,
        body: some Codable & Sendable,
        apiKey: String,
        network: any NetworkProvider
    ) async throws -> Job {
        let envelope = try await network.performSingleAttemptRequest(
            url: url,
            method: "POST",
            body: body,
            headers: headers(apiKey: apiKey),
            attachments: nil
        )
        let response = try envelope.requireParsedResponse()
        let code = statusCode(of: response)
        guard (200 ... 299).contains(code) else {
            throw RunwayAdapterError.provider(httpFailureMessage(response, operation: "create"))
        }
        guard case let .dictionary(_, data) = response,
              let id = data["id"] as? String,
              UUID(uuidString: id) != nil
        else {
            throw RunwayAdapterError.invalidResponse("Runway create response omitted a valid task ID.")
        }

        let taskURL = tasksURL.appendingPathComponent(id)
        return Job(id: id, statusURL: taskURL, cancelURL: taskURL)
    }

    static func poll(
        job: Job,
        apiKey: String,
        network: any NetworkProvider,
        policy: ProviderPollingPolicy
    ) async throws -> NetworkResponseData {
        if policy.intervalNanoseconds > 0 {
            try await Task.sleep(nanoseconds: policy.intervalNanoseconds)
        }

        return try await withTaskCancellationHandler {
            try await ProviderAsyncJobPoller.poll(
                policy: policy,
                fetch: {
                    try await network.performRequest(
                        url: job.statusURL,
                        method: "GET",
                        body: nil as String?,
                        headers: headers(apiKey: apiKey, includesJSONBody: false),
                        attachments: nil
                    )
                },
                classify: classify
            )
        } onCancel: {
            Task {
                try? await cancel(
                    jobId: job.id,
                    apiKey: apiKey,
                    network: network
                )
            }
        }
    }

    static func classify(_ response: NetworkResponseData) throws -> ProviderAsyncJobState {
        let code = statusCode(of: response)
        guard (200 ... 299).contains(code) else {
            return .failed(httpFailureMessage(response, operation: "status"))
        }
        guard case let .dictionary(_, data) = response,
              let status = data["status"] as? String
        else {
            return .failed("Runway status response omitted status.")
        }

        switch status.uppercased() {
        case "PENDING", "THROTTLED", "RUNNING":
            return .pending
        case "SUCCEEDED":
            return .succeeded
        case "FAILED":
            return .failed(failureMessage(from: data))
        case "CANCELLED":
            return .cancelled
        default:
            return .failed("Unknown Runway task status: \(status)")
        }
    }

    static func materialize(
        response: NetworkResponseData,
        network: any NetworkProvider
    ) async throws -> (base64: String, outputURL: URL) {
        guard case let .dictionary(code, data) = response,
              (200 ... 299).contains(code),
              let outputs = data["output"] as? [String],
              let output = outputs.first,
              let outputURL = URL(string: output),
              outputURL.scheme?.lowercased() == "https"
        else {
            throw RunwayAdapterError.invalidResponse("Runway succeeded without a valid HTTPS output URL.")
        }

        let base64 = try await ProviderMediaMaterializer.base64(
            from: outputURL,
            network: network
        )
        return (base64, outputURL)
    }

    static func cancel(
        jobId: String,
        apiKey: String,
        network: any NetworkProvider
    ) async throws {
        guard UUID(uuidString: jobId) != nil else {
            throw RunwayAdapterError.invalidInput("Runway task ID is not a valid UUID.")
        }

        let url = tasksURL.appendingPathComponent(jobId)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        for (key, value) in headers(apiKey: apiKey, includesJSONBody: false) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        do {
            let response = try await network.performRawRequest(request)
            let code = statusCode(of: response)
            guard (200 ... 299).contains(code) || code == 404 else {
                throw RunwayAdapterError.provider(httpFailureMessage(response, operation: "cancel"))
            }
        } catch let error as NSError where error.code == 404 {
            // Runway documents cancellation as idempotent even though repeated
            // DELETE requests return 404 after the task is removed.
        }
    }

    static func validatedPrompt(_ prompt: String) throws -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RunwayAdapterError.invalidInput("Runway requires a non-empty prompt.")
        }
        guard trimmed.utf16.count <= 1000 else {
            throw RunwayAdapterError.invalidInput("Runway prompts cannot exceed 1000 UTF-16 code units.")
        }
        return trimmed
    }

    static func validatedSeed(_ seed: Int?) throws -> Int? {
        guard let seed else { return nil }
        guard (0 ... 4_294_967_295).contains(seed) else {
            throw RunwayAdapterError.invalidInput("Runway seed must be between 0 and 4294967295.")
        }
        return seed
    }

    static func validatedModeration(_ moderation: String?) throws -> String? {
        guard let moderation else { return nil }
        let normalized = moderation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        guard normalized == "auto" || normalized == "low" else {
            throw RunwayAdapterError.invalidInput("Runway public figure threshold must be auto or low.")
        }
        return normalized
    }

    static func validatedImageURI(_ input: String, mimeType: String = "image/png") throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RunwayAdapterError.invalidInput("Runway image input is empty.")
        }

        if trimmed.hasPrefix("https://") {
            guard trimmed.utf8.count <= 2048 else {
                throw RunwayAdapterError.invalidInput("Runway image URL exceeds 2048 characters.")
            }
            return trimmed
        }
        if trimmed.hasPrefix("runway://") {
            guard trimmed.utf8.count <= 5000 else {
                throw RunwayAdapterError.invalidInput("Runway upload URI exceeds 5000 characters.")
            }
            return trimmed
        }
        if trimmed.hasPrefix("data:") {
            try validateDataURI(trimmed)
            return trimmed
        }

        guard Data(base64Encoded: trimmed) != nil else {
            throw RunwayAdapterError.invalidInput("Runway image input is not valid base64.")
        }
        let normalizedMIME = try validatedImageMIME(mimeType)
        let dataURI = "data:\(normalizedMIME);base64,\(trimmed)"
        try validateDataURI(dataURI)
        return dataURI
    }

    private static func validateDataURI(_ dataURI: String) throws {
        guard dataURI.utf8.count <= 5 * 1024 * 1024 else {
            throw RunwayAdapterError.invalidInput("Runway image data URI exceeds 5 MB.")
        }
        guard let comma = dataURI.firstIndex(of: ",") else {
            throw RunwayAdapterError.invalidInput("Runway image data URI is malformed.")
        }
        let header = String(dataURI[..<comma]).lowercased()
        guard header.hasSuffix(";base64") else {
            throw RunwayAdapterError.invalidInput("Runway image data URI must use base64 encoding.")
        }
        let mimeStart = header.index(header.startIndex, offsetBy: "data:".count)
        let mimeEnd = header.index(header.endIndex, offsetBy: -";base64".count)
        _ = try validatedImageMIME(String(header[mimeStart ..< mimeEnd]))
        let encoded = String(dataURI[dataURI.index(after: comma)...])
        guard !encoded.isEmpty, Data(base64Encoded: encoded) != nil else {
            throw RunwayAdapterError.invalidInput("Runway image data URI contains invalid base64.")
        }
    }

    private static func validatedImageMIME(_ mimeType: String) throws -> String {
        let normalized = mimeType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let supported = ["image/jpeg", "image/png", "image/webp"]
        guard supported.contains(normalized) else {
            throw RunwayAdapterError.invalidInput("Runway supports JPEG, PNG, and WebP image inputs.")
        }
        return normalized
    }

    private static func failureMessage(from data: [String: Any]) -> String {
        let failure = data["failure"] as? String
            ?? providerError(in: data)
            ?? "Runway generation failed."
        if let failureCode = data["failureCode"] as? String, !failureCode.isEmpty {
            return "Runway generation failed (\(failureCode)): \(failure)"
        }
        return "Runway generation failed: \(failure)"
    }

    private static func httpFailureMessage(_ response: NetworkResponseData, operation: String) -> String {
        let code = statusCode(of: response)
        let data: [String: Any] = switch response {
        case let .dictionary(_, data): data
        case .array, .image: [:]
        }
        let detail = providerError(in: data).map { ": \($0)" } ?? ""
        return "Runway \(operation) request failed with HTTP \(code)\(detail)."
    }

    private static func providerError(in data: [String: Any]) -> String? {
        if let error = data["error"] as? String, !error.isEmpty { return error }
        if let error = data["error"] as? [String: Any] {
            return error["message"] as? String ?? error["detail"] as? String
        }
        if let message = data["message"] as? String, !message.isEmpty { return message }
        return nil
    }

    private static func statusCode(of response: NetworkResponseData) -> Int {
        switch response {
        case let .dictionary(code, _), let .array(code, _), let .image(code, _, _):
            code
        }
    }
}

enum RunwayAdapterError: Error, Equatable, LocalizedError {
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
