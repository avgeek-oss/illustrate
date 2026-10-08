// MARK: - GeminiFinishReason.swift

// Enum for Google Gemini API finish reasons.
//
// Maps API response finish reasons to determine success/failure
// and provide user-friendly error messages.

import Foundation

// MARK: - Gemini Finish Reason

/// Gemini API finish reason codes with error detection.
enum GeminiFinishReason: String, CaseIterable {
    case unspecified = "FINISH_REASON_UNSPECIFIED"
    case stop = "STOP"
    case maxTokens = "MAX_TOKENS"
    case safety = "SAFETY"
    case recitation = "RECITATION"
    case other = "OTHER"
    case blocklist = "BLOCKLIST"
    case prohibitedContent = "PROHIBITED_CONTENT"
    case spii = "SPII"
    case malformedFunctionCall = "MALFORMED_FUNCTION_CALL"
    case modelArmor = "MODEL_ARMOR"
    case imageSafety = "IMAGE_SAFETY"
    case imageProhibitedContent = "IMAGE_PROHIBITED_CONTENT"
    case imageRecitation = "IMAGE_RECITATION"
    case imageOther = "IMAGE_OTHER"
    case unexpectedToolCall = "UNEXPECTED_TOOL_CALL"
    case noImage = "NO_IMAGE"

    /// Returns true if this finish reason indicates an error condition
    var isError: Bool {
        switch self {
        case .stop:
            false
        default:
            true
        }
    }

    /// Returns true if this finish reason is related to image generation failures
    var isImageError: Bool {
        switch self {
        case .imageSafety, .imageProhibitedContent, .imageRecitation, .imageOther, .noImage:
            true
        default:
            false
        }
    }

    /// User-friendly description of the finish reason
    var userDescription: String {
        switch self {
        case .unspecified:
            "The generation stopped for an unspecified reason."
        case .stop:
            "The model reached a natural stopping point."
        case .maxTokens:
            "The model generated the maximum number of tokens allowed."
        case .safety:
            "The content was blocked because it potentially violates safety policies."
        case .recitation:
            "The content was blocked because it may be a recitation from a source."
        case .other:
            "The model stopped generating for an unspecified reason."
        case .blocklist:
            "The content contains a term from a configured blocklist."
        case .prohibitedContent:
            "The content may be prohibited."
        case .spii:
            "The content may contain sensitive personally identifiable information (SPII)."
        case .malformedFunctionCall:
            "The model generated a function call that is syntactically invalid."
        case .modelArmor:
            "The response was blocked by Model Armor."
        case .imageSafety:
            "The generated image potentially violates safety policies."
        case .imageProhibitedContent:
            "The generated image may contain prohibited content."
        case .imageRecitation:
            "The generated image may be a recitation from a source."
        case .imageOther:
            "Image generation stopped for an unspecified reason."
        case .unexpectedToolCall:
            "The model generated an invalid function call."
        case .noImage:
            "The model was expected to generate an image, but didn't. Try rephrasing your prompt or using a different model."
        }
    }

    /// Creates a GeminiFinishReason from a raw string value
    /// - Parameter rawValue: The string value from the API response
    /// - Returns: The matching finish reason, or nil if not recognized
    static func from(_ rawValue: String?) -> GeminiFinishReason? {
        guard let rawValue else { return nil }
        return GeminiFinishReason(rawValue: rawValue)
    }
}
