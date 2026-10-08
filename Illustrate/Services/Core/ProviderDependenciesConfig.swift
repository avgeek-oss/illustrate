// MARK: - ProviderDependenciesConfig.swift

// Configures IllustrateProviders package dependencies for the main app.
// Must be called at app startup before using any provider implementations.

import Foundation
import IllustrateProviders

// MARK: - Network Provider Implementation

/// Implementation of NetworkProvider that wraps the main app's NetworkAdapter.
///
/// Now that NetworkAdapter uses IllustrateProviders types directly,
/// no conversion is needed - types pass through unchanged.
struct AppNetworkProvider: NetworkProvider {
    func performRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        try await NetworkAdapter.shared.performRequest(
            url: url,
            method: method,
            body: body,
            headers: headers,
            attachments: attachments
        )
    }

    func performSingleAttemptRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseEnvelope {
        try await NetworkAdapter.shared.performSingleAttemptRequest(
            url: url,
            method: method,
            body: body,
            headers: headers,
            attachments: attachments
        )
    }

    func performRawRequest(_ request: URLRequest) async throws -> NetworkResponseData {
        try await NetworkAdapter.shared.performRawRequest(request)
    }

    func performDataRequest(_ request: URLRequest) async throws -> NetworkDataResponse {
        try await NetworkAdapter.shared.performDataRequest(request)
    }
}

// MARK: - Model Provider Implementation

/// Implementation of ModelProvider that wraps ProviderService.
struct AppModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        guard let swiftDataModel = ProviderService.shared.model(by: code) else {
            return nil
        }
        return swiftDataModel.toProviderModelData()
    }
}

// MARK: - ProviderModel Extension

extension ProviderModel {
    /// Converts SwiftData ProviderModel to IllustrateProviders ProviderModelData.
    func toProviderModelData() -> ProviderModelData {
        ProviderModelData(
            providerId: providerId,
            modelCode: modelCode,
            modelSetType: modelSetType,
            modelName: modelName,
            modelDescription: modelDescription,
            modelParams: modelParams,
            modelLaunchDate: modelLaunchDate,
            modelDeprecationDate: modelDeprecationDate,
            modelVerificationDate: modelVerificationDate,
            modelShutdownDate: modelShutdownDate,
            replacementModelCode: replacementModelCode,
            pricingMetadata: pricingMetadata,
            modelGenerateBaseURL: modelGenerateBaseURL,
            modelStatusBaseURL: modelStatusBaseURL,
            modelAPIDocumentationURL: modelAPIDocumentationURL,
            active: active
        )
    }
}

// MARK: - ProviderModelData Extension

extension ProviderModelData {
    /// Converts IllustrateProviders ProviderModelData to SwiftData ProviderModel.
    func toProviderModel() -> ProviderModel {
        ProviderModel(
            providerId: providerId,
            modelCode: modelCode,
            modelSetType: modelSetType,
            modelName: modelName,
            modelDescription: modelDescription,
            modelParams: modelParams,
            modelLaunchDate: modelLaunchDate,
            modelDeprecationDate: modelDeprecationDate,
            modelVerificationDate: modelVerificationDate,
            modelShutdownDate: modelShutdownDate,
            replacementModelCode: replacementModelCode,
            pricingMetadata: pricingMetadata,
            modelGenerateBaseURL: modelGenerateBaseURL,
            modelStatusBaseURL: modelStatusBaseURL,
            modelAPIDocumentationURL: modelAPIDocumentationURL,
            active: active
        )
    }
}

// MARK: - ProviderKey Extension

extension ProviderKey {
    /// Converts SwiftData ProviderKey to IllustrateProviders ProviderKeyInfo.
    func toProviderKeyInfo() throws -> ProviderKeyInfo {
        guard let provider = getProvider(providerId: providerId) else {
            throw NSError(
                domain: "ProviderKeyError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Provider not found for id: \(providerId)"]
            )
        }
        return ProviderKeyInfo(providerId: providerId, providerCode: provider.providerCode, projectId: projectId)
    }
}

// MARK: - Configuration Function

/// Configures the IllustrateProviders package dependencies.
/// Must be called at app startup before using any provider implementations.
func configureProviderDependencies() {
    ProviderDependencies.shared.configure(
        networkProvider: AppNetworkProvider(),
        modelProvider: AppModelProvider()
    )
}
