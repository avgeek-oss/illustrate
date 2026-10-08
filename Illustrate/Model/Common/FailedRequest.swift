// MARK: - FailedRequest.swift

// Tracks failed generation requests for debugging and retry.
//
// When a generation request fails, a FailedRequest entry is created to:
// - Show users what went wrong
// - Enable debugging with raw responses
// - Allow retrying failed requests with modifications
//
// ## Error Tracking
// Failed requests capture comprehensive error information:
// - `errorMessage`: Human-readable error description
// - `errorCode`: Provider-specific error code (if available)
// - `rawResponse`: Full API response for debugging

import Foundation
import SwiftData

// MARK: - Failed Request Model

/// SwiftData model tracking failed generation attempts.
///
/// Every failed generation creates a FailedRequest entry containing:
/// - The original request parameters
/// - Error details from the provider
/// - Debug information for troubleshooting
///
/// ## Use Cases
/// 1. **User visibility**: Shows what went wrong in the UI
/// 2. **Debugging**: raw response for investigation
/// 3. **Retry**: Original parameters enable retry with modifications
/// 4. **Analytics**: Track error patterns over time
///
/// ## Storage Considerations
/// Failed requests are persisted to help users track issues.
/// The `rawResponse` field can be large, so consider cleanup
/// policies for old failed requests.
@Model
class FailedRequest: Identifiable {
    #Index<FailedRequest>([\.projectId])

    var id = UUID()

    /// When the failure occurred
    var createdAt = Date()

    var projectId: UUID = Project.defaultProjectId

    var project: Project?

    // MARK: - Request Information

    /// The prompt that was submitted
    var prompt = ""

    /// Model UUID (as string) that was used
    var modelId = ""

    /// Requested output dimensions
    var dimensions = ""

    /// Whether this was a video generation request
    var isVideoGeneration = false

    // MARK: - Error Information

    /// Human-readable error message
    var errorMessage = ""

    /// Provider-specific error code (e.g., "content_policy_violation")
    var errorCode = ""

    // MARK: - Debug Information

    /// Raw API response body for debugging
    var rawResponse: String?

    /// Creates a new failed request entry.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - projectId: Parent project
    ///   - prompt: The prompt that was used
    ///   - modelId: Model UUID string
    ///   - dimensions: Requested output dimensions
    ///   - isVideoGeneration: Whether this was a video request
    ///   - errorMessage: Human-readable error description
    ///   - errorCode: Provider error code
    ///   - rawResponse: Raw API response
    init(
        id: UUID = UUID(),
        projectId: UUID = Project.defaultProjectId,
        prompt: String,
        modelId: String,
        dimensions: String = "",
        isVideoGeneration: Bool = false,
        errorMessage: String,
        errorCode: String = "",
        rawResponse: String? = nil
    ) {
        self.id = id
        createdAt = Date()
        self.projectId = projectId
        self.prompt = prompt
        self.modelId = modelId
        self.dimensions = dimensions
        self.isVideoGeneration = isVideoGeneration
        self.errorMessage = errorMessage
        self.errorCode = errorCode

        self.rawResponse = rawResponse
    }
}
