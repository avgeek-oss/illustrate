// MARK: - KlingAIClient.swift

import Foundation

enum KlingAIClient {
    static let baseURL = URL(string: "https://api-singapore.klingai.com")!

    enum OutputKind: Equatable {
        case image
        case video
    }

    struct Credentials: Equatable {
        let apiKey: String
        let baseURL: URL
    }

    struct Job: Equatable {
        let id: String
        let statusURL: URL
        let requestId: String?

        var metadata: [String: String] {
            var result = [
                ProviderJobMetadataKey.jobId: id,
                ProviderJobMetadataKey.statusURL: statusURL.absoluteString,
            ]
            if let requestId, !requestId.isEmpty {
                result["klingRequestId"] = requestId
            }
            return result
        }
    }

    static func credentials(from secret: String) throws -> Credentials {
        let apiKey = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty,
              apiKey.utf8.count <= 4096,
              !apiKey.contains(where: { $0.isWhitespace || $0.isNewline }),
              !apiKey.hasPrefix("{")
        else {
            throw KlingAIError.invalidInput(
                "Kling requires one raw API key, not AK/SK or JSON credentials."
            )
        }
        return Credentials(apiKey: apiKey, baseURL: baseURL)
    }

    static func create(
        body: some Codable & Sendable,
        endpoint: String,
        credentials: Credentials,
        network: any NetworkProvider
    ) async throws -> Job {
        let createURL = credentials.baseURL.appendingPathComponent(endpoint)
        let envelope = try await network.performSingleAttemptRequest(
            url: createURL,
            method: "POST",
            body: body,
            headers: headers(apiKey: credentials.apiKey, includesJSONBody: true),
            attachments: nil
        )
        let response = try parsedResponse(from: envelope, operation: "create")
        try validateResponse(response, operation: "create")
        guard case let .dictionary(_, payload) = response,
              let data = payload["data"] as? [String: Any],
              let taskId = data["task_id"] as? String,
              isValidTaskId(taskId),
              let status = data["task_status"] as? String,
              ["submitted", "processing"].contains(status.lowercased())
        else {
            throw KlingAIError.invalidResponse(
                "Kling create response omitted a valid submitted task."
            )
        }

        return Job(
            id: taskId,
            statusURL: createURL.appendingPathComponent(taskId),
            requestId: payload["request_id"] as? String
        )
    }

    static func poll(
        job: Job,
        credentials: Credentials,
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
                    headers: headers(apiKey: credentials.apiKey, includesJSONBody: false),
                    attachments: nil
                )
            },
            classify: classify
        )
    }

    static func classify(_ response: NetworkResponseData) throws -> ProviderAsyncJobState {
        do {
            try validateResponse(response, operation: "status")
        } catch {
            return .failed(error.localizedDescription)
        }
        guard case let .dictionary(_, payload) = response,
              let data = payload["data"] as? [String: Any],
              let status = data["task_status"] as? String
        else {
            return .failed("Kling status response omitted data.task_status.")
        }

        switch status.lowercased() {
        case "submitted", "processing":
            return .pending
        case "succeed":
            return .succeeded
        case "failed":
            let message = data["task_status_msg"] as? String
                ?? payload["message"] as? String
                ?? "Kling generation failed."
            return .failed(message)
        default:
            return .failed("Unknown Kling task status: \(status)")
        }
    }

    static func outputURL(
        from response: NetworkResponseData,
        kind: OutputKind
    ) throws -> URL {
        guard case let .dictionary(_, payload) = response,
              let data = payload["data"] as? [String: Any],
              (data["task_status"] as? String)?.lowercased() == "succeed",
              let result = data["task_result"] as? [String: Any]
        else {
            throw KlingAIError.invalidResponse("Kling task did not contain a successful output.")
        }

        let collectionName = kind == .image ? "images" : "videos"
        guard let outputs = result[collectionName] as? [[String: Any]],
              outputs.count == 1,
              let rawURL = outputs[0]["url"] as? String,
              let url = URL(string: rawURL),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false
        else {
            throw KlingAIError.invalidResponse(
                "Kling succeeded without exactly one valid HTTPS media URL."
            )
        }
        return url
    }

    static func materialize(
        response: NetworkResponseData,
        kind: OutputKind,
        network: any NetworkProvider
    ) async throws -> (base64: String, url: URL) {
        let url = try outputURL(from: response, kind: kind)
        let base64 = try await ProviderMediaMaterializer.base64(from: url, network: network)
        return (base64, url)
    }

    static func imagePrice(omni: Bool, resolution: String) throws -> Double {
        switch (omni, resolution.uppercased()) {
        case (false, "1K"), (false, "2K"), (true, "1K"), (true, "2K"):
            0.028
        case (true, "4K"):
            0.056
        default:
            throw KlingAIError.invalidInput("Kling does not support the requested image resolution.")
        }
    }

    static func videoPricePerSecond(resolution: String, audio: Bool) throws -> Double {
        switch (resolution.uppercased(), audio) {
        case ("720P", false): 0.084
        case ("720P", true): 0.126
        case ("1080P", false): 0.112
        case ("1080P", true): 0.168
        case ("4K", _): 0.42
        default:
            throw KlingAIError.invalidInput("Kling video resolution must be 720p, 1080p, or 4K.")
        }
    }

    static func normalizedImageInput(_ input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw KlingAIError.invalidInput("Kling image input is empty.")
        }
        if value.lowercased().hasPrefix("https://") {
            guard value.utf8.count <= 4096,
                  let components = URLComponents(string: value),
                  components.scheme?.lowercased() == "https",
                  components.user == nil,
                  components.password == nil,
                  let host = components.host,
                  host.contains("."),
                  !host.contains(":")
            else {
                throw KlingAIError.invalidInput(
                    "Kling image URLs must use HTTPS with a public domain."
                )
            }
            return value
        }

        let base64: String
        if value.lowercased().hasPrefix("data:") {
            guard value.utf8.count <= 27_000_000,
                  let comma = value.firstIndex(of: ",")
            else {
                throw KlingAIError.invalidInput("Kling image data is malformed or too large.")
            }
            let header = String(value[..<comma]).lowercased()
            let supported = [
                "data:image/jpeg;base64",
                "data:image/jpg;base64",
                "data:image/png;base64",
                "data:image/webp;base64",
            ]
            guard supported.contains(header) else {
                throw KlingAIError.invalidInput(
                    "Kling image data must be base64 JPEG, PNG, or WebP."
                )
            }
            base64 = String(value[value.index(after: comma)...])
        } else {
            guard value.utf8.count <= 27_000_000 else {
                throw KlingAIError.invalidInput("Kling image data is too large.")
            }
            base64 = value
        }
        guard !base64.isEmpty, Data(base64Encoded: base64) != nil else {
            throw KlingAIError.invalidInput("Kling image input must be HTTPS or valid base64 data.")
        }
        return base64
    }

    static func headers(apiKey: String, includesJSONBody: Bool) -> [String: String] {
        var result = [
            "Authorization": "Bearer \(apiKey)",
            "Accept": "application/json",
        ]
        if includesJSONBody {
            result["Content-Type"] = "application/json"
        }
        return result
    }

    private static func parsedResponse(
        from envelope: NetworkResponseEnvelope,
        operation: String
    ) throws -> NetworkResponseData {
        guard let response = envelope.response else {
            let detail = envelope.bodyString?.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = detail.map { ": \($0)" } ?? ""
            throw KlingAIError.provider(
                "Kling \(operation) request failed with HTTP \(envelope.statusCode)\(suffix)."
            )
        }
        return response
    }

    private static func validateResponse(
        _ response: NetworkResponseData,
        operation: String
    ) throws {
        if case let .dictionary(_, payload) = response,
           integer(payload["code"]) == 1303
        {
            throw KlingAIError.provider(
                "Kling concurrency limit reached; retry manually after capacity is available."
            )
        }
        guard (200 ... 299).contains(response.statusCode) else {
            throw KlingAIError.provider(
                "Kling \(operation) request failed with HTTP \(response.statusCode)."
            )
        }
        guard case let .dictionary(_, payload) = response,
              let code = integer(payload["code"])
        else {
            throw KlingAIError.invalidResponse("Kling \(operation) response omitted code.")
        }
        guard code == 0 else {
            let message = payload["message"] as? String ?? "Kling request failed."
            throw KlingAIError.provider("Kling \(operation) failed (\(code)): \(message)")
        }
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func isValidTaskId(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128
            && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}

enum KlingAIError: Error, Equatable, LocalizedError {
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
