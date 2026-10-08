// MARK: - BulkSessionWorkflowTests.swift

// Workflow tests for BulkSession and BulkSessionItem models.
//
// Tests cover:
// - BulkSessionStatus enum cases, raw values, backward-compatible decoding
// - BulkSession defaults and initialization
// - bulkSessionMaxItems constant
// - savedConfiguration round-trip via ImageGenerationConfiguration
// - BulkSessionItemStatus enum cases and backward-compatible decoding

import XCTest
@testable import Illustrate

final class BulkSessionWorkflowTests: XCTestCase {
    // MARK: - BulkSessionStatus Enum Tests

    func testBulkSessionStatus_RawValues() {
        XCTAssertEqual(BulkSessionStatus.IDLE.rawValue, "IDLE")
        XCTAssertEqual(BulkSessionStatus.RUNNING.rawValue, "RUNNING")
        XCTAssertEqual(BulkSessionStatus.COMPLETED.rawValue, "COMPLETED")
    }

    func testBulkSessionStatus_BackwardCompatible_LowercaseIdle() throws {
        let json = "\"idle\""
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(BulkSessionStatus.self, from: data)
        XCTAssertEqual(decoded, .IDLE)
    }

    func testBulkSessionStatus_BackwardCompatible_LowercaseRunning() throws {
        let json = "\"running\""
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(BulkSessionStatus.self, from: data)
        XCTAssertEqual(decoded, .RUNNING)
    }

    func testBulkSessionStatus_BackwardCompatible_LowercaseCompleted() throws {
        let json = "\"completed\""
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(BulkSessionStatus.self, from: data)
        XCTAssertEqual(decoded, .COMPLETED)
    }

    func testBulkSessionStatus_BackwardCompatible_UnknownThrows() {
        let json = "\"unknown_status\""
        let data = Data(json.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(BulkSessionStatus.self, from: data))
    }

    // MARK: - BulkSession Default Values Tests

    func testBulkSession_Defaults_StatusIsIdle() {
        let session = BulkSession()
        XCTAssertEqual(session.status, .IDLE)
    }

    func testBulkSession_Defaults_ConcurrencyLimitIs2() {
        let session = BulkSession()
        XCTAssertEqual(session.concurrencyLimit, 2)
    }

    func testBulkSession_Defaults_NameIsUntitled() {
        let session = BulkSession()
        XCTAssertEqual(session.name, "Untitled Session")
    }

    // MARK: - bulkSessionMaxItems Constant

    func testBulkSessionMaxItems_Equals250() {
        XCTAssertEqual(bulkSessionMaxItems, 250)
    }

    // MARK: - savedConfiguration Round-Trip

    func testBulkSession_SavedConfiguration_DefaultIsEmpty() {
        let session = BulkSession()
        let config = session.savedConfiguration
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.selectedModelId, "")
    }

    func testBulkSession_SavedConfiguration_RoundTrip() {
        let session = BulkSession()

        var config = ImageGenerationConfiguration()
        config.prompt = "Test prompt for bulk"
        config.selectedModelId = "model-xyz"
        config.selectedDimensions = "512x512"
        session.savedConfiguration = config

        let retrieved = session.savedConfiguration
        XCTAssertEqual(retrieved.prompt, "Test prompt for bulk")
        XCTAssertEqual(retrieved.selectedModelId, "model-xyz")
        XCTAssertEqual(retrieved.selectedDimensions, "512x512")
    }

    // MARK: - BulkSessionItemStatus Enum Tests

    func testBulkSessionItemStatus_RawValues() {
        XCTAssertEqual(BulkSessionItemStatus.PENDING.rawValue, "PENDING")
        XCTAssertEqual(BulkSessionItemStatus.IN_PROGRESS.rawValue, "IN_PROGRESS")
        XCTAssertEqual(BulkSessionItemStatus.COMPLETED.rawValue, "COMPLETED")
        XCTAssertEqual(BulkSessionItemStatus.FAILED.rawValue, "FAILED")
        XCTAssertEqual(BulkSessionItemStatus.CANCELLED.rawValue, "CANCELLED")
    }

    func testBulkSessionItemStatus_BackwardCompatible_LowercasePending() throws {
        let json = "\"pending\""
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(BulkSessionItemStatus.self, from: data)
        XCTAssertEqual(decoded, .PENDING)
    }

    func testBulkSessionItemStatus_BackwardCompatible_CamelCaseInProgress() throws {
        let json = "\"inProgress\""
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(BulkSessionItemStatus.self, from: data)
        XCTAssertEqual(decoded, .IN_PROGRESS)
    }

    func testBulkSessionItemStatus_BackwardCompatible_SnakeCaseInProgress() throws {
        let json = "\"in_progress\""
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(BulkSessionItemStatus.self, from: data)
        XCTAssertEqual(decoded, .IN_PROGRESS)
    }

    func testBulkSessionItemStatus_BackwardCompatible_UnknownThrows() {
        let json = "\"invalid_value\""
        let data = Data(json.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(BulkSessionItemStatus.self, from: data))
    }
}
