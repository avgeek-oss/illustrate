// MARK: - ResponseHelpers.swift

// Helper functions for processing API responses.

import Foundation

/// Extract a raw response string from NetworkResponseData for debugging.
///
/// - Note: Prefer using `response.rawResponseString` directly instead.
@available(*, deprecated, message: "Use response.rawResponseString instead")
public func extractRawResponse(from response: NetworkResponseData) -> String? {
    response.rawResponseString
}

/// Creates an "Invalid response" error for when the API returns an unexpected format.
public func createInvalidResponseError(
    response: NetworkResponseData,
    modelCode: EnumProviderModelCode,
    customMessage: String = "Invalid response"
) -> ImageGenerationResponse {
    ImageGenerationResponse(
        status: .FAILED,
        errorCode: .MODEL_ERROR,
        errorMessage: customMessage,
        rawResponse: response.rawResponseString
    )
}

/// Creates an "Invalid response" error for video generation.
public func createInvalidVideoResponseError(
    response: NetworkResponseData,
    modelCode: EnumProviderModelCode,
    customMessage: String = "Invalid response"
) -> VideoGenerationResponse {
    VideoGenerationResponse(
        status: .FAILED,
        errorCode: .MODEL_ERROR,
        errorMessage: customMessage,
        rawResponse: response.rawResponseString
    )
}

/// Creates an error response for when the model's status URL is missing or invalid.
public func createInvalidStatusURLError() -> ImageGenerationResponse {
    ImageGenerationResponse(
        status: .FAILED,
        errorCode: .MODEL_ERROR,
        errorMessage: "Invalid status URL"
    )
}

/// Creates a video error response for when the model's status URL is missing or invalid.
public func createInvalidVideoStatusURLError() -> VideoGenerationResponse {
    VideoGenerationResponse(
        status: .FAILED,
        errorCode: .MODEL_ERROR,
        errorMessage: "Invalid status URL"
    )
}
