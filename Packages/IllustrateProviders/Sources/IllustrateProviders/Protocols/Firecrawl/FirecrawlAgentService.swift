// MARK: - FirecrawlAgentService.swift

// Service for interacting with Firecrawl Agent API.
//
// FirecrawlAgentService provides methods to:
// - Start an agent job for brand information extraction
// - Poll for job status until completion
// - Parse extraction results into BrandKitExtraction model
//
// ## API Flow
// 1. POST /v2/agent - Start agent job with prompt, schema, and URLs
// 2. GET /v2/agent/{id} - Poll for status (processing/completed/failed)

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Response Models

/// Response from starting an agent job
struct FirecrawlAgentStartResponse: Codable {
    let success: Bool
    let id: String?
    let error: String?
}

/// Status response from polling an agent job
struct FirecrawlAgentStatusResponse {
    let success: Bool
    let status: FirecrawlAgentStatus
    let data: BrandKitExtraction?
    let error: String?
}

/// Possible agent job statuses
public enum FirecrawlAgentStatus: String {
    case processing
    case completed
    case failed
    case unknown
}

/// Extracted brand information from Firecrawl Agent
public struct BrandKitExtraction: Codable, Sendable {
    public let brandName: String?
    public let brandAbout: String?
    public let brandPersonality: String?
    public let fontFace: String?
    public let primaryColor: String?
    public let secondaryColor: String?
    public let accentColor: String?
    public let backgroundColor: String?
    public let additionalColors: [String]?
    public let imageAssets: BrandImageAssets?
}

/// Extracted image asset URLs from Firecrawl Agent
public struct BrandImageAssets: Codable, Sendable {
    public let lightLogoUrl: String?
    public let darkLogoUrl: String?
    public let asset1Url: String?
    public let asset2Url: String?
    public let asset3Url: String?
    public let asset4Url: String?
    public let asset5Url: String?
}

// MARK: - Service Errors

public enum FirecrawlAgentError: Error, LocalizedError {
    case invalidURL
    case noJobId
    case apiError(String)
    case networkError(String)
    case timeout
    case parsingError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid API URL"
        case .noJobId:
            "No job ID returned from API"
        case let .apiError(message):
            "API Error: \(message)"
        case let .networkError(message):
            "Network Error: \(message)"
        case .timeout:
            "Request timed out after 10 minutes"
        case let .parsingError(message):
            "Failed to parse response: \(message)"
        }
    }
}

// MARK: - Firecrawl Agent Service

/// Singleton service for Firecrawl Agent API interactions.
///
/// Provides methods to start brand extraction jobs and poll for results.
/// Uses the Firecrawl Agent API v2 for autonomous web data extraction.
public class FirecrawlAgentService: @unchecked Sendable {
    /// Shared singleton instance
    public static let shared = FirecrawlAgentService()

    /// Base URL for Firecrawl API v2
    private let baseURL = "https://api.firecrawl.dev/v2"

    /// Polling interval in seconds
    private let pollingInterval: UInt64 = 10_000_000_000 // 10 seconds in nanoseconds

    /// Maximum polling duration in seconds (10 minutes)
    private let maxPollingDuration: TimeInterval = 600

    private init() {}

    // MARK: - Public Methods

    /// Starts an agent job to extract brand information from URLs.
    ///
    /// - Parameters:
    ///   - urls: Array of brand-related URLs to analyze
    ///   - apiKey: Firecrawl API key
    ///   - includeImages: Whether to extract image asset URLs (slower if true)
    /// - Returns: Job ID for polling
    /// - Throws: FirecrawlAgentError if request fails
    public func startAgentJob(urls: [String], apiKey: String, includeImages: Bool = true) async throws -> String {
        guard let url = URL(string: "\(baseURL)/agent") else {
            throw FirecrawlAgentError.invalidURL
        }

        let prompt: String
        let schema: [String: Any]

        if includeImages {
            prompt = """
            Fetch branding information for the brand found in the URL. Extract the name of the brand, \
            about description, personality traits, and color codes (hex) \
            for the primary, secondary, accent, background, and additional brand colors.
            """

            schema = [
                "type": "object",
                "properties": [
                    "brandName": [
                        "type": "string",
                        "description": "The official name of the brand or company",
                    ],
                    "brandAbout": [
                        "type": "string",
                        "description": "A brief description about the brand, what they do, their mission or value proposition (up to 500 characters)",
                    ],
                    "brandPersonality": [
                        "type": "string",
                        "description": "Brand personality traits and voice characteristics like professional, playful, innovative, trustworthy (up to 160 characters)",
                    ],
                    "fontFace": [
                        "type": "string",
                        "description": "The primary font or typeface name used by the brand (e.g., Helvetica, Inter, Roboto). Default to Arial if not found.",
                    ],
                    "primaryColor": [
                        "type": "string",
                        "description": "Primary brand color in hex format (e.g., #FF5500)",
                    ],
                    "secondaryColor": [
                        "type": "string",
                        "description": "Secondary brand color in hex format",
                    ],
                    "accentColor": [
                        "type": "string",
                        "description": "Accent or highlight color in hex format",
                    ],
                    "backgroundColor": [
                        "type": "string",
                        "description": "Background or base color in hex format",
                    ],
                    "additionalColors": [
                        "type": "array",
                        "description": "Additional brand colors in hex format (up to 4)",
                        "items": ["type": "string"],
                    ],
                    "imageAssets": [
                        "type": "object",
                        "description": "Brand image assets including logos and style images",
                        "properties": [
                            "lightLogoUrl": [
                                "type": "string",
                                "description": "URL to the brand's light/primary logo image. Transparent PNG preferred.",
                            ],
                            "darkLogoUrl": [
                                "type": "string",
                                "description": "URL to the brand's dark/inverted logo image for dark backgrounds. Transparent PNG preferred.",
                            ],
                            "asset1Url": [
                                "type": "string",
                                "description": "URL to a brand style/theme image, product photo, or model image.",
                            ],
                            "asset2Url": [
                                "type": "string",
                                "description": "URL to a brand style/theme image, product photo, or model image.",
                            ],
                            "asset3Url": [
                                "type": "string",
                                "description": "URL to a brand style/theme image, product photo, or model image.",
                            ],
                            "asset4Url": [
                                "type": "string",
                                "description": "URL to a brand style/theme image, product photo, or model image.",
                            ],
                            "asset5Url": [
                                "type": "string",
                                "description": "URL to a brand style/theme image, product photo, or model image.",
                            ],
                        ],
                    ],
                ],
                "required": ["imageAssets"],
            ]
        } else {
            // Simplified prompt and schema without images for faster extraction
            prompt = """
            Fetch branding information for the brand found in the URL. Extract the name of the brand, \
            about description, personality traits, and color codes (hex) \
            for the primary, secondary, accent, background, and additional brand colors. \
            Do not extract any image URLs.
            """

            schema = [
                "type": "object",
                "properties": [
                    "brandName": [
                        "type": "string",
                        "description": "The official name of the brand or company",
                    ],
                    "brandAbout": [
                        "type": "string",
                        "description": "A brief description about the brand, what they do, their mission or value proposition (up to 500 characters)",
                    ],
                    "brandPersonality": [
                        "type": "string",
                        "description": "Brand personality traits and voice characteristics like professional, playful, innovative, trustworthy (up to 160 characters)",
                    ],
                    "fontFace": [
                        "type": "string",
                        "description": "The primary font or typeface name used by the brand (e.g., Helvetica, Inter, Roboto). Default to Arial if not found.",
                    ],
                    "primaryColor": [
                        "type": "string",
                        "description": "Primary brand color in hex format (e.g., #FF5500)",
                    ],
                    "secondaryColor": [
                        "type": "string",
                        "description": "Secondary brand color in hex format",
                    ],
                    "accentColor": [
                        "type": "string",
                        "description": "Accent or highlight color in hex format",
                    ],
                    "backgroundColor": [
                        "type": "string",
                        "description": "Background or base color in hex format",
                    ],
                    "additionalColors": [
                        "type": "array",
                        "description": "Additional brand colors in hex format (up to 4)",
                        "items": ["type": "string"],
                    ],
                ],
                "required": [],
            ]
        }

        let requestBody: [String: Any] = [
            "prompt": prompt,
            "urls": urls,
            "schema": schema,
            "strictConstrainToURLs": true,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirecrawlAgentError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 402 {
            throw FirecrawlAgentError.apiError("Payment required - insufficient credits")
        } else if httpResponse.statusCode == 429 {
            throw FirecrawlAgentError.apiError("Rate limit exceeded")
        } else if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorJson["error"] as? String
            {
                throw FirecrawlAgentError.apiError(errorMessage)
            }
            throw FirecrawlAgentError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let startResponse = try JSONDecoder().decode(FirecrawlAgentStartResponse.self, from: data)

        guard startResponse.success, let jobId = startResponse.id else {
            throw FirecrawlAgentError.noJobId
        }

        return jobId
    }

    /// Polls for agent job status until completion or timeout.
    ///
    /// - Parameters:
    ///   - jobId: The job ID returned from startAgentJob
    ///   - apiKey: Firecrawl API key
    ///   - onStatusUpdate: Callback for status updates during polling
    /// - Returns: Extracted brand information
    /// - Throws: FirecrawlAgentError if job fails or times out
    public func pollForResult(
        jobId: String,
        apiKey: String,
        onStatusUpdate: ((String) -> Void)? = nil
    ) async throws -> BrandKitExtraction {
        let startTime = Date()

        while true {
            // Check for timeout
            if Date().timeIntervalSince(startTime) > maxPollingDuration {
                throw FirecrawlAgentError.timeout
            }

            let status = try await checkAgentStatus(jobId: jobId, apiKey: apiKey)

            switch status.status {
            case .completed:
                if let data = status.data {
                    return data
                }
                throw FirecrawlAgentError.parsingError("No data in completed response")

            case .failed:
                throw FirecrawlAgentError.apiError(status.error ?? "Job failed")

            case .processing:
                onStatusUpdate?("Processing...")
                try await Task.sleep(nanoseconds: pollingInterval)

            case .unknown:
                onStatusUpdate?("Waiting...")
                try await Task.sleep(nanoseconds: pollingInterval)
            }
        }
    }

    // MARK: - Private Methods

    /// Checks the status of an agent job.
    ///
    /// - Parameters:
    ///   - jobId: The job ID to check
    ///   - apiKey: Firecrawl API key
    /// - Returns: Current job status and data if available
    private func checkAgentStatus(jobId: String, apiKey: String) async throws -> FirecrawlAgentStatusResponse {
        guard let url = URL(string: "\(baseURL)/agent/\(jobId)") else {
            throw FirecrawlAgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirecrawlAgentError.networkError("Invalid response")
        }

        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorJson["error"] as? String
            {
                throw FirecrawlAgentError.apiError(errorMessage)
            }
            throw FirecrawlAgentError.apiError("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FirecrawlAgentError.parsingError("Invalid JSON response")
        }

        let success = json["success"] as? Bool ?? false
        let statusString = json["status"] as? String ?? "unknown"
        let status = FirecrawlAgentStatus(rawValue: statusString) ?? .unknown
        let error = json["error"] as? String

        var extraction: BrandKitExtraction?
        if status == .completed {
            // The data is nested inside the response
            if let resultData = json["data"] as? [String: Any] {
                extraction = parseBrandKitExtraction(from: resultData)
            }
        }

        return FirecrawlAgentStatusResponse(
            success: success,
            status: status,
            data: extraction,
            error: error
        )
    }

    /// Parses brand extraction data from JSON response.
    private func parseBrandKitExtraction(from json: [String: Any]) -> BrandKitExtraction {
        let brandName = json["brandName"] as? String
        let brandAbout = json["brandAbout"] as? String
        let brandPersonality = json["brandPersonality"] as? String
        let fontFace = json["fontFace"] as? String
        let primaryColor = normalizeHexColor(json["primaryColor"] as? String)
        let secondaryColor = normalizeHexColor(json["secondaryColor"] as? String)
        let accentColor = normalizeHexColor(json["accentColor"] as? String)
        let backgroundColor = normalizeHexColor(json["backgroundColor"] as? String)

        var additionalColors: [String]?
        if let colors = json["additionalColors"] as? [String] {
            additionalColors = colors.compactMap { normalizeHexColor($0) }
        }

        var imageAssets: BrandImageAssets?
        if let assetsJson = json["imageAssets"] as? [String: Any] {
            imageAssets = BrandImageAssets(
                lightLogoUrl: assetsJson["lightLogoUrl"] as? String,
                darkLogoUrl: assetsJson["darkLogoUrl"] as? String,
                asset1Url: assetsJson["asset1Url"] as? String,
                asset2Url: assetsJson["asset2Url"] as? String,
                asset3Url: assetsJson["asset3Url"] as? String,
                asset4Url: assetsJson["asset4Url"] as? String,
                asset5Url: assetsJson["asset5Url"] as? String
            )
        }

        return BrandKitExtraction(
            brandName: brandName,
            brandAbout: brandAbout,
            brandPersonality: brandPersonality,
            fontFace: fontFace,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            accentColor: accentColor,
            backgroundColor: backgroundColor,
            additionalColors: additionalColors,
            imageAssets: imageAssets
        )
    }

    /// Normalizes a color string to proper hex format.
    private func normalizeHexColor(_ color: String?) -> String? {
        guard var hex = color?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() else {
            return nil
        }

        // Remove # if present
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }

        // Validate hex color (3 or 6 characters)
        let validChars = CharacterSet(charactersIn: "0123456789ABCDEF")
        guard hex.unicodeScalars.allSatisfy({ validChars.contains($0) }) else {
            return nil
        }

        if hex.count == 3 {
            // Expand 3-digit hex to 6-digit
            hex = hex.map { "\($0)\($0)" }.joined()
        }

        guard hex.count == 6 else {
            return nil
        }

        return "#\(hex)"
    }
}
