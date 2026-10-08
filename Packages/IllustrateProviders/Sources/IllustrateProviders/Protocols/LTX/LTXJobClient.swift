// MARK: - LTXJobClient.swift

import Foundation

enum LTXJobClient {
    static let baseURL = URL(string: "https://api.ltx.video/v2")!
    static let maxImageDataURIBytes = 7_000_000
    static let defaultPollingPolicy = ProviderPollingPolicy(
        maxAttempts: 120,
        intervalNanoseconds: 5_000_000_000
    )

    enum EndpointFamily: String, Equatable {
        case textToVideo = "text-to-video"
        case imageToVideo = "image-to-video"
    }

    struct Job: Equatable {
        let id: String
        let createdAt: String
        let endpoint: EndpointFamily
        let statusURL: URL

        var metadata: [String: String] {
            [
                ProviderJobMetadataKey.jobId: id,
                ProviderJobMetadataKey.statusURL: statusURL.absoluteString,
                "ltxEndpointFamily": endpoint.rawValue,
                "ltxCreatedAt": createdAt,
            ]
        }
    }

    static func headers(apiKey: String, includesJSONBody: Bool = true) -> [String: String] {
        var headers = [
            "Authorization": "Bearer \(apiKey)",
            "Accept": "application/json",
        ]
        if includesJSONBody {
            headers["Content-Type"] = "application/json"
        }
        return headers
    }

    static func create(
        endpoint: EndpointFamily,
        body: some Codable & Sendable,
        apiKey: String,
        network: any NetworkProvider
    ) async throws -> Job {
        let createURL = baseURL.appendingPathComponent(endpoint.rawValue)
        let envelope = try await network.performSingleAttemptRequest(
            url: createURL,
            method: "POST",
            body: body,
            headers: headers(apiKey: apiKey),
            attachments: nil
        )
        let response = try envelope.requireParsedResponse()

        guard statusCode(of: response) == 202 else {
            throw LTXAdapterError.provider(httpFailureMessage(response, operation: "create"))
        }
        guard case let .dictionary(_, data) = response,
              let id = data["id"] as? String,
              isValidJobID(id),
              let createdAt = data["created_at"] as? String,
              !createdAt.isEmpty
        else {
            throw LTXAdapterError.invalidResponse(
                "LTX create response omitted a valid id or created_at timestamp."
            )
        }

        return Job(
            id: id,
            createdAt: createdAt,
            endpoint: endpoint,
            statusURL: baseURL
                .appendingPathComponent(endpoint.rawValue)
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
                    headers: headers(apiKey: apiKey, includesJSONBody: false),
                    attachments: nil
                )
            },
            classify: classify
        )
    }

    static func classify(_ response: NetworkResponseData) throws -> ProviderAsyncJobState {
        guard statusCode(of: response) == 200 else {
            return .failed(httpFailureMessage(response, operation: "status"))
        }
        guard case let .dictionary(_, data) = response,
              let status = data["status"] as? String
        else {
            return .failed("LTX status response omitted status.")
        }

        switch status.lowercased() {
        case "pending", "processing":
            return .pending
        case "completed":
            return .succeeded
        case "failed":
            return .failed(failureMessage(from: data))
        default:
            return .failed("Unknown LTX job status: \(status)")
        }
    }

    static func materialize(
        response: NetworkResponseData,
        network: any NetworkProvider
    ) async throws -> (base64: String, outputURL: URL) {
        let outputURL = try completedVideoURL(from: response)
        let base64 = try await ProviderMediaMaterializer.base64(
            from: outputURL,
            network: network
        )
        return (base64, outputURL)
    }

    static func completedVideoURL(from response: NetworkResponseData) throws -> URL {
        guard case let .dictionary(code, data) = response,
              code == 200,
              (data["status"] as? String)?.lowercased() == "completed",
              let result = data["result"] as? [String: Any],
              let output = result["video_url"] as? String,
              let outputURL = URL(string: output),
              outputURL.scheme?.lowercased() == "https",
              outputURL.host?.isEmpty == false
        else {
            throw LTXAdapterError.invalidResponse(
                "LTX completed without a valid HTTPS result.video_url."
            )
        }
        return outputURL
    }

    static func validatedImageURI(_ input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LTXAdapterError.invalidInput("LTX image input is empty.")
        }

        if trimmed.lowercased().hasPrefix("https://") {
            return try validatedHTTPSURL(trimmed)
        }
        if trimmed.lowercased().hasPrefix("ltx://") {
            return try validatedUploadURI(trimmed)
        }
        if trimmed.lowercased().hasPrefix("data:") {
            try validateImageDataURI(trimmed)
            return trimmed
        }

        guard Data(base64Encoded: trimmed) != nil else {
            throw LTXAdapterError.invalidInput(
                "LTX image input must be an LTX upload URI, HTTPS domain URL, or base64 image data URI."
            )
        }
        let dataURI = "data:image/png;base64,\(trimmed)"
        try validateImageDataURI(dataURI)
        return dataURI
    }

    private static func validatedHTTPSURL(_ input: String) throws -> String {
        guard let components = URLComponents(string: input),
              components.scheme?.lowercased() == "https",
              components.user == nil,
              components.password == nil,
              let host = components.host?.lowercased(),
              isDomainName(host)
        else {
            throw LTXAdapterError.invalidInput(
                "LTX image URLs must use HTTPS with a public domain name, not an IP address."
            )
        }
        return input
    }

    private static func validatedUploadURI(_ input: String) throws -> String {
        guard input.utf8.count <= 2048,
              let components = URLComponents(string: input),
              components.scheme?.lowercased() == "ltx",
              components.host?.lowercased() == "uploads",
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil
        else {
            throw LTXAdapterError.invalidInput("LTX upload URI is malformed.")
        }

        let identifier = components.path.drop(while: { $0 == "/" })
        guard !identifier.isEmpty,
              !identifier.contains("/"),
              identifier.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        else {
            throw LTXAdapterError.invalidInput("LTX upload URI is malformed.")
        }
        return input
    }

    private static func isDomainName(_ host: String) -> Bool {
        guard host.contains("."), !host.contains(":"), host.utf8.count <= 253 else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              labels.allSatisfy({ label in
                  !label.isEmpty
                      && label.utf8.count <= 63
                      && label.first != "-"
                      && label.last != "-"
                      && label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
              }),
              labels.last?.contains(where: \.isLetter) == true
        else {
            return false
        }
        return true
    }

    private static func validateImageDataURI(_ dataURI: String) throws {
        guard dataURI.utf8.count <= maxImageDataURIBytes else {
            throw LTXAdapterError.invalidInput("LTX image data URIs cannot exceed 7 MB.")
        }
        guard let comma = dataURI.firstIndex(of: ",") else {
            throw LTXAdapterError.invalidInput("LTX image data URI is malformed.")
        }

        let header = String(dataURI[..<comma]).lowercased()
        let supportedHeaders = [
            "data:image/jpeg;base64",
            "data:image/png;base64",
            "data:image/webp;base64",
        ]
        guard supportedHeaders.contains(header) else {
            throw LTXAdapterError.invalidInput(
                "LTX image data URIs must be base64-encoded JPEG, PNG, or WebP."
            )
        }

        let encoded = String(dataURI[dataURI.index(after: comma)...])
        guard !encoded.isEmpty, Data(base64Encoded: encoded) != nil else {
            throw LTXAdapterError.invalidInput("LTX image data URI contains invalid base64.")
        }
    }

    private static func isValidJobID(_ id: String) -> Bool {
        !id.isEmpty
            && id.utf8.count <= 256
            && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    private static func failureMessage(from data: [String: Any]) -> String {
        guard let error = data["error"] as? [String: Any] else {
            return "LTX generation failed."
        }
        let message = error["message"] as? String ?? "LTX generation failed."
        if let type = error["type"] as? String, !type.isEmpty {
            return "LTX generation failed (\(type)): \(message)"
        }
        return "LTX generation failed: \(message)"
    }

    private static func httpFailureMessage(_ response: NetworkResponseData, operation: String) -> String {
        let code = statusCode(of: response)
        let data: [String: Any] = switch response {
        case let .dictionary(_, data): data
        case .array, .image: [:]
        }
        let detail = providerError(in: data).map { ": \($0)" } ?? ""
        return "LTX \(operation) request failed with HTTP \(code)\(detail)."
    }

    private static func providerError(in data: [String: Any]) -> String? {
        if let error = data["error"] as? [String: Any] {
            return error["message"] as? String
        }
        if let error = data["error"] as? [String: String] {
            return error["message"]
        }
        return data["message"] as? String
    }

    private static func statusCode(of response: NetworkResponseData) -> Int {
        switch response {
        case let .dictionary(code, _), let .array(code, _), let .image(code, _, _):
            code
        }
    }
}

enum LTXAdapterError: Error, Equatable, LocalizedError {
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
