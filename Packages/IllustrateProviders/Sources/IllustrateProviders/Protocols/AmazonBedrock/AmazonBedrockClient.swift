// MARK: - AmazonBedrockClient.swift

import Foundation

struct AmazonBedrockConfiguration: Equatable {
    let apiKey: String
    let region: String

    init(secret: String) throws {
        let credentials = try ProviderCredentialConfiguration(secret: secret)
        apiKey = try Self.validatedAPIKey(credentials.require("api_key"))
        region = try Self.validatedRegion(credentials.require("region"))
    }

    func invokeURL(modelId: String) throws -> URL {
        guard Self.allowedModelIds.contains(modelId) else {
            throw AmazonBedrockError.invalidInput("Amazon Bedrock model route is not allowlisted.")
        }
        guard region == "us-west-2" else {
            throw AmazonBedrockError.invalidInput(
                "Amazon Bedrock Stable Image 1.1 models are available in us-west-2."
            )
        }
        guard let url = URL(
            string: "https://bedrock-runtime.\(region).amazonaws.com/model/\(modelId)/invoke"
        ) else {
            throw AmazonBedrockError.invalidInput("Amazon Bedrock endpoint could not be constructed.")
        }
        return url
    }

    private static func validatedAPIKey(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 4096,
              trimmed.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 })
        else {
            throw AmazonBedrockError.invalidInput("Amazon Bedrock api_key is malformed.")
        }
        return trimmed
    }

    private static func validatedRegion(_ value: String) throws -> String {
        let region = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = region.split(separator: "-")
        guard parts.count == 3,
              (2 ... 16).contains(parts[0].count),
              (2 ... 16).contains(parts[1].count),
              (1 ... 2).contains(parts[2].count),
              parts[0].allSatisfy(\.isLetter),
              parts[1].allSatisfy(\.isLetter),
              parts[2].allSatisfy(\.isNumber)
        else {
            throw AmazonBedrockError.invalidInput("Amazon Bedrock region is malformed.")
        }
        return region
    }

    private static let allowedModelIds: Set = [
        "stability.stable-image-ultra-v1:1",
        "stability.stable-image-core-v1:1",
    ]
}

enum AmazonBedrockClient {
    /// Amazon Bedrock service-specific API keys use bearer authentication on
    /// native Bedrock Runtime endpoints. AWS documents this direct HTTP form at:
    /// https://docs.aws.amazon.com/bedrock/latest/userguide/api-keys-use.html
    static func headers(configuration: AmazonBedrockConfiguration) -> [String: String] {
        [
            "Authorization": "Bearer \(configuration.apiKey)",
            "Content-Type": "application/json",
            "Accept": "application/json",
        ]
    }

    static func response(
        from envelope: NetworkResponseEnvelope,
        operation: String
    ) throws -> NetworkResponseData {
        guard (200 ... 299).contains(envelope.statusCode) else {
            let detail = envelope.response.flatMap(providerMessage)
                ?? envelope.bodyString?.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = detail?.isEmpty == false ? ": \(detail!)" : ""
            throw AmazonBedrockError.provider(
                "Amazon Bedrock \(operation) failed with HTTP \(envelope.statusCode)\(suffix)."
            )
        }
        do {
            return try envelope.requireParsedResponse()
        } catch {
            throw AmazonBedrockError.invalidResponse(
                "Amazon Bedrock \(operation) returned an undecodable response."
            )
        }
    }

    static func dictionary(
        from response: NetworkResponseData,
        operation: String
    ) throws -> [String: Any] {
        guard case let .dictionary(statusCode, data) = response else {
            throw AmazonBedrockError.invalidResponse(
                "Amazon Bedrock \(operation) did not return a JSON object."
            )
        }
        guard (200 ... 299).contains(statusCode) else {
            let suffix = providerMessage(response).map { ": \($0)" } ?? ""
            throw AmazonBedrockError.provider(
                "Amazon Bedrock \(operation) failed with HTTP \(statusCode)\(suffix)."
            )
        }
        if let message = providerMessage(response), data["images"] == nil {
            throw AmazonBedrockError.provider("Amazon Bedrock \(operation) failed: \(message)")
        }
        return data
    }

    private static func providerMessage(_ response: NetworkResponseData) -> String? {
        guard case let .dictionary(_, data) = response else { return nil }
        if let error = data["error"] as? [String: Any] {
            return error["message"] as? String ?? error["Message"] as? String
        }
        if let error = data["error"] as? String, !error.isEmpty { return error }
        return data["message"] as? String ?? data["Message"] as? String
    }
}

enum AmazonBedrockError: Error, Equatable, LocalizedError {
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
