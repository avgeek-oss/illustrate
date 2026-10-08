// MARK: - VertexAIClient.swift

import Foundation

struct VertexAIConfiguration: Equatable {
    let accessToken: String
    let projectId: String
    let location: String

    init(secret: String) throws {
        let credentials = try ProviderCredentialConfiguration(secret: secret)
        accessToken = try credentials.require("access_token")
        projectId = try credentials.require("project_id").lowercased()
        location = try credentials.require("location").lowercased()

        guard Self.isValidProjectId(projectId) else {
            throw VertexAIError.invalidInput("Vertex AI project_id is malformed.")
        }
        guard Self.isValidLocation(location) else {
            throw VertexAIError.invalidInput("Vertex AI location is malformed.")
        }
    }

    var host: String {
        "\(location)-aiplatform.googleapis.com"
    }

    func modelURL(modelId: String, method: String) throws -> URL {
        guard VertexAIClient.isValidModelId(modelId), VertexAIClient.allowedMethods.contains(method) else {
            throw VertexAIError.invalidInput("Vertex AI model route is invalid.")
        }
        let value = "https://\(host)/v1/projects/\(projectId)/locations/\(location)/publishers/google/models/\(modelId):\(method)"
        guard let url = URL(string: value) else {
            throw VertexAIError.invalidInput("Vertex AI endpoint could not be constructed.")
        }
        return url
    }

    private static func isValidProjectId(_ value: String) -> Bool {
        guard (6 ... 30).contains(value.count),
              value.first?.isLetter == true,
              value.last?.isLetter == true || value.last?.isNumber == true
        else { return false }
        return value.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" }
    }

    private static func isValidLocation(_ value: String) -> Bool {
        guard (2 ... 63).contains(value.count),
              value.first?.isLetter == true,
              value.last?.isLetter == true || value.last?.isNumber == true,
              !value.contains("--")
        else { return false }
        return value.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" }
    }
}

enum VertexAIClient {
    static let allowedMethods: Set = [
        "generateContent",
        "predictLongRunning",
        "fetchPredictOperation",
    ]

    static func headers(configuration: VertexAIConfiguration) -> [String: String] {
        [
            "Authorization": "Bearer \(configuration.accessToken)",
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
            throw VertexAIError.provider(
                "Vertex AI \(operation) failed with HTTP \(envelope.statusCode)\(suffix)."
            )
        }
        do {
            return try envelope.requireParsedResponse()
        } catch {
            throw VertexAIError.invalidResponse(
                "Vertex AI \(operation) returned an undecodable response."
            )
        }
    }

    static func response(
        from response: NetworkResponseData,
        operation: String
    ) throws -> [String: Any] {
        guard case let .dictionary(statusCode, data) = response else {
            throw VertexAIError.invalidResponse("Vertex AI \(operation) did not return a JSON object.")
        }
        guard (200 ... 299).contains(statusCode) else {
            let detail = providerMessage(response).map { ": \($0)" } ?? ""
            throw VertexAIError.provider(
                "Vertex AI \(operation) failed with HTTP \(statusCode)\(detail)."
            )
        }
        if let error = data["error"] as? [String: Any] {
            let code = error["code"].map { String(describing: $0) }
            let message = error["message"] as? String ?? "Vertex AI request failed."
            let prefix = code.map { " (\($0))" } ?? ""
            throw VertexAIError.provider("Vertex AI \(operation) failed\(prefix): \(message)")
        }
        return data
    }

    static func imageInput(_ value: String, defaultMimeType: String = "image/png") throws -> ImageInput {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VertexAIError.invalidInput("Vertex AI image input is empty.")
        }

        if trimmed.lowercased().hasPrefix("data:") {
            guard let comma = trimmed.firstIndex(of: ",") else {
                throw VertexAIError.invalidInput("Vertex AI image data URI is malformed.")
            }
            let header = String(trimmed[..<comma]).lowercased()
            guard header.hasSuffix(";base64") else {
                throw VertexAIError.invalidInput("Vertex AI image data URI must use base64.")
            }
            let mimeType = String(header.dropFirst(5).dropLast(7))
            guard supportedImageMimeTypes.contains(mimeType) else {
                throw VertexAIError.invalidInput("Vertex AI supports PNG, JPEG, or WebP image inputs.")
            }
            let data = String(trimmed[trimmed.index(after: comma)...])
            guard !data.isEmpty, Data(base64Encoded: data) != nil else {
                throw VertexAIError.invalidInput("Vertex AI image input contains invalid base64.")
            }
            return ImageInput(data: data, mimeType: mimeType)
        }

        guard supportedImageMimeTypes.contains(defaultMimeType), Data(base64Encoded: trimmed) != nil else {
            throw VertexAIError.invalidInput("Vertex AI image input contains invalid base64.")
        }
        return ImageInput(data: trimmed, mimeType: defaultMimeType)
    }

    static func isValidOperationName(
        _ value: String,
        configuration: VertexAIConfiguration,
        modelId: String
    ) -> Bool {
        let prefix = "projects/\(configuration.projectId)/locations/\(configuration.location)/publishers/google/models/\(modelId)/operations/"
        guard value.hasPrefix(prefix) else { return false }
        let id = value.dropFirst(prefix.count)
        return !id.isEmpty
            && id.count <= 256
            && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    struct ImageInput: Equatable {
        let data: String
        let mimeType: String
    }

    private static let supportedImageMimeTypes: Set = [
        "image/jpeg", "image/png", "image/webp",
    ]

    static func isValidModelId(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 128 && value.allSatisfy {
            $0.isLowercase || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_"
        }
    }

    private static func providerMessage(_ response: NetworkResponseData) -> String? {
        guard case let .dictionary(_, data) = response else { return nil }
        if let error = data["error"] as? [String: Any] {
            return error["message"] as? String
        }
        return data["message"] as? String
    }
}

enum VertexAIError: Error, Equatable, LocalizedError {
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
