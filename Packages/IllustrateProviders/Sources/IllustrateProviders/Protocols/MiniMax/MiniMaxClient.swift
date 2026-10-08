// MARK: - MiniMaxClient.swift

import Foundation

enum MiniMaxClient {
    enum Region: String, Equatable {
        case global
        case mainland

        var baseURL: URL {
            switch self {
            case .global:
                URL(string: "https://api.minimax.io")!
            case .mainland:
                URL(string: "https://api.minimaxi.com")!
            }
        }
    }

    enum VideoMode: Equatable {
        case standard
        case fast
    }

    struct Credentials: Equatable {
        let apiKey: String
        let region: Region
        let baseURL: URL
    }

    struct Job: Equatable {
        let id: String
        let statusURL: URL
        let region: Region

        var metadata: [String: String] {
            [
                ProviderJobMetadataKey.jobId: id,
                ProviderJobMetadataKey.statusURL: statusURL.absoluteString,
                "minimaxRegion": region.rawValue,
            ]
        }
    }

    static func credentials(from secret: String) throws -> Credentials {
        let configuration = try ProviderCredentialConfiguration(secret: secret)
        let apiKey = try configuration.require("api_key")
        let regionValue = try configuration.require("region").lowercased()
        guard let region = Region(rawValue: regionValue) else {
            throw MiniMaxError.invalidInput("MiniMax region must be global or mainland.")
        }
        return Credentials(apiKey: apiKey, region: region, baseURL: region.baseURL)
    }

    static func performCreate(
        body: some Codable & Sendable,
        path: String,
        credentials: Credentials,
        network: any NetworkProvider
    ) async throws -> NetworkResponseData {
        let envelope = try await network.performSingleAttemptRequest(
            url: credentials.baseURL.appendingPathComponent(path),
            method: "POST",
            body: body,
            headers: headers(apiKey: credentials.apiKey, includesJSONBody: true),
            attachments: nil
        )
        let response = try parsedResponse(from: envelope, operation: "create")
        try validateResponse(response, operation: "create")
        return response
    }

    static func videoJob(
        from response: NetworkResponseData,
        credentials: Credentials
    ) throws -> Job {
        guard case let .dictionary(_, data) = response,
              let taskId = identifier(data["task_id"]),
              isValidIdentifier(taskId),
              let statusURL = queryURL(
                  baseURL: credentials.baseURL,
                  path: "v1/query/video_generation",
                  name: "task_id",
                  value: taskId
              )
        else {
            throw MiniMaxError.invalidResponse("MiniMax create response omitted a valid task_id.")
        }
        return Job(id: taskId, statusURL: statusURL, region: credentials.region)
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
        guard case let .dictionary(_, data) = response,
              let status = data["status"] as? String
        else {
            return .failed("MiniMax status response omitted status.")
        }

        switch status.lowercased() {
        case "preparing", "queueing", "processing":
            return .pending
        case "success":
            return .succeeded
        case "fail":
            let message = data["error_message"] as? String
                ?? data["message"] as? String
                ?? "MiniMax generation failed."
            return .failed(message)
        default:
            return .failed("Unknown MiniMax task status: \(status)")
        }
    }

    static func retrieveOutputURL(
        from finalResponse: NetworkResponseData,
        credentials: Credentials,
        network: any NetworkProvider
    ) async throws -> URL {
        guard case let .dictionary(_, data) = finalResponse,
              (data["status"] as? String)?.lowercased() == "success",
              let fileId = identifier(data["file_id"]),
              isValidIdentifier(fileId),
              let url = queryURL(
                  baseURL: credentials.baseURL,
                  path: "v1/files/retrieve",
                  name: "file_id",
                  value: fileId
              )
        else {
            throw MiniMaxError.invalidResponse("MiniMax succeeded without a valid file_id.")
        }

        let response = try await network.performRequest(
            url: url,
            method: "GET",
            body: nil as String?,
            headers: headers(apiKey: credentials.apiKey, includesJSONBody: false),
            attachments: nil
        )
        try validateResponse(response, operation: "file retrieval")
        guard case let .dictionary(_, retrieveData) = response,
              let file = retrieveData["file"] as? [String: Any],
              let rawURL = file["download_url"] as? String,
              let outputURL = URL(string: rawURL),
              outputURL.scheme?.lowercased() == "https",
              outputURL.host?.isEmpty == false
        else {
            throw MiniMaxError.invalidResponse(
                "MiniMax file response omitted a valid HTTPS download_url."
            )
        }
        return outputURL
    }

    static func materialize(
        from outputURL: URL,
        network: any NetworkProvider
    ) async throws -> String {
        try await ProviderMediaMaterializer.base64(from: outputURL, network: network)
    }

    static func imageBase64(from response: NetworkResponseData) throws -> String {
        guard case let .dictionary(_, data) = response,
              let result = data["data"] as? [String: Any],
              let images = result["image_base64"] as? [String],
              images.count == 1
        else {
            throw MiniMaxError.invalidResponse(
                "MiniMax image response must contain exactly one data.image_base64 value."
            )
        }
        let value = images[0]
        let rawBase64: String
        if value.lowercased().hasPrefix("data:") {
            guard let comma = value.firstIndex(of: ",") else {
                throw MiniMaxError.invalidResponse("MiniMax returned malformed image data.")
            }
            rawBase64 = String(value[value.index(after: comma)...])
        } else {
            rawBase64 = value
        }
        guard !rawBase64.isEmpty, Data(base64Encoded: rawBase64) != nil else {
            throw MiniMaxError.invalidResponse("MiniMax returned invalid base64 image data.")
        }
        return rawBase64
    }

    static func price(
        mode: VideoMode,
        resolution: String,
        duration: Int
    ) throws -> Double {
        let resolution = resolution.uppercased()
        return switch (mode, resolution, duration) {
        case (.standard, "768P", 6): 0.28
        case (.standard, "768P", 10): 0.56
        case (.standard, "1080P", 6): 0.49
        case (.fast, "768P", 6): 0.19
        case (.fast, "768P", 10): 0.32
        case (.fast, "1080P", 6): 0.33
        default:
            throw MiniMaxError.invalidInput(
                "MiniMax supports 768P for 6 or 10 seconds and 1080P for 6 seconds."
            )
        }
    }

    static func validatedImageInput(_ input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw MiniMaxError.invalidInput("MiniMax first frame is empty.")
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
                throw MiniMaxError.invalidInput(
                    "MiniMax first-frame URLs must use HTTPS with a public domain."
                )
            }
            return value
        }

        let dataURI = value.lowercased().hasPrefix("data:")
            ? value
            : "data:image/png;base64,\(value)"
        guard dataURI.utf8.count <= 27_000_000,
              let comma = dataURI.firstIndex(of: ",")
        else {
            throw MiniMaxError.invalidInput("MiniMax first-frame data is malformed or too large.")
        }
        let header = String(dataURI[..<comma]).lowercased()
        let supported = [
            "data:image/jpeg;base64",
            "data:image/jpg;base64",
            "data:image/png;base64",
            "data:image/webp;base64",
        ]
        guard supported.contains(header),
              Data(base64Encoded: String(dataURI[dataURI.index(after: comma)...])) != nil
        else {
            throw MiniMaxError.invalidInput(
                "MiniMax first frame must be base64 JPEG, PNG, or WebP."
            )
        }
        return dataURI
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
            throw MiniMaxError.provider(
                "MiniMax \(operation) request failed with HTTP \(envelope.statusCode)\(suffix)."
            )
        }
        return response
    }

    private static func validateResponse(
        _ response: NetworkResponseData,
        operation: String
    ) throws {
        guard (200 ... 299).contains(response.statusCode) else {
            throw MiniMaxError.provider(
                "MiniMax \(operation) request failed with HTTP \(response.statusCode)."
            )
        }
        guard case let .dictionary(_, data) = response,
              let baseResponse = data["base_resp"] as? [String: Any],
              let statusCode = integer(baseResponse["status_code"])
        else {
            throw MiniMaxError.invalidResponse(
                "MiniMax \(operation) response omitted base_resp.status_code."
            )
        }
        guard statusCode == 0 else {
            let message = baseResponse["status_msg"] as? String ?? "MiniMax request failed."
            throw MiniMaxError.provider(
                "MiniMax \(operation) failed (\(statusCode)): \(message)"
            )
        }
    }

    private static func queryURL(
        baseURL: URL,
        path: String,
        name: String,
        value: String
    ) -> URL? {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: name, value: value)]
        return components?.url
    }

    private static func identifier(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128
            && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}

enum MiniMaxError: Error, Equatable, LocalizedError {
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
