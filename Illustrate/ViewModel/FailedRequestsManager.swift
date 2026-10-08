// MARK: - FailedRequestsManager.swift

// Singleton manager for tracking and managing failed generation requests.
//
// When generation requests fail, this manager creates FailedRequest entries
// that are persisted in SwiftData. This enables:
// - Debugging failed requests with raw responses
// - Viewing error patterns over time
// - Clearing old failures
//
// ## Integration
// QueueManager calls this manager when generation adapters return errors.
// The manager persists the failure with all relevant debug information.

import Foundation
import OSLog
import SwiftData
import SwiftUI

/// Singleton manager for failed request tracking and cleanup.
///
/// This manager provides a simple interface for:
/// - Recording new failed requests with full debug context
/// - Deleting individual failed requests
/// - Bulk clearing failures for a project
@MainActor
class FailedRequestsManager: ObservableObject {
    /// Shared singleton instance
    static let shared = FailedRequestsManager()

    /// Maximum size for rawResponse storage (40 KB)
    private let maxRawResponseSize = 40 * 1024

    private init() {}

    /// Truncates rawResponse to maxRawResponseSize to prevent database bloat
    private func truncateRawResponse(_ response: String?) -> String? {
        guard let response else { return nil }

        if response.utf8.count <= maxRawResponseSize {
            return response
        }

        // Truncate to max size and append indicator
        let truncated = String(response.prefix(maxRawResponseSize))
        return truncated + "\n\n[Response truncated - original size: \(response.utf8.count) bytes]"
    }

    func addFailedRequest(
        modelContext: ModelContext,
        projectId: UUID,
        prompt: String,
        modelId: String,
        dimensions: String = "",
        isVideoGeneration: Bool = false,
        errorMessage: String,
        errorCode: String = "",
        rawResponse: String? = nil
    ) {
        let failedRequest = FailedRequest(
            projectId: projectId,
            prompt: prompt,
            modelId: modelId,
            dimensions: dimensions,
            isVideoGeneration: isVideoGeneration,
            errorMessage: errorMessage,
            errorCode: errorCode,
            rawResponse: truncateRawResponse(rawResponse)
        )

        modelContext.insert(failedRequest)
        // SwiftData autosave handles persistence - this reduces WAL checkpoint contention
    }

    func deleteFailedRequest(modelContext: ModelContext, request: FailedRequest) {
        modelContext.delete(request)

        do {
            try modelContext.save()
        } catch {
            AppLogger.data.error("Failed to delete failed request: \(error.localizedDescription, privacy: .public)")
        }
    }

    func clearAllFailedRequests(modelContext: ModelContext, projectId: UUID) {
        let descriptor = FetchDescriptor<FailedRequest>(
            predicate: #Predicate { $0.projectId == projectId }
        )

        do {
            let requests = try modelContext.fetch(descriptor)
            for request in requests {
                modelContext.delete(request)
            }
            try modelContext.save()
        } catch {
            AppLogger.data.error("Failed to clear failed requests: \(error.localizedDescription, privacy: .public)")
        }
    }
}
