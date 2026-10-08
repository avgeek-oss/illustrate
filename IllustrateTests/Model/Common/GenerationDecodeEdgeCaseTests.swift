// MARK: - GenerationDecodeEdgeCaseTests.swift

// Tests for Generation's init(from decoder:) decodeIfPresent defaults.
//
// Existing GenerationTests covers: init with params, full Codable round-trip,
// and content types. This file tests each decodeIfPresent field individually
// by constructing partial JSON with specific fields removed.

import IllustrateProviders
import XCTest
@testable import Illustrate

final class GenerationDecodeEdgeCaseTests: XCTestCase {
    // MARK: - Helpers

    /// Creates a full Generation and encodes to JSON dictionary for modification.
    private func makeFullGenerationJSON() throws -> [String: Any] {
        let gen = Generation(
            id: UUID(),
            setId: UUID(),
            projectId: UUID(),
            modelId: "test-model",
            prompt: "test prompt",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1024x1024",
            size: 1000,
            creditUsed: 0.5,
            status: .GENERATED,
            colorPalette: ["#FF0000"]
        )
        gen.runId = UUID()
        gen.agentId = UUID()
        gen.isHidden = true
        gen.realtimeSessionId = UUID()
        gen.hasClientImage = true
        gen.hasClientMask = true
        gen.clientReferenceImagesCount = 3
        gen.negativePrompt = "blurry"
        gen.searchPrompt = "find object"
        gen.modelRevisedPrompt = "revised prompt"
        gen.metadata = ["key1": "val1", "key2": "val2"]

        let data = try JSONEncoder().encode(gen)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    private func decodeGeneration(from json: [String: Any]) throws -> Generation {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(Generation.self, from: data)
    }

    // MARK: - Individual decodeIfPresent Defaults

    func testMissingProjectId_DefaultsToDefaultProjectId() throws {
        var json = try makeFullGenerationJSON()
        json.removeValue(forKey: "projectId")
        let gen = try decodeGeneration(from: json)
        XCTAssertEqual(gen.projectId, Project.defaultProjectId)
    }

    func testMissingClientReferenceImagesCount_DefaultsToZero() throws {
        var json = try makeFullGenerationJSON()
        json.removeValue(forKey: "clientReferenceImagesCount")
        let gen = try decodeGeneration(from: json)
        XCTAssertEqual(gen.clientReferenceImagesCount, 0)
    }

    func testMissingMetadata_DefaultsToEmptyDict() throws {
        var json = try makeFullGenerationJSON()
        json.removeValue(forKey: "metadata")
        let gen = try decodeGeneration(from: json)
        XCTAssertTrue(gen.metadata.isEmpty)
    }

    func testMissingRunId_DefaultsToNil() throws {
        var json = try makeFullGenerationJSON()
        json.removeValue(forKey: "runId")
        let gen = try decodeGeneration(from: json)
        XCTAssertNil(gen.runId)
    }

    func testMissingAgentId_DefaultsToNil() throws {
        var json = try makeFullGenerationJSON()
        json.removeValue(forKey: "agentId")
        let gen = try decodeGeneration(from: json)
        XCTAssertNil(gen.agentId)
    }

    func testMissingIsHidden_DefaultsToFalse() throws {
        var json = try makeFullGenerationJSON()
        json.removeValue(forKey: "isHidden")
        let gen = try decodeGeneration(from: json)
        XCTAssertFalse(gen.isHidden)
    }

    func testMissingRealtimeSessionId_DefaultsToNil() throws {
        var json = try makeFullGenerationJSON()
        json.removeValue(forKey: "realtimeSessionId")
        let gen = try decodeGeneration(from: json)
        XCTAssertNil(gen.realtimeSessionId)
    }

    func testMissingModelRevisedPrompt_DefaultsToNil() throws {
        var json = try makeFullGenerationJSON()
        json.removeValue(forKey: "modelRevisedPrompt")
        let gen = try decodeGeneration(from: json)
        XCTAssertNil(gen.modelRevisedPrompt)
    }

    func testMissingHasClientImage_DefaultsToFalse() throws {
        var json = try makeFullGenerationJSON()
        json.removeValue(forKey: "hasClientImage")
        let gen = try decodeGeneration(from: json)
        XCTAssertFalse(gen.hasClientImage)
    }

    func testMissingHasClientMask_DefaultsToFalse() throws {
        var json = try makeFullGenerationJSON()
        json.removeValue(forKey: "hasClientMask")
        let gen = try decodeGeneration(from: json)
        XCTAssertFalse(gen.hasClientMask)
    }

    func testMissingNegativePrompt_DefaultsToNil() throws {
        var json = try makeFullGenerationJSON()
        json.removeValue(forKey: "negativePrompt")
        let gen = try decodeGeneration(from: json)
        XCTAssertNil(gen.negativePrompt)
    }

    func testMissingSearchPrompt_DefaultsToNil() throws {
        var json = try makeFullGenerationJSON()
        json.removeValue(forKey: "searchPrompt")
        let gen = try decodeGeneration(from: json)
        XCTAssertNil(gen.searchPrompt)
    }

    // MARK: - Combined Missing Fields

    func testAllOptionalFieldsMissing_AllDefaults() throws {
        var json = try makeFullGenerationJSON()
        let optionalKeys = [
            "projectId", "clientReferenceImagesCount", "metadata",
            "runId", "agentId", "isHidden", "realtimeSessionId",
            "modelRevisedPrompt", "hasClientImage", "hasClientMask",
            "negativePrompt", "searchPrompt",
        ]
        for key in optionalKeys {
            json.removeValue(forKey: key)
        }
        let gen = try decodeGeneration(from: json)

        XCTAssertEqual(gen.projectId, Project.defaultProjectId)
        XCTAssertEqual(gen.clientReferenceImagesCount, 0)
        XCTAssertTrue(gen.metadata.isEmpty)
        XCTAssertNil(gen.runId)
        XCTAssertNil(gen.agentId)
        XCTAssertFalse(gen.isHidden)
        XCTAssertNil(gen.realtimeSessionId)
        XCTAssertNil(gen.modelRevisedPrompt)
        XCTAssertFalse(gen.hasClientImage)
        XCTAssertFalse(gen.hasClientMask)
        XCTAssertNil(gen.negativePrompt)
        XCTAssertNil(gen.searchPrompt)
    }

    func testOnlyAgentFieldsMissing_BothNil() throws {
        var json = try makeFullGenerationJSON()
        json.removeValue(forKey: "runId")
        json.removeValue(forKey: "agentId")
        let gen = try decodeGeneration(from: json)

        XCTAssertNil(gen.runId)
        XCTAssertNil(gen.agentId)
        // Other fields should still be present
        XCTAssertTrue(gen.hasClientImage)
    }

    func testOnlyMediaFieldsMissing_AllDefaults() throws {
        var json = try makeFullGenerationJSON()
        json.removeValue(forKey: "hasClientImage")
        json.removeValue(forKey: "hasClientMask")
        json.removeValue(forKey: "clientReferenceImagesCount")
        let gen = try decodeGeneration(from: json)

        XCTAssertFalse(gen.hasClientImage)
        XCTAssertFalse(gen.hasClientMask)
        XCTAssertEqual(gen.clientReferenceImagesCount, 0)
        // Other fields should still be present
        XCTAssertNotNil(gen.runId)
    }

    // MARK: - Generation With Agent Context Preserved

    func testRunIdAndAgentId_PreservedThroughCodable() throws {
        let runId = UUID()
        let agentId = UUID()
        let gen = Generation(
            id: UUID(), setId: UUID(), modelId: "m", prompt: "p",
            promptEnhanceOpted: false, promptAfterEnhance: "",
            dimensions: "1024x1024", size: 100, creditUsed: 0.1,
            status: .GENERATED, colorPalette: []
        )
        gen.runId = runId
        gen.agentId = agentId

        let data = try JSONEncoder().encode(gen)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)

        XCTAssertEqual(decoded.runId, runId)
        XCTAssertEqual(decoded.agentId, agentId)
    }

    func testIsHiddenTrue_PreservedThroughCodable() throws {
        let gen = Generation(
            id: UUID(), setId: UUID(), modelId: "m", prompt: "p",
            promptEnhanceOpted: false, promptAfterEnhance: "",
            dimensions: "1024x1024", size: 100, creditUsed: 0.1,
            status: .GENERATED, colorPalette: []
        )
        gen.isHidden = true

        let data = try JSONEncoder().encode(gen)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)
        XCTAssertTrue(decoded.isHidden)
    }

    func testRealtimeSessionId_PreservedThroughCodable() throws {
        let sessionId = UUID()
        let gen = Generation(
            id: UUID(), setId: UUID(), modelId: "m", prompt: "p",
            promptEnhanceOpted: false, promptAfterEnhance: "",
            dimensions: "1024x1024", size: 100, creditUsed: 0.1,
            status: .GENERATED, colorPalette: []
        )
        gen.realtimeSessionId = sessionId

        let data = try JSONEncoder().encode(gen)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)
        XCTAssertEqual(decoded.realtimeSessionId, sessionId)
    }

    // MARK: - Edge Cases

    func testMetadata_ManyKeys_AllPreserved() throws {
        let gen = Generation(
            id: UUID(), setId: UUID(), modelId: "m", prompt: "p",
            promptEnhanceOpted: false, promptAfterEnhance: "",
            dimensions: "1024x1024", size: 100, creditUsed: 0.1,
            status: .GENERATED, colorPalette: [],
            metadata: (0 ..< 15).reduce(into: [:]) { dict, i in dict["key\(i)"] = "value\(i)" }
        )

        let data = try JSONEncoder().encode(gen)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)
        XCTAssertEqual(decoded.metadata.count, 15)
        XCTAssertEqual(decoded.metadata["key0"], "value0")
        XCTAssertEqual(decoded.metadata["key14"], "value14")
    }

    func testMetadata_SpecialCharactersInValues() throws {
        let gen = Generation(
            id: UUID(), setId: UUID(), modelId: "m", prompt: "p",
            promptEnhanceOpted: false, promptAfterEnhance: "",
            dimensions: "1024x1024", size: 100, creditUsed: 0.1,
            status: .GENERATED, colorPalette: [],
            metadata: ["emoji": "🎨", "quotes": "he said \"hello\"", "newline": "line1\nline2"]
        )

        let data = try JSONEncoder().encode(gen)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)
        XCTAssertEqual(decoded.metadata["emoji"], "🎨")
        XCTAssertEqual(decoded.metadata["quotes"], "he said \"hello\"")
        XCTAssertEqual(decoded.metadata["newline"], "line1\nline2")
    }

    func testVeryLargeSize_Preserved() throws {
        let gen = Generation(
            id: UUID(), setId: UUID(), modelId: "m", prompt: "p",
            promptEnhanceOpted: false, promptAfterEnhance: "",
            dimensions: "1024x1024", size: 50_000_000, creditUsed: 0.1,
            status: .GENERATED, colorPalette: []
        )

        let data = try JSONEncoder().encode(gen)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)
        XCTAssertEqual(decoded.size, 50_000_000)
    }

    func testZeroCreditUsed_Preserved() throws {
        let gen = Generation(
            id: UUID(), setId: UUID(), modelId: "m", prompt: "p",
            promptEnhanceOpted: false, promptAfterEnhance: "",
            dimensions: "1024x1024", size: 100, creditUsed: 0,
            status: .GENERATED, colorPalette: []
        )

        let data = try JSONEncoder().encode(gen)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)
        XCTAssertEqual(decoded.creditUsed, 0)
    }

    func testEmptyColorPalette_PreservedAsEmpty() throws {
        let gen = Generation(
            id: UUID(), setId: UUID(), modelId: "m", prompt: "p",
            promptEnhanceOpted: false, promptAfterEnhance: "",
            dimensions: "1024x1024", size: 100, creditUsed: 0.1,
            status: .GENERATED, colorPalette: []
        )

        let data = try JSONEncoder().encode(gen)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)
        XCTAssertTrue(decoded.colorPalette.isEmpty)
    }

    // MARK: - Mutability Persistence

    func testSetRunIdAfterInit_PersistsThroughCodable() throws {
        let gen = Generation(
            id: UUID(), setId: UUID(), modelId: "m", prompt: "p",
            promptEnhanceOpted: false, promptAfterEnhance: "",
            dimensions: "1024x1024", size: 100, creditUsed: 0.1,
            status: .GENERATED, colorPalette: []
        )
        XCTAssertNil(gen.runId)

        let runId = UUID()
        gen.runId = runId

        let data = try JSONEncoder().encode(gen)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)
        XCTAssertEqual(decoded.runId, runId)
    }

    func testSetIsHiddenAfterInit_PersistsThroughCodable() throws {
        let gen = Generation(
            id: UUID(), setId: UUID(), modelId: "m", prompt: "p",
            promptEnhanceOpted: false, promptAfterEnhance: "",
            dimensions: "1024x1024", size: 100, creditUsed: 0.1,
            status: .GENERATED, colorPalette: []
        )
        XCTAssertFalse(gen.isHidden)

        gen.isHidden = true

        let data = try JSONEncoder().encode(gen)
        let decoded = try JSONDecoder().decode(Generation.self, from: data)
        XCTAssertTrue(decoded.isHidden)
    }
}
