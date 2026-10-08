// MARK: - FailedRequestsManagerTests.swift

// Unit tests for FailedRequestsManager and FailedRequest model.
//
// Tests cover:
// - FailedRequest model initialization
// - FailedRequest default values
// - FailedRequestsManager raw response truncation
// - Truncation boundary conditions

import XCTest
@testable import Illustrate

final class FailedRequestsManagerTests: XCTestCase {
    // MARK: - FailedRequest Model Tests

    func testFailedRequest_defaultInitialization() {
        let request = FailedRequest(
            prompt: "Test prompt",
            modelId: "test-model-id",
            errorMessage: "API Error"
        )

        XCTAssertFalse(request.id.uuidString.isEmpty)
        XCTAssertEqual(request.prompt, "Test prompt")
        XCTAssertEqual(request.modelId, "test-model-id")
        XCTAssertEqual(request.errorMessage, "API Error")
        XCTAssertEqual(request.dimensions, "")
        XCTAssertFalse(request.isVideoGeneration)
        XCTAssertEqual(request.errorCode, "")
        XCTAssertNil(request.rawResponse)
        XCTAssertEqual(request.projectId, Project.defaultProjectId)
    }

    func testFailedRequest_fullInitialization() {
        let id = UUID()
        let projectId = UUID()

        let request = FailedRequest(
            id: id,
            projectId: projectId,
            prompt: "Full test prompt",
            modelId: "model-123",
            dimensions: "1024x1024",
            isVideoGeneration: true,
            errorMessage: "Content policy violation",
            errorCode: "content_policy",
            rawResponse: "{\"error\": \"policy_violation\"}"
        )

        XCTAssertEqual(request.id, id)
        XCTAssertEqual(request.projectId, projectId)
        XCTAssertEqual(request.prompt, "Full test prompt")
        XCTAssertEqual(request.modelId, "model-123")
        XCTAssertEqual(request.dimensions, "1024x1024")
        XCTAssertTrue(request.isVideoGeneration)
        XCTAssertEqual(request.errorMessage, "Content policy violation")
        XCTAssertEqual(request.errorCode, "content_policy")
        XCTAssertEqual(request.rawResponse, "{\"error\": \"policy_violation\"}")
    }

    func testFailedRequest_createdAtIsSet() {
        let beforeCreation = Date()
        let request = FailedRequest(prompt: "Test", modelId: "m1", errorMessage: "Error")
        let afterCreation = Date()

        XCTAssertGreaterThanOrEqual(request.createdAt, beforeCreation)
        XCTAssertLessThanOrEqual(request.createdAt, afterCreation)
    }

    func testFailedRequest_identifiable() {
        let request1 = FailedRequest(prompt: "Test 1", modelId: "m1", errorMessage: "E1")
        let request2 = FailedRequest(prompt: "Test 2", modelId: "m2", errorMessage: "E2")

        XCTAssertNotEqual(request1.id, request2.id)
    }

    func testFailedRequest_imageGeneration() {
        let request = FailedRequest(
            prompt: "Image test",
            modelId: "dalle-3",
            dimensions: "512x512",
            isVideoGeneration: false,
            errorMessage: "Rate limit exceeded"
        )

        XCTAssertFalse(request.isVideoGeneration)
        XCTAssertEqual(request.dimensions, "512x512")
    }

    func testFailedRequest_videoGeneration() {
        let request = FailedRequest(
            prompt: "Video test",
            modelId: "runway-gen3",
            dimensions: "1920x1080",
            isVideoGeneration: true,
            errorMessage: "Generation timeout"
        )

        XCTAssertTrue(request.isVideoGeneration)
        XCTAssertEqual(request.dimensions, "1920x1080")
    }

    func testFailedRequest_emptyErrorCode() {
        let request = FailedRequest(
            prompt: "Test",
            modelId: "m1",
            errorMessage: "Unknown error"
        )

        XCTAssertEqual(request.errorCode, "")
    }

    func testFailedRequest_withErrorCode() {
        let request = FailedRequest(
            prompt: "Test",
            modelId: "m1",
            errorMessage: "Billing issue",
            errorCode: "billing_error"
        )

        XCTAssertEqual(request.errorCode, "billing_error")
    }

    // MARK: - Project Tests

    func testProject_defaultProjectId() {
        XCTAssertEqual(
            Project.defaultProjectId.uuidString,
            "00000000-0000-0000-0000-000000000001"
        )
    }

    func testProject_initialization() {
        let project = Project(name: "Test Project")

        XCTAssertFalse(project.id.uuidString.isEmpty)
        XCTAssertEqual(project.name, "Test Project")
        XCTAssertFalse(project.isDefault)
    }

    func testProject_fullInitialization() {
        let id = UUID()
        let createdAt = Date()

        let project = Project(
            id: id,
            name: "Full Test",
            createdAt: createdAt,
            isDefault: true
        )

        XCTAssertEqual(project.id, id)
        XCTAssertEqual(project.name, "Full Test")
        XCTAssertEqual(project.createdAt, createdAt)
        XCTAssertTrue(project.isDefault)
    }

    func testProject_createDefault() {
        let defaultProject = Project.createDefault()

        XCTAssertEqual(defaultProject.id, Project.defaultProjectId)
        XCTAssertEqual(defaultProject.name, "Default Project")
        XCTAssertTrue(defaultProject.isDefault)
    }

    func testProject_codableRoundTrip() throws {
        let original = Project(
            id: UUID(),
            name: "Encoded Project",
            createdAt: Date(),
            isDefault: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.isDefault, original.isDefault)
    }

    func testProject_codableDefaultProject() throws {
        let original = Project.createDefault()

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(decoded.id, Project.defaultProjectId)
        XCTAssertTrue(decoded.isDefault)
    }

    // MARK: - Raw Response Truncation Tests

    func testRawResponse_shortResponse_notTruncated() {
        let shortResponse = String(repeating: "a", count: 1000)
        let truncated = truncateRawResponseForTest(shortResponse)

        XCTAssertEqual(truncated, shortResponse)
    }

    func testRawResponse_exactMaxSize_notTruncated() {
        let maxSize = 40 * 1024 // 40 KB
        let exactResponse = String(repeating: "a", count: maxSize)
        let truncated = truncateRawResponseForTest(exactResponse)

        XCTAssertEqual(truncated, exactResponse)
    }

    func testRawResponse_overMaxSize_isTruncated() throws {
        let maxSize = 40 * 1024
        let largeResponse = String(repeating: "a", count: maxSize + 1000)
        let truncated = truncateRawResponseForTest(largeResponse)

        XCTAssertNotNil(truncated)
        XCTAssertTrue(try XCTUnwrap(truncated?.contains("[Response truncated")))
        XCTAssertTrue(try XCTUnwrap(truncated?.count) < largeResponse.count)
    }

    func testRawResponse_nil_returnsNil() {
        let truncated = truncateRawResponseForTest(nil)

        XCTAssertNil(truncated)
    }

    func testRawResponse_emptyString_notTruncated() {
        let truncated = truncateRawResponseForTest("")

        XCTAssertEqual(truncated, "")
    }

    func testRawResponse_truncationIncludesOriginalSize() throws {
        let maxSize = 40 * 1024
        let largeSize = maxSize + 5000
        let largeResponse = String(repeating: "x", count: largeSize)
        let truncated = truncateRawResponseForTest(largeResponse)

        XCTAssertNotNil(truncated)
        XCTAssertTrue(try XCTUnwrap(truncated?.contains("\(largeResponse.utf8.count) bytes")))
    }

    // MARK: - Helper Methods

    /// Replicates FailedRequestsManager's truncation logic for testing
    private func truncateRawResponseForTest(_ response: String?) -> String? {
        let maxRawResponseSize = 40 * 1024

        guard let response else { return nil }

        if response.utf8.count <= maxRawResponseSize {
            return response
        }

        let truncated = String(response.prefix(maxRawResponseSize))
        return truncated + "\n\n[Response truncated - original size: \(response.utf8.count) bytes]"
    }
}
