// MARK: - ProviderAsyncJob.swift

import Foundation

/// Normalized state returned by provider-specific async job classifiers.
public enum ProviderAsyncJobState: Equatable, Sendable {
    case pending
    case succeeded
    case failed(String)
    case cancelled
}

public enum ProviderAsyncJobError: Error, Equatable, LocalizedError, Sendable {
    case failed(String)
    case cancelled
    case timedOut(maxAttempts: Int)

    public var errorDescription: String? {
        switch self {
        case let .failed(message):
            message
        case .cancelled:
            "The provider cancelled the generation job."
        case let .timedOut(maxAttempts):
            "The provider job did not finish after \(maxAttempts) status checks."
        }
    }
}

/// Bounded polling settings shared by asynchronous media providers.
public struct ProviderPollingPolicy: Equatable, Sendable {
    public var maxAttempts: Int
    public var intervalNanoseconds: UInt64

    public init(maxAttempts: Int = 120, intervalNanoseconds: UInt64 = 2_000_000_000) {
        precondition(maxAttempts > 0, "maxAttempts must be positive")
        self.maxAttempts = maxAttempts
        self.intervalNanoseconds = intervalNanoseconds
    }
}

/// Shared bounded poller for provider job APIs.
///
/// Provider adapters remain responsible for decoding their own status payload,
/// while this type enforces timeout, failure, cancellation, and sleep behavior.
public enum ProviderAsyncJobPoller {
    public static func poll<Response: Sendable>(
        policy: ProviderPollingPolicy = ProviderPollingPolicy(),
        fetch: @Sendable () async throws -> Response,
        classify: @Sendable (Response) throws -> ProviderAsyncJobState
    ) async throws -> Response {
        for attempt in 1 ... policy.maxAttempts {
            let response = try await fetch()
            switch try classify(response) {
            case .succeeded:
                return response
            case let .failed(message):
                throw ProviderAsyncJobError.failed(message)
            case .cancelled:
                throw ProviderAsyncJobError.cancelled
            case .pending:
                guard attempt < policy.maxAttempts else {
                    throw ProviderAsyncJobError.timedOut(maxAttempts: policy.maxAttempts)
                }
                if policy.intervalNanoseconds > 0 {
                    try await Task.sleep(nanoseconds: policy.intervalNanoseconds)
                }
            }
        }

        throw ProviderAsyncJobError.timedOut(maxAttempts: policy.maxAttempts)
    }
}
