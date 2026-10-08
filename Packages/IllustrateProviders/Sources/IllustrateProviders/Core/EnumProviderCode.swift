// MARK: - EnumProviderCode.swift

import Foundation

// MARK: - Provider Code Enumeration

/// Unique identifier codes for supported AI providers.
///
/// Each code maps to a deterministic UUID via SHA256 hashing, ensuring consistent
/// provider identification across devices and iCloud sync. The raw string value
/// is used for persistence and API identification.
///
/// ## Adding New Providers
/// See the provider package README for the model registration guide.
/// New providers require:
/// 1. Adding a case here
/// 2. Creating a Provider instance in the `providers` array
/// 3. Adding model definitions in Services/Provider/Models/
public enum EnumProviderCode: String, Codable, CaseIterable, Identifiable, Sendable {
    public var id: String {
        rawValue
    }

    case GOOGLE_CLOUD
    case OPENAI
    case STABILITY_AI
    case REPLICATE
    case FAL_AI
    case FIRECRAWL
    case TOGETHER_AI
    case LUMA_AI
    case CLOUDFLARE_AI
    case RECRAFT
    case IDEOGRAM
    case BLACK_FOREST_LABS
    case BRIA
    case RUNWAY
    case LTX
    case GOOGLE_VERTEX_AI
    case AZURE_AI_FOUNDRY
    case AMAZON_BEDROCK
    case ALIBABA_MODEL_STUDIO
    case MINIMAX
    case KLING_AI
    case XAI
    case BYTEPLUS_MODELARK
    case VIDU
    case PIXVERSE
    case DEEPINFRA
    case NOVITA_AI

    /// Generates a deterministic UUID from the provider code string.
    /// Uses SHA256 hashing to ensure the same code always produces the same UUID.
    public var providerId: UUID {
        UUID.deterministicUUID(from: rawValue)
    }
}

// MARK: - Provider Key Type Enumeration

/// Specifies the authentication method required by a provider.
///
/// Different providers use different authentication mechanisms:
/// - `.API`: Simple API key string (most common, e.g., OpenAI, Stability AI)
/// - `.JSON`: JSON credential file (used by Google Cloud service accounts)
public enum EnumProviderKeyType: String, Codable, CaseIterable, Identifiable, Sendable {
    public var id: String {
        rawValue
    }

    /// JSON credential file authentication (e.g., Google Cloud service account)
    case JSON
    /// Simple API key string authentication
    case API = "API Key"
    /// Multiple named values stored together as an opaque JSON object.
    case CONFIGURATION = "Configuration"

    /// Human-readable label for UI display
    public var label: String {
        switch self {
        case .JSON:
            "JSON credential"
        case .API:
            "API key"
        case .CONFIGURATION:
            "configuration"
        }
    }
}

// MARK: - Credit Currency Enumeration

/// Defines the billing unit used by a provider.
///
/// Providers bill differently:
/// - `.USD`: Direct dollar billing (OpenAI, Replicate, Fal AI, Google Cloud)
/// - `.CREDITS`: Provider-specific credit system (Stability AI)
public enum EnumProviderCreditCurrency: String, Codable, CaseIterable, Identifiable, Sendable {
    public var id: String {
        rawValue
    }

    /// US Dollar billing
    case USD
    /// Provider-specific credit units (e.g., Stability AI credits)
    case CREDITS = "Credits"
}
