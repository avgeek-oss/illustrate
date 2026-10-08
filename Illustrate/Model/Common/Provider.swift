// MARK: - Provider.swift

// Defines the core provider entities and configuration for AI service integrations.
//
// This file contains the foundational types for managing external AI providers
// (OpenAI, Stability AI, Google Cloud, Replicate, Fal AI) including their
// authentication methods, credit systems, and UI representations.
//
// ## Architecture
// Providers are configured statically in the `providers` array at the bottom of this file.
// Each provider has a deterministic UUID generated from its code string, ensuring
// consistent identification across app sessions and iCloud sync.
//
// ## Key Types
// - `EnumProviderCode`: Identifies supported AI providers
// - `EnumProviderKeyType`: Specifies authentication method (API key vs JSON credential)
// - `EnumProviderCreditCurrency`: Defines billing unit (USD vs provider-specific credits)
// - `Provider`: The main SwiftData model storing provider configuration

import Foundation
import IllustrateProviders
import SwiftData
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - JSON Credential Field

struct JSONCredentialField: Identifiable {
    let id: String
    let label: String
    let placeholder: String
    let isRequired: Bool
    let isSensitive: Bool

    init(
        id: String,
        label: String,
        placeholder: String,
        isRequired: Bool = true,
        isSensitive: Bool = false
    ) {
        self.id = id
        self.label = label
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.isSensitive = isSensitive
    }
}

// MARK: - Provider Model

/// SwiftData model representing an AI service provider configuration.
///
/// Each provider instance contains all the metadata needed to:
/// - Display provider information in the UI (name, description, icon)
/// - Validate API keys using regex patterns
/// - Direct users to provider documentation
/// - Check account balances (for supported providers)
///
/// ## Persistence
/// Provider instances are stored in SwiftData but the canonical source of truth
/// is the static `providers` array at the bottom of this file. The SwiftData
/// storage enables iCloud sync of user-specific configurations.
///
/// ## Key Validation
/// The `keyStructure` property contains a regex pattern used to validate
/// API keys before saving. The `keyPlaceholder` shows users the expected format.
///
/// ## Balance Checking
/// Providers that support balance checking (e.g., Stability AI) set:
/// - `supportsBalanceCheck = true`
/// - `balanceEndpoint` to the API URL for checking credits
@Model
final class Provider: Codable, Identifiable {
    enum CodingKeys: CodingKey {
        case providerId
        case providerCode
        case providerName
        case providerDescription
        case providerOnboardingUrl
        case keyStructure
        case keyPlaceholder
        case keyType
        case creditCurrency
        case active
        case supportsBalanceCheck
        case balanceEndpoint
    }

    /// Unique identifier for the provider (deterministic from provider code)
    var providerId = UUID()

    /// Enum code identifying the provider type
    var providerCode = EnumProviderCode.OPENAI

    /// Display name shown in UI (e.g., "OpenAI", "Stability AI")
    var providerName = "OpenAI"

    /// Short description of the provider for UI display
    var providerDescription = ""

    /// URL to provider's API documentation for user onboarding
    var providerOnboardingUrl = ""

    /// Regex pattern for validating API key format
    var keyStructure = ""

    /// Placeholder text showing expected key format
    var keyPlaceholder = ""

    /// Authentication type required by this provider
    var keyType = EnumProviderKeyType.JSON

    /// Billing currency used by this provider
    var creditCurrency = EnumProviderCreditCurrency.USD

    /// Whether this provider is currently enabled in the app
    var active = true

    /// Whether this provider supports checking account balance/credits
    var supportsBalanceCheck = false

    /// API endpoint URL for checking balance (if supported)
    var balanceEndpoint: String? = nil

    var jsonCredentialFields: [JSONCredentialField] {
        credentialFields
    }

    /// Named fields shown for JSON and multi-value provider configurations.
    var credentialFields: [JSONCredentialField] {
        guard keyType == .JSON || keyType == .CONFIGURATION else { return [] }
        switch providerCode {
        case .CLOUDFLARE_AI:
            return [
                JSONCredentialField(id: "account_id", label: "Account ID", placeholder: "your-account-id"),
                JSONCredentialField(
                    id: "api_token",
                    label: "API Token",
                    placeholder: "your-api-token",
                    isSensitive: true
                ),
            ]
        case .GOOGLE_VERTEX_AI:
            return [
                JSONCredentialField(
                    id: "access_token",
                    label: "OAuth Access Token",
                    placeholder: "Short-lived access token",
                    isSensitive: true
                ),
                JSONCredentialField(id: "project_id", label: "Project ID", placeholder: "my-gcp-project"),
                JSONCredentialField(id: "location", label: "Location", placeholder: "us-central1"),
            ]
        case .AZURE_AI_FOUNDRY:
            return [
                JSONCredentialField(
                    id: "endpoint",
                    label: "Resource Endpoint",
                    placeholder: "https://my-resource.openai.azure.com"
                ),
                JSONCredentialField(
                    id: "api_key",
                    label: "API Key",
                    placeholder: "Azure OpenAI API key",
                    isSensitive: true
                ),
                JSONCredentialField(
                    id: "image_deployment",
                    label: "GPT Image 2 Deployment",
                    placeholder: "gpt-image-2"
                ),
                JSONCredentialField(
                    id: "video_deployment",
                    label: "Sora 2 Deployment",
                    placeholder: "sora-2"
                ),
            ]
        case .AMAZON_BEDROCK:
            return [
                JSONCredentialField(
                    id: "api_key",
                    label: "Bedrock API Key",
                    placeholder: "Long-term or short-term Bedrock API key",
                    isSensitive: true
                ),
                JSONCredentialField(
                    id: "region",
                    label: "AWS Region",
                    placeholder: "us-west-2"
                ),
            ]
        case .ALIBABA_MODEL_STUDIO:
            return [
                JSONCredentialField(
                    id: "api_key",
                    label: "API Key",
                    placeholder: "Alibaba Model Studio API key",
                    isSensitive: true
                ),
                JSONCredentialField(
                    id: "workspace_id",
                    label: "Workspace ID",
                    placeholder: "your-workspace-id"
                ),
                JSONCredentialField(
                    id: "region",
                    label: "Region",
                    placeholder: "singapore or beijing"
                ),
            ]
        case .MINIMAX:
            return [
                JSONCredentialField(
                    id: "api_key",
                    label: "API Key",
                    placeholder: "MiniMax API key",
                    isSensitive: true
                ),
                JSONCredentialField(
                    id: "region",
                    label: "Region",
                    placeholder: "global or mainland"
                ),
            ]
        case .BYTEPLUS_MODELARK:
            return [
                JSONCredentialField(
                    id: "api_key",
                    label: "API Key",
                    placeholder: "ModelArk API key",
                    isSensitive: true
                ),
                JSONCredentialField(
                    id: "region",
                    label: "Region",
                    placeholder: "ap-southeast-1 or eu-west-1"
                ),
            ]
        default:
            return []
        }
    }

    init(
        providerId: UUID,
        providerCode: EnumProviderCode,
        providerName: String,
        providerDescription: String,
        providerOnboardingUrl: String,
        keyStructure: String,
        keyPlaceholder: String,
        keyType: EnumProviderKeyType,
        creditCurrency: EnumProviderCreditCurrency,
        active: Bool,
        supportsBalanceCheck: Bool = false,
        balanceEndpoint: String? = nil
    ) {
        self.providerId = providerId
        self.providerCode = providerCode
        self.providerName = providerName
        self.providerDescription = providerDescription
        self.providerOnboardingUrl = providerOnboardingUrl
        self.keyStructure = keyStructure
        self.keyPlaceholder = keyPlaceholder
        self.keyType = keyType
        self.creditCurrency = creditCurrency
        self.active = active
        self.supportsBalanceCheck = supportsBalanceCheck
        self.balanceEndpoint = balanceEndpoint
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerId = try container.decode(UUID.self, forKey: .providerId)
        providerCode = try container.decode(EnumProviderCode.self, forKey: .providerCode)
        providerName = try container.decode(String.self, forKey: .providerName)
        providerDescription = try container.decode(String.self, forKey: .providerDescription)
        providerOnboardingUrl = try container.decode(String.self, forKey: .providerOnboardingUrl)
        keyStructure = try container.decode(String.self, forKey: .keyStructure)
        keyPlaceholder = try container.decode(String.self, forKey: .keyPlaceholder)
        keyType = try container.decode(EnumProviderKeyType.self, forKey: .keyType)
        creditCurrency = try container.decode(EnumProviderCreditCurrency.self, forKey: .creditCurrency)
        active = try container.decode(Bool.self, forKey: .active)
        supportsBalanceCheck = try container.decodeIfPresent(Bool.self, forKey: .supportsBalanceCheck) ?? false
        balanceEndpoint = try container.decodeIfPresent(String.self, forKey: .balanceEndpoint)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(providerId, forKey: .providerId)
        try container.encode(providerCode, forKey: .providerCode)
        try container.encode(providerName, forKey: .providerName)
        try container.encode(providerDescription, forKey: .providerDescription)
        try container.encode(providerOnboardingUrl, forKey: .providerOnboardingUrl)
        try container.encode(keyStructure, forKey: .keyStructure)
        try container.encode(keyPlaceholder, forKey: .keyPlaceholder)
        try container.encode(keyType, forKey: .keyType)
        try container.encode(creditCurrency, forKey: .creditCurrency)
        try container.encode(active, forKey: .active)
        try container.encode(supportsBalanceCheck, forKey: .supportsBalanceCheck)
        try container.encodeIfPresent(balanceEndpoint, forKey: .balanceEndpoint)
    }
}

// MARK: - Provider Lookup Functions

/// Retrieves the provider associated with a specific model ID.
///
/// This function performs a two-step lookup:
/// 1. Finds the model configuration using ProviderService
/// 2. Maps the model's providerId to the corresponding Provider instance
///
/// - Parameter modelId: The UUID string of the model to look up
/// - Returns: The Provider instance if found, nil otherwise
func getProvider(modelId: String) -> Provider? {
    let model = ProviderService.shared.model(by: modelId)
    guard let providerId = model?.providerId else { return nil }
    return providersById[providerId]
}

/// Retrieves a provider by its unique identifier.
///
/// - Parameter providerId: The UUID of the provider to find
/// - Returns: The Provider instance if found, nil otherwise
func getProvider(providerId: UUID) -> Provider? {
    providersById[providerId]
}

// MARK: - Provider Artwork

/// Artwork variants used by provider rows, pickers, and detail views.
enum ProviderArtworkVariant: CaseIterable {
    case base
    case square
    case trimmed

    fileprivate var suffix: String {
        switch self {
        case .base: ""
        case .square: "_square"
        case .trimmed: "_trimmed"
        }
    }

    fileprivate var fallbackAssetName: String {
        switch self {
        case .base: "provider_generic"
        case .square: "provider_generic_square"
        case .trimmed: "provider_generic_trimmed"
        }
    }
}

/// Resolves official provider artwork when bundled and a guaranteed generic
/// variant otherwise, preventing SwiftUI's missing-name behavior from
/// silently rendering an empty image.
func providerArtworkName(
    code: EnumProviderCode,
    variant: ProviderArtworkVariant
) -> String {
    providerArtworkName(code: code.rawValue, variant: variant)
}

func providerArtworkName(
    code: String,
    variant: ProviderArtworkVariant
) -> String {
    let requestedName = "\(code.lowercased())\(variant.suffix)"
    return providerArtworkExists(named: requestedName) ? requestedName : variant.fallbackAssetName
}

private func providerArtworkExists(named name: String) -> Bool {
    #if os(macOS)
    NSImage(named: NSImage.Name(name)) != nil
    #else
    UIImage(named: name) != nil
    #endif
}

// MARK: - Provider Label View

/// A reusable SwiftUI view displaying a provider's icon and name.
///
/// Used throughout the app wherever provider identification is needed,
/// such as in dropdown menus, list rows, and detail headers.
///
/// The icon is loaded from Assets using the naming convention:
/// `{providerCode}_square` in lowercase (e.g., "openai_square")
struct ProviderLabel: View {
    var provider: Provider

    var body: some View {
        HStack {
            // Load provider icon from Assets using code-based naming
            Image(providerArtworkName(code: provider.providerCode, variant: .square))
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
            Text(provider.providerName)
        }
    }
}

// MARK: - Static Provider Definitions

/// The canonical list of all supported AI providers.
///
/// This array serves as the single source of truth for provider configurations.
/// Each provider entry contains:
/// - Provider identification and metadata
/// - API key validation patterns
/// - Authentication type requirements
/// - Balance checking capabilities
///
/// ## Important
/// Provider UUIDs are deterministic (derived from provider codes) to ensure
/// consistency across devices and iCloud sync. Never manually create UUIDs.
///
/// ## Adding New Providers
/// To add a new provider:
/// 1. Add a case to `EnumProviderCode`
/// 2. Add a Provider instance here with correct configuration
/// 3. Create model definitions in Services/Provider/Models/
/// 4. Add protocol implementations in Services/Provider/Protocols/
let providers = [
    Provider(
        providerId: EnumProviderCode.OPENAI.providerId,
        providerCode: EnumProviderCode.OPENAI,
        providerName: "OpenAI",
        providerDescription: "Creating safe AGI that benefits all of humanity.",
        providerOnboardingUrl: "https://platform.openai.com/docs/overview",
        keyStructure: "^sk-proj-[a-zA-Z0-9]{32}$",
        keyPlaceholder: "sk-proj-************",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.STABILITY_AI.providerId,
        providerCode: EnumProviderCode.STABILITY_AI,
        providerName: "Stability AI",
        providerDescription: "World's leading open source generative AI company.",
        providerOnboardingUrl: "https://platform.stability.ai/docs/api-reference",
        keyStructure: "^sk-[a-zA-Z0-9]{38}$",
        keyPlaceholder: "sk-************",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.CREDITS,
        active: true,
        supportsBalanceCheck: true,
        balanceEndpoint: "https://api.stability.ai/v1/user/balance"
    ),
    Provider(
        providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
        providerCode: EnumProviderCode.GOOGLE_CLOUD,
        providerName: "Google Cloud",
        providerDescription: "High-performance infrastructure for cloud.",
        providerOnboardingUrl: "https://console.cloud.google.com/apis/credentials",
        keyStructure: "^AIza[a-zA-Z0-9_-]{35}$",
        keyPlaceholder: "AIza************",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.REPLICATE.providerId,
        providerCode: EnumProviderCode.REPLICATE,
        providerName: "Replicate",
        providerDescription: "Making ML accessible to every software developer.",
        providerOnboardingUrl: "https://replicate.com",
        keyStructure: "^r8_[a-zA-Z0-9]{38}$",
        keyPlaceholder: "r8_************",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.FAL_AI.providerId,
        providerCode: EnumProviderCode.FAL_AI,
        providerName: "Fal AI",
        providerDescription: "Fast, reliable, cheap. Lightning fast inference.",
        providerOnboardingUrl: "https://fal.ai",
        keyStructure: "^$",
        keyPlaceholder: "********-****-****-****-************:*******************",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.FIRECRAWL.providerId,
        providerCode: EnumProviderCode.FIRECRAWL,
        providerName: "Firecrawl",
        providerDescription: "Turn websites into LLM-ready data with web scraping.",
        providerOnboardingUrl: "https://www.firecrawl.dev",
        keyStructure: "^fc-[a-f0-9]{32}$",
        keyPlaceholder: "fc-********************************",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.TOGETHER_AI.providerId,
        providerCode: EnumProviderCode.TOGETHER_AI,
        providerName: "Together AI",
        providerDescription: "Run, train, and serve open-source AI models with fast inference.",
        providerOnboardingUrl: "https://docs.together.ai/docs/quickstart",
        keyStructure: "^[a-f0-9]{64}$",
        keyPlaceholder: "****************************************",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.LUMA_AI.providerId,
        providerCode: EnumProviderCode.LUMA_AI,
        providerName: "Luma AI",
        providerDescription: "AI-powered image and video generation with cinematic quality.",
        providerOnboardingUrl: "https://platform.lumalabs.ai",
        keyStructure: "^[a-zA-Z0-9_-]+$",
        keyPlaceholder: "luma-********************************",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true,
        supportsBalanceCheck: true,
        balanceEndpoint: "https://api.lumalabs.ai/dream-machine/v1/credits"
    ),
    Provider(
        providerId: EnumProviderCode.CLOUDFLARE_AI.providerId,
        providerCode: EnumProviderCode.CLOUDFLARE_AI,
        providerName: "Cloudflare AI",
        providerDescription: "Serverless AI inference at the edge. Fast, affordable image generation.",
        providerOnboardingUrl: "https://dash.cloudflare.com/?to=/:account/workers/ai",
        keyStructure: "^\\s*\\{[\\s\\S]*\\}\\s*$",
        keyPlaceholder: "{\"account_id\":\"...\",\"api_token\":\"...\"}",
        keyType: EnumProviderKeyType.JSON,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.RECRAFT.providerId,
        providerCode: EnumProviderCode.RECRAFT,
        providerName: "Recraft",
        providerDescription: "Production-ready raster image generation with precise visual control.",
        providerOnboardingUrl: "https://www.recraft.ai/docs/api-reference/getting-started",
        keyStructure: "^.+$",
        keyPlaceholder: "Recraft API token",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.IDEOGRAM.providerId,
        providerCode: EnumProviderCode.IDEOGRAM,
        providerName: "Ideogram",
        providerDescription: "Typography-focused image generation for polished creative work.",
        providerOnboardingUrl: "https://developer.ideogram.ai/ideogram-api/api-setup",
        keyStructure: "^.+$",
        keyPlaceholder: "Ideogram API key",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.BLACK_FOREST_LABS.providerId,
        providerCode: EnumProviderCode.BLACK_FOREST_LABS,
        providerName: "Black Forest Labs",
        providerDescription: "Direct access to reproducible FLUX image generation endpoints.",
        providerOnboardingUrl: "https://docs.bfl.ai/quick_start/introduction",
        keyStructure: "^.+$",
        keyPlaceholder: "BFL API key",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.CREDITS,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.BRIA.providerId,
        providerCode: EnumProviderCode.BRIA,
        providerName: "Bria AI",
        providerDescription: "Commercially safe, controllable image generation powered by licensed data.",
        providerOnboardingUrl: "https://platform.bria.ai",
        keyStructure: "^.+$",
        keyPlaceholder: "Bria API token",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.RUNWAY.providerId,
        providerCode: EnumProviderCode.RUNWAY,
        providerName: "Runway",
        providerDescription: "First-party image and video generation through Runway's developer API.",
        providerOnboardingUrl: "https://docs.dev.runwayml.com/guides/setup/",
        keyStructure: "^key_[A-Fa-f0-9]{128}$",
        keyPlaceholder: "key_********************************",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.CREDITS,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.LTX.providerId,
        providerCode: EnumProviderCode.LTX,
        providerName: "LTX",
        providerDescription: "Managed video generation with synchronized audio and cinematic output.",
        providerOnboardingUrl: "https://docs.ltx.video/authentication",
        keyStructure: "^.+$",
        keyPlaceholder: "LTX API key",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.GOOGLE_VERTEX_AI.providerId,
        providerCode: EnumProviderCode.GOOGLE_VERTEX_AI,
        providerName: "Google Vertex AI",
        providerDescription: "Google Cloud media models using project-scoped short-lived OAuth access.",
        providerOnboardingUrl: "https://cloud.google.com/vertex-ai/generative-ai/docs/start/gcp-auth",
        keyStructure: "^\\s*\\{[\\s\\S]*\\}\\s*$",
        keyPlaceholder: "OAuth token, project ID, and location",
        keyType: EnumProviderKeyType.CONFIGURATION,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.AZURE_AI_FOUNDRY.providerId,
        providerCode: EnumProviderCode.AZURE_AI_FOUNDRY,
        providerName: "Azure AI Foundry",
        providerDescription: "Azure-hosted GPT Image and Sora deployments with resource-scoped credentials.",
        providerOnboardingUrl: "https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/create-resource",
        keyStructure: "^\\s*\\{[\\s\\S]*\\}\\s*$",
        keyPlaceholder: "Endpoint, API key, and deployment names",
        keyType: EnumProviderKeyType.CONFIGURATION,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.AMAZON_BEDROCK.providerId,
        providerCode: EnumProviderCode.AMAZON_BEDROCK,
        providerName: "Amazon Bedrock",
        providerDescription: "Managed image inference through region-scoped Bedrock Runtime endpoints.",
        providerOnboardingUrl: "https://docs.aws.amazon.com/bedrock/latest/userguide/getting-started-api-keys.html",
        keyStructure: "^\\s*\\{[\\s\\S]*\\}\\s*$",
        keyPlaceholder: "Bedrock API key and AWS region",
        keyType: EnumProviderKeyType.CONFIGURATION,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.ALIBABA_MODEL_STUDIO.providerId,
        providerCode: EnumProviderCode.ALIBABA_MODEL_STUDIO,
        providerName: "Alibaba Model Studio",
        providerDescription: "Regional managed Wan image and video generation APIs.",
        providerOnboardingUrl: "https://www.alibabacloud.com/help/en/model-studio/get-api-key",
        keyStructure: "^\\s*\\{[\\s\\S]*\\}\\s*$",
        keyPlaceholder: "{\"api_key\":\"...\",\"workspace_id\":\"...\",\"region\":\"singapore\"}",
        keyType: EnumProviderKeyType.CONFIGURATION,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.MINIMAX.providerId,
        providerCode: EnumProviderCode.MINIMAX,
        providerName: "MiniMax",
        providerDescription: "Direct Image-01 and Hailuo media generation APIs.",
        providerOnboardingUrl: "https://platform.minimax.io/user-center/basic-information/interface-key",
        keyStructure: "^\\s*\\{[\\s\\S]*\\}\\s*$",
        keyPlaceholder: "{\"api_key\":\"...\",\"region\":\"global\"}",
        keyType: EnumProviderKeyType.CONFIGURATION,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.KLING_AI.providerId,
        providerCode: EnumProviderCode.KLING_AI,
        providerName: "Kling AI",
        providerDescription: "Direct Kling image and video generation APIs.",
        providerOnboardingUrl: "https://app.klingai.com/global/dev/document-api/quickStart/userManual",
        keyStructure: "^(?!\\{)\\S{1,4096}$",
        keyPlaceholder: "Kling API key",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.XAI.providerId,
        providerCode: EnumProviderCode.XAI,
        providerName: "xAI",
        providerDescription: "First-party Grok Imagine image and video generation APIs.",
        providerOnboardingUrl: "https://console.x.ai/",
        keyStructure: "^.+$",
        keyPlaceholder: "xAI API key",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.BYTEPLUS_MODELARK.providerId,
        providerCode: EnumProviderCode.BYTEPLUS_MODELARK,
        providerName: "BytePlus ModelArk",
        providerDescription: "First-party Seedream image and Seedance video generation through ModelArk.",
        providerOnboardingUrl: "https://docs.byteplus.com/en/docs/modelark/1298459",
        keyStructure: "^.+$",
        keyPlaceholder: "ModelArk API key and region",
        keyType: EnumProviderKeyType.CONFIGURATION,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.VIDU.providerId,
        providerCode: EnumProviderCode.VIDU,
        providerName: "Vidu",
        providerDescription: "First-party Vidu Q3 text-to-video generation with synchronized audio.",
        providerOnboardingUrl: "https://platform.vidu.com/docs/quick-start",
        keyStructure: "^.+$",
        keyPlaceholder: "Vidu API key",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.PIXVERSE.providerId,
        providerCode: EnumProviderCode.PIXVERSE,
        providerName: "PixVerse",
        providerDescription: "First-party cinematic video generation with synchronized audio.",
        providerOnboardingUrl: "https://docs.platform.pixverse.ai/how-to-get-api-key-796037m0",
        keyStructure: "^.+$",
        keyPlaceholder: "PixVerse API key",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.CREDITS,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.DEEPINFRA.providerId,
        providerCode: EnumProviderCode.DEEPINFRA,
        providerName: "DeepInfra",
        providerDescription: "OpenAI-compatible image generation on managed open-model infrastructure.",
        providerOnboardingUrl: "https://docs.deepinfra.com/quickstart",
        keyStructure: "^.+$",
        keyPlaceholder: "DeepInfra API token",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
    Provider(
        providerId: EnumProviderCode.NOVITA_AI.providerId,
        providerCode: EnumProviderCode.NOVITA_AI,
        providerName: "Novita AI",
        providerDescription: "Managed multimodal inference through asynchronous image and video APIs.",
        providerOnboardingUrl: "https://novita.ai/docs/get-started/quickstart",
        keyStructure: "^.+$",
        keyPlaceholder: "Novita AI API key",
        keyType: EnumProviderKeyType.API,
        creditCurrency: EnumProviderCreditCurrency.USD,
        active: true
    ),
]

let providersById: [UUID: Provider] = {
    var dict = [UUID: Provider]()
    dict.reserveCapacity(providers.count)
    for provider in providers {
        dict[provider.providerId] = provider
    }
    return dict
}()
