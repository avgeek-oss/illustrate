// MARK: - ModelParamsTests.swift

// Workflow tests for ModelParams and NumericRange.
//
// Tests cover:
// - NumericRange: storage, Codable round-trip, Equatable, edge cases
// - ModelParams computed properties: 21 Bool properties derived from arrays/ranges
// - effectiveDimensions fallback chain: explicit → source image defaults → empty
// - ModelParams Codable round-trip with full, minimal, and custom configurations
// - Real-world model configuration patterns (DALL-E 3-like, video model-like)

import XCTest
@testable import IllustrateProviders

final class ModelParamsTests: XCTestCase {
    // MARK: - NumericRange Tests

    func testIntRange_StoresMinMax() {
        let range = IntRange(1, 10)
        XCTAssertEqual(range.min, 1)
        XCTAssertEqual(range.max, 10)
    }

    func testDoubleRange_StoresMinMax() {
        let range = DoubleRange(0.0, 1.0)
        XCTAssertEqual(range.min, 0.0)
        XCTAssertEqual(range.max, 1.0)
    }

    func testIntRange_CodableRoundTrip() throws {
        let original = IntRange(5, 50)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IntRange.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testDoubleRange_CodableRoundTrip() throws {
        let original = DoubleRange(0.5, 7.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DoubleRange.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testNumericRange_Equatable_SameValues() {
        XCTAssertEqual(IntRange(1, 10), IntRange(1, 10))
    }

    func testNumericRange_Equatable_DifferentValues() {
        XCTAssertNotEqual(IntRange(1, 10), IntRange(1, 20))
    }

    func testNumericRange_SingleValueRange() {
        let range = IntRange(5, 5)
        XCTAssertEqual(range.min, range.max)
    }

    func testNumericRange_NegativeValues() {
        let range = IntRange(-10, -1)
        XCTAssertEqual(range.min, -10)
        XCTAssertEqual(range.max, -1)
    }

    func testIntRange_JSONStructure() throws {
        let range = IntRange(1, 10)
        let data = try JSONEncoder().encode(range)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["min"])
        XCTAssertNotNil(json?["max"])
        XCTAssertEqual(json?["min"] as? Int, 1)
        XCTAssertEqual(json?["max"] as? Int, 10)
    }

    // MARK: - ModelParams Default Values

    func testDefaults_ActiveIsTrue() {
        let params = ModelParams()
        XCTAssertTrue(params.active)
    }

    func testDefaults_MaxGenerationsIs1() {
        XCTAssertEqual(ModelParams().maxGenerations, 1)
    }

    func testDefaults_MaxPromptLengthIs256() {
        XCTAssertEqual(ModelParams().maxPromptLength, 256)
    }

    func testDefaults_MaxReferenceImagesIs0() {
        XCTAssertEqual(ModelParams().maxReferenceImages, 0)
    }

    func testDefaults_OptionalFieldsAreNil() {
        let params = ModelParams()
        XCTAssertNil(params.maxImagePixels)
        XCTAssertNil(params.maxImageSizeBytes)
        XCTAssertNil(params.supportedMotionRange)
        XCTAssertNil(params.supportedStickynessRange)
        XCTAssertNil(params.supportedGrowMaskRange)
        XCTAssertNil(params.supportedGuidanceRange)
        XCTAssertNil(params.supportedSafetyRange)
        XCTAssertNil(params.supportedStepsRange)
    }

    func testDefaults_BooleanFlags() {
        let params = ModelParams()
        XCTAssertFalse(params.supportsAudio)
        XCTAssertFalse(params.supportsCameraFixed)
        XCTAssertTrue(params.supportsFlexibleReferenceDimensions)
        XCTAssertFalse(params.supportsLastFrame)
        XCTAssertFalse(params.supportsMask)
        XCTAssertFalse(params.supportsExpandDirections)
        XCTAssertFalse(params.supportsNegativePrompt)
        XCTAssertTrue(params.supportsPrompt)
        XCTAssertFalse(params.supportsPromptEnhance)
        XCTAssertFalse(params.supportsSearchPrompt)
        XCTAssertFalse(params.supportsSeed)
        XCTAssertFalse(params.supportsSourceImage)
        XCTAssertFalse(params.supportsVideoUpload)
    }

    func testDefaults_ArraysAreEmpty() {
        let params = ModelParams()
        XCTAssertTrue(params.supportedDimensions.isEmpty)
        XCTAssertTrue(params.supportedStyles.isEmpty)
        XCTAssertTrue(params.supportedImageQualities.isEmpty)
        XCTAssertTrue(params.supportedBackgrounds.isEmpty)
        XCTAssertTrue(params.supportedVideoResolutions.isEmpty)
        XCTAssertTrue(params.supportedVideoDurations.isEmpty)
    }

    // MARK: - Computed Property Workflow Tests

    func testComputed_SupportsDimensions_DefaultFalse() {
        // Default: no explicit dimensions, no source image → empty effectiveDimensions → false
        let params = ModelParams()
        XCTAssertFalse(params.supportsDimensions)
    }

    func testComputed_SupportsDimensions_WithExplicitDimensions() {
        let params = ModelParams(supportedDimensions: ["1024x1024", "512x512"])
        XCTAssertTrue(params.supportsDimensions)
    }

    func testComputed_EffectiveDimensions_ExplicitDimensions_ReturnsThem() {
        let dims = ["1024x1024", "1792x1024"]
        let params = ModelParams(supportedDimensions: dims)
        XCTAssertEqual(params.effectiveDimensions, dims)
    }

    func testComputed_EffectiveDimensions_SourceImage_ReturnsDefaults() {
        // No explicit dimensions + supportsSourceImage → defaultSourceImageDimensions
        let params = ModelParams(supportsSourceImage: true)
        XCTAssertEqual(params.effectiveDimensions, ModelParams.defaultSourceImageDimensions)
    }

    func testComputed_EffectiveDimensions_NoSourceImage_ReturnsEmpty() {
        let params = ModelParams(supportsSourceImage: false)
        XCTAssertTrue(params.effectiveDimensions.isEmpty)
    }

    func testComputed_EffectiveDimensions_ExplicitOverridesSourceImage() {
        // When explicit dimensions are set, they take priority over defaults
        let dims = ["2048x2048"]
        let params = ModelParams(supportedDimensions: dims, supportsSourceImage: true)
        XCTAssertEqual(params.effectiveDimensions, dims)
    }

    func testComputed_DefaultSourceImageDimensions_Has7Entries() {
        XCTAssertEqual(ModelParams.defaultSourceImageDimensions.count, 7)
    }

    func testComputed_SupportsStepsRange_NilRange_False() {
        XCTAssertFalse(ModelParams().supportsStepsRange)
    }

    func testComputed_SupportsStepsRange_ValidRange_True() {
        let params = ModelParams(supportedStepsRange: IntRange(1, 50))
        XCTAssertTrue(params.supportsStepsRange)
    }

    func testComputed_SupportsGuidanceRange_ValidRange_True() {
        let params = ModelParams(supportedGuidanceRange: DoubleRange(0, 10))
        XCTAssertTrue(params.supportsGuidanceRange)
    }

    func testComputed_SupportsGuidanceRange_NilRange_False() {
        XCTAssertFalse(ModelParams().supportsGuidanceRange)
    }

    func testComputed_SupportsReferenceImages_WithRefs_True() {
        let params = ModelParams(maxReferenceImages: 3)
        XCTAssertTrue(params.supportsReferenceImages)
    }

    func testComputed_SupportsReferenceImages_ZeroRefs_False() {
        XCTAssertFalse(ModelParams().supportsReferenceImages)
    }

    func testComputed_SupportsQualities_NonEmpty_True() {
        let params = ModelParams(supportedImageQualities: ["standard", "hd"])
        XCTAssertTrue(params.supportsQualities)
    }

    func testComputed_SupportsQualities_Empty_False() {
        XCTAssertFalse(ModelParams().supportsQualities)
    }

    func testComputed_SupportsStyles_NonEmpty_True() {
        let params = ModelParams(supportedStyles: ["vivid", "natural"])
        XCTAssertTrue(params.supportsStyles)
    }

    func testComputed_SupportsStyles_Empty_False() {
        XCTAssertFalse(ModelParams().supportsStyles)
    }

    func testComputed_SupportsImageResolution_NonEmpty_True() {
        let params = ModelParams(supportedImageResolutions: ["1080p", "4k"])
        XCTAssertTrue(params.supportsImageResolution)
    }

    func testComputed_SupportsBackgrounds_NonEmpty_True() {
        let params = ModelParams(supportedBackgrounds: ["transparent", "white"])
        XCTAssertTrue(params.supportsBackgrounds)
    }

    func testComputed_SupportsFPS_NonEmpty_True() {
        let params = ModelParams(supportedVideoFPS: [24, 30, 60])
        XCTAssertTrue(params.supportsFPS)
    }

    func testComputed_SupportsMotion_WithRange_True() {
        let params = ModelParams(supportedMotionRange: DoubleRange(0, 1))
        XCTAssertTrue(params.supportsMotion)
    }

    func testComputed_SupportsMotion_NilRange_False() {
        XCTAssertFalse(ModelParams().supportsMotion)
    }

    func testComputed_SupportsStickyness_WithRange_True() {
        let params = ModelParams(supportedStickynessRange: DoubleRange(0, 1))
        XCTAssertTrue(params.supportsStickyness)
    }

    func testComputed_SupportsTools_NonEmpty_True() {
        let params = ModelParams(supportedTools: ["inpaint", "outpaint"])
        XCTAssertTrue(params.supportsTools)
    }

    func testComputed_SupportsPersonGeneration_NonEmpty_True() {
        let params = ModelParams(supportedPersonGenerationOptions: ["allow", "block"])
        XCTAssertTrue(params.supportsPersonGeneration)
    }

    func testComputed_SupportsVideoResolutions_NonEmpty_True() {
        let params = ModelParams(supportedVideoResolutions: ["720p", "1080p"])
        XCTAssertTrue(params.supportsVideoResolutions)
    }

    func testComputed_SupportsVideoDurations_NonEmpty_True() {
        let params = ModelParams(supportedVideoDurations: [4, 8, 16])
        XCTAssertTrue(params.supportsVideoDurations)
    }

    func testComputed_SupportsVariants_NonEmpty_True() {
        let params = ModelParams(supportedVariants: ["default", "turbo"])
        XCTAssertTrue(params.supportsVariants)
    }

    func testComputed_SupportsSafetyRange_ValidRange_True() {
        let params = ModelParams(supportedSafetyRange: IntRange(1, 5))
        XCTAssertTrue(params.supportsSafetyRange)
    }

    func testComputed_SupportsGrowMaskRange_ValidRange_True() {
        let params = ModelParams(supportedGrowMaskRange: IntRange(0, 100))
        XCTAssertTrue(params.supportsGrowMaskRange)
    }

    func testComputed_SupportsInputFidelity_NonEmpty_True() {
        let params = ModelParams(supportedInputFidelities: ["high", "low"])
        XCTAssertTrue(params.supportsInputFidelity)
    }

    func testComputed_SupportsModeration_NonEmpty_True() {
        let params = ModelParams(supportedModerations: ["auto", "manual"])
        XCTAssertTrue(params.supportsModeration)
    }

    // MARK: - ModelParams Codable Workflow Tests

    func testCodable_FullRoundTrip() throws {
        let original = ModelParams(
            active: false,
            maxGenerations: 4,
            maxImagePixels: 4_194_304,
            maxImageSizeBytes: 20_000_000,
            maxPromptLength: 4000,
            maxReferenceImages: 2,
            supportedDimensions: ["1024x1024", "1792x1024", "1024x1792"],
            supportedGuidanceRange: DoubleRange(1.0, 20.0),
            supportedImageQualities: ["standard", "hd"],
            supportedStepsRange: IntRange(10, 100),
            supportedStyles: ["vivid", "natural"],
            supportsNegativePrompt: true,
            supportsSeed: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelParams.self, from: data)

        XCTAssertEqual(decoded.active, false)
        XCTAssertEqual(decoded.maxGenerations, 4)
        XCTAssertEqual(decoded.maxImagePixels, 4_194_304)
        XCTAssertEqual(decoded.maxImageSizeBytes, 20_000_000)
        XCTAssertEqual(decoded.maxPromptLength, 4000)
        XCTAssertEqual(decoded.maxReferenceImages, 2)
        XCTAssertEqual(decoded.supportedDimensions, ["1024x1024", "1792x1024", "1024x1792"])
        XCTAssertEqual(decoded.supportedGuidanceRange, DoubleRange(1.0, 20.0))
        XCTAssertEqual(decoded.supportedImageQualities, ["standard", "hd"])
        XCTAssertEqual(decoded.supportedStepsRange, IntRange(10, 100))
        XCTAssertEqual(decoded.supportedStyles, ["vivid", "natural"])
        XCTAssertTrue(decoded.supportsNegativePrompt)
        XCTAssertTrue(decoded.supportsSeed)
    }

    func testCodable_DefaultValues_RoundTrip() throws {
        let original = ModelParams()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelParams.self, from: data)

        XCTAssertEqual(decoded.active, true)
        XCTAssertEqual(decoded.maxGenerations, 1)
        XCTAssertNil(decoded.maxImagePixels)
        XCTAssertEqual(decoded.maxPromptLength, 256)
        XCTAssertTrue(decoded.supportedDimensions.isEmpty)
        XCTAssertTrue(decoded.supportsPrompt)
        XCTAssertFalse(decoded.supportsAudio)
    }

    func testCodable_ComputedProperties_AfterDecode() throws {
        let original = ModelParams(
            supportedDimensions: ["1024x1024"],
            supportedGuidanceRange: DoubleRange(1, 10),
            supportedImageQualities: ["standard"],
            supportedStepsRange: IntRange(1, 50)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelParams.self, from: data)

        // Computed properties should work correctly after decode
        XCTAssertTrue(decoded.supportsDimensions)
        XCTAssertTrue(decoded.supportsGuidanceRange)
        XCTAssertTrue(decoded.supportsQualities)
        XCTAssertTrue(decoded.supportsStepsRange)
        XCTAssertFalse(decoded.supportsMotion) // Not set
        XCTAssertFalse(decoded.supportsStyles) // Not set
    }

    func testCodable_RangeFields_PreservedCorrectly() throws {
        let original = ModelParams(
            supportedMotionRange: DoubleRange(0.0, 1.0),
            supportedStickynessRange: DoubleRange(0.5, 2.0),
            supportedGrowMaskRange: IntRange(0, 100),
            supportedGuidanceRange: DoubleRange(1.0, 20.0),
            supportedSafetyRange: IntRange(1, 5),
            supportedStepsRange: IntRange(10, 150)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelParams.self, from: data)

        XCTAssertEqual(decoded.supportedMotionRange, DoubleRange(0.0, 1.0))
        XCTAssertEqual(decoded.supportedStickynessRange, DoubleRange(0.5, 2.0))
        XCTAssertEqual(decoded.supportedGrowMaskRange, IntRange(0, 100))
        XCTAssertEqual(decoded.supportedGuidanceRange, DoubleRange(1.0, 20.0))
        XCTAssertEqual(decoded.supportedSafetyRange, IntRange(1, 5))
        XCTAssertEqual(decoded.supportedStepsRange, IntRange(10, 150))
    }

    func testCodable_ArrayFields_PreservedCorrectly() throws {
        let original = ModelParams(
            supportedBackgrounds: ["transparent", "white", "black"],
            supportedDimensions: ["1024x1024", "512x512"],
            supportedVideoDurations: [4, 8, 16],
            supportedVideoFPS: [24, 30],
            supportedStyles: ["vivid", "natural"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelParams.self, from: data)

        XCTAssertEqual(decoded.supportedBackgrounds, ["transparent", "white", "black"])
        XCTAssertEqual(decoded.supportedDimensions, ["1024x1024", "512x512"])
        XCTAssertEqual(decoded.supportedStyles, ["vivid", "natural"])
        XCTAssertEqual(decoded.supportedVideoDurations, [4, 8, 16])
        XCTAssertEqual(decoded.supportedVideoFPS, [24, 30])
    }

    // MARK: - Real-World Configuration Workflow Tests

    func testWorkflow_DallE3LikeConfig() {
        // Simulates a DALL-E 3-like model configuration
        let params = ModelParams(
            maxGenerations: 1,
            maxPromptLength: 4000,
            supportedDimensions: ["1024x1024", "1792x1024", "1024x1792"],
            supportedImageQualities: ["standard", "hd"],
            supportedStyles: ["vivid", "natural"]
        )

        XCTAssertTrue(params.supportsDimensions)
        XCTAssertTrue(params.supportsQualities)
        XCTAssertTrue(params.supportsStyles)
        XCTAssertFalse(params.supportsGuidanceRange)
        XCTAssertFalse(params.supportsStepsRange)
        XCTAssertFalse(params.supportsSourceImage)
        XCTAssertFalse(params.supportsNegativePrompt)
        XCTAssertEqual(params.effectiveDimensions.count, 3)
    }

    func testWorkflow_VideoModelLikeConfig() {
        // Simulates a video generation model configuration
        let params = ModelParams(
            maxGenerations: 1,
            supportedVideoDurations: [4, 8],
            supportedVideoFPS: [24],
            supportedVideoResolutions: ["720p", "1080p"],
            supportsSourceImage: true
        )

        XCTAssertTrue(params.supportsVideoDurations)
        XCTAssertTrue(params.supportsFPS)
        XCTAssertTrue(params.supportsVideoResolutions)
        XCTAssertTrue(params.supportsSourceImage)
        // Should have effective dimensions from defaultSourceImageDimensions
        XCTAssertTrue(params.supportsDimensions)
        XCTAssertEqual(params.effectiveDimensions.count, 7)
    }

    func testWorkflow_ImageEditingModelConfig() {
        // Model with source image support but no explicit dimensions → gets defaults
        let params = ModelParams(
            maxReferenceImages: 1,
            supportsMask: true,
            supportsSourceImage: true
        )

        XCTAssertTrue(params.supportsReferenceImages)
        XCTAssertTrue(params.supportsMask)
        XCTAssertTrue(params.supportsDimensions)
        XCTAssertEqual(params.effectiveDimensions, ModelParams.defaultSourceImageDimensions)
    }

    func testWorkflow_FullFeaturedModel() {
        // Model with every feature enabled
        let params = ModelParams(
            maxGenerations: 4,
            maxReferenceImages: 5,
            supportedDimensions: ["1024x1024"],
            supportedMotionRange: DoubleRange(0, 1),
            supportedGrowMaskRange: IntRange(0, 50),
            supportedGuidanceRange: DoubleRange(1, 20),
            supportedImageQualities: ["standard"],
            supportedStepsRange: IntRange(1, 100),
            supportedStyles: ["vivid"],
            supportsNegativePrompt: true,
            supportsSeed: true,
            supportsSourceImage: true
        )

        XCTAssertTrue(params.supportsDimensions)
        XCTAssertTrue(params.supportsReferenceImages)
        XCTAssertTrue(params.supportsMotion)
        XCTAssertTrue(params.supportsGrowMaskRange)
        XCTAssertTrue(params.supportsGuidanceRange)
        XCTAssertTrue(params.supportsQualities)
        XCTAssertTrue(params.supportsStepsRange)
        XCTAssertTrue(params.supportsStyles)
        XCTAssertTrue(params.supportsNegativePrompt)
        XCTAssertTrue(params.supportsSeed)
    }
}
