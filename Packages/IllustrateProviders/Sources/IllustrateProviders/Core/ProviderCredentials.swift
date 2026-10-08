// MARK: - ProviderCredentials.swift

import Foundation

/// Errors raised while decoding or reading provider credentials from Keychain.
public enum ProviderCredentialError: Error, Equatable, LocalizedError, Sendable {
    case empty
    case invalidJSON
    case missingField(String)
    case invalidEmbeddedJSON(String)

    public var errorDescription: String? {
        switch self {
        case .empty:
            "Provider credentials are empty."
        case .invalidJSON:
            "Provider credentials are not valid JSON."
        case let .missingField(field):
            "Provider credentials are missing the required field: \(field)."
        case let .invalidEmbeddedJSON(field):
            "Provider credential field \(field) does not contain valid JSON."
        }
    }
}

/// A normalized view of the opaque credential string stored in Keychain.
///
/// Simple providers store one API key. Providers that require multiple values
/// store a flat JSON object assembled by the connection form. The normalized
/// representation keeps parsing and validation out of individual adapters and
/// never persists decoded secrets.
public struct ProviderCredentialConfiguration: Equatable, Sendable {
    public let apiKey: String?
    public let values: [String: String]

    public init(secret: String) throws {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProviderCredentialError.empty
        }

        guard trimmed.first == "{" else {
            apiKey = trimmed
            values = [:]
            return
        }

        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any]
        else {
            throw ProviderCredentialError.invalidJSON
        }

        var normalized: [String: String] = [:]
        normalized.reserveCapacity(dictionary.count)
        for (key, value) in dictionary {
            if let string = value as? String {
                normalized[key] = string
            } else if value is NSNull {
                continue
            } else if JSONSerialization.isValidJSONObject(value),
                      let nestedData = try? JSONSerialization.data(withJSONObject: value),
                      let nestedString = String(data: nestedData, encoding: .utf8)
            {
                normalized[key] = nestedString
            } else {
                normalized[key] = String(describing: value)
            }
        }

        apiKey = nil
        values = normalized
    }

    public func value(for field: String) -> String? {
        guard let value = values[field]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return nil
        }
        return value
    }

    public func require(_ field: String) throws -> String {
        guard let value = value(for: field) else {
            throw ProviderCredentialError.missingField(field)
        }
        return value
    }

    public func requireAPIKey() throws -> String {
        guard let apiKey, !apiKey.isEmpty else {
            throw ProviderCredentialError.missingField("api_key")
        }
        return apiKey
    }

    public func decodeEmbeddedJSON<Value: Decodable>(
        _ type: Value.Type,
        from field: String,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> Value {
        let raw = try require(field)
        guard let data = raw.data(using: .utf8) else {
            throw ProviderCredentialError.invalidEmbeddedJSON(field)
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw ProviderCredentialError.invalidEmbeddedJSON(field)
        }
    }
}
