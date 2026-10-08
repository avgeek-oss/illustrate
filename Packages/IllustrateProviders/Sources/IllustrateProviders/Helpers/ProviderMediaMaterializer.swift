// MARK: - ProviderMediaMaterializer.swift

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ProviderMediaMaterializer {
    /// Downloads a temporary provider result and returns the bytes as base64.
    ///
    /// Illustrate's existing persistence layer consumes base64 for both images
    /// and videos. Keeping the download behind `NetworkProvider` makes the
    /// complete create, poll, and materialize workflow fixture-testable.
    public static func base64(
        from url: URL,
        headers: [String: String] = [:],
        network: any NetworkProvider
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let response = try await network.performDataRequest(request)
        guard (200 ... 299).contains(response.statusCode) else {
            throw ProviderMediaMaterializerError.httpStatus(response.statusCode)
        }
        guard !response.data.isEmpty else {
            throw ProviderMediaMaterializerError.emptyResponse
        }
        return response.data.base64EncodedString()
    }
}

public enum ProviderMediaMaterializerError: Error, Equatable, LocalizedError, Sendable {
    case httpStatus(Int)
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case let .httpStatus(code):
            "Provider media download failed with HTTP \(code)."
        case .emptyResponse:
            "Provider media download returned no data."
        }
    }
}
