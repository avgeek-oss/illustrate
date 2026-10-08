// MARK: - AlibabaModelStudioClient.swift

import Foundation

enum AlibabaModelStudioClient {
    static let defaultPollingPolicy = ProviderPollingPolicy(
        maxAttempts: 40,
        intervalNanoseconds: 15_000_000_000
    )

    enum Region: String, Equatable {
        case singapore
        case beijing

        var hostSuffix: String {
            switch self {
            case .singapore:
                "ap-southeast-1.maas.aliyuncs.com"
            case .beijing:
                "cn-beijing.maas.aliyuncs.com"
            }
        }
    }

    enum GenerationKind: Equatable {
        case image
        case video
    }

    struct Credentials: Equatable {
        let apiKey: String
        let workspaceId: String
        let region: Region
        let baseURL: URL
    }

    struct Job: Equatable {
        let id: String
        let statusURL: URL
        let requestId: String?
        let region: Region

        var metadata: [String: String] {
            var result = [
                ProviderJobMetadataKey.jobId: id,
                ProviderJobMetadataKey.statusURL: statusURL.absoluteString,
                "alibabaRegion": region.rawValue,
            ]
            if let requestId, !requestId.isEmpty {
                result["alibabaRequestId"] = requestId
            }
            return result
        }
    }

    static func credentials(from secret: String) throws -> Credentials {
        let configuration = try ProviderCredentialConfiguration(secret: secret)
        let apiKey = try configuration.require("api_key")
        let workspaceId = try validatedWorkspaceId(configuration.require("workspace_id"))
        let regionValue = try configuration.require("region").lowercased()
        guard let region = Region(rawValue: regionValue) else {
            throw AlibabaModelStudioError.invalidInput(
                "Alibaba region must be singapore or beijing."
            )
        }
        guard let baseURL = URL(string: "https://\(workspaceId).\(region.hostSuffix)") else {
            throw AlibabaModelStudioError.invalidInput("Alibaba workspace configuration is invalid.")
        }
        return Credentials(
            apiKey: apiKey,
            workspaceId: workspaceId,
            region: region,
            baseURL: baseURL
        )
    }

    static func create(
        body: some Codable & Sendable,
        path: String,
        credentials: Credentials,
        network: any NetworkProvider
    ) async throws -> Job {
        let createURL = credentials.baseURL.appendingPathComponent(path)
        let envelope = try await network.performSingleAttemptRequest(
            url: createURL,
            method: "POST",
            body: body,
            headers: headers(apiKey: credentials.apiKey, async: true),
            attachments: nil
        )
        let response = try parsedResponse(from: envelope, operation: "create")
        try validateSuccessfulHTTP(response, operation: "create")
        try validateNoBodyError(response)

        guard case let .dictionary(_, data) = response,
              let output = data["output"] as? [String: Any],
              let taskId = output["task_id"] as? String,
              isValidTaskId(taskId),
              let status = output["task_status"] as? String,
              ["PENDING", "RUNNING"].contains(status.uppercased())
        else {
            throw AlibabaModelStudioError.invalidResponse(
                "Alibaba create response omitted a valid pending task."
            )
        }

        return Job(
            id: taskId,
            statusURL: credentials.baseURL
                .appendingPathComponent("api/v1/tasks")
                .appendingPathComponent(taskId),
            requestId: data["request_id"] as? String,
            region: credentials.region
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
                    headers: headers(apiKey: credentials.apiKey, async: false),
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
        if let bodyError = bodyError(from: response) {
            return .failed(bodyError)
        }
        guard case let .dictionary(_, data) = response,
              let output = data["output"] as? [String: Any],
              let status = output["task_status"] as? String
        else {
            return .failed("Alibaba status response omitted output.task_status.")
        }

        switch status.uppercased() {
        case "PENDING", "RUNNING":
            return .pending
        case "SUCCEEDED":
            return .succeeded
        case "FAILED":
            return .failed(taskFailureMessage(output))
        case "CANCELED":
            return .cancelled
        case "UNKNOWN":
            return .failed("Alibaba task is unknown or its 24-hour query window expired.")
        default:
            return .failed("Unknown Alibaba task status: \(status)")
        }
    }

    static func outputURL(
        from response: NetworkResponseData,
        kind: GenerationKind
    ) throws -> URL {
        guard case let .dictionary(statusCode, data) = response,
              (200 ... 299).contains(statusCode),
              let output = data["output"] as? [String: Any],
              (output["task_status"] as? String)?.uppercased() == "SUCCEEDED"
        else {
            throw AlibabaModelStudioError.invalidResponse(
                "Alibaba task did not contain a successful output."
            )
        }

        let rawURL: String?
        switch kind {
        case .video:
            rawURL = output["video_url"] as? String
        case .image:
            rawURL = imageURL(from: output)
        }
        guard let rawURL,
              let url = URL(string: rawURL),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false
        else {
            throw AlibabaModelStudioError.invalidResponse(
                "Alibaba succeeded without a valid HTTPS media URL."
            )
        }
        return url
    }

    static func materialize(
        response: NetworkResponseData,
        kind: GenerationKind,
        network: any NetworkProvider
    ) async throws -> (base64: String, url: URL) {
        let url = try outputURL(from: response, kind: kind)
        let base64 = try await ProviderMediaMaterializer.base64(from: url, network: network)
        return (base64, url)
    }

    static func actualSize(from response: NetworkResponseData) -> String? {
        guard case let .dictionary(_, data) = response,
              let usage = data["usage"] as? [String: Any]
        else { return nil }
        if let size = usage["size"] as? String, !size.isEmpty { return size }
        if let width = usage["width"] as? Int, let height = usage["height"] as? Int {
            return "\(width)x\(height)"
        }
        return nil
    }

    static func validatedImageInput(_ input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw AlibabaModelStudioError.invalidInput("Alibaba image input is empty.")
        }
        if value.lowercased().hasPrefix("https://") {
            return try validatedHTTPSURL(value, mediaName: "image")
        }
        if value.lowercased().hasPrefix("data:") {
            try validateImageDataURI(value)
            return value
        }
        guard Data(base64Encoded: value) != nil else {
            throw AlibabaModelStudioError.invalidInput(
                "Alibaba image input must be HTTPS or valid base64 data."
            )
        }
        let dataURI = "data:image/png;base64,\(value)"
        try validateImageDataURI(dataURI)
        return dataURI
    }

    static func validatedVideoURL(_ input: String) throws -> String {
        try validatedHTTPSURL(input, mediaName: "video")
    }

    static func headers(apiKey: String, async: Bool) -> [String: String] {
        var result = [
            "Authorization": "Bearer \(apiKey)",
            "Accept": "application/json",
        ]
        if async {
            result["Content-Type"] = "application/json"
            result["X-DashScope-Async"] = "enable"
        }
        return result
    }

    static func pricePerImage(modelCode: EnumProviderModelCode, region: Region) -> Double {
        switch (modelCode, region) {
        case (.ALIBABA_WAN_2_7_IMAGE_PRO, .singapore): 0.075
        case (.ALIBABA_WAN_2_7_IMAGE_PRO, .beijing): 0.068761
        case (.ALIBABA_WAN_2_7_IMAGE, .singapore): 0.03
        case (.ALIBABA_WAN_2_7_IMAGE, .beijing): 0.028671
        default: 0
        }
    }

    static func pricePerVideoSecond(resolution: String, region: Region) -> Double {
        let is1080 = resolution.uppercased() == "1080P"
        return switch (region, is1080) {
        case (.singapore, false): 0.10
        case (.singapore, true): 0.15
        case (.beijing, false): 0.086012
        case (.beijing, true): 0.143353
        }
    }

    private static func parsedResponse(
        from envelope: NetworkResponseEnvelope,
        operation: String
    ) throws -> NetworkResponseData {
        guard let response = envelope.response else {
            let detail = envelope.bodyString?.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = detail.map { ": \($0)" } ?? ""
            throw AlibabaModelStudioError.provider(
                "Alibaba \(operation) request failed with HTTP \(envelope.statusCode)\(suffix)."
            )
        }
        return response
    }

    private static func validateSuccessfulHTTP(
        _ response: NetworkResponseData,
        operation: String
    ) throws {
        guard (200 ... 299).contains(response.statusCode) else {
            throw AlibabaModelStudioError.provider(httpFailureMessage(response, operation: operation))
        }
    }

    private static func validateNoBodyError(_ response: NetworkResponseData) throws {
        if let error = bodyError(from: response) {
            throw AlibabaModelStudioError.provider(error)
        }
    }

    private static func bodyError(from response: NetworkResponseData) -> String? {
        guard case let .dictionary(_, data) = response else { return nil }
        if let code = data["code"] as? String, !code.isEmpty {
            let message = data["message"] as? String ?? "Alibaba request failed."
            return "Alibaba request failed (\(code)): \(message)"
        }
        return nil
    }

    private static func taskFailureMessage(_ output: [String: Any]) -> String {
        let message = output["message"] as? String ?? "Alibaba generation failed."
        if let code = output["code"] as? String, !code.isEmpty {
            return "Alibaba generation failed (\(code)): \(message)"
        }
        return "Alibaba generation failed: \(message)"
    }

    private static func imageURL(from output: [String: Any]) -> String? {
        guard let choices = output["choices"] as? [[String: Any]] else { return nil }
        for choice in choices {
            guard let message = choice["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]]
            else { continue }
            if let value = content.first(where: { $0["type"] as? String == "image" })?["image"] as? String {
                return value
            }
        }
        return nil
    }

    private static func validatedWorkspaceId(_ input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.utf8.count <= 63,
              value.first != "-",
              value.last != "-",
              value.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" })
        else {
            throw AlibabaModelStudioError.invalidInput(
                "Alibaba workspace ID must be one DNS-safe host label."
            )
        }
        return value
    }

    private static func validatedHTTPSURL(_ input: String, mediaName: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.utf8.count <= 4096,
              let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              components.user == nil,
              components.password == nil,
              let host = components.host,
              host.contains("."),
              !host.contains(":")
        else {
            throw AlibabaModelStudioError.invalidInput(
                "Alibaba \(mediaName) URLs must use HTTPS with a public domain."
            )
        }
        return value
    }

    private static func validateImageDataURI(_ input: String) throws {
        guard input.utf8.count <= 27_000_000,
              let comma = input.firstIndex(of: ",")
        else {
            throw AlibabaModelStudioError.invalidInput("Alibaba image data URI is malformed or too large.")
        }
        let header = input[..<comma].lowercased()
        let supported = [
            "data:image/jpeg;base64",
            "data:image/jpg;base64",
            "data:image/png;base64",
            "data:image/bmp;base64",
            "data:image/webp;base64",
        ]
        guard supported.contains(String(header)),
              Data(base64Encoded: String(input[input.index(after: comma)...])) != nil
        else {
            throw AlibabaModelStudioError.invalidInput(
                "Alibaba image data must be base64 JPEG, PNG, BMP, or WebP."
            )
        }
    }

    private static func isValidTaskId(_ id: String) -> Bool {
        !id.isEmpty && id.utf8.count <= 128
            && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    private static func httpFailureMessage(
        _ response: NetworkResponseData,
        operation: String
    ) -> String {
        let data: [String: Any] = switch response {
        case let .dictionary(_, data): data
        case .array, .image: [:]
        }
        let detail = (data["message"] as? String).map { ": \($0)" } ?? ""
        return "Alibaba \(operation) request failed with HTTP \(response.statusCode)\(detail)."
    }
}

enum AlibabaModelStudioError: Error, Equatable, LocalizedError {
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
