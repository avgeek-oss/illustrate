// MARK: - ReplicateFileUploader.swift

// Handles file uploads to Replicate's file storage API.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Utility for uploading images to Replicate's file storage.
///
/// Replicate models require image inputs to be URLs, not raw data.
/// This uploader handles converting base64 image data to a Replicate-hosted URL.
public enum ReplicateFileUploader {
    /// Uploads a base64-encoded image to Replicate's file storage.
    ///
    /// - Parameters:
    ///   - base64Image: Base64-encoded image (with or without data URL prefix)
    ///   - apiToken: Replicate API key for authentication
    /// - Returns: URL string where the uploaded file can be accessed
    /// - Throws: NSError for upload failures or invalid data
    public static func uploadImage(base64Image: String, apiToken: String) async throws -> String {
        guard let uploadUrl = URL(string: "https://api.replicate.com/v1/files") else {
            throw NSError(domain: "Invalid upload URL", code: -1, userInfo: nil)
        }

        // Strip data URL prefix if present (e.g., "data:image/png;base64,")
        let cleanBase64 = base64Image.replacingOccurrences(
            of: "^data:.*;base64,",
            with: "",
            options: .regularExpression
        )

        // Decode base64 to raw image data
        guard let imageData = Data(base64Encoded: cleanBase64) else {
            throw NSError(domain: "Invalid base64 image data", code: -1, userInfo: nil)
        }

        // Build multipart form data with unique boundary
        let boundary = UUID().uuidString
        var bodyData = Data()

        // Part 1: Image content
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData
            .append("Content-Disposition: form-data; name=\"content\"; filename=\"image.png\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        bodyData.append(imageData)
        bodyData.append("\r\n".data(using: .utf8)!)

        // Part 2: Metadata identifying the upload source
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"metadata\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        bodyData.append("{\"agent\":\"illustrate\"}".data(using: .utf8)!)
        bodyData.append("\r\n".data(using: .utf8)!)

        // End of multipart data
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Configure the upload request
        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "POST"
        request.setValue("Token \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        // Execute the upload
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid response", code: -1, userInfo: nil)
        }

        // Check for HTTP errors
        if httpResponse.statusCode >= 400 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "Upload failed: \(errorMessage)", code: httpResponse.statusCode, userInfo: nil)
        }

        // Parse the response to extract the file URL
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urls = json["urls"] as? [String: Any],
              let getUrl = urls["get"] as? String
        else {
            throw NSError(domain: "Failed to parse upload response", code: -1, userInfo: nil)
        }

        return getUrl
    }

    /// Uploads a base64-encoded video to Replicate's file storage.
    ///
    /// - Parameters:
    ///   - base64Video: Base64-encoded video (with or without data URL prefix)
    ///   - apiToken: Replicate API key for authentication
    /// - Returns: URL string where the uploaded file can be accessed
    /// - Throws: NSError for upload failures or invalid data
    public static func uploadVideo(base64Video: String, apiToken: String) async throws -> String {
        guard let uploadUrl = URL(string: "https://api.replicate.com/v1/files") else {
            throw NSError(domain: "Invalid upload URL", code: -1, userInfo: nil)
        }

        // Strip data URL prefix if present (e.g., "data:video/mp4;base64,")
        let cleanBase64 = base64Video.replacingOccurrences(
            of: "^data:.*;base64,",
            with: "",
            options: .regularExpression
        )

        // Decode base64 to raw video data
        guard let videoData = Data(base64Encoded: cleanBase64) else {
            throw NSError(domain: "Invalid base64 video data", code: -1, userInfo: nil)
        }

        // Build multipart form data with unique boundary
        let boundary = UUID().uuidString
        var bodyData = Data()

        // Part 1: Video content
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData
            .append("Content-Disposition: form-data; name=\"content\"; filename=\"video.mp4\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        bodyData.append(videoData)
        bodyData.append("\r\n".data(using: .utf8)!)

        // Part 2: Metadata identifying the upload source
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"metadata\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        bodyData.append("{\"agent\":\"illustrate\"}".data(using: .utf8)!)
        bodyData.append("\r\n".data(using: .utf8)!)

        // End of multipart data
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Configure the upload request
        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "POST"
        request.setValue("Token \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        // Execute the upload
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid response", code: -1, userInfo: nil)
        }

        // Check for HTTP errors
        if httpResponse.statusCode >= 400 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "Upload failed: \(errorMessage)", code: httpResponse.statusCode, userInfo: nil)
        }

        // Parse the response to extract the file URL
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urls = json["urls"] as? [String: Any],
              let getUrl = urls["get"] as? String
        else {
            throw NSError(domain: "Failed to parse upload response", code: -1, userInfo: nil)
        }

        return getUrl
    }
}
