// MARK: - AgentCardConfigurationTests.swift

// Unit tests for AgentCard configuration structs.
//
// Tests cover:
// - StartCardConfiguration serialization and defaults
// - ImageGenerationConfiguration serialization and defaults
// - VideoGenerationConfiguration serialization and defaults
// - ReferenceImageConfig serialization
// - PreviousCardInput computed properties
// - AgentCard factory methods and configuration accessors
// - CardType and ProcessCardType enums

import XCTest
@testable import Illustrate

final class AgentCardConfigurationTests: XCTestCase {
    // MARK: - StartCardConfiguration Tests

    func testStartCardConfiguration_defaultValues() {
        let config = StartCardConfiguration()

        XCTAssertEqual(config.inputType, "Text")
        XCTAssertEqual(config.textInput, "")
        XCTAssertNil(config.imagePath)
        XCTAssertNil(config.videoPath)
    }

    func testStartCardConfiguration_codableRoundTrip() throws {
        var config = StartCardConfiguration()
        config.inputType = "Image"
        config.textInput = "Test prompt"
        config.imagePath = "/path/to/image.png"
        config.videoPath = "/path/to/video.mp4"

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(StartCardConfiguration.self, from: data)

        XCTAssertEqual(decoded.inputType, "Image")
        XCTAssertEqual(decoded.textInput, "Test prompt")
        XCTAssertEqual(decoded.imagePath, "/path/to/image.png")
        XCTAssertEqual(decoded.videoPath, "/path/to/video.mp4")
    }

    func testStartCardConfiguration_codableWithNilOptionals() throws {
        let config = StartCardConfiguration()

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(StartCardConfiguration.self, from: data)

        XCTAssertNil(decoded.imagePath)
        XCTAssertNil(decoded.videoPath)
    }

    // MARK: - ImageGenerationConfiguration Tests

    func testImageGenerationConfiguration_defaultValues() {
        let config = ImageGenerationConfiguration()

        XCTAssertEqual(config.selectedProviderId, "")
        XCTAssertEqual(config.selectedModelId, "")
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.negativePrompt, "")
        XCTAssertEqual(config.selectedDimensions, "1024x1024")
        XCTAssertEqual(config.selectedQuality, "standard")
        XCTAssertEqual(config.stepsValue, 28)
        XCTAssertEqual(config.guidanceValue, 3.5)
        XCTAssertEqual(config.seedValue, "")
        XCTAssertEqual(config.safetyValue, 5)
        XCTAssertEqual(config.growMaskValue, 3)
        XCTAssertTrue(config.modelPromptEnhance)
        XCTAssertTrue(config.referenceImages.isEmpty)
        XCTAssertFalse(config.usePreviousImageAsReference)
        XCTAssertFalse(config.usePreviousImageAsSourceImage)
    }

    func testImageGenerationConfiguration_codableRoundTrip() throws {
        var config = ImageGenerationConfiguration()
        config.selectedProviderId = "provider-123"
        config.selectedModelId = "model-456"
        config.prompt = "A beautiful sunset"
        config.negativePrompt = "ugly, blurry"
        config.searchPrompt = "sunset"
        config.selectedDimensions = "1920x1080"
        config.selectedQuality = "hd"
        config.selectedStyle = "vivid"
        config.selectedVariant = "natural"
        config.stepsValue = 50
        config.guidanceValue = 7.5
        config.seedValue = "12345"
        config.safetyValue = 3
        config.modelPromptEnhance = false
        config.usePreviousImageAsReference = true
        config.usePreviousImageAsSourceImage = true

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ImageGenerationConfiguration.self, from: data)

        XCTAssertEqual(decoded.selectedProviderId, "provider-123")
        XCTAssertEqual(decoded.selectedModelId, "model-456")
        XCTAssertEqual(decoded.prompt, "A beautiful sunset")
        XCTAssertEqual(decoded.negativePrompt, "ugly, blurry")
        XCTAssertEqual(decoded.searchPrompt, "sunset")
        XCTAssertEqual(decoded.selectedDimensions, "1920x1080")
        XCTAssertEqual(decoded.selectedQuality, "hd")
        XCTAssertEqual(decoded.selectedStyle, "vivid")
        XCTAssertEqual(decoded.selectedVariant, "natural")
        XCTAssertEqual(decoded.stepsValue, 50)
        XCTAssertEqual(decoded.guidanceValue, 7.5)
        XCTAssertEqual(decoded.seedValue, "12345")
        XCTAssertEqual(decoded.safetyValue, 3)
        XCTAssertFalse(decoded.modelPromptEnhance)
        XCTAssertTrue(decoded.usePreviousImageAsReference)
        XCTAssertTrue(decoded.usePreviousImageAsSourceImage)
    }

    func testImageGenerationConfiguration_withReferenceImages() throws {
        var config = ImageGenerationConfiguration()
        config.referenceImages = [
            ReferenceImageConfig(imagePath: "/image1.png", referenceType: "style"),
            ReferenceImageConfig(imagePath: "/image2.png", referenceType: "asset"),
        ]

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ImageGenerationConfiguration.self, from: data)

        XCTAssertEqual(decoded.referenceImages.count, 2)
        XCTAssertEqual(decoded.referenceImages[0].imagePath, "/image1.png")
        XCTAssertEqual(decoded.referenceImages[0].referenceType, "style")
        XCTAssertEqual(decoded.referenceImages[1].imagePath, "/image2.png")
        XCTAssertEqual(decoded.referenceImages[1].referenceType, "asset")
    }

    func testImageGenerationConfiguration_withSelectedTools() throws {
        var config = ImageGenerationConfiguration()
        config.selectedTools = ["tool1", "tool2", "tool3"]

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ImageGenerationConfiguration.self, from: data)

        XCTAssertEqual(decoded.selectedTools, ["tool1", "tool2", "tool3"])
    }

    // MARK: - VideoGenerationConfiguration Tests

    func testVideoGenerationConfiguration_defaultValues() {
        let config = VideoGenerationConfiguration()

        XCTAssertEqual(config.selectedProviderId, "")
        XCTAssertEqual(config.selectedModelId, "")
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.negativePrompt, "")
        XCTAssertEqual(config.selectedDimensions, "1280x720")
        XCTAssertEqual(config.durationSeconds, 5)
        XCTAssertEqual(config.selectedFPS, 24)
        XCTAssertFalse(config.generateAudio)
        XCTAssertEqual(config.guidanceValue, 3.5)
        XCTAssertEqual(config.seedValue, "")
        XCTAssertEqual(config.safetyValue, 5)
        XCTAssertTrue(config.modelPromptEnhance)
        XCTAssertFalse(config.usePreviousImageAsSourceImage)
    }

    func testVideoGenerationConfiguration_codableRoundTrip() throws {
        var config = VideoGenerationConfiguration()
        config.selectedProviderId = "video-provider"
        config.selectedModelId = "video-model"
        config.prompt = "A timelapse of clouds"
        config.negativePrompt = "static, boring"
        config.selectedDimensions = "1920x1080"
        config.selectedResolution = "4K"
        config.durationSeconds = 10
        config.selectedFPS = 60
        config.generateAudio = true
        config.guidanceValue = 5.0
        config.seedValue = "67890"
        config.safetyValue = 2
        config.modelPromptEnhance = false
        config.usePreviousImageAsSourceImage = true

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VideoGenerationConfiguration.self, from: data)

        XCTAssertEqual(decoded.selectedProviderId, "video-provider")
        XCTAssertEqual(decoded.selectedModelId, "video-model")
        XCTAssertEqual(decoded.prompt, "A timelapse of clouds")
        XCTAssertEqual(decoded.negativePrompt, "static, boring")
        XCTAssertEqual(decoded.selectedDimensions, "1920x1080")
        XCTAssertEqual(decoded.selectedResolution, "4K")
        XCTAssertEqual(decoded.durationSeconds, 10)
        XCTAssertEqual(decoded.selectedFPS, 60)
        XCTAssertTrue(decoded.generateAudio)
        XCTAssertEqual(decoded.guidanceValue, 5.0)
        XCTAssertEqual(decoded.seedValue, "67890")
        XCTAssertEqual(decoded.safetyValue, 2)
        XCTAssertFalse(decoded.modelPromptEnhance)
        XCTAssertTrue(decoded.usePreviousImageAsSourceImage)
    }

    // MARK: - ReferenceImageConfig Tests

    func testReferenceImageConfig_initialization() {
        let config = ReferenceImageConfig(imagePath: "/path/to/ref.png", referenceType: "style")

        XCTAssertNotEqual(config.id, UUID())
        XCTAssertEqual(config.imagePath, "/path/to/ref.png")
        XCTAssertEqual(config.referenceType, "style")
    }

    func testReferenceImageConfig_codableRoundTrip() throws {
        let original = ReferenceImageConfig(imagePath: "/ref.png", referenceType: "asset")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ReferenceImageConfig.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.imagePath, "/ref.png")
        XCTAssertEqual(decoded.referenceType, "asset")
    }

    func testReferenceImageConfig_identifiable() {
        let config1 = ReferenceImageConfig(imagePath: "/a.png", referenceType: "style")
        let config2 = ReferenceImageConfig(imagePath: "/b.png", referenceType: "style")

        XCTAssertNotEqual(config1.id, config2.id, "Each instance should have unique ID")
    }

    // MARK: - PreviousCardInput Tests

    func testPreviousCardInput_hasText_withNonEmptyText() {
        let input = PreviousCardInput(text: "Hello")

        XCTAssertTrue(input.hasText)
    }

    func testPreviousCardInput_hasText_withEmptyText() {
        let input = PreviousCardInput(text: "")

        XCTAssertFalse(input.hasText)
    }

    func testPreviousCardInput_hasText_withNilText() {
        let input = PreviousCardInput(text: nil)

        XCTAssertFalse(input.hasText)
    }

    func testPreviousCardInput_hasImage_withImage() {
        #if os(macOS)
        let image = NSImage()
        #else
        let image = UIImage()
        #endif
        let input = PreviousCardInput(image: image)

        XCTAssertTrue(input.hasImage)
    }

    func testPreviousCardInput_hasImage_withNilImage() {
        let input = PreviousCardInput(image: nil)

        XCTAssertFalse(input.hasImage)
    }

    func testPreviousCardInput_hasVideo_withVideo() throws {
        let videoURL = try XCTUnwrap(URL(string: "file:///video.mp4"))
        let input = PreviousCardInput(video: videoURL)

        XCTAssertTrue(input.hasVideo)
    }

    func testPreviousCardInput_hasVideo_withNilVideo() {
        let input = PreviousCardInput(video: nil)

        XCTAssertFalse(input.hasVideo)
    }

    func testPreviousCardInput_hasAnyInput_withText() {
        let input = PreviousCardInput(text: "Hello")

        XCTAssertTrue(input.hasAnyInput)
    }

    func testPreviousCardInput_hasAnyInput_withVideo() throws {
        let input = try PreviousCardInput(video: XCTUnwrap(URL(string: "file:///video.mp4")))

        XCTAssertTrue(input.hasAnyInput)
    }

    func testPreviousCardInput_hasAnyInput_withNothing() {
        let input = PreviousCardInput()

        XCTAssertFalse(input.hasAnyInput)
    }

    func testPreviousCardInput_canProvideImage_withImage() {
        #if os(macOS)
        let image = NSImage()
        #else
        let image = UIImage()
        #endif
        let input = PreviousCardInput(image: image)

        XCTAssertTrue(input.canProvideImage)
    }

    func testPreviousCardInput_canProvideImage_withPlaceholder() {
        let input = PreviousCardInput(isImagePlaceholder: true)

        XCTAssertTrue(input.canProvideImage)
    }

    func testPreviousCardInput_canProvideImage_withNeither() {
        let input = PreviousCardInput()

        XCTAssertFalse(input.canProvideImage)
    }

    // MARK: - CardType Tests

    func testCardType_allCases() {
        let allCases = CardType.allCases

        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.start))
        XCTAssertTrue(allCases.contains(.process))
        XCTAssertTrue(allCases.contains(.output))
    }

    func testCardType_rawValues() {
        XCTAssertEqual(CardType.start.rawValue, "start")
        XCTAssertEqual(CardType.process.rawValue, "process")
        XCTAssertEqual(CardType.output.rawValue, "output")
    }

    func testCardType_identifiable() {
        XCTAssertEqual(CardType.start.id, "start")
        XCTAssertEqual(CardType.process.id, "process")
        XCTAssertEqual(CardType.output.id, "output")
    }

    func testCardType_codable() throws {
        let types: [CardType] = [.start, .process, .output]

        let data = try JSONEncoder().encode(types)
        let decoded = try JSONDecoder().decode([CardType].self, from: data)

        XCTAssertEqual(decoded, types)
    }

    // MARK: - ProcessCardType Tests

    func testProcessCardType_allCases() {
        let allCases = ProcessCardType.allCases

        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.imageGeneration))
        XCTAssertTrue(allCases.contains(.videoGeneration))
    }

    func testProcessCardType_rawValues() {
        XCTAssertEqual(ProcessCardType.imageGeneration.rawValue, "image_generation")
        XCTAssertEqual(ProcessCardType.videoGeneration.rawValue, "video_generation")
    }

    func testProcessCardType_displayName() {
        XCTAssertEqual(ProcessCardType.imageGeneration.displayName, "Image Generation")
        XCTAssertEqual(ProcessCardType.videoGeneration.displayName, "Video Generation")
    }

    func testProcessCardType_icon() {
        XCTAssertEqual(ProcessCardType.imageGeneration.icon, "photo.fill")
        XCTAssertEqual(ProcessCardType.videoGeneration.icon, "video.fill")
    }

    func testProcessCardType_codable() throws {
        let types: [ProcessCardType] = [.imageGeneration, .videoGeneration]

        let data = try JSONEncoder().encode(types)
        let decoded = try JSONDecoder().decode([ProcessCardType].self, from: data)

        XCTAssertEqual(decoded, types)
    }

    // MARK: - AgentCard Factory Method Tests

    func testAgentCard_createDefault() {
        let agentId = UUID()
        let card = AgentCard.createDefault(agentId: agentId)

        XCTAssertEqual(card.agentId, agentId)
        XCTAssertEqual(card.cardType, .start)
        XCTAssertTrue(card.isDefault)
        XCTAssertEqual(card.title, "Start")
        XCTAssertEqual(card.position, .zero)
    }

    func testAgentCard_createDefault_withPosition() {
        let agentId = UUID()
        let position = CGPoint(x: 100, y: 200)
        let card = AgentCard.createDefault(agentId: agentId, position: position)

        XCTAssertEqual(card.position, position)
    }

    func testAgentCard_createProcessCard_imageGeneration() {
        let agentId = UUID()
        let card = AgentCard.createProcessCard(
            agentId: agentId,
            processType: .imageGeneration
        )

        XCTAssertEqual(card.agentId, agentId)
        XCTAssertEqual(card.cardType, .process)
        XCTAssertEqual(card.processCardType, .imageGeneration)
        XCTAssertFalse(card.isDefault)
        XCTAssertEqual(card.title, "Image Generation")
    }

    func testAgentCard_createProcessCard_videoGeneration() {
        let agentId = UUID()
        let card = AgentCard.createProcessCard(
            agentId: agentId,
            processType: .videoGeneration,
            position: CGPoint(x: 50, y: 75)
        )

        XCTAssertEqual(card.cardType, .process)
        XCTAssertEqual(card.processCardType, .videoGeneration)
        XCTAssertEqual(card.title, "Video Generation")
        XCTAssertEqual(card.position, CGPoint(x: 50, y: 75))
    }

    func testAgentCard_createOutputCard() {
        let agentId = UUID()
        let card = AgentCard.createOutputCard(agentId: agentId)

        XCTAssertEqual(card.agentId, agentId)
        XCTAssertEqual(card.cardType, .output)
        XCTAssertFalse(card.isDefault)
        XCTAssertEqual(card.title, "Output")
        XCTAssertNil(card.processCardType)
    }

    // MARK: - AgentCard Configuration Accessor Tests

    func testAgentCard_startConfiguration_getDefault() {
        let card = AgentCard(agentId: UUID(), cardType: .start)

        let config = card.startConfiguration

        XCTAssertEqual(config.inputType, "Text")
        XCTAssertEqual(config.textInput, "")
    }

    func testAgentCard_startConfiguration_setAndGet() {
        let card = AgentCard(agentId: UUID(), cardType: .start)

        var config = StartCardConfiguration()
        config.inputType = "Image"
        config.textInput = "Test input"
        card.startConfiguration = config

        let retrieved = card.startConfiguration
        XCTAssertEqual(retrieved.inputType, "Image")
        XCTAssertEqual(retrieved.textInput, "Test input")
    }

    func testAgentCard_imageGenerationConfiguration_getDefault() {
        let card = AgentCard.createProcessCard(agentId: UUID(), processType: .imageGeneration)

        let config = card.imageGenerationConfiguration

        XCTAssertEqual(config.selectedDimensions, "1024x1024")
        XCTAssertEqual(config.stepsValue, 28)
    }

    func testAgentCard_imageGenerationConfiguration_setAndGet() {
        let card = AgentCard.createProcessCard(agentId: UUID(), processType: .imageGeneration)

        var config = ImageGenerationConfiguration()
        config.prompt = "A test prompt"
        config.selectedDimensions = "512x512"
        config.stepsValue = 40
        card.imageGenerationConfiguration = config

        let retrieved = card.imageGenerationConfiguration
        XCTAssertEqual(retrieved.prompt, "A test prompt")
        XCTAssertEqual(retrieved.selectedDimensions, "512x512")
        XCTAssertEqual(retrieved.stepsValue, 40)
    }

    func testAgentCard_videoGenerationConfiguration_getDefault() {
        let card = AgentCard.createProcessCard(agentId: UUID(), processType: .videoGeneration)

        let config = card.videoGenerationConfiguration

        XCTAssertEqual(config.selectedDimensions, "1280x720")
        XCTAssertEqual(config.durationSeconds, 5)
        XCTAssertEqual(config.selectedFPS, 24)
    }

    func testAgentCard_videoGenerationConfiguration_setAndGet() {
        let card = AgentCard.createProcessCard(agentId: UUID(), processType: .videoGeneration)

        var config = VideoGenerationConfiguration()
        config.prompt = "Video prompt"
        config.durationSeconds = 15
        config.selectedFPS = 30
        card.videoGenerationConfiguration = config

        let retrieved = card.videoGenerationConfiguration
        XCTAssertEqual(retrieved.prompt, "Video prompt")
        XCTAssertEqual(retrieved.durationSeconds, 15)
        XCTAssertEqual(retrieved.selectedFPS, 30)
    }

    // MARK: - AgentCard Position Tests

    func testAgentCard_position_computedProperty() {
        let card = AgentCard(agentId: UUID())

        card.position = CGPoint(x: 150, y: 250)

        XCTAssertEqual(card.positionX, 150)
        XCTAssertEqual(card.positionY, 250)
        XCTAssertEqual(card.position, CGPoint(x: 150, y: 250))
    }

    func testAgentCard_position_negativeValues() {
        let card = AgentCard(agentId: UUID())

        card.position = CGPoint(x: -100, y: -200)

        XCTAssertEqual(card.positionX, -100)
        XCTAssertEqual(card.positionY, -200)
    }

    // MARK: - AgentCard Codable Tests

    func testAgentCard_codableRoundTrip() throws {
        let agentId = UUID()
        let card = AgentCard(
            agentId: agentId,
            cardType: .process,
            processCardType: .imageGeneration,
            position: CGPoint(x: 100, y: 200),
            isDefault: false,
            title: "Test Card"
        )
        card.isRunning = true
        card.isErrored = true
        card.errorMessage = "Test error"
        card.generationId = UUID()

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(AgentCard.self, from: data)

        XCTAssertEqual(decoded.id, card.id)
        XCTAssertEqual(decoded.agentId, agentId)
        XCTAssertEqual(decoded.cardType, .process)
        XCTAssertEqual(decoded.processCardType, .imageGeneration)
        XCTAssertEqual(decoded.positionX, 100)
        XCTAssertEqual(decoded.positionY, 200)
        XCTAssertFalse(decoded.isDefault)
        XCTAssertEqual(decoded.title, "Test Card")
        XCTAssertTrue(decoded.isRunning)
        XCTAssertTrue(decoded.isErrored)
        XCTAssertEqual(decoded.errorMessage, "Test error")
        XCTAssertEqual(decoded.generationId, card.generationId)
    }

    func testAgentCard_codable_withConfiguration() throws {
        let card = AgentCard.createProcessCard(agentId: UUID(), processType: .imageGeneration)

        var config = ImageGenerationConfiguration()
        config.prompt = "Encoded prompt"
        card.imageGenerationConfiguration = config

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(AgentCard.self, from: data)

        XCTAssertEqual(decoded.imageGenerationConfiguration.prompt, "Encoded prompt")
    }

    func testAgentCard_codable_withoutOptionalFields() throws {
        let card = AgentCard(agentId: UUID())

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(AgentCard.self, from: data)

        XCTAssertNil(decoded.processCardType)
        XCTAssertNil(decoded.generationId)
        XCTAssertNil(decoded.errorMessage)
        XCTAssertFalse(decoded.isRunning)
        XCTAssertFalse(decoded.isErrored)
    }
}
