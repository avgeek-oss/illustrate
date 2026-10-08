import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum BytePlusModelArkClient {
    enum Region: String, CaseIterable {
        case asiaPacific = "ap-southeast-1"
        case europe = "eu-west-1"

        var baseURL: URL {
            switch self {
            case .asiaPacific:
                URL(string: "https://ark.ap-southeast.bytepluses.com/api/v3")!
            case .europe:
                URL(string: "https://ark.eu-west.bytepluses.com/api/v3")!
            }
        }
    }

    struct Credentials {
        let apiKey: String
        let region: Region
    }

    struct Job {
        let id: String
        let statusURL: URL

        var metadata: [String: String] {
            [
                ProviderJobMetadataKey.jobId: id,
                ProviderJobMetadataKey.statusURL: statusURL.absoluteString,
                ProviderJobMetadataKey.cancelURL: statusURL.absoluteString,
            ]
        }
    }

    static func credentials(from secret: String) throws -> Credentials {
        let configuration = try ProviderCredentialConfiguration(secret: secret)
        let apiKey = try configuration.require("api_key")
        let rawRegion = try configuration.require("region").lowercased()
        guard let region = Region(rawValue: rawRegion) else {
            throw BytePlusModelArkError.invalidInput(
                "BytePlus ModelArk region must be ap-southeast-1 or eu-west-1."
            )
        }
        return Credentials(apiKey: apiKey, region: region)
    }

    static func validateAvailability(
        modelCode: EnumProviderModelCode,
        region: Region
    ) throws {
        guard region == .asiaPacific || modelCode == .BYTEPLUS_SEEDREAM_5_0_LITE else {
            throw BytePlusModelArkError.invalidInput(
                "This BytePlus ModelArk model is available only in ap-southeast-1."
            )
        }
    }

    static func headers(apiKey: String, includesJSONBody: Bool = true) -> [String: String] {
        var result = [
            "Authorization": "Bearer \(apiKey)",
            "Accept": "application/json",
        ]
        if includesJSONBody {
            result["Content-Type"] = "application/json"
        }
        return result
    }

    static func imageURL(region: Region) -> URL {
        region.baseURL.appendingPathComponent("images/generations")
    }

    static func tasksURL(region: Region) -> URL {
        region.baseURL.appendingPathComponent("contents/generations/tasks")
    }

    static func createVideoJob(
        body: some Codable & Sendable,
        credentials: Credentials,
        network: any NetworkProvider
    ) async throws -> Job {
        let tasksURL = tasksURL(region: credentials.region)
        let envelope = try await network.performSingleAttemptRequest(
            url: tasksURL,
            method: "POST",
            body: body,
            headers: headers(apiKey: credentials.apiKey),
            attachments: nil
        )
        guard (200 ... 299).contains(envelope.statusCode) else {
            throw BytePlusModelArkError.provider(
                httpFailureMessage(envelope: envelope, operation: "video create")
            )
        }
        guard let response = envelope.response,
              case let .dictionary(_, data) = response
        else {
            throw BytePlusModelArkError.invalidResponse(
                "BytePlus video create response could not be decoded."
            )
        }
        try validateNoBodyError(data)
        guard let id = data["id"] as? String, isValidTaskId(id) else {
            throw BytePlusModelArkError.invalidResponse(
                "BytePlus video create response omitted a valid task ID."
            )
        }
        return Job(id: id, statusURL: tasksURL.appendingPathComponent(id))
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
        guard case let .dictionary(statusCode, data) = response else {
            return .failed("BytePlus video status response was not a JSON object.")
        }
        guard (200 ... 299).contains(statusCode) else {
            return .failed(httpFailureMessage(response: response, operation: "video status"))
        }
        if let error = providerError(in: data) {
            return .failed(error)
        }
        guard let status = data["status"] as? String, !status.isEmpty else {
            return .failed("BytePlus video status response omitted status.")
        }
        switch status.lowercased() {
        case "queued", "running":
            return .pending
        case "succeeded":
            return .succeeded
        case "cancelled":
            return .cancelled
        case "failed":
            return .failed(providerError(in: data) ?? "BytePlus video generation failed.")
        case "expired":
            return .failed("BytePlus video task expired before completion.")
        default:
            return .failed("Unknown BytePlus video task status: \(status)")
        }
    }

    static func cancel(
        jobId: String,
        credentials: Credentials,
        network: any NetworkProvider
    ) async throws {
        guard isValidTaskId(jobId) else {
            throw BytePlusModelArkError.invalidInput("BytePlus video task ID is invalid.")
        }
        let url = tasksURL(region: credentials.region).appendingPathComponent(jobId)
        let envelope = try await network.performSingleAttemptRequest(
            url: url,
            method: "DELETE",
            body: nil as String?,
            headers: headers(apiKey: credentials.apiKey, includesJSONBody: false),
            attachments: nil
        )
        guard (200 ... 299).contains(envelope.statusCode) || envelope.statusCode == 404 else {
            throw BytePlusModelArkError.provider(
                httpFailureMessage(envelope: envelope, operation: "video cancel")
            )
        }
    }

    static func validatedImageURI(
        _ input: String,
        mimeType: String = "image/png"
    ) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BytePlusModelArkError.invalidInput("BytePlus image input is empty.")
        }
        if trimmed.lowercased().hasPrefix("https://") {
            guard let components = URLComponents(string: trimmed),
                  components.scheme?.lowercased() == "https",
                  components.user == nil,
                  components.password == nil,
                  components.host?.isEmpty == false
            else {
                throw BytePlusModelArkError.invalidInput("BytePlus image URLs must be valid HTTPS URLs.")
            }
            return trimmed
        }
        if trimmed.lowercased().hasPrefix("data:") {
            guard let comma = trimmed.firstIndex(of: ","),
                  validatedImageMIMEType(in: String(trimmed[..<comma])) != nil,
                  let encoded = normalizedBase64(trimmed)
            else {
                throw BytePlusModelArkError.invalidInput("BytePlus image data URI is invalid.")
            }
            return "\(trimmed[..<comma]),\(encoded)"
        }
        guard let encoded = normalizedBase64(trimmed) else {
            throw BytePlusModelArkError.invalidInput("BytePlus image input is not valid base64.")
        }
        let mime = mimeType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard supportedImageMIMETypes.contains(mime) else {
            throw BytePlusModelArkError.invalidInput("BytePlus image MIME type is unsupported.")
        }
        return "data:\(mime);base64,\(encoded)"
    }

    static func normalizedBase64(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload: String
        if trimmed.lowercased().hasPrefix("data:") {
            guard let comma = trimmed.firstIndex(of: ",") else { return nil }
            payload = String(trimmed[trimmed.index(after: comma)...])
        } else {
            payload = trimmed
        }
        let compact = payload.filter { !$0.isWhitespace }
        guard !compact.isEmpty, Data(base64Encoded: compact) != nil else { return nil }
        return compact
    }

    static func validatedOutputURL(_ raw: String) throws -> URL {
        guard let components = URLComponents(string: raw),
              components.scheme?.lowercased() == "https",
              components.user == nil,
              components.password == nil,
              components.host?.isEmpty == false,
              let url = components.url
        else {
            throw BytePlusModelArkError.invalidResponse(
                "BytePlus returned an invalid media URL."
            )
        }
        return url
    }

    static func providerError(in data: [String: Any]) -> String? {
        guard let error = data["error"] as? [String: Any] else { return nil }
        let code = error["code"] as? String
        let message = error["message"] as? String
        if let code, !code.isEmpty, let message, !message.isEmpty {
            return "\(code): \(message)"
        }
        return message ?? code
    }

    static func validateNoBodyError(_ data: [String: Any]) throws {
        if let error = providerError(in: data) {
            throw BytePlusModelArkError.provider(error)
        }
    }

    static func numericDouble(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    static func httpFailureMessage(
        envelope: NetworkResponseEnvelope,
        operation: String
    ) -> String {
        let parsed = envelope.response.flatMap { response -> [String: Any]? in
            guard case let .dictionary(_, data) = response else { return nil }
            return data
        }
        let detail = parsed.flatMap(providerError)
            ?? envelope.bodyString?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let detail, !detail.isEmpty {
            return "BytePlus \(operation) failed with HTTP \(envelope.statusCode): \(detail)"
        }
        return "BytePlus \(operation) failed with HTTP \(envelope.statusCode)."
    }

    static func httpFailureMessage(
        response: NetworkResponseData,
        operation: String
    ) -> String {
        let detail: String? = if case let .dictionary(_, data) = response {
            providerError(in: data)
        } else {
            nil
        }
        if let detail {
            return "BytePlus \(operation) failed with HTTP \(response.statusCode): \(detail)"
        }
        return "BytePlus \(operation) failed with HTTP \(response.statusCode)."
    }

    private static func isValidTaskId(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 160 else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func validatedImageMIMEType(in dataURIHeader: String) -> String? {
        let header = dataURIHeader.lowercased()
        guard header.hasPrefix("data:"), header.hasSuffix(";base64") else { return nil }
        let start = header.index(header.startIndex, offsetBy: 5)
        let end = header.index(header.endIndex, offsetBy: -7)
        let mime = String(header[start ..< end])
        return supportedImageMIMETypes.contains(mime) ? mime : nil
    }

    private static let supportedImageMIMETypes: Set = [
        "image/jpeg", "image/png", "image/webp", "image/bmp", "image/tiff",
        "image/gif", "image/heic", "image/heif",
    ]
}

enum BytePlusModelArkError: Error, Equatable, LocalizedError {
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
