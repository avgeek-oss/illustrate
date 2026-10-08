// MARK: - ProviderModel.swift

// Defines AI model configurations and their capabilities for image/video generation.
//
// This is a central file in the application that defines:
// - All supported AI models across providers (EnumProviderModelCode)
// - Model capability parameters (ModelParams)
// - The ProviderModel SwiftData entity
//
// ## Architecture Overview
// Each AI provider (OpenAI, Stability, etc.) offers multiple models with different
// capabilities. This file provides a unified way to describe what each model can do,
// enabling the UI to dynamically show/hide options based on model capabilities.
//
// ## Model Parameters System
// The `ModelParams` struct is a comprehensive capability descriptor that tells the UI:
// - What input types the model accepts (images, masks, prompts)
// - What output options are available (dimensions, quality, duration)
// - What parameter ranges are valid (guidance, steps, safety)
//
// ## Cost Calculation
// The `EnumProviderModelCode` enum includes methods to calculate generation costs,
// which delegate to provider-specific adapters for accurate pricing.

import Foundation
import IllustrateProviders
import SwiftData
import SwiftUI

// MARK: - Cost Calculation Extension

extension EnumProviderModelCode {
    // MARK: - Image Cost Calculation

    /// Calculates and formats the cost for image generation with this model.
    ///
    /// The cost depends on model-specific pricing which varies by:
    /// - Quality setting (e.g., "hd" vs "standard" for DALL-E 3)
    /// - Output dimensions (larger images typically cost more)
    /// - Number of images in the batch
    ///
    /// - Parameters:
    ///   - quality: Quality tier (model-dependent, e.g., "hd", "standard")
    ///   - dimensions: Output size as "WIDTHxHEIGHT" string
    ///   - numberOfImages: Number of images to generate
    /// - Returns: Formatted cost string (e.g., "$0.04") or "Free" if no adapter
    func formattedImageCost(
        quality: String = "",
        dimensions: String = "1024x1024",
        resolution: String? = nil,
        numberOfImages: Int = 1,
        hasSourceImage: Bool = false,
        referenceImageCount: Int = 0,
        providerSecret: String? = nil
    ) -> String {
        guard let adapter = getImageGenerationAdapter(modelCode: self) else { return "Free" }
        let request = ImageGenerationCostRequest(
            modelId: rawValue,
            quality: quality,
            dimensions: dimensions,
            resolution: resolution,
            numberOfImages: numberOfImages,
            hasSourceImage: hasSourceImage,
            referenceImageCount: referenceImageCount,
            providerSecret: providerSecret
        )
        return adapter.formatCost(request: request)
    }

    /// Returns the raw numeric cost for image generation.
    ///
    /// Used for calculations, totals, and comparisons where formatted strings
    /// aren't appropriate.
    ///
    /// - Returns: Cost as a Double (in USD or credits depending on provider)
    func rawImageCost(
        quality: String = "",
        dimensions: String = "1024x1024",
        resolution: String? = nil,
        numberOfImages: Int = 1,
        hasSourceImage: Bool = false,
        referenceImageCount: Int = 0,
        providerSecret: String? = nil
    ) -> Double {
        guard let adapter = getImageGenerationAdapter(modelCode: self) else { return 0 }
        let request = ImageGenerationCostRequest(
            modelId: rawValue,
            quality: quality,
            dimensions: dimensions,
            resolution: resolution,
            numberOfImages: numberOfImages,
            hasSourceImage: hasSourceImage,
            referenceImageCount: referenceImageCount,
            providerSecret: providerSecret
        )
        return adapter.getCostEstimate(request: request)
    }

    // MARK: - Video Cost Calculation

    /// Calculates and formats the cost for video generation with this model.
    ///
    /// Video generation costs vary significantly by:
    /// - Duration (longer videos cost more)
    /// - Resolution (higher resolutions cost more)
    /// - Model tier (pro models cost more than lite/fast versions)
    ///
    /// - Parameters:
    ///   - durationSeconds: Video length in seconds
    ///   - numberOfVideos: Number of videos to generate
    ///   - dimensions: Output size as "WIDTHxHEIGHT" string
    ///   - resolution: Resolution tier (e.g., "480p", "720p", "1080p")
    /// - Returns: Formatted cost string (e.g., "$0.50") or "Free" if no adapter
    func formattedVideoCost(
        durationSeconds: Int,
        numberOfVideos: Int = 1,
        dimensions: String = "1280x720",
        resolution: String = "1080p",
        generateAudio: Bool? = nil,
        hasSourceImage: Bool = false,
        referenceImageCount: Int = 0,
        lumaHDR: Bool? = nil,
        lumaEXRExport: Bool? = nil,
        lumaLoop: Bool? = nil,
        providerSecret: String? = nil
    ) -> String {
        guard let adapter = getVideoGenerationAdapter(modelCode: self) else { return "Free" }
        let request = VideoGenerationCostRequest(
            dimensions: dimensions,
            durationSeconds: durationSeconds,
            numberOfVideos: numberOfVideos,
            resolution: resolution,
            generateAudio: generateAudio,
            hasSourceImage: hasSourceImage,
            hasReferenceImages: referenceImageCount > 0,
            referenceImageCount: referenceImageCount,
            lumaHDR: lumaHDR,
            lumaEXRExport: lumaEXRExport,
            lumaLoop: lumaLoop,
            providerSecret: providerSecret
        )
        return adapter.formatCost(request: request)
    }

    /// Returns the raw numeric cost for video generation.
    ///
    /// - Returns: Cost as a Double (in USD or credits depending on provider)
    func rawVideoCost(
        durationSeconds: Int,
        numberOfVideos: Int = 1,
        dimensions: String = "1280x720",
        resolution: String = "1080p",
        generateAudio: Bool? = nil,
        hasSourceImage: Bool = false,
        referenceImageCount: Int = 0,
        lumaHDR: Bool? = nil,
        lumaEXRExport: Bool? = nil,
        lumaLoop: Bool? = nil,
        providerSecret: String? = nil
    ) -> Double {
        guard let adapter = getVideoGenerationAdapter(modelCode: self) else { return 0 }
        let request = VideoGenerationCostRequest(
            dimensions: dimensions,
            durationSeconds: durationSeconds,
            numberOfVideos: numberOfVideos,
            resolution: resolution,
            generateAudio: generateAudio,
            hasSourceImage: hasSourceImage,
            hasReferenceImages: referenceImageCount > 0,
            referenceImageCount: referenceImageCount,
            lumaHDR: lumaHDR,
            lumaEXRExport: lumaEXRExport,
            lumaLoop: lumaLoop,
            providerSecret: providerSecret
        )
        return adapter.getCostEstimate(request: request)
    }
}

// MARK: - Provider Model Entity

/// SwiftData model representing a specific AI model's configuration.
///
/// Each ProviderModel instance describes a single AI model (e.g., DALL-E 3,
/// Stable Diffusion XL, Veo 2) including its capabilities, pricing, and
/// API endpoints.
///
/// ## Relationship to Provider
/// Models belong to providers: `providerId` links to the parent Provider.
/// Multiple ProviderModel instances share the same providerId.
///
/// ## Model Identification
/// The `modelId` is derived deterministically from `modelCode`, ensuring
/// consistent identification across sessions and devices.
///
/// ## Lifecycle Management
/// - `modelLaunchDate`: When the model became available
/// - `modelDeprecationDate`: When the model will be/was retired (nil if active)
/// - `active`: Whether the model is currently usable
///
/// ## API Configuration
/// - `modelGenerateBaseURL`: Primary API endpoint for generation
/// - `modelStatusBaseURL`: Polling endpoint for async operations (optional)
/// - `modelAPIDocumentationURL`: Link to official API docs
@Model
final class ProviderModel: Codable {
    enum CodingKeys: CodingKey {
        case providerId
        case modelCode
        case modelSetType
        case modelName
        case modelDescription
        case modelParams
        case modelLaunchDate
        case modelDeprecationDate
        case modelVerificationDate
        case modelShutdownDate
        case replacementModelCode
        case pricingMetadata
        case modelGenerateBaseURL
        case modelStatusBaseURL
        case modelAPIDocumentationURL
        case active
    }

    /// ID of the parent provider (e.g., OpenAI, Stability AI)
    var providerId = UUID()

    /// Unique code identifying this specific model
    var modelCode = EnumProviderModelCode.OPENAI_DALLE3

    /// Deterministic UUID derived from model code for consistent referencing
    var modelId: UUID {
        modelCode.modelId
    }

    /// Type of generation this model performs (image generate, video generate, video extend)
    var modelSetType = EnumSetType.IMAGE_GENERATE

    /// Display name for the model (e.g., "DALL-E 3", "Stable Diffusion XL")
    var modelName = ""

    /// Brief description of the model's capabilities
    var modelDescription = ""

    /// Comprehensive capability parameters for this model
    var modelParams = ModelParams()

    /// When the model was launched/became available
    var modelLaunchDate = Date()

    /// When the model will be/was deprecated (nil if not deprecated)
    var modelDeprecationDate: Date? = nil

    /// Last date the request, response, lifecycle, and pricing contract was checked.
    var modelVerificationDate: Date? = nil

    /// Date the provider will stop accepting requests for this model.
    var modelShutdownDate: Date? = nil

    /// Suggested migration target for a deprecated or disabled model.
    var replacementModelCode: EnumProviderModelCode? = nil

    /// Official pricing source and verification timestamp.
    var pricingMetadata: ProviderPricingMetadata? = nil

    /// Base URL for the generation API endpoint
    var modelGenerateBaseURL = ""

    /// Base URL for checking generation status (for async operations)
    var modelStatusBaseURL: String? = nil

    /// Link to official API documentation
    var modelAPIDocumentationURL = ""

    /// Whether this model is currently active and usable
    var active = true

    init(
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

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerId = try container.decode(UUID.self, forKey: .providerId)
        modelCode = try container.decode(EnumProviderModelCode.self, forKey: .modelCode)
        modelSetType = try container.decode(EnumSetType.self, forKey: .modelSetType)
        modelName = try container.decode(String.self, forKey: .modelName)
        modelDescription = try container.decode(String.self, forKey: .modelDescription)
        modelParams = try container.decode(ModelParams.self, forKey: .modelParams)
        modelLaunchDate = try container.decode(Date.self, forKey: .modelLaunchDate)
        modelDeprecationDate = try container.decodeIfPresent(Date.self, forKey: .modelDeprecationDate)
        modelVerificationDate = try container.decodeIfPresent(Date.self, forKey: .modelVerificationDate)
        modelShutdownDate = try container.decodeIfPresent(Date.self, forKey: .modelShutdownDate)
        replacementModelCode = try container.decodeIfPresent(EnumProviderModelCode.self, forKey: .replacementModelCode)
        pricingMetadata = try container.decodeIfPresent(ProviderPricingMetadata.self, forKey: .pricingMetadata)
        modelGenerateBaseURL = try container.decode(String.self, forKey: .modelGenerateBaseURL)
        modelStatusBaseURL = try container.decodeIfPresent(String.self, forKey: .modelStatusBaseURL)
        modelAPIDocumentationURL = try container.decode(String.self, forKey: .modelAPIDocumentationURL)
        active = try container.decode(Bool.self, forKey: .active)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(providerId, forKey: .providerId)
        try container.encode(modelCode, forKey: .modelCode)
        try container.encode(modelSetType, forKey: .modelSetType)
        try container.encode(modelName, forKey: .modelName)
        try container.encode(modelDescription, forKey: .modelDescription)
        try container.encode(modelParams, forKey: .modelParams)
        try container.encode(modelLaunchDate, forKey: .modelLaunchDate)
        try container.encode(modelDeprecationDate, forKey: .modelDeprecationDate)
        try container.encodeIfPresent(modelVerificationDate, forKey: .modelVerificationDate)
        try container.encodeIfPresent(modelShutdownDate, forKey: .modelShutdownDate)
        try container.encodeIfPresent(replacementModelCode, forKey: .replacementModelCode)
        try container.encodeIfPresent(pricingMetadata, forKey: .pricingMetadata)
        try container.encode(modelGenerateBaseURL, forKey: .modelGenerateBaseURL)
        try container.encode(modelStatusBaseURL, forKey: .modelStatusBaseURL)
        try container.encode(modelAPIDocumentationURL, forKey: .modelAPIDocumentationURL)
        try container.encode(active, forKey: .active)
    }
}

// MARK: - Model Label View

/// Simple SwiftUI view displaying a model's name.
///
/// Used in dropdown menus and lists where only the model name
/// needs to be shown. For more detailed model display, use
/// custom views that access the full ProviderModel properties.
struct ModelLabel: View {
    var model: ProviderModel

    var body: some View {
        Text(model.modelName)
    }
}
