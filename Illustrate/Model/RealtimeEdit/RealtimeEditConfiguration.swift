// MARK: - RealtimeEditConfiguration.swift

// Configuration structure for Realtime Edit prompt bar settings.
//
// Stores all prompt bar configuration including:
// - Provider and model selection
// - Image dimensions
// - Standard generation parameters (prompt, negative prompt, steps, guidance)
//
// ## Usage
// This struct is JSON-encoded and stored in RealtimeEditSession.configurationData.
// It's accessed via the session.configuration computed property.

import Foundation

// MARK: - Realtime Edit Configuration

/// Complete configuration for Realtime Edit prompt bar.
///
/// Stores provider/model selection and generation parameters for
/// future LLM-powered realtime editing capabilities.
struct RealtimeEditConfiguration: Codable {
    // MARK: Provider and Model Selection

    /// Selected AI provider UUID string
    var selectedProviderId = ""

    /// Selected model UUID string
    var selectedModelId = ""

    // MARK: Image Generation Settings

    /// Image dimensions (e.g., "1024x1024", "1024x1792")
    var selectedDimensions = "1024x1024"

    // MARK: Canvas Tool Selection

    /// Selected editing tool (select, brush, shape, attach)
    var selectedToolRawValue = "select"

    // MARK: Prompt Configuration

    /// User's text prompt
    var prompt = ""

    /// Negative prompt for excluding unwanted elements
    var negativePrompt = ""

    // MARK: Generation Parameters

    /// Number of inference steps (quality vs. speed trade-off)
    var stepsValue: Double = 28

    /// Guidance scale for prompt adherence (higher = stricter)
    var guidanceValue = 3.5

    /// Seed value for reproducible generations (empty = random)
    var seedValue = ""

    // MARK: Model-Specific Options

    /// Output quality level (standard, high, etc.)
    var selectedQuality = "standard"

    /// Style preset (if model supports)
    var selectedStyle = ""

    /// Whether to use model's built-in prompt enhancement
    var modelPromptEnhance = true

    /// Default configuration with sensible defaults.
    init() {
        // Uses default property values defined above
    }

    /// Creates a configuration with specific settings.
    ///
    /// - Parameters:
    ///   - providerId: AI provider UUID
    ///   - modelId: Model UUID
    ///   - dimensions: Image dimensions string
    init(
        providerId: String = "",
        modelId: String = "",
        dimensions: String = "1024x1024"
    ) {
        selectedProviderId = providerId
        selectedModelId = modelId
        selectedDimensions = dimensions
    }
}
