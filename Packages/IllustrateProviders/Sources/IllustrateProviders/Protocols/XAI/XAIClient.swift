import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum XAIClient {
    static let imageEditsURL = URL(string: "https://api.x.ai/v1/images/edits")!
    static let defaultPollingPolicy = ProviderPollingPolicy(
        maxAttempts: 120,
        intervalNanoseconds: 5_000_000_000
    )

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

    static func validatedPrompt(
        _ prompt: String,
        required: Bool = true,
        maxLength: Int? = nil
    ) throws -> String? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            guard !required else {
                throw XAIAdapterError.invalidInput("xAI requires a non-empty prompt.")
            }
            return nil
        }
        if let maxLength, trimmed.count > maxLength {
            throw XAIAdapterError.invalidInput("xAI prompts cannot exceed \(maxLength) characters.")
        }
        return trimmed
    }

    static func validatedImageURI(_ input: String, mimeType: String = "image/png") throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw XAIAdapterError.invalidInput("xAI image input is empty.")
        }

        if trimmed.hasPrefix("https://") {
            guard let components = URLComponents(string: trimmed),
                  components.scheme?.lowercased() == "https",
                  components.user == nil,
                  components.password == nil,
                  components.host?.isEmpty == false
            else {
                throw XAIAdapterError.invalidInput("xAI image URLs must be valid HTTPS URLs.")
            }
            return trimmed
        }

        if trimmed.hasPrefix("data:") {
            try validateImageDataURI(trimmed)
            guard let comma = trimmed.firstIndex(of: ","),
                  let encoded = normalizedBase64(trimmed)
            else {
                throw XAIAdapterError.invalidInput("xAI image data URI is malformed.")
            }
            return "\(trimmed[..<comma]),\(encoded)"
        }

        guard let encoded = normalizedBase64(trimmed) else {
            throw XAIAdapterError.invalidInput("xAI image input is not valid base64.")
        }
        let normalizedMIME = try validatedImageMIME(mimeType)
        return "data:\(normalizedMIME);base64,\(encoded)"
    }

    static func normalizedBase64(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let encoded: String
        if trimmed.hasPrefix("data:") {
            guard let comma = trimmed.firstIndex(of: ","),
                  String(trimmed[..<comma]).lowercased().hasSuffix(";base64")
            else {
                return nil
            }
            encoded = String(trimmed[trimmed.index(after: comma)...])
        } else {
            encoded = trimmed
        }

        let compact = encoded.filter { !$0.isWhitespace }
        guard !compact.isEmpty, Data(base64Encoded: compact) != nil else { return nil }
        return compact
    }

    static func usageCost(from data: [String: Any]) -> Double? {
        guard let usage = data["usage"] as? [String: Any],
              let ticks = numericDouble(usage["cost_in_usd_ticks"]),
              ticks >= 0
        else {
            return nil
        }
        return ticks / 10_000_000_000
    }

    static func numericDouble(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    static func statusCode(of response: NetworkResponseData) -> Int {
        response.statusCode
    }

    static func dictionary(from response: NetworkResponseData) -> [String: Any]? {
        guard case let .dictionary(_, data) = response else { return nil }
        return data
    }

    static func providerError(in data: [String: Any]) -> String? {
        if let error = data["error"] as? [String: Any] {
            let message = error["message"] as? String
            let code = error["code"] as? String
            if let code, !code.isEmpty, let message, !message.isEmpty {
                return "\(code): \(message)"
            }
            return message ?? code
        }
        if let error = data["error"] as? String, !error.isEmpty { return error }
        if let message = data["message"] as? String, !message.isEmpty { return message }
        return nil
    }

    static func httpFailureMessage(
        envelope: NetworkResponseEnvelope,
        operation: String
    ) -> String {
        let parsedData = envelope.response.flatMap(dictionary)
        let detail = parsedData.flatMap(providerError)
            ?? envelope.bodyString?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let detail, !detail.isEmpty {
            return "xAI \(operation) failed with HTTP \(envelope.statusCode): \(detail)"
        }
        return "xAI \(operation) failed with HTTP \(envelope.statusCode)."
    }

    static func validatedOutputURL(_ input: String) throws -> URL {
        guard let components = URLComponents(string: input),
              components.scheme?.lowercased() == "https",
              components.user == nil,
              components.password == nil,
              components.host?.isEmpty == false,
              let url = components.url
        else {
            throw XAIAdapterError.invalidResponse("xAI returned an invalid output URL.")
        }
        return url
    }

    private static func validateImageDataURI(_ input: String) throws {
        guard let comma = input.firstIndex(of: ",") else {
            throw XAIAdapterError.invalidInput("xAI image data URI is malformed.")
        }
        let header = String(input[..<comma]).lowercased()
        guard header.hasSuffix(";base64") else {
            throw XAIAdapterError.invalidInput("xAI image data URI must use base64 encoding.")
        }
        let mimeStart = header.index(header.startIndex, offsetBy: "data:".count)
        let mimeEnd = header.index(header.endIndex, offsetBy: -";base64".count)
        _ = try validatedImageMIME(String(header[mimeStart ..< mimeEnd]))
        guard normalizedBase64(input) != nil else {
            throw XAIAdapterError.invalidInput("xAI image data URI contains invalid base64.")
        }
    }

    private static func validatedImageMIME(_ input: String) throws -> String {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ["image/jpeg", "image/png", "image/webp"].contains(normalized) else {
            throw XAIAdapterError.invalidInput("xAI supports JPEG, PNG, and WebP image inputs.")
        }
        return normalized
    }
}

enum XAIAdapterError: Error, Equatable, LocalizedError {
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
