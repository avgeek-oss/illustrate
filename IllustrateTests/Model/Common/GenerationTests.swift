// MARK: - GenerationTests.swift

// Unit tests for Generation model serialization and properties.
//
// Tests cover:
// - Generation initialization with all parameters
// - Codable round-trip serialization
// - Optional field handling
// - EnumGenerationContentType enum
// - Backward compatibility with missing fields

import IllustrateProviders
import XCTest
@testable import Illustrate

final class GenerationTests: XCTestCase {
    // MARK: - EnumGenerationContentType Tests

    func testEnumGenerationContentType_allCases() {
        let allCases = EnumGenerationContentType.allCases

        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.IMAGE_2D))
        XCTAssertTrue(allCases.contains(.VIDEO))
        XCTAssertTrue(allCases.contains(.IMAGE_3D))
    }

    func testEnumGenerationContentType_rawValues() {
        XCTAssertEqual(EnumGenerationContentType.IMAGE_2D.rawValue, "IMAGE_2D")
        XCTAssertEqual(EnumGenerationContentType.VIDEO.rawValue, "VIDEO")
        XCTAssertEqual(EnumGenerationContentType.IMAGE_3D.rawValue, "IMAGE_3D")
    }

    func testEnumGenerationContentType_identifiable() {
        XCTAssertEqual(EnumGenerationContentType.IMAGE_2D.id, "IMAGE_2D")
        XCTAssertEqual(EnumGenerationContentType.VIDEO.id, "VIDEO")
        XCTAssertEqual(EnumGenerationContentType.IMAGE_3D.id, "IMAGE_3D")
    }

    func testEnumGenerationContentType_codable() throws {
        let types: [EnumGenerationContentType] = [.IMAGE_2D, .VIDEO, .IMAGE_3D]

        let data = try JSONEncoder().encode(types)
        let decoded = try JSONDecoder().decode([EnumGenerationContentType].self, from: data)

        XCTAssertEqual(decoded, types)
    }

    // MARK: - EnumGenerationStatus Tests

    func testEnumGenerationStatus_allCases() {
        let allCases = EnumGenerationStatus.allCases

        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.GENERATED))
        XCTAssertTrue(allCases.contains(.FAILED))
    }

    func testEnumGenerationStatus_rawValues() {
        XCTAssertEqual(EnumGenerationStatus.GENERATED.rawValue, "GENERATED")
        XCTAssertEqual(EnumGenerationStatus.FAILED.rawValue, "FAILED")
    }

    func testEnumGenerationStatus_codable() throws {
        let statuses: [EnumGenerationStatus] = [.GENERATED, .FAILED]

        let data = try JSONEncoder().encode(statuses)
        let decoded = try JSONDecoder().decode([EnumGenerationStatus].self, from: data)

        XCTAssertEqual(decoded, statuses)
    }

    // MARK: - Generation Initialization Tests

    func testGeneration_initialization_allParameters() {
        let id = UUID()
        let setId = UUID()
        let projectId = UUID()

        let generation = Generation(
            id: id,
            setId: setId,
            projectId: projectId,
            modelId: "model-123",
            prompt: "A beautiful landscape",
            promptEnhanceOpted: true,
            promptAfterEnhance: "A beautiful landscape with mountains",
            style: "Vivid",
            variant: "Natural",
            quality: "hd",
            dimensions: "1920x1080",
            size: 2_048_000,
            creditUsed: 0.5,
            status: .GENERATED,
            colorPalette: ["#FF0000", "#00FF00", "#0000FF"],
            modelRevisedPrompt: "Revised prompt",
            clientImage: "/path/to/source.png",
            clientMask: "/path/to/mask.png",
            clientReferenceImagesCount: 3,
            negativePrompt: "ugly, blurry",
            searchPrompt: "landscape",
            contentType: .IMAGE_2D,
            metadata: ["key": "value"]
        )

        XCTAssertEqual(generation.id, id)
        XCTAssertEqual(generation.setId, setId)
        XCTAssertEqual(generation.projectId, projectId)
        XCTAssertEqual(generation.modelId, "model-123")
        XCTAssertEqual(generation.prompt, "A beautiful landscape")
        XCTAssertTrue(generation.promptEnhanceOpted)
        XCTAssertEqual(generation.promptAfterEnhance, "A beautiful landscape with mountains")
        XCTAssertEqual(generation.style, "Vivid")
        XCTAssertEqual(generation.variant, "Natural")
        XCTAssertEqual(generation.quality, "hd")
        XCTAssertEqual(generation.dimensions, "1920x1080")
        XCTAssertEqual(generation.size, 2_048_000)
        XCTAssertEqual(generation.creditUsed, 0.5)
        XCTAssertEqual(generation.status, .GENERATED)
        XCTAssertEqual(generation.colorPalette, ["#FF0000", "#00FF00", "#0000FF"])
        XCTAssertEqual(generation.modelRevisedPrompt, "Revised prompt")
        XCTAssertTrue(generation.hasClientImage)
        XCTAssertTrue(generation.hasClientMask)
        XCTAssertEqual(generation.clientReferenceImagesCount, 3)
        XCTAssertEqual(generation.negativePrompt, "ugly, blurry")
        XCTAssertEqual(generation.searchPrompt, "landscape")
        XCTAssertEqual(generation.contentType, .IMAGE_2D)
        XCTAssertEqual(generation.metadata["key"], "value")
    }

    func testGeneration_initialization_defaultValues() {
        let generation = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model-123",
            prompt: "Test",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1024x1024",
            size: 1000,
            creditUsed: 0.1,
            status: .GENERATED,
            colorPalette: []
        )

        // Check defaults
        XCTAssertEqual(generation.style, "Natural")
        XCTAssertEqual(generation.variant, "Normal")
        XCTAssertEqual(generation.quality, "")
        XCTAssertNil(generation.modelRevisedPrompt)
        XCTAssertFalse(generation.hasClientImage)
        XCTAssertFalse(generation.hasClientMask)
        XCTAssertEqual(generation.clientReferenceImagesCount, 0)
        XCTAssertNil(generation.negativePrompt)
        XCTAssertNil(generation.searchPrompt)
        XCTAssertEqual(generation.contentType, .IMAGE_2D)
        XCTAssertTrue(generation.metadata.isEmpty)
    }

    // MARK: - Generation Codable Tests

    func testGeneration_codableRoundTrip_allFields() throws {
        let id = UUID()
        let setId = UUID()
        let projectId = UUID()
        let runId = UUID()
        let agentId = UUID()
        let realtimeSessionId = UUID()

        let original = Generation(
            id: id,
            setId: setId,
            projectId: projectId,
            modelId: "model-456",
            prompt: "A sunset over the ocean",
            promptEnhanceOpted: true,
            promptAfterEnhance: "Enhanced sunset prompt",
            style: "Dramatic",
            variant: "Cinematic",
            quality: "ultra",
            dimensions: "2048x2048",
            size: 4_096_000,
            creditUsed: 1.5,
            status: .GENERATED,
            colorPalette: ["#FFA500", "#FF4500"],
            modelRevisedPrompt: "Model revised it",
            clientImage: "/source.jpg",
            clientMask: "/mask.jpg",
            clientReferenceImagesCount: 2,
            negativePrompt: "low quality",
            searchPrompt: "ocean",
            contentType: .VIDEO,
            metadata: ["duration": "10s", "fps": "24"]
        )
        original.runId = runId
        original.agentId = agentId
        original.isHidden = true
        original.realtimeSessionId = realtimeSessionId

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Generation.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.setId, setId)
        XCTAssertEqual(decoded.projectId, projectId)
        XCTAssertEqual(decoded.modelId, "model-456")
        XCTAssertEqual(decoded.prompt, "A sunset over the ocean")
        XCTAssertTrue(decoded.promptEnhanceOpted)
        XCTAssertEqual(decoded.promptAfterEnhance, "Enhanced sunset prompt")
        XCTAssertEqual(decoded.style, "Dramatic")
        XCTAssertEqual(decoded.variant, "Cinematic")
        XCTAssertEqual(decoded.quality, "ultra")
        XCTAssertEqual(decoded.dimensions, "2048x2048")
        XCTAssertEqual(decoded.size, 4_096_000)
        XCTAssertEqual(decoded.creditUsed, 1.5)
        XCTAssertEqual(decoded.status, .GENERATED)
        XCTAssertEqual(decoded.colorPalette, ["#FFA500", "#FF4500"])
        XCTAssertEqual(decoded.modelRevisedPrompt, "Model revised it")
        XCTAssertTrue(decoded.hasClientImage)
        XCTAssertTrue(decoded.hasClientMask)
        XCTAssertEqual(decoded.clientReferenceImagesCount, 2)
        XCTAssertEqual(decoded.negativePrompt, "low quality")
        XCTAssertEqual(decoded.searchPrompt, "ocean")
        XCTAssertEqual(decoded.contentType, .VIDEO)
        XCTAssertEqual(decoded.metadata["duration"], "10s")
        XCTAssertEqual(decoded.metadata["fps"], "24")
        XCTAssertEqual(decoded.runId, runId)
        XCTAssertEqual(decoded.agentId, agentId)
        XCTAssertTrue(decoded.isHidden)
        XCTAssertEqual(decoded.realtimeSessionId, realtimeSessionId)
    }

    func testGeneration_codableRoundTrip_minimalFields() throws {
        let original = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model-min",
            prompt: "Minimal",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "512x512",
            size: 500,
            creditUsed: 0.01,
            status: .FAILED,
            colorPalette: []
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.modelId, "model-min")
        XCTAssertEqual(decoded.status, .FAILED)
        XCTAssertNil(decoded.modelRevisedPrompt)
        XCTAssertFalse(decoded.hasClientImage)
        XCTAssertNil(decoded.runId)
        XCTAssertFalse(decoded.isHidden)
    }

    func testGeneration_codable_emptyColorPalette() throws {
        let original = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model",
            prompt: "Test",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1024x1024",
            size: 1000,
            creditUsed: 0.1,
            status: .GENERATED,
            colorPalette: []
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertTrue(decoded.colorPalette.isEmpty)
    }

    func testGeneration_codable_largeColorPalette() throws {
        let colors = (1 ... 10).map { "#\(String(format: "%06X", $0 * 100_000))" }

        let original = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model",
            prompt: "Test",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1024x1024",
            size: 1000,
            creditUsed: 0.1,
            status: .GENERATED,
            colorPalette: colors
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertEqual(decoded.colorPalette.count, 10)
    }

    func testGeneration_codable_emptyMetadata() throws {
        let original = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model",
            prompt: "Test",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1024x1024",
            size: 1000,
            creditUsed: 0.1,
            status: .GENERATED,
            colorPalette: [],
            metadata: [:]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertTrue(decoded.metadata.isEmpty)
    }

    func testGeneration_codable_complexMetadata() throws {
        let metadata: [String: String] = [
            "video_uri": "gs://bucket/video.mp4",
            "generation_id": "gen-12345",
            "processing_time": "45.3",
            "model_version": "v2.1",
        ]

        let original = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model",
            prompt: "Test",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1024x1024",
            size: 1000,
            creditUsed: 0.1,
            status: .GENERATED,
            colorPalette: [],
            metadata: metadata
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertEqual(decoded.metadata.count, 4)
        XCTAssertEqual(decoded.metadata["video_uri"], "gs://bucket/video.mp4")
        XCTAssertEqual(decoded.metadata["generation_id"], "gen-12345")
    }

    // MARK: - Generation Content Type Tests

    func testGeneration_contentType_image2D() throws {
        let original = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model",
            prompt: "Image",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1024x1024",
            size: 1000,
            creditUsed: 0.1,
            status: .GENERATED,
            colorPalette: [],
            contentType: .IMAGE_2D
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertEqual(decoded.contentType, .IMAGE_2D)
    }

    func testGeneration_contentType_video() throws {
        let original = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model",
            prompt: "Video",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1920x1080",
            size: 50_000_000,
            creditUsed: 2.0,
            status: .GENERATED,
            colorPalette: [],
            contentType: .VIDEO
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertEqual(decoded.contentType, .VIDEO)
    }

    func testGeneration_contentType_image3D() throws {
        let original = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model",
            prompt: "3D Model",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1024x1024",
            size: 10_000_000,
            creditUsed: 5.0,
            status: .GENERATED,
            colorPalette: [],
            contentType: .IMAGE_3D
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertEqual(decoded.contentType, .IMAGE_3D)
    }

    // MARK: - Generation Status Tests

    func testGeneration_status_generated() throws {
        let original = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model",
            prompt: "Success",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1024x1024",
            size: 1000,
            creditUsed: 0.1,
            status: .GENERATED,
            colorPalette: []
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertEqual(decoded.status, .GENERATED)
    }

    func testGeneration_status_failed() throws {
        let original = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model",
            prompt: "Failed request",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1024x1024",
            size: 0,
            creditUsed: 0,
            status: .FAILED,
            colorPalette: []
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertEqual(decoded.status, .FAILED)
    }

    // MARK: - Edge Cases

    func testGeneration_specialCharactersInPrompt() throws {
        let specialPrompt = "A café with émojis 🎨 and \"quotes\" & <symbols>"

        let original = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model",
            prompt: specialPrompt,
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1024x1024",
            size: 1000,
            creditUsed: 0.1,
            status: .GENERATED,
            colorPalette: []
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertEqual(decoded.prompt, specialPrompt)
    }

    func testGeneration_unicodeInNegativePrompt() throws {
        let original = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model",
            prompt: "Test",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1024x1024",
            size: 1000,
            creditUsed: 0.1,
            status: .GENERATED,
            colorPalette: [],
            negativePrompt: "日本語テスト 한국어 العربية"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertEqual(decoded.negativePrompt, "日本語テスト 한국어 العربية")
    }

    func testGeneration_zeroCreditUsed() throws {
        let original = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model",
            prompt: "Free generation",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1024x1024",
            size: 1000,
            creditUsed: 0,
            status: .GENERATED,
            colorPalette: []
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertEqual(decoded.creditUsed, 0)
    }

    func testGeneration_largeCreditUsed() throws {
        let original = Generation(
            id: UUID(),
            setId: UUID(),
            modelId: "model",
            prompt: "Expensive generation",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "4096x4096",
            size: 100_000_000,
            creditUsed: 999.99,
            status: .GENERATED,
            colorPalette: []
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertEqual(decoded.creditUsed, 999.99, accuracy: 0.001)
    }
}
