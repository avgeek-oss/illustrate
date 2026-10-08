// MARK: - ProviderDependencies.swift

// Dependency injection for provider implementations.
// Allows the main app to inject network and provider service implementations.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Network Provider Protocol

/// Protocol for performing network requests.
/// The main app provides an implementation that wraps NetworkAdapter.
public protocol NetworkProvider: Sendable {
    func performRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData

    /// Performs one application-level HTTP attempt, without automatic retry,
    /// and preserves the response for all status codes. Use this for
    /// non-idempotent paid generation requests.
    /// Safe polling GETs should continue to use `performRequest` so they keep
    /// the normal transient-error retry behavior.
    func performSingleAttemptRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseEnvelope

    /// Performs a fully constructed request without re-encoding its body.
    /// Required for OAuth form posts and signature schemes such as AWS SigV4,
    /// where the signed bytes must exactly match the transmitted bytes.
    func performRawRequest(_ request: URLRequest) async throws -> NetworkResponseData

    /// Downloads unparsed bytes for temporary image and video result URLs.
    func performDataRequest(_ request: URLRequest) async throws -> NetworkDataResponse
}

public extension NetworkProvider {
    func performSingleAttemptRequest(
        url _: URL,
        method _: String,
        body _: (some Codable & Sendable)?,
        headers _: [String: String]?,
        attachments _: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseEnvelope {
        // Compatibility default for existing test doubles. Failing closed is
        // safer than delegating to a potentially retrying implementation.
        throw URLError(.unsupportedURL)
    }

    func performRawRequest(_: URLRequest) async throws -> NetworkResponseData {
        throw URLError(.unsupportedURL)
    }

    func performDataRequest(_: URLRequest) async throws -> NetworkDataResponse {
        throw URLError(.unsupportedURL)
    }
}

// MARK: - Model Provider Protocol

/// Protocol for accessing provider models.
/// The main app provides an implementation that wraps ProviderService.
public protocol ModelProvider: Sendable {
    func model(by code: EnumProviderModelCode) -> ProviderModelData?
}

// MARK: - Provider Dependencies

private struct DefaultModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        AllModels.createModels().first { $0.modelCode == code }
    }
}

private struct ProviderDependencyOverride {
    let networkProvider: any NetworkProvider
    let modelProvider: any ModelProvider
}

/// Central registration point for provider dependencies.
/// Must be configured by the main app before using provider implementations.
public final class ProviderDependencies: @unchecked Sendable {
    public static let shared = ProviderDependencies()

    @TaskLocal private static var taskOverride: ProviderDependencyOverride?

    private var _networkProvider: (any NetworkProvider)?
    private var _modelProvider: any ModelProvider = DefaultModelProvider()
    private let lock = NSLock()

    private init() {}

    /// The network provider for making API requests.
    public var networkProvider: any NetworkProvider {
        if let override = Self.taskOverride {
            return override.networkProvider
        }

        lock.lock()
        defer { lock.unlock() }
        guard let provider = _networkProvider else {
            fatalError("ProviderDependencies.networkProvider not configured. Call configure() first.")
        }
        return provider
    }

    /// The model provider for accessing provider models.
    public var modelProvider: any ModelProvider {
        if let override = Self.taskOverride {
            return override.modelProvider
        }

        lock.lock()
        defer { lock.unlock() }
        return _modelProvider
    }

    /// Configure the provider dependencies.
    /// Must be called by the main app during initialization.
    public func configure(
        networkProvider: some NetworkProvider,
        modelProvider: some ModelProvider
    ) {
        lock.lock()
        defer { lock.unlock() }
        _networkProvider = networkProvider
        _modelProvider = modelProvider
    }

    /// Check if dependencies are configured.
    public var isConfigured: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _networkProvider != nil
    }

    /// Run an operation with dependencies scoped to the current Swift task.
    /// This keeps concurrent tests isolated without mutating app-wide configuration.
    public func withDependencies<Result>(
        networkProvider: some NetworkProvider,
        modelProvider: some ModelProvider,
        operation: () async throws -> Result
    ) async rethrows -> Result {
        try await Self.$taskOverride.withValue(
            ProviderDependencyOverride(
                networkProvider: networkProvider,
                modelProvider: modelProvider
            ),
            operation: operation
        )
    }

    /// Run a synchronous operation with dependencies scoped to the current Swift task.
    public func withDependencies<Result>(
        networkProvider: some NetworkProvider,
        modelProvider: some ModelProvider,
        operation: () throws -> Result
    ) rethrows -> Result {
        try Self.$taskOverride.withValue(
            ProviderDependencyOverride(
                networkProvider: networkProvider,
                modelProvider: modelProvider
            ),
            operation: operation
        )
    }
}
