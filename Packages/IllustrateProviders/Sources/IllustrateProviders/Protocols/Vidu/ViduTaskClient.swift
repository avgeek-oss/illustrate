// MARK: - ViduTaskClient.swift

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum ViduTaskClient {
    static let baseURL = URL(string: "https://api.vidu.com/ent/v2")!
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
            "Authorization": "Token \(apiKey)",
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
        guard (200 ... 299).contains(response.statusCode) else {
            throw ViduAdapterError.provider(httpFailureMessage(response, operation: "create"))
        }
        guard case let .dictionary(_, data) = response,
              let id = data["task_id"] as? String,
              isValidTaskID(id)
        else {
            throw ViduAdapterError.invalidResponse("Vidu create response omitted a valid task_id.")
        }

        let taskURL = baseURL.appendingPathComponent("tasks").appendingPathComponent(id)
        return Job(
            id: id,
            statusURL: taskURL.appendingPathComponent("creations"),
            cancelURL: taskURL.appendingPathComponent("cancel")
        )
    }

    static func poll(
        job: Job,
        apiKey: String,
        network: any NetworkProvider,
        policy: ProviderPollingPolicy
    ) async throws -> NetworkResponseData {
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
    }

    static func classify(_ response: NetworkResponseData) throws -> ProviderAsyncJobState {
        guard (200 ... 299).contains(response.statusCode) else {
            return .failed(httpFailureMessage(response, operation: "status"))
        }
        guard case let .dictionary(_, data) = response,
              let state = data["state"] as? String
        else {
            return .failed("Vidu status response omitted state.")
        }

        switch state.lowercased() {
        case "created", "queueing", "processing":
            return .pending
        case "success":
            return .succeeded
        case "failed":
            let code = data["err_code"] as? String
            let suffix = code.flatMap { $0.isEmpty ? nil : " (\($0))" } ?? ""
            return .failed("Vidu generation failed\(suffix).")
        default:
            return .failed("Unknown Vidu task state: \(state)")
        }
    }

    static func materialize(
        response: NetworkResponseData,
        network: any NetworkProvider
    ) async throws -> (base64: String, outputURL: URL) {
        guard case let .dictionary(code, data) = response,
              (200 ... 299).contains(code),
              (data["state"] as? String)?.lowercased() == "success",
              let creations = data["creations"] as? [[String: Any]],
              let output = creations.first?["url"] as? String,
              let outputURL = URL(string: output),
              outputURL.scheme?.lowercased() == "https",
              outputURL.host?.isEmpty == false
        else {
            throw ViduAdapterError.invalidResponse("Vidu succeeded without a valid HTTPS creation URL.")
        }
        let base64 = try await ProviderMediaMaterializer.base64(from: outputURL, network: network)
        return (base64, outputURL)
    }

    static func cancel(
        jobId: String,
        apiKey: String,
        network: any NetworkProvider
    ) async throws {
        guard isValidTaskID(jobId) else {
            throw ViduAdapterError.invalidInput("Vidu task ID is malformed.")
        }
        let url = baseURL
            .appendingPathComponent("tasks")
            .appendingPathComponent(jobId)
            .appendingPathComponent("cancel")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in headers(apiKey: apiKey) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = Data("{}".utf8)
        let response = try await network.performRawRequest(request)
        guard (200 ... 299).contains(response.statusCode) else {
            throw ViduAdapterError.provider(httpFailureMessage(response, operation: "cancel"))
        }
    }

    static func validatedPrompt(_ prompt: String) throws -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ViduAdapterError.invalidInput("Vidu requires a non-empty prompt.")
        }
        guard trimmed.count <= 5000 else {
            throw ViduAdapterError.invalidInput("Vidu prompts cannot exceed 5000 characters.")
        }
        return trimmed
    }

    static func validatedSeed(_ seed: Int?) throws -> Int? {
        guard let seed else { return nil }
        guard seed >= 0 else {
            throw ViduAdapterError.invalidInput("Vidu seed cannot be negative.")
        }
        return seed
    }

    private static func isValidTaskID(_ id: String) -> Bool {
        !id.isEmpty
            && id.utf8.count <= 256
            && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    private static func httpFailureMessage(_ response: NetworkResponseData, operation: String) -> String {
        let detail: String? = if case let .dictionary(_, data) = response {
            data["message"] as? String ?? data["reason"] as? String
        } else {
            nil
        }
        return "Vidu \(operation) request failed with HTTP \(response.statusCode)\(detail.map { ": \($0)" } ?? "")."
    }
}

enum ViduAdapterError: Error, Equatable, LocalizedError {
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
