// MARK: - ChatThreadModelWorkflowTests.swift

// Workflow tests for ChatThread and ChatMessage models.
//
// Tests cover:
// - ChatThread defaults, Codable round-trip, savedConfiguration accessor
// - ChatMessageStatus enum: raw values, backward-compatible decoding
// - ChatMessage defaults, generationIds/queueItemIds computed properties,
//   imageGenerationConfiguration accessor, corrupt-data resilience

import XCTest
@testable import Illustrate

final class ChatThreadModelWorkflowTests: XCTestCase {
    // MARK: - ChatThread Default Values

    func testChatThread_Default_Name() {
        let thread = ChatThread()
        XCTAssertEqual(thread.name, "Untitled Thread")
    }

    func testChatThread_Default_ImagesPerIteration() {
        let thread = ChatThread()
        XCTAssertEqual(thread.imagesPerIteration, 4)
    }

    func testChatThread_Default_IsPinned() {
        let thread = ChatThread()
        XCTAssertFalse(thread.isPinned)
    }

    func testChatThread_Default_SelectedProviderIdEmpty() {
        let thread = ChatThread()
        XCTAssertEqual(thread.selectedProviderId, "")
    }

    func testChatThread_Default_SelectedModelIdEmpty() {
        let thread = ChatThread()
        XCTAssertEqual(thread.selectedModelId, "")
    }

    func testChatThread_Default_ConfigurationDataNil() {
        let thread = ChatThread()
        XCTAssertNil(thread.configurationData)
    }

    // MARK: - ChatThread Custom Init

    func testChatThread_CustomInit_SetsProperties() {
        let projectId = UUID()
        let thread = ChatThread(
            name: "My Thread",
            projectId: projectId,
            imagesPerIteration: 8
        )
        XCTAssertEqual(thread.name, "My Thread")
        XCTAssertEqual(thread.projectId, projectId)
        XCTAssertEqual(thread.imagesPerIteration, 8)
    }

    // MARK: - ChatThread savedConfiguration Accessor

    func testChatThread_SavedConfig_DefaultWhenNilData() {
        let thread = ChatThread()
        let config = thread.savedConfiguration
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.selectedModelId, "")
    }

    func testChatThread_SavedConfig_Setter_EncodesData() {
        let thread = ChatThread()
        var config = ImageGenerationConfiguration()
        config.prompt = "test prompt"
        thread.savedConfiguration = config

        XCTAssertNotNil(thread.configurationData)
    }

    func testChatThread_SavedConfig_RoundTrip() {
        let thread = ChatThread()
        var config = ImageGenerationConfiguration()
        config.prompt = "sunset over mountains"
        config.selectedModelId = "model-xyz"
        config.selectedDimensions = "1024x1024"
        thread.savedConfiguration = config

        let retrieved = thread.savedConfiguration
        XCTAssertEqual(retrieved.prompt, "sunset over mountains")
        XCTAssertEqual(retrieved.selectedModelId, "model-xyz")
        XCTAssertEqual(retrieved.selectedDimensions, "1024x1024")
    }

    func testChatThread_SavedConfig_CorruptData_ReturnsDefault() {
        let thread = ChatThread()
        thread.configurationData = Data("corrupt data".utf8)

        let config = thread.savedConfiguration
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.selectedModelId, "")
    }

    // MARK: - ChatThread Codable Round-Trip

    func testChatThread_CodableRoundTrip_PreservesAllFields() throws {
        let projectId = UUID()
        let thread = ChatThread(
            name: "Encoded Thread",
            projectId: projectId,
            imagesPerIteration: 6
        )
        thread.isPinned = true
        thread.selectedProviderId = "provider-abc"
        thread.selectedModelId = "model-def"

        let data = try JSONEncoder().encode(thread)
        let decoded = try JSONDecoder().decode(ChatThread.self, from: data)

        XCTAssertEqual(decoded.id, thread.id)
        XCTAssertEqual(decoded.projectId, projectId)
        XCTAssertEqual(decoded.name, "Encoded Thread")
        XCTAssertEqual(decoded.imagesPerIteration, 6)
        XCTAssertTrue(decoded.isPinned)
        XCTAssertEqual(decoded.selectedProviderId, "provider-abc")
        XCTAssertEqual(decoded.selectedModelId, "model-def")
    }

    // MARK: - ChatMessageStatus Raw Values

    func testChatMessageStatus_RawValue_Processing() {
        XCTAssertEqual(ChatMessageStatus.PROCESSING.rawValue, "PROCESSING")
    }

    func testChatMessageStatus_RawValue_Generated() {
        XCTAssertEqual(ChatMessageStatus.GENERATED.rawValue, "GENERATED")
    }

    func testChatMessageStatus_RawValue_Failed() {
        XCTAssertEqual(ChatMessageStatus.FAILED.rawValue, "FAILED")
    }

    // MARK: - ChatMessageStatus Backward Compatible Decoding

    func testChatMessageStatus_Decode_Lowercase_Processing() throws {
        let decoded = try JSONDecoder().decode(
            ChatMessageStatus.self,
            from: Data("\"processing\"".utf8)
        )
        XCTAssertEqual(decoded, .PROCESSING)
    }

    func testChatMessageStatus_Decode_Lowercase_Generated() throws {
        let decoded = try JSONDecoder().decode(
            ChatMessageStatus.self,
            from: Data("\"generated\"".utf8)
        )
        XCTAssertEqual(decoded, .GENERATED)
    }

    func testChatMessageStatus_Decode_Lowercase_Failed() throws {
        let decoded = try JSONDecoder().decode(
            ChatMessageStatus.self,
            from: Data("\"failed\"".utf8)
        )
        XCTAssertEqual(decoded, .FAILED)
    }

    func testChatMessageStatus_Decode_UnknownValue_Throws() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                ChatMessageStatus.self,
                from: Data("\"unknown\"".utf8)
            )
        )
    }

    // MARK: - ChatMessage Default Values

    func testChatMessage_Default_StatusIsProcessing() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        XCTAssertEqual(msg.status, .PROCESSING)
    }

    func testChatMessage_Default_PendingCountZero() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        XCTAssertEqual(msg.pendingCount, 0)
    }

    func testChatMessage_Default_IsDelinkedFalse() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        XCTAssertFalse(msg.isDelinked)
    }

    func testChatMessage_Init_SetsPromptAndThreadId() {
        let threadId = UUID()
        let msg = ChatMessage(threadId: threadId, prompt: "Hello world")
        XCTAssertEqual(msg.threadId, threadId)
        XCTAssertEqual(msg.prompt, "Hello world")
    }

    // MARK: - ChatMessage generationIds Computed Property

    func testChatMessage_GenerationIds_EmptyByDefault() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        XCTAssertTrue(msg.generationIds.isEmpty)
    }

    func testChatMessage_GenerationIds_Setter_EncodesData() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let ids = [UUID(), UUID(), UUID()]
        msg.generationIds = ids

        XCTAssertNotNil(msg.generationIdsData)
    }

    func testChatMessage_GenerationIds_RoundTrip() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        msg.generationIds = [id1, id2, id3]

        let retrieved = msg.generationIds
        XCTAssertEqual(retrieved.count, 3)
        XCTAssertEqual(retrieved[0], id1)
        XCTAssertEqual(retrieved[1], id2)
        XCTAssertEqual(retrieved[2], id3)
    }

    func testChatMessage_GenerationIds_CorruptData_ReturnsEmptyArray() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.generationIdsData = Data("not json".utf8)

        XCTAssertTrue(msg.generationIds.isEmpty)
    }

    // MARK: - ChatMessage queueItemIds Computed Property

    func testChatMessage_QueueItemIds_EmptyByDefault() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        XCTAssertTrue(msg.queueItemIds.isEmpty)
    }

    func testChatMessage_QueueItemIds_Setter_EncodesData() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.queueItemIds = [UUID()]
        XCTAssertNotNil(msg.queueItemIdsData)
    }

    func testChatMessage_QueueItemIds_RoundTrip() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let id1 = UUID()
        let id2 = UUID()
        msg.queueItemIds = [id1, id2]

        let retrieved = msg.queueItemIds
        XCTAssertEqual(retrieved.count, 2)
        XCTAssertEqual(retrieved[0], id1)
        XCTAssertEqual(retrieved[1], id2)
    }

    func testChatMessage_QueueItemIds_CorruptData_ReturnsEmptyArray() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.queueItemIdsData = Data("{\"bad\":true}".utf8)

        XCTAssertTrue(msg.queueItemIds.isEmpty)
    }

    // MARK: - ChatMessage imageGenerationConfiguration Accessor

    func testChatMessage_ImageConfig_DefaultWhenNilData() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let config = msg.imageGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
    }

    func testChatMessage_ImageConfig_RoundTrip() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        var config = ImageGenerationConfiguration()
        config.prompt = "config prompt"
        config.selectedModelId = "dalle-3"
        msg.imageGenerationConfiguration = config

        let retrieved = msg.imageGenerationConfiguration
        XCTAssertEqual(retrieved.prompt, "config prompt")
        XCTAssertEqual(retrieved.selectedModelId, "dalle-3")
    }

    func testChatMessage_ImageConfig_CorruptData_ReturnsDefault() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.configurationData = Data("broken".utf8)

        let config = msg.imageGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
    }

    // MARK: - ChatMessage Codable Round-Trip

    func testChatMessage_CodableRoundTrip_PreservesAllFields() throws {
        let threadId = UUID()
        let msg = ChatMessage(threadId: threadId, prompt: "Encode me")
        msg.status = .GENERATED
        msg.pendingCount = 3
        msg.isDelinked = true
        msg.errorMessage = "test error"
        msg.generationIds = [UUID(), UUID()]
        msg.queueItemIds = [UUID()]

        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        XCTAssertEqual(decoded.id, msg.id)
        XCTAssertEqual(decoded.threadId, threadId)
        XCTAssertEqual(decoded.prompt, "Encode me")
        XCTAssertEqual(decoded.status, .GENERATED)
        XCTAssertEqual(decoded.pendingCount, 3)
        XCTAssertTrue(decoded.isDelinked)
        XCTAssertEqual(decoded.errorMessage, "test error")
        XCTAssertEqual(decoded.generationIds.count, 2)
        XCTAssertEqual(decoded.queueItemIds.count, 1)
    }
}
