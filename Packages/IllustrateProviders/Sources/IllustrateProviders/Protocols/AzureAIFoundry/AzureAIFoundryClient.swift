// MARK: - AzureAIFoundryClient.swift

import Foundation

struct AzureAIFoundryConfiguration: Equatable {
    let endpoint: URL
    let apiKey: String
    let imageDeployment: String
    let videoDeployment: String

    init(secret: String) throws {
        let credentials = try ProviderCredentialConfiguration(secret: secret)
        endpoint = try Self.validatedEndpoint(credentials.require("endpoint"))
        apiKey = try Self.validatedAPIKey(credentials.require("api_key"))
        imageDeployment = try Self.validatedDeployment(
            credentials.require("image_deployment"),
            field: "image_deployment"
        )
        videoDeployment = try Self.validatedDeployment(
            credentials.require("video_deployment"),
            field: "video_deployment"
        )
    }

    func imageGenerationURL() throws -> URL {
        try url(path: "/openai/v1/images/generations", query: "api-version=preview")
    }

    func imageEditURL() throws -> URL {
        try url(
            path: "/openai/deployments/\(imageDeployment)/images/edits",
            query: "api-version=2025-04-01"
        )
    }

    func videoCreateURL() throws -> URL {
        try url(path: "/openai/v1/videos")
    }

    func videoStatusURL(videoId: String) throws -> URL {
        let videoId = try Self.validatedVideoId(videoId)
        return try url(path: "/openai/v1/videos/\(videoId)")
    }

    func videoContentURL(videoId: String) throws -> URL {
        let videoId = try Self.validatedVideoId(videoId)
        return try url(path: "/openai/v1/videos/\(videoId)/content")
    }

    private func url(path: String, query: String? = nil) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = endpoint.host
        components.path = path
        components.percentEncodedQuery = query
        guard let url = components.url else {
            throw AzureAIFoundryError.invalidInput("Azure AI Foundry endpoint could not be constructed.")
        }
        return url
    }

    private static func validatedEndpoint(_ value: String) throws -> URL {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/",
              let host = components.host?.lowercased(),
              host.hasSuffix(".openai.azure.com")
        else {
            throw AzureAIFoundryError.invalidInput(
                "Azure AI Foundry endpoint must be an HTTPS Azure OpenAI resource endpoint."
            )
        }

        let resource = String(host.dropLast(".openai.azure.com".count))
        guard (2 ... 64).contains(resource.count),
              resource.first?.isLetter == true || resource.first?.isNumber == true,
              resource.last?.isLetter == true || resource.last?.isNumber == true,
              resource.allSatisfy({ $0.isLowercase || $0.isNumber || $0 == "-" })
        else {
            throw AzureAIFoundryError.invalidInput("Azure AI Foundry resource name is malformed.")
        }

        components.scheme = "https"
        components.host = host
        components.path = ""
        guard let endpoint = components.url else {
            throw AzureAIFoundryError.invalidInput("Azure AI Foundry endpoint is malformed.")
        }
        return endpoint
    }

    private static func validatedAPIKey(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 512,
              !trimmed.contains(where: \.isNewline)
        else {
            throw AzureAIFoundryError.invalidInput("Azure AI Foundry api_key is malformed.")
        }
        return trimmed
    }

    private static func validatedDeployment(_ value: String, field: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 128,
              trimmed.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." })
        else {
            throw AzureAIFoundryError.invalidInput("Azure AI Foundry \(field) is malformed.")
        }
        return trimmed
    }

    private static func validatedVideoId(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("video_"),
              trimmed.count <= 128,
              trimmed.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        else {
            throw AzureAIFoundryError.invalidInput("Azure AI Foundry video ID is malformed.")
        }
        return trimmed
    }
}

enum AzureAIFoundryClient {
    struct ImageInput: Equatable {
        let data: Data
        let mimeType: String
    }

    static func headers(
        configuration: AzureAIFoundryConfiguration,
        multipart: Bool = false
    ) -> [String: String] {
        [
            "api-key": configuration.apiKey,
            "Content-Type": multipart ? "multipart/form-data" : "application/json",
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
            throw AzureAIFoundryError.provider(
                "Azure AI Foundry \(operation) failed with HTTP \(envelope.statusCode)\(suffix)."
            )
        }
        do {
            return try envelope.requireParsedResponse()
        } catch {
            throw AzureAIFoundryError.invalidResponse(
                "Azure AI Foundry \(operation) returned an undecodable response."
            )
        }
    }

    static func dictionary(
        from response: NetworkResponseData,
        operation: String
    ) throws -> [String: Any] {
        guard case let .dictionary(statusCode, data) = response else {
            throw AzureAIFoundryError.invalidResponse(
                "Azure AI Foundry \(operation) did not return a JSON object."
            )
        }
        guard (200 ... 299).contains(statusCode) else {
            let suffix = providerMessage(response).map { ": \($0)" } ?? ""
            throw AzureAIFoundryError.provider(
                "Azure AI Foundry \(operation) failed with HTTP \(statusCode)\(suffix)."
            )
        }
        if let error = data["error"] as? [String: Any] {
            let code = error["code"].map { String(describing: $0) }
            let message = error["message"] as? String ?? "Azure AI Foundry request failed."
            let suffix = code.map { " (\($0))" } ?? ""
            throw AzureAIFoundryError.provider(
                "Azure AI Foundry \(operation) failed\(suffix): \(message)"
            )
        }
        return data
    }

    static func imageInput(
        _ value: String,
        defaultMimeType: String = "image/png",
        allowWebP: Bool = false
    ) throws -> ImageInput {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AzureAIFoundryError.invalidInput("Azure AI Foundry image input is empty.")
        }

        var mimeType = defaultMimeType.lowercased()
        var base64 = trimmed
        if trimmed.lowercased().hasPrefix("data:") {
            guard let comma = trimmed.firstIndex(of: ",") else {
                throw AzureAIFoundryError.invalidInput("Azure AI Foundry image data URI is malformed.")
            }
            let header = String(trimmed[..<comma]).lowercased()
            guard header.hasSuffix(";base64") else {
                throw AzureAIFoundryError.invalidInput("Azure AI Foundry image data URI must use base64.")
            }
            mimeType = String(header.dropFirst(5).dropLast(7))
            base64 = String(trimmed[trimmed.index(after: comma)...])
        }

        let allowedMimeTypes = allowWebP
            ? supportedImageMimeTypes.union(["image/webp"])
            : supportedImageMimeTypes
        guard allowedMimeTypes.contains(mimeType),
              let data = Data(base64Encoded: base64),
              !data.isEmpty,
              data.count < 50 * 1024 * 1024
        else {
            throw AzureAIFoundryError.invalidInput(
                "Azure AI Foundry image input must use a supported format and be smaller than 50 MB."
            )
        }
        return ImageInput(data: data, mimeType: mimeType)
    }

    static func rawResponse(_ response: NetworkResponseData) -> String? {
        response.rawResponseString
    }

    private static let supportedImageMimeTypes: Set = ["image/jpeg", "image/jpg", "image/png"]

    private static func providerMessage(_ response: NetworkResponseData) -> String? {
        guard case let .dictionary(_, data) = response else { return nil }
        if let error = data["error"] as? [String: Any] {
            return error["message"] as? String
        }
        if let error = data["error"] as? String, !error.isEmpty {
            return error
        }
        return data["message"] as? String
    }
}

enum AzureAIFoundryError: Error, Equatable, LocalizedError {
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
