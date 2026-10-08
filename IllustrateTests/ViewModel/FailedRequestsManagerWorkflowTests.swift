// MARK: - FailedRequestsManagerWorkflowTests.swift

// Tests for FailedRequestsManager - the service that tracks and persists
// failed generation requests for debugging.
//
// Tests cover:
// - Adding failed requests with all fields
// - Raw response truncation at 40KB boundary
// - Individual and bulk deletion
// - Project-scoped deletion isolation

import Foundation
import SwiftData
import XCTest
@testable import Illustrate

@MainActor
final class FailedRequestsManagerWorkflowTests: XCTestCase {
    private var container: ModelContainer!
    private var modelContext: ModelContext!
    private var manager: FailedRequestsManager!

    override func setUp() async throws {
        try await super.setUp()
        container = try makeTestModelContainer()
        modelContext = container.mainContext
        manager = FailedRequestsManager.shared
    }

    override func tearDown() async throws {
        container = nil
        modelContext = nil
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func fetchAllFailedRequests() -> [FailedRequest] {
        let descriptor = FetchDescriptor<FailedRequest>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchFailedRequests(for projectId: UUID) -> [FailedRequest] {
        let descriptor = FetchDescriptor<FailedRequest>(
            predicate: #Predicate { $0.projectId == projectId }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Add Failed Request

    func testAddFailedRequest_insertsWithAllFields() throws {
        let projectId = UUID()

        manager.addFailedRequest(
            modelContext: modelContext,
            projectId: projectId,
            prompt: "A sunset over mountains",
            modelId: "test-model-123",
            dimensions: "1024x1024",
            isVideoGeneration: false,
            errorMessage: "Rate limit exceeded",
            errorCode: "rate_limit_error",
            rawResponse: "{\"error\": \"rate_limit\"}"
        )
        try? modelContext.save()

        let requests = fetchFailedRequests(for: projectId)
        XCTAssertEqual(requests.count, 1)

        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.projectId, projectId)
        XCTAssertEqual(request.prompt, "A sunset over mountains")
        XCTAssertEqual(request.modelId, "test-model-123")
        XCTAssertEqual(request.dimensions, "1024x1024")
        XCTAssertFalse(request.isVideoGeneration)
        XCTAssertEqual(request.errorMessage, "Rate limit exceeded")
        XCTAssertEqual(request.errorCode, "rate_limit_error")
        XCTAssertEqual(request.rawResponse, "{\"error\": \"rate_limit\"}")
    }

    func testAddFailedRequest_videoGeneration() {
        let projectId = UUID()

        manager.addFailedRequest(
            modelContext: modelContext,
            projectId: projectId,
            prompt: "A rotating globe",
            modelId: "video-model",
            isVideoGeneration: true,
            errorMessage: "Content policy violation"
        )
        try? modelContext.save()

        let requests = fetchFailedRequests(for: projectId)
        XCTAssertTrue(requests.first?.isVideoGeneration ?? false)
    }

    // MARK: - Raw Response Truncation

    func testAddFailedRequest_smallRawResponse_preserved() {
        let projectId = UUID()
        let smallResponse = String(repeating: "a", count: 100)

        manager.addFailedRequest(
            modelContext: modelContext,
            projectId: projectId,
            prompt: "test",
            modelId: "model",
            errorMessage: "error",
            rawResponse: smallResponse
        )
        try? modelContext.save()

        let requests = fetchFailedRequests(for: projectId)
        XCTAssertEqual(requests.first?.rawResponse, smallResponse)
    }

    func testAddFailedRequest_largeRawResponse_truncated() {
        let projectId = UUID()
        let maxSize = 40 * 1024 // 40 KB
        let largeResponse = String(repeating: "x", count: maxSize + 1000)

        manager.addFailedRequest(
            modelContext: modelContext,
            projectId: projectId,
            prompt: "test",
            modelId: "model",
            errorMessage: "error",
            rawResponse: largeResponse
        )
        try? modelContext.save()

        let requests = fetchFailedRequests(for: projectId)
        let storedResponse = requests.first?.rawResponse ?? ""
        XCTAssertTrue(storedResponse.contains("[Response truncated"))
        XCTAssertTrue(storedResponse.count < largeResponse.count)
    }

    func testAddFailedRequest_exactlyMaxSize_notTruncated() {
        let projectId = UUID()
        let maxSize = 40 * 1024
        let exactResponse = String(repeating: "y", count: maxSize)

        manager.addFailedRequest(
            modelContext: modelContext,
            projectId: projectId,
            prompt: "test",
            modelId: "model",
            errorMessage: "error",
            rawResponse: exactResponse
        )
        try? modelContext.save()

        let requests = fetchFailedRequests(for: projectId)
        XCTAssertEqual(requests.first?.rawResponse, exactResponse)
    }

    func testAddFailedRequest_nilRawResponse_storesNil() {
        let projectId = UUID()

        manager.addFailedRequest(
            modelContext: modelContext,
            projectId: projectId,
            prompt: "test",
            modelId: "model",
            errorMessage: "error",
            rawResponse: nil
        )
        try? modelContext.save()

        let requests = fetchFailedRequests(for: projectId)
        XCTAssertNil(requests.first?.rawResponse)
    }

    // MARK: - Delete

    func testDeleteFailedRequest_removesSingleRecord() throws {
        let projectId = UUID()

        manager.addFailedRequest(
            modelContext: modelContext,
            projectId: projectId,
            prompt: "request 1",
            modelId: "model",
            errorMessage: "error 1"
        )
        manager.addFailedRequest(
            modelContext: modelContext,
            projectId: projectId,
            prompt: "request 2",
            modelId: "model",
            errorMessage: "error 2"
        )
        try? modelContext.save()

        let requests = fetchFailedRequests(for: projectId)
        XCTAssertEqual(requests.count, 2)

        try manager.deleteFailedRequest(modelContext: modelContext, request: XCTUnwrap(requests.first))

        let remaining = fetchFailedRequests(for: projectId)
        XCTAssertEqual(remaining.count, 1)
    }

    // MARK: - Clear All

    func testClearAllFailedRequests_removesForProject() {
        let projectId = UUID()

        manager.addFailedRequest(
            modelContext: modelContext,
            projectId: projectId,
            prompt: "req 1",
            modelId: "model",
            errorMessage: "err 1"
        )
        manager.addFailedRequest(
            modelContext: modelContext,
            projectId: projectId,
            prompt: "req 2",
            modelId: "model",
            errorMessage: "err 2"
        )
        try? modelContext.save()

        manager.clearAllFailedRequests(modelContext: modelContext, projectId: projectId)

        let remaining = fetchFailedRequests(for: projectId)
        XCTAssertEqual(remaining.count, 0)
    }

    func testClearAllFailedRequests_doesNotAffectOtherProjects() {
        let projectA = UUID()
        let projectB = UUID()

        manager.addFailedRequest(
            modelContext: modelContext,
            projectId: projectA,
            prompt: "A",
            modelId: "model",
            errorMessage: "err"
        )
        manager.addFailedRequest(
            modelContext: modelContext,
            projectId: projectB,
            prompt: "B",
            modelId: "model",
            errorMessage: "err"
        )
        try? modelContext.save()

        manager.clearAllFailedRequests(modelContext: modelContext, projectId: projectA)

        let remainingA = fetchFailedRequests(for: projectA)
        let remainingB = fetchFailedRequests(for: projectB)
        XCTAssertEqual(remainingA.count, 0)
        XCTAssertEqual(remainingB.count, 1, "Other project's failed requests should be untouched")
    }
}
