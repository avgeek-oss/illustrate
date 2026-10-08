// MARK: - ModelParams.swift

import Foundation

// MARK: - Model Parameters

/// Comprehensive capability descriptor for AI models.
///
/// This struct describes everything an AI model can do, enabling the UI to
/// dynamically configure itself based on model capabilities. When a user
/// selects a different model, the UI reads this struct to show/hide options.
///
/// ## Design Philosophy
/// Rather than hardcoding UI for each model, the app uses this declarative
/// approach where each model declares its capabilities and the UI adapts.
/// This makes adding new models much simpler.
///
/// ## Parameter Categories
///
/// ### Limits
/// - `maxGenerations`: How many images/videos per request
/// - `maxImagePixels`: Maximum total pixels (prevents memory issues)
/// - `maxImageSizeBytes`: Upload size limit
/// - `maxPromptLength`: Character limit for prompts
/// - `maxReferenceImages`: Number of reference images supported
///
/// ### Supported Options (Arrays)
/// These arrays list valid options the UI should present:
/// - Dimensions, qualities, styles, variants
/// - Video durations, FPS options, resolutions
/// - Moderation levels, background options
///
/// ### Supported Ranges
/// Numeric ranges for slider-based parameters:
/// - `supportedGuidanceRange`: How closely to follow the prompt
/// - `supportedStepsRange`: Inference steps (quality vs speed)
/// - `supportedSafetyRange`: Content filtering level
/// - `supportedMotionRange`: Video motion intensity
///
/// ### Feature Flags (Booleans)
/// Simple yes/no capabilities:
/// - `supportsPrompt`: Whether text prompts are supported
/// - `supportsSourceImage`: Image-to-image/video support
/// - `supportsMask`: Inpainting mask support
/// - `supportsNegativePrompt`: Negative prompt support
///
/// ## Inferred Properties
/// The struct includes computed properties that derive support flags from
/// array/range presence, reducing redundancy in model definitions.
public struct ModelParams: Codable, Sendable {
    public enum CodingKeys: CodingKey {
        case active
        case maxGenerations
        case maxImagePixels
        case maxImageSizeBytes
        case maxPromptLength
        case maxReferenceImages
        case requiredMetadata
        case supportedBackgrounds
        case supportedDimensions
        case supportedInputFidelities
        case supportedModerations
        case supportedMotionRange
        case supportedReferenceTypes
        case supportedStickynessRange
        case supportedTools
        case supportedPersonGenerationOptions
        case supportedVideoDurations
        case supportedVideoFPS
        case supportedGrowMaskRange
        case supportedGuidanceRange
        case supportedImageResolutions
        case supportedImageQualities
        case supportedSafetyRange
        case supportedStepsRange
        case supportedStyles
        case supportedVariants
        case supportedVideoResolutions
        case supportsAudio
        case supportsCameraFixed
        case supportsFlexibleReferenceDimensions
        case supportsLastFrame
        case supportsMask
        case supportsNegativePrompt
        case supportsPrompt
        case supportsPromptEnhance
        case supportsSearchPrompt
        case supportsSeed
        case supportsSourceImage
        case supportsVideoUpload
        case supportsExpandDirections
    }

    public var active = true
    public var maxGenerations = 1
    public var maxImagePixels: Int? = nil
    public var maxImageSizeBytes: Int? = nil
    public var maxPromptLength = 256
    public var maxReferenceImages = 0
    public var requiredMetadata: [String] = []
    public var supportedBackgrounds: [String] = []
    public var supportedDimensions: [String] = []
    public var supportedInputFidelities: [String] = []
    public var supportedModerations: [String] = []
    public var supportedMotionRange: DoubleRange? = nil
    public var supportedReferenceTypes: [String] = []
    public var supportedStickynessRange: DoubleRange? = nil
    public var supportedTools: [String] = []
    public var supportedPersonGenerationOptions: [String] = []
    public var supportedVideoDurations: [Int] = []
    public var supportedVideoFPS: [Int] = []
    public var supportedGrowMaskRange: IntRange? = nil
    public var supportedGuidanceRange: DoubleRange? = nil
    public var supportedImageResolutions: [String] = []
    public var supportedImageQualities: [String] = []
    public var supportedSafetyRange: IntRange? = nil
    public var supportedStepsRange: IntRange? = nil
    public var supportedStyles: [String] = []
    public var supportedVariants: [String] = []
    public var supportedVideoResolutions: [String] = []
    public var supportsAudio = false
    public var supportsCameraFixed = false
    public var supportsFlexibleReferenceDimensions = true
    public var supportsLastFrame = false
    public var supportsMask = false
    public var supportsExpandDirections = false
    public var supportsNegativePrompt = false
    public var supportsPrompt = true
    public var supportsPromptEnhance = false
    public var supportsSearchPrompt = false
    public var supportsSeed = false
    public var supportsSourceImage = false
    public var supportsVideoUpload = false

    public var supportsImageResolution: Bool {
        !supportedImageResolutions.isEmpty
    }

    public var supportsReferenceImages: Bool {
        maxReferenceImages > 0
    }

    public var supportsStepsRange: Bool {
        supportedStepsRange != nil && supportedStepsRange!.min <= supportedStepsRange!.max
    }

    public var supportsGrowMaskRange: Bool {
        supportedGrowMaskRange != nil && supportedGrowMaskRange!.min <= supportedGrowMaskRange!.max
    }

    public var supportsGuidanceRange: Bool {
        supportedGuidanceRange != nil && supportedGuidanceRange!.min <= supportedGuidanceRange!.max
    }

    public var supportsSafetyRange: Bool {
        supportedSafetyRange != nil && supportedSafetyRange!.min <= supportedSafetyRange!.max
    }

    public var supportsBackgrounds: Bool {
        !supportedBackgrounds.isEmpty
    }

    public var supportsFPS: Bool {
        !supportedVideoFPS.isEmpty
    }

    public var supportsInputFidelity: Bool {
        !supportedInputFidelities.isEmpty
    }

    public var supportsModeration: Bool {
        !supportedModerations.isEmpty
    }

    public var supportsMotion: Bool {
        supportedMotionRange != nil
    }

    public var supportsStickyness: Bool {
        supportedStickynessRange != nil
    }

    public var supportsTools: Bool {
        !supportedTools.isEmpty
    }

    public var supportsPersonGeneration: Bool {
        !supportedPersonGenerationOptions.isEmpty
    }

    public var supportsVideoResolutions: Bool {
        !supportedVideoResolutions.isEmpty
    }

    public var supportsVideoDurations: Bool {
        !supportedVideoDurations.isEmpty
    }

    public var supportsDimensions: Bool {
        !effectiveDimensions.isEmpty
    }

    public var supportsQualities: Bool {
        !supportedImageQualities.isEmpty
    }

    /// Default dimensions used when a model requires source image but doesn't specify dimensions
    public static let defaultSourceImageDimensions = [
        "1024x1024",
        "1152x896",
        "896x1152",
        "1344x768",
        "768x1344",
        "1536x640",
        "640x1536",
    ]

    /// Returns the effective dimensions - either the specified dimensions or defaults when
    /// the model supports source image but has no dimensions specified
    public var effectiveDimensions: [String] {
        if !supportedDimensions.isEmpty {
            return supportedDimensions
        }
        // Provide default dimensions for image editing models that don't specify dimensions
        if supportsSourceImage {
            return Self.defaultSourceImageDimensions
        }
        return []
    }

    public var supportsVariants: Bool {
        !supportedVariants.isEmpty
    }

    public var supportsStyles: Bool {
        !supportedStyles.isEmpty
    }

    public init(
        active: Bool = true,
        maxGenerations: Int = 1,
        maxImagePixels: Int? = nil,
        maxImageSizeBytes: Int? = nil,
        maxPromptLength: Int = 256,
        maxReferenceImages: Int = 0,
        requiredMetadata: [String] = [],
        supportedBackgrounds: [String] = [],
        supportedDimensions: [String] = [],
        supportedInputFidelities: [String] = [],
        supportedModerations: [String] = [],
        supportedMotionRange: DoubleRange? = nil,
        supportedReferenceTypes: [String] = [],
        supportedStickynessRange: DoubleRange? = nil,
        supportedTools: [String] = [],
        supportedPersonGenerationOptions: [String] = [],
        supportedVideoDurations: [Int] = [],
        supportedVideoFPS: [Int] = [],
        supportedGrowMaskRange: IntRange? = nil,
        supportedGuidanceRange: DoubleRange? = nil,
        supportedImageResolutions: [String] = [],
        supportedImageQualities: [String] = [],
        supportedSafetyRange: IntRange? = nil,
        supportedStepsRange: IntRange? = nil,
        supportedStyles: [String] = [],
        supportedVariants: [String] = [],
        supportedVideoResolutions: [String] = [],
        supportsAudio: Bool = false,
        supportsCameraFixed: Bool = false,
        supportsFlexibleReferenceDimensions: Bool = true,
        supportsLastFrame: Bool = false,
        supportsMask: Bool = false,
        supportsExpandDirections: Bool = false,
        supportsNegativePrompt: Bool = false,
        supportsPrompt: Bool = true,
        supportsPromptEnhance: Bool = false,
        supportsSearchPrompt: Bool = false,
        supportsSeed: Bool = false,
        supportsSourceImage: Bool = false,
        supportsVideoUpload: Bool = false
    ) {
        self.active = active
        self.maxGenerations = maxGenerations
        self.maxImagePixels = maxImagePixels
        self.maxImageSizeBytes = maxImageSizeBytes
        self.maxPromptLength = maxPromptLength
        self.maxReferenceImages = maxReferenceImages
        self.requiredMetadata = requiredMetadata
        self.supportedBackgrounds = supportedBackgrounds
        self.supportedDimensions = supportedDimensions
        self.supportedInputFidelities = supportedInputFidelities
        self.supportedModerations = supportedModerations
        self.supportedMotionRange = supportedMotionRange
        self.supportedReferenceTypes = supportedReferenceTypes
        self.supportedStickynessRange = supportedStickynessRange
        self.supportedTools = supportedTools
        self.supportedPersonGenerationOptions = supportedPersonGenerationOptions
        self.supportedVideoDurations = supportedVideoDurations
        self.supportedVideoFPS = supportedVideoFPS
        self.supportedGrowMaskRange = supportedGrowMaskRange
        self.supportedGuidanceRange = supportedGuidanceRange
        self.supportedImageResolutions = supportedImageResolutions
        self.supportedImageQualities = supportedImageQualities
        self.supportedSafetyRange = supportedSafetyRange
        self.supportedStepsRange = supportedStepsRange
        self.supportedStyles = supportedStyles
        self.supportedVariants = supportedVariants
        self.supportedVideoResolutions = supportedVideoResolutions
        self.supportsAudio = supportsAudio
        self.supportsCameraFixed = supportsCameraFixed
        self.supportsFlexibleReferenceDimensions = supportsFlexibleReferenceDimensions
        self.supportsLastFrame = supportsLastFrame
        self.supportsMask = supportsMask
        self.supportsExpandDirections = supportsExpandDirections
        self.supportsNegativePrompt = supportsNegativePrompt
        self.supportsPrompt = supportsPrompt
        self.supportsPromptEnhance = supportsPromptEnhance
        self.supportsSearchPrompt = supportsSearchPrompt
        self.supportsSeed = supportsSeed
        self.supportsSourceImage = supportsSourceImage
        self.supportsVideoUpload = supportsVideoUpload
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(active, forKey: .active)
        try container.encode(maxGenerations, forKey: .maxGenerations)
        try container.encodeIfPresent(maxImagePixels, forKey: .maxImagePixels)
        try container.encodeIfPresent(maxImageSizeBytes, forKey: .maxImageSizeBytes)
        try container.encode(maxPromptLength, forKey: .maxPromptLength)
        try container.encode(maxReferenceImages, forKey: .maxReferenceImages)
        try container.encode(requiredMetadata, forKey: .requiredMetadata)
        try container.encode(supportedBackgrounds, forKey: .supportedBackgrounds)
        try container.encode(supportedDimensions, forKey: .supportedDimensions)
        try container.encode(supportedInputFidelities, forKey: .supportedInputFidelities)
        try container.encode(supportedModerations, forKey: .supportedModerations)
        try container.encodeIfPresent(supportedMotionRange, forKey: .supportedMotionRange)
        try container.encode(supportedReferenceTypes, forKey: .supportedReferenceTypes)
        try container.encodeIfPresent(supportedStickynessRange, forKey: .supportedStickynessRange)
        try container.encode(supportedTools, forKey: .supportedTools)
        try container.encode(supportedPersonGenerationOptions, forKey: .supportedPersonGenerationOptions)
        try container.encode(supportedVideoDurations, forKey: .supportedVideoDurations)
        try container.encode(supportedVideoFPS, forKey: .supportedVideoFPS)
        try container.encodeIfPresent(supportedGrowMaskRange, forKey: .supportedGrowMaskRange)
        try container.encodeIfPresent(supportedGuidanceRange, forKey: .supportedGuidanceRange)
        try container.encode(supportedImageResolutions, forKey: .supportedImageResolutions)
        try container.encode(supportedImageQualities, forKey: .supportedImageQualities)
        try container.encodeIfPresent(supportedSafetyRange, forKey: .supportedSafetyRange)
        try container.encodeIfPresent(supportedStepsRange, forKey: .supportedStepsRange)
        try container.encode(supportedStyles, forKey: .supportedStyles)
        try container.encode(supportedVariants, forKey: .supportedVariants)
        try container.encode(supportedVideoResolutions, forKey: .supportedVideoResolutions)
        try container.encode(supportsAudio, forKey: .supportsAudio)
        try container.encode(supportsCameraFixed, forKey: .supportsCameraFixed)
        try container.encode(supportsFlexibleReferenceDimensions, forKey: .supportsFlexibleReferenceDimensions)
        try container.encode(supportsLastFrame, forKey: .supportsLastFrame)
        try container.encode(supportsMask, forKey: .supportsMask)
        try container.encode(supportsExpandDirections, forKey: .supportsExpandDirections)
        try container.encode(supportsNegativePrompt, forKey: .supportsNegativePrompt)
        try container.encode(supportsPrompt, forKey: .supportsPrompt)
        try container.encode(supportsPromptEnhance, forKey: .supportsPromptEnhance)
        try container.encode(supportsSearchPrompt, forKey: .supportsSearchPrompt)
        try container.encode(supportsSeed, forKey: .supportsSeed)
        try container.encode(supportsSourceImage, forKey: .supportsSourceImage)
        try container.encode(supportsVideoUpload, forKey: .supportsVideoUpload)
    }
}
