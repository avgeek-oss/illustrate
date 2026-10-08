// MARK: - ProviderModelData.swift

// Provider model definition for AI model configurations.
// This is a value type that can be converted to/from SwiftData models.

import Foundation

/// Value type representing a specific AI model's configuration.
///
/// Each ProviderModelData instance describes a single AI model (e.g., DALL-E 3,
/// Stable Diffusion XL, Veo 2) including its capabilities and API endpoints.
///
/// Note: Named `ProviderModelData` to avoid conflict with main app's SwiftData `ProviderModel` class.
public struct ProviderModelData: Codable, Sendable {
    /// ID of the parent provider (e.g., OpenAI, Stability AI)
    public var providerId: UUID

    /// Unique code identifying this specific model
    public var modelCode: EnumProviderModelCode

    /// Deterministic UUID derived from model code for consistent referencing
    public var modelId: UUID {
        modelCode.modelId
    }

    /// Type of generation this model performs (image generate, video generate, video extend)
    public var modelSetType: EnumSetType

    /// Display name for the model (e.g., "DALL-E 3", "Stable Diffusion XL")
    public var modelName: String

    /// Brief description of the model's capabilities
    public var modelDescription: String

    /// Comprehensive capability parameters for this model
    public var modelParams: ModelParams

    /// When the model was launched/became available
    public var modelLaunchDate: Date

    /// When the model will be/was deprecated (nil if not deprecated)
    public var modelDeprecationDate: Date?

    /// When this local contract was last checked against official documentation.
    public var modelVerificationDate: Date?

    /// Hard provider shutdown date, distinct from deprecation.
    public var modelShutdownDate: Date?

    /// Replacement model to present when this model is deprecated or disabled.
    public var replacementModelCode: EnumProviderModelCode?

    /// Source and verification metadata for the adapter's cost estimator.
    public var pricingMetadata: ProviderPricingMetadata?

    /// Base URL for the generation API endpoint
    public var modelGenerateBaseURL: String

    /// Base URL for checking generation status (for async operations)
    public var modelStatusBaseURL: String?

    /// Link to official API documentation
    public var modelAPIDocumentationURL: String

    /// Whether this model is currently active and usable
    public var active: Bool

    /// Parsed URL for checking generation status, if configured.
    /// Combines the nil check on `modelStatusBaseURL` with URL parsing.
    public var statusURL: URL? {
        guard let urlString = modelStatusBaseURL else { return nil }
        return URL(string: urlString)
    }

    /// Parsed URL for the generation API endpoint.
    public var generateURL: URL? {
        URL(string: modelGenerateBaseURL)
    }

    public init(
        providerId: UUID,
        modelCode: EnumProviderModelCode,
        modelSetType: EnumSetType,
        modelName: String,
        modelDescription: String,
        modelParams: ModelParams,
        modelLaunchDate: Date,
        modelDeprecationDate: Date? = nil,
        modelVerificationDate: Date? = nil,
        modelShutdownDate: Date? = nil,
        replacementModelCode: EnumProviderModelCode? = nil,
        pricingMetadata: ProviderPricingMetadata? = nil,
        modelGenerateBaseURL: String,
        modelStatusBaseURL: String? = nil,
        modelAPIDocumentationURL: String,
        active: Bool
    ) {
        self.providerId = providerId
        self.modelCode = modelCode
        self.modelSetType = modelSetType
        self.modelName = modelName
        self.modelDescription = modelDescription
        self.modelParams = modelParams
        self.modelLaunchDate = modelLaunchDate
        self.modelDeprecationDate = modelDeprecationDate
        self.modelVerificationDate = modelVerificationDate
        self.modelShutdownDate = modelShutdownDate
        self.replacementModelCode = replacementModelCode
        self.pricingMetadata = pricingMetadata
        self.modelGenerateBaseURL = modelGenerateBaseURL
        self.modelStatusBaseURL = modelStatusBaseURL
        self.modelAPIDocumentationURL = modelAPIDocumentationURL
        self.active = active
    }
}
