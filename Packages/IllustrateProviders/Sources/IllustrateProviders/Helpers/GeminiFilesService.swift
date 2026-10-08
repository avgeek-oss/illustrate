// MARK: - GeminiFilesService.swift

// Service for uploading files to Google's Gemini Files API.
//
// Some Gemini models require images to be uploaded to their
// file storage before use. This service handles the upload.
//
// ## Upload Flow
// Uses resumable upload protocol:
// 1. Start resumable upload -> Get upload URL
// 2. Upload bytes to URL
// 3. Get file URI for use in generation
//
// ## File URI
// Returned URI (e.g., "files/abc123") is used in generation
// requests instead of inline base64 data.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Result from Gemini file upload.
public struct GeminiUploadedFile: Sendable {
    public var uri: String
    public var mimeType: String
    public var name: String

    public init(uri: String, mimeType: String, name: String) {
        self.uri = uri
        self.mimeType = mimeType
        self.name = name
    }
}

public class GeminiFilesService: @unchecked Sendable {
    public static let shared = GeminiFilesService()

    private let uploadBaseURL = "https://generativelanguage.googleapis.com/upload/v1beta/files"

    private init() {}

    /// Uploads image data to the Gemini Files API and returns the file URI
    /// - Parameters:
    ///   - imageData: Raw image data (not base64 encoded)
    ///   - mimeType: MIME type of the image (e.g., "image/png", "image/jpeg")
    ///   - apiKey: Gemini API key
    ///   - displayName: Optional display name for the file
    /// - Returns: GeminiUploadedFile containing the file URI and metadata
    public func uploadImage(
        imageData: Data,
        mimeType: String,
        apiKey: String,
        displayName: String = "image"
    ) async throws -> GeminiUploadedFile {
        let uploadURL = try await startResumableUpload(
            numBytes: imageData.count,
            mimeType: mimeType,
            apiKey: apiKey,
            displayName: displayName
        )

        return try await uploadBytes(
            to: uploadURL,
            data: imageData,
            apiKey: apiKey
        )
    }

    /// Uploads base64 encoded image to the Gemini Files API
    /// - Parameters:
    ///   - base64Image: Base64 encoded image (with or without data URI prefix)
    ///   - mimeType: MIME type of the image
    ///   - apiKey: Gemini API key
    ///   - displayName: Optional display name for the file
    /// - Returns: GeminiUploadedFile containing the file URI and metadata
    public func uploadBase64Image(
        base64Image: String,
        mimeType: String,
        apiKey: String,
        displayName: String = "image"
    ) async throws -> GeminiUploadedFile {
        let cleanBase64 = base64Image.replacingOccurrences(
            of: "^data:.*;base64,",
            with: "",
            options: .regularExpression
        )

        guard let imageData = Data(base64Encoded: cleanBase64) else {
            throw GeminiFilesError.invalidBase64Data
        }

        return try await uploadImage(
            imageData: imageData,
            mimeType: mimeType,
            apiKey: apiKey,
            displayName: displayName
        )
    }

    private func startResumableUpload(
        numBytes: Int,
        mimeType: String,
        apiKey: String,
        displayName: String
    ) async throws -> URL {
        guard let url = URL(string: uploadBaseURL) else {
            throw GeminiFilesError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("resumable", forHTTPHeaderField: "X-Goog-Upload-Protocol")
        request.setValue("start", forHTTPHeaderField: "X-Goog-Upload-Command")
        request.setValue(String(numBytes), forHTTPHeaderField: "X-Goog-Upload-Header-Content-Length")
        request.setValue(mimeType, forHTTPHeaderField: "X-Goog-Upload-Header-Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["file": ["display_name": displayName]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60

        let session = URLSession(configuration: configuration)
        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiFilesError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GeminiFilesError.uploadStartFailed(statusCode: httpResponse.statusCode)
        }

        guard let uploadURLString = httpResponse.value(forHTTPHeaderField: "X-Goog-Upload-URL"),
              let uploadURL = URL(string: uploadURLString)
        else {
            throw GeminiFilesError.missingUploadURL
        }

        return uploadURL
    }

    private func uploadBytes(
        to uploadURL: URL,
        data: Data,
        apiKey: String
    ) async throws -> GeminiUploadedFile {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
        request.setValue("0", forHTTPHeaderField: "X-Goog-Upload-Offset")
        request.setValue("upload, finalize", forHTTPHeaderField: "X-Goog-Upload-Command")
        request.httpBody = data

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 120

        let session = URLSession(configuration: configuration)
        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiFilesError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GeminiFilesError.uploadFailed(statusCode: httpResponse.statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]

        guard let fileInfo = json?["file"] as? [String: Any],
              let uri = fileInfo["uri"] as? String,
              let name = fileInfo["name"] as? String
        else {
            throw GeminiFilesError.invalidFileResponse
        }

        let mimeType = fileInfo["mimeType"] as? String ?? "image/png"

        return GeminiUploadedFile(uri: uri, mimeType: mimeType, name: name)
    }
}

public enum GeminiFilesError: LocalizedError {
    case invalidURL
    case invalidBase64Data
    case invalidResponse
    case uploadStartFailed(statusCode: Int)
    case missingUploadURL
    case uploadFailed(statusCode: Int)
    case invalidFileResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid upload URL"
        case .invalidBase64Data:
            "Invalid base64 image data"
        case .invalidResponse:
            "Invalid response from server"
        case let .uploadStartFailed(statusCode):
            "Failed to start upload (status: \(statusCode))"
        case .missingUploadURL:
            "Upload URL not found in response"
        case let .uploadFailed(statusCode):
            "Upload failed (status: \(statusCode))"
        case .invalidFileResponse:
            "Invalid file info in response"
        }
    }
}
