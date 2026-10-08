// MARK: - EnumGenerationStatus.swift

// Shared enumeration for generation status across the app and packages.

import Foundation

// MARK: - Generation Status

/// Tracks the outcome of a generation request.
///
/// Used to filter and display generations appropriately:
/// - GENERATED: Successfully completed, file available
/// - FAILED: Request failed, see FailedRequest for details
public enum EnumGenerationStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    public var id: String {
        rawValue
    }

    /// Generation completed successfully
    case GENERATED
    /// Generation failed (error details in FailedRequest)
    case FAILED
}

// MARK: - Error Codes

/// Unified error codes for generation adapter failures.
///
/// Used to categorize errors for UI display and debugging.
public enum EnumGenerationAdapterErrorCode: String, Codable, Sendable {
    case GENERATOR_ERROR = "Internal Generator Error"
    case MODEL_ERROR = "Provider Model Error"
    case ADAPTER_ERROR = "Internal Adapter Error"
    case TRANSFORM_RESPONSE_ERROR = "Internal Response Transform Error"
}
