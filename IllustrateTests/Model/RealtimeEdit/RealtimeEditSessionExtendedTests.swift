// MARK: - RealtimeEditSessionExtendedTests.swift

// Extended tests for RealtimeEditSession model - all 18+ decodeIfPresent defaults.
//
// Tests cover:
// - Decode with missing optional fields (every decodeIfPresent default)
// - Full Codable round-trip with all fields set to non-default values
// - Configuration accessor round-trip
// - Pinnable conformance
// - Combined scenario tests

import Foundation
import XCTest
@testable import Illustrate

final class RealtimeEditSessionExtendedTests: XCTestCase {
    // MARK: - Decode with Missing Optional Fields

    func testRealtimeEditSession_decode_missingProjectId_defaultsToDefault() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertEqual(restored.projectId, Project.defaultProjectId)
    }

    func testRealtimeEditSession_decode_missingCanvasScale_defaultsToCanvasSettings() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertEqual(restored.canvasScale, CanvasSettings.defaultScale)
    }

    func testRealtimeEditSession_decode_missingCanvasOffsetX_defaults() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertEqual(restored.canvasOffsetX, CanvasSettings.defaultOffset)
    }

    func testRealtimeEditSession_decode_missingCanvasOffsetY_defaults() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertEqual(restored.canvasOffsetY, CanvasSettings.defaultOffset)
    }

    func testRealtimeEditSession_decode_missingIsLocked_defaultsToFalse() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertFalse(restored.isLocked)
    }

    func testRealtimeEditSession_decode_missingIsPinned_defaultsToFalse() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertFalse(restored.isPinned)
    }

    func testRealtimeEditSession_decode_missingSelectedProviderId_defaultsToEmpty() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertEqual(restored.selectedProviderId, "")
    }

    func testRealtimeEditSession_decode_missingSelectedModelId_defaultsToEmpty() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertEqual(restored.selectedModelId, "")
    }

    func testRealtimeEditSession_decode_missingSelectedDimensions_defaultsToGenerationSettings() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertEqual(restored.selectedDimensions, GenerationSettings.defaultDimensions)
    }

    func testRealtimeEditSession_decode_missingSelectedToolRawValue_defaultsToSelect() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertEqual(restored.selectedToolRawValue, "select")
    }

    func testRealtimeEditSession_decode_missingBrushColorHex_defaultsToRealtimeEditColors() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertEqual(restored.brushColorHex, RealtimeEditColors.defaultBrush)
    }

    func testRealtimeEditSession_decode_missingBrushSize_defaultsToBrushSettings() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertEqual(restored.brushSize, BrushSettings.defaultSize)
    }

    func testRealtimeEditSession_decode_missingShapeColorHex_defaults() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertEqual(restored.shapeColorHex, RealtimeEditColors.defaultShape)
    }

    func testRealtimeEditSession_decode_missingSelectedShapeTypeRawValue_defaultsToSquare() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertEqual(restored.selectedShapeTypeRawValue, "square")
    }

    func testRealtimeEditSession_decode_missingSeed_defaultsToValidRange() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertTrue(GenerationSettings.seedRange.contains(restored.seed))
    }

    func testRealtimeEditSession_decode_missingGenerationSpeedMs_defaultsTo500() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertEqual(restored.generationSpeedMs, 500.0)
    }

    func testRealtimeEditSession_decode_missingConfigurationData_defaultsToNil() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertNil(restored.configurationData)
    }

    func testRealtimeEditSession_decode_missingLastGenerationFilePath_defaultsToNil() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)
        XCTAssertNil(restored.lastGenerationFilePath)
    }

    func testRealtimeEditSession_decode_missingAllOptionals_allDefaults() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Minimal Session",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)

        XCTAssertEqual(restored.name, "Minimal Session")
        XCTAssertEqual(restored.projectId, Project.defaultProjectId)
        XCTAssertEqual(restored.canvasScale, CanvasSettings.defaultScale)
        XCTAssertEqual(restored.canvasOffsetX, CanvasSettings.defaultOffset)
        XCTAssertEqual(restored.canvasOffsetY, CanvasSettings.defaultOffset)
        XCTAssertFalse(restored.isLocked)
        XCTAssertFalse(restored.isPinned)
        XCTAssertEqual(restored.selectedProviderId, "")
        XCTAssertEqual(restored.selectedModelId, "")
        XCTAssertEqual(restored.selectedDimensions, GenerationSettings.defaultDimensions)
        XCTAssertEqual(restored.selectedToolRawValue, "select")
        XCTAssertEqual(restored.brushColorHex, RealtimeEditColors.defaultBrush)
        XCTAssertEqual(restored.brushSize, BrushSettings.defaultSize)
        XCTAssertEqual(restored.shapeColorHex, RealtimeEditColors.defaultShape)
        XCTAssertEqual(restored.selectedShapeTypeRawValue, "square")
        XCTAssertEqual(restored.generationSpeedMs, 500.0)
        XCTAssertNil(restored.configurationData)
        XCTAssertNil(restored.lastGenerationFilePath)
    }

    // MARK: - Full Codable Round-Trip (All Fields Non-Default)

    func testRealtimeEditSession_codableRoundTrip_allFieldsNonDefault() throws {
        let projectId = UUID()
        let session = RealtimeEditSession(name: "Full Test", projectId: projectId)
        session.canvasScale = 2.5
        session.canvasOffsetX = 100.0
        session.canvasOffsetY = -75.0
        session.isLocked = true
        session.isPinned = true
        session.selectedProviderId = "openai"
        session.selectedModelId = "dall-e-3"
        session.selectedDimensions = "512x512"
        session.selectedToolRawValue = "brush"
        session.brushColorHex = "00FF00"
        session.brushSize = 32.0
        session.shapeColorHex = "FF00FF"
        session.selectedShapeTypeRawValue = "circle"
        session.seed = 42
        session.generationSpeedMs = 1000.0
        session.lastGenerationFilePath = "/tmp/last.png"

        let data = try JSONEncoder().encode(session)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)

        XCTAssertEqual(restored.id, session.id)
        XCTAssertEqual(restored.projectId, projectId)
        XCTAssertEqual(restored.name, "Full Test")
        XCTAssertEqual(restored.canvasScale, 2.5)
        XCTAssertEqual(restored.canvasOffsetX, 100.0)
        XCTAssertEqual(restored.canvasOffsetY, -75.0)
        XCTAssertTrue(restored.isLocked)
        XCTAssertTrue(restored.isPinned)
        XCTAssertEqual(restored.selectedProviderId, "openai")
        XCTAssertEqual(restored.selectedModelId, "dall-e-3")
        XCTAssertEqual(restored.selectedDimensions, "512x512")
        XCTAssertEqual(restored.selectedToolRawValue, "brush")
        XCTAssertEqual(restored.brushColorHex, "00FF00")
        XCTAssertEqual(restored.brushSize, 32.0)
        XCTAssertEqual(restored.shapeColorHex, "FF00FF")
        XCTAssertEqual(restored.selectedShapeTypeRawValue, "circle")
        XCTAssertEqual(restored.seed, 42)
        XCTAssertEqual(restored.generationSpeedMs, 1000.0)
        XCTAssertEqual(restored.lastGenerationFilePath, "/tmp/last.png")
    }

    // MARK: - Configuration Accessor

    func testRealtimeEditSession_configuration_nilData_returnsDefault() {
        let session = RealtimeEditSession()
        let config = session.configuration
        XCTAssertEqual(config.prompt, "")
    }

    func testRealtimeEditSession_configuration_setAndGet_roundTrip() {
        let session = RealtimeEditSession()
        var config = RealtimeEditConfiguration()
        config.prompt = "A colorful abstract"
        config.selectedProviderId = "stability"
        config.selectedModelId = "core"
        session.configuration = config

        let retrieved = session.configuration
        XCTAssertEqual(retrieved.prompt, "A colorful abstract")
        XCTAssertEqual(retrieved.selectedProviderId, "stability")
        XCTAssertEqual(retrieved.selectedModelId, "core")
    }

    func testRealtimeEditSession_configuration_invalidData_returnsDefault() {
        let session = RealtimeEditSession()
        session.configurationData = Data("not json".utf8)
        let config = session.configuration
        XCTAssertEqual(config.prompt, "")
    }

    // MARK: - Pinnable Conformance

    func testRealtimeEditSession_pinnable_projectIdMatches() {
        let projectId = UUID()
        let session = RealtimeEditSession(projectId: projectId)
        XCTAssertEqual(session.projectId, projectId)
    }

    func testRealtimeEditSession_pinnable_nameMatches() {
        let session = RealtimeEditSession(name: "Pinnable Test")
        XCTAssertEqual(session.name, "Pinnable Test")
    }

    func testRealtimeEditSession_pinnable_isPinnedUpdatable() {
        let session = RealtimeEditSession()
        XCTAssertFalse(session.isPinned)
        session.isPinned = true
        XCTAssertTrue(session.isPinned)
    }

    // MARK: - Combined Scenarios

    func testRealtimeEditSession_canvasLockedWithBrushSettings_allPreserved() throws {
        let session = RealtimeEditSession()
        session.isLocked = true
        session.brushColorHex = "0000FF"
        session.brushSize = 48.0

        let data = try JSONEncoder().encode(session)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)

        XCTAssertTrue(restored.isLocked)
        XCTAssertEqual(restored.brushColorHex, "0000FF")
        XCTAssertEqual(restored.brushSize, 48.0)
    }

    func testRealtimeEditSession_shapeAndBrushState_independent() throws {
        let session = RealtimeEditSession()
        session.brushColorHex = "FF0000"
        session.brushSize = 16.0
        session.shapeColorHex = "00FF00"
        session.selectedShapeTypeRawValue = "circle"

        let data = try JSONEncoder().encode(session)
        let restored = try JSONDecoder().decode(RealtimeEditSession.self, from: data)

        XCTAssertEqual(restored.brushColorHex, "FF0000")
        XCTAssertEqual(restored.brushSize, 16.0)
        XCTAssertEqual(restored.shapeColorHex, "00FF00")
        XCTAssertEqual(restored.selectedShapeTypeRawValue, "circle")
    }
}
