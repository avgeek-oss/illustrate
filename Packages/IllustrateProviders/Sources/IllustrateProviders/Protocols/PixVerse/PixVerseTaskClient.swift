// MARK: - PixVerseTaskClient.swift

import Foundation

enum PixVerseTaskClient {
    static let baseURL = URL(string: "https://app-api.pixverse.ai/openapi/v2")!
    static let defaultPollingPolicy = ProviderPollingPolicy(
        maxAttempts: 120,
        intervalNanoseconds: 5_000_000_000
    )

    struct Job: Equatable {
        let id: String
        let traceId: UUID
        let statusURL: URL

        var metadata: [String: String] {
            [
                ProviderJobMetadataKey.jobId: id,
                ProviderJobMetadataKey.statusURL: statusURL.absoluteString,
                "pixVerseTraceId": traceId.uuidString.lowercased(),
            ]
        }
    }

    static func headers(
        apiKey: String,
        traceId: UUID,
        includesJSONBody: Bool = true
    ) -> [String: String] {
        var headers = [
            "API-KEY": apiKey,
            "Ai-trace-id": traceId.uuidString.lowercased(),
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
        traceId: UUID = UUID(),
        network: any NetworkProvider
    ) async throws -> Job {
        let envelope = try await network.performSingleAttemptRequest(
            url: url,
            method: "POST",
            body: body,
            headers: headers(apiKey: apiKey, traceId: traceId),
            attachments: nil
        )
        let response = try envelope.requireParsedResponse()
        guard (200 ... 299).contains(response.statusCode) else {
            throw PixVerseAdapterError.provider(httpFailureMessage(response, operation: "create"))
        }
        guard case let .dictionary(_, data) = response else {
            throw PixVerseAdapterError.invalidResponse("PixVerse create response was not a JSON object.")
        }
        try requireSuccessEnvelope(data, operation: "create")
        guard let payload = data["Resp"] as? [String: Any],
              let id = videoId(from: payload["video_id"]),
              isValidVideoID(id)
        else {
            throw PixVerseAdapterError.invalidResponse("PixVerse create response omitted a valid Resp.video_id.")
        }
        return Job(
            id: id,
            traceId: traceId,
            statusURL: baseURL
                .appendingPathComponent("video")
                .appendingPathComponent("result")
                .appendingPathComponent(id)
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
                    headers: headers(apiKey: apiKey, traceId: UUID(), includesJSONBody: false),
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
        guard case let .dictionary(_, data) = response else {
            return .failed("PixVerse status response was not a JSON object.")
        }
        do {
            try requireSuccessEnvelope(data, operation: "status")
        } catch {
            return .failed(error.localizedDescription)
        }
        guard let payload = data["Resp"] as? [String: Any],
              let status = payload["status"] as? Int
        else {
            return .failed("PixVerse status response omitted Resp.status.")
        }
        switch status {
        case 5:
            return .pending
        case 1:
            return .succeeded
        case 7:
            return .failed("PixVerse content moderation failed.")
        case 8:
            return .failed("PixVerse generation failed.")
        default:
            return .failed("Unknown PixVerse video status: \(status)")
        }
    }

    static func materialize(
        response: NetworkResponseData,
        network: any NetworkProvider
    ) async throws -> (base64: String, outputURL: URL) {
        guard case let .dictionary(code, data) = response,
              (200 ... 299).contains(code)
        else {
            throw PixVerseAdapterError.invalidResponse("PixVerse result was not a successful JSON object.")
        }
        try requireSuccessEnvelope(data, operation: "status")
        guard let payload = data["Resp"] as? [String: Any],
              payload["status"] as? Int == 1,
              let output = payload["url"] as? String,
              let outputURL = URL(string: output),
              outputURL.scheme?.lowercased() == "https",
              outputURL.host?.isEmpty == false
        else {
            throw PixVerseAdapterError.invalidResponse("PixVerse succeeded without a valid HTTPS result URL.")
        }
        let base64 = try await ProviderMediaMaterializer.base64(from: outputURL, network: network)
        return (base64, outputURL)
    }

    static func validatedPrompt(_ prompt: String) throws -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PixVerseAdapterError.invalidInput("PixVerse requires a non-empty prompt.")
        }
        guard trimmed.count <= 5000 else {
            throw PixVerseAdapterError.invalidInput("PixVerse prompts cannot exceed 5000 characters.")
        }
        return trimmed
    }

    static func validatedSeed(_ seed: Int?) throws -> Int? {
        guard let seed else { return nil }
        guard (0 ... 2_147_483_647).contains(seed) else {
            throw PixVerseAdapterError.invalidInput("PixVerse seed must be between 0 and 2147483647.")
        }
        return seed
    }

    private static func requireSuccessEnvelope(_ data: [String: Any], operation: String) throws {
        let code = data["ErrCode"] as? Int
        guard code == 0 else {
            let message = data["ErrMsg"] as? String ?? "Unknown provider error"
            throw PixVerseAdapterError.provider("PixVerse \(operation) failed (\(code ?? -1)): \(message).")
        }
    }

    private static func videoId(from value: Any?) -> String? {
        if let value = value as? Int { return String(value) }
        if let value = value as? String { return value }
        return nil
    }

    private static func isValidVideoID(_ id: String) -> Bool {
        !id.isEmpty && id.utf8.count <= 32 && id.allSatisfy(\.isNumber)
    }

    private static func httpFailureMessage(_ response: NetworkResponseData, operation: String) -> String {
        let detail: String? = if case let .dictionary(_, data) = response {
            data["ErrMsg"] as? String
        } else {
            nil
        }
        return "PixVerse \(operation) request failed with HTTP \(response.statusCode)\(detail.map { ": \($0)" } ?? "")."
    }
}

enum PixVerseAdapterError: Error, Equatable, LocalizedError {
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
