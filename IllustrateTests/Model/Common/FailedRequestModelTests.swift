// MARK: - FailedRequestModelTests.swift

// Tests for the FailedRequest model - tracks failed generation requests.
//
// Tests cover:
// - Initialization with required and optional parameters
// - Default values for optional fields
// - Full initialization with all parameters
// - Identifiable conformance and unique ids
// - Mutability of key fields
// - NOTE: FailedRequest intentionally does NOT conform to Codable

import Foundation
import XCTest
@testable import Illustrate

final class FailedRequestModelTests: XCTestCase {
    // MARK: - Initialization with Required Fields

    func testFailedRequest_init_setsPrompt() {
        let request = FailedRequest(prompt: "A sunset", modelId: "model-1", errorMessage: "Rate limit")
        XCTAssertEqual(request.prompt, "A sunset")
    }

    func testFailedRequest_init_setsModelId() {
        let request = FailedRequest(prompt: "Test", modelId: "model-abc", errorMessage: "Error")
        XCTAssertEqual(request.modelId, "model-abc")
    }

    func testFailedRequest_init_setsErrorMessage() {
        let request = FailedRequest(prompt: "Test", modelId: "model-1", errorMessage: "Content policy violation")
        XCTAssertEqual(request.errorMessage, "Content policy violation")
    }

    func testFailedRequest_init_generatesId() {
        let request = FailedRequest(prompt: "Test", modelId: "model-1", errorMessage: "Error")
        XCTAssertNotNil(request.id)
    }

    func testFailedRequest_init_setsCreatedAt() {
        let before = Date()
        let request = FailedRequest(prompt: "Test", modelId: "model-1", errorMessage: "Error")
        let after = Date()
        XCTAssertGreaterThanOrEqual(request.createdAt, before)
        XCTAssertLessThanOrEqual(request.createdAt, after)
    }

    // MARK: - Default Values

    func testFailedRequest_init_defaultProjectId() {
        let request = FailedRequest(prompt: "Test", modelId: "model-1", errorMessage: "Error")
        XCTAssertEqual(request.projectId, Project.defaultProjectId)
    }

    func testFailedRequest_init_defaultDimensionsEmpty() {
        let request = FailedRequest(prompt: "Test", modelId: "model-1", errorMessage: "Error")
        XCTAssertEqual(request.dimensions, "")
    }

    func testFailedRequest_init_defaultIsVideoGenerationFalse() {
        let request = FailedRequest(prompt: "Test", modelId: "model-1", errorMessage: "Error")
        XCTAssertFalse(request.isVideoGeneration)
    }

    func testFailedRequest_init_defaultErrorCodeEmpty() {
        let request = FailedRequest(prompt: "Test", modelId: "model-1", errorMessage: "Error")
        XCTAssertEqual(request.errorCode, "")
    }

    func testFailedRequest_init_defaultRawResponseNil() {
        let request = FailedRequest(prompt: "Test", modelId: "model-1", errorMessage: "Error")
        XCTAssertNil(request.rawResponse)
    }

    // MARK: - Full Initialization

    func testFailedRequest_fullInit_setsAllFields() {
        let projectId = UUID()
        let request = FailedRequest(
            projectId: projectId,
            prompt: "A mountain landscape",
            modelId: "stability-xl",
            dimensions: "1024x1024",
            isVideoGeneration: true,
            errorMessage: "Insufficient credits",
            errorCode: "CREDITS_LOW",
            rawResponse: "{\"error\": \"credits_low\"}"
        )

        XCTAssertEqual(request.projectId, projectId)
        XCTAssertEqual(request.prompt, "A mountain landscape")
        XCTAssertEqual(request.modelId, "stability-xl")
        XCTAssertEqual(request.dimensions, "1024x1024")
        XCTAssertTrue(request.isVideoGeneration)
        XCTAssertEqual(request.errorMessage, "Insufficient credits")
        XCTAssertEqual(request.errorCode, "CREDITS_LOW")
        XCTAssertEqual(request.rawResponse, "{\"error\": \"credits_low\"}")
    }

    func testFailedRequest_init_customId() {
        let customId = UUID()
        let request = FailedRequest(
            id: customId,
            prompt: "Test",
            modelId: "model-1",
            errorMessage: "Error"
        )
        XCTAssertEqual(request.id, customId)
    }

    func testFailedRequest_init_customProjectId() {
        let projectId = UUID()
        let request = FailedRequest(
            projectId: projectId,
            prompt: "Test",
            modelId: "model-1",
            errorMessage: "Error"
        )
        XCTAssertEqual(request.projectId, projectId)
    }

    // MARK: - Identifiable Conformance

    func testFailedRequest_identifiable_hasUniqueId() {
        let request = FailedRequest(prompt: "Test", modelId: "model-1", errorMessage: "Error")
        let _: UUID = request.id
        XCTAssertNotNil(request.id)
    }

    func testFailedRequest_twoInstances_haveDifferentIds() {
        let r1 = FailedRequest(prompt: "Test", modelId: "model-1", errorMessage: "Error")
        let r2 = FailedRequest(prompt: "Test", modelId: "model-1", errorMessage: "Error")
        XCTAssertNotEqual(r1.id, r2.id)
    }

    // MARK: - Mutability

    func testFailedRequest_setRawResponse_updatesValue() {
        let request = FailedRequest(prompt: "Test", modelId: "model-1", errorMessage: "Error")
        XCTAssertNil(request.rawResponse)
        request.rawResponse = "{\"status\": 500}"
        XCTAssertEqual(request.rawResponse, "{\"status\": 500}")
    }

    func testFailedRequest_setErrorMessage_updatesValue() {
        let request = FailedRequest(prompt: "Test", modelId: "model-1", errorMessage: "Original")
        request.errorMessage = "Updated error"
        XCTAssertEqual(request.errorMessage, "Updated error")
    }

    func testFailedRequest_setIsVideoGeneration_updatesValue() {
        let request = FailedRequest(prompt: "Test", modelId: "model-1", errorMessage: "Error")
        XCTAssertFalse(request.isVideoGeneration)
        request.isVideoGeneration = true
        XCTAssertTrue(request.isVideoGeneration)
    }

    // MARK: - Edge Cases

    func testFailedRequest_emptyPrompt_isAllowed() {
        let request = FailedRequest(prompt: "", modelId: "model-1", errorMessage: "Error")
        XCTAssertEqual(request.prompt, "")
    }

    func testFailedRequest_emptyModelId_isAllowed() {
        let request = FailedRequest(prompt: "Test", modelId: "", errorMessage: "Error")
        XCTAssertEqual(request.modelId, "")
    }

    func testFailedRequest_videoGenerationRequest_setsFlag() {
        let request = FailedRequest(
            prompt: "A flying bird",
            modelId: "video-model",
            isVideoGeneration: true,
            errorMessage: "Timeout"
        )
        XCTAssertTrue(request.isVideoGeneration)
    }
}
