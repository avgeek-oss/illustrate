// MARK: - GenerationProtocols.swift

// Protocols for image and video generation adapters.

import Foundation

// MARK: - Image Generation Protocol

/// Protocol that all image generation adapters must implement.
public protocol ImageGenerationProtocol {
    /// The provider model this adapter handles
    var model: ProviderModelData { get }

    /// Associated type for the provider-specific request format
    associatedtype ServiceRequest

    /// Calculate the estimated cost for a generation request
    func getCostEstimate(request: ImageGenerationCostRequest) -> Double

    /// Format the cost as a displayable string
    func formatCost(request: ImageGenerationCostRequest) -> String

    /// Transform the unified request to provider-specific format
    func transformRequest(request: ImageGenerationRequest) -> ServiceRequest

    /// Transform the provider response to unified format
    func transformResponse(request: ImageGenerationRequest, response: NetworkResponseData) throws
        -> ImageGenerationResponse

    /// Execute the generation request
    func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse
}

// MARK: - Video Generation Protocol

/// Protocol that all video generation adapters must implement.
public protocol VideoGenerationProtocol {
    /// The provider model this adapter handles
    var model: ProviderModelData { get }

    /// Associated type for the provider-specific request format
    associatedtype ServiceRequest

    /// Calculate the estimated cost for a generation request
    func getCostEstimate(request: VideoGenerationCostRequest) -> Double

    /// Format the cost as a displayable string
    func formatCost(request: VideoGenerationCostRequest) -> String

    /// Transform the unified request to provider-specific format
    func transformRequest(request: VideoGenerationRequest) -> ServiceRequest

    /// Transform the provider response to unified format
    func transformResponse(request: VideoGenerationRequest, response: NetworkResponseData) throws
        -> VideoGenerationResponse

    /// Execute the generation request
    func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse
}

// MARK: - Asynchronous Job Control

/// Optional capability for providers that expose a remote cancellation endpoint.
///
/// Adapters should include `providerJobId` in response metadata so the app can
/// persist and later pass that identifier to this method.
public protocol ProviderJobControlProtocol {
    func cancel(jobId: String, providerSecret: String) async throws
}

/// Stable metadata keys shared by async image and video adapters.
public enum ProviderJobMetadataKey {
    public static let jobId = "providerJobId"
    public static let statusURL = "providerStatusURL"
    public static let cancelURL = "providerCancelURL"
}
