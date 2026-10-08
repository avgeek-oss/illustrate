// MARK: - AgentRun.swift

// Tracks individual execution instances of agent workflows.
//
// When a user runs an agent, an AgentRun is created to track that specific
// execution. This enables:
// - Progress tracking during execution
// - History of past runs
// - Error attribution to specific cards
// - Linking generated content to run instances
//
// ## Run Lifecycle
// 1. Created with status `running` when execution starts
// 2. Each card in the workflow processes in sequence
// 3. On success: status → `successful`, completedAt is set
// 4. On failure: status → `errored`, errorMessage and errorCardId are set
//
// ## Relationship to Generations
// Generations created during a run have their `runId` set to the AgentRun's id.
// This allows querying all content produced by a specific run.

import Foundation
import SwiftData

// MARK: - Agent Run Status Enumeration

/// Tracks the current state of an agent workflow execution.
///
/// Used to display progress to users and filter run history:
/// - `RUNNING`: Execution in progress
/// - `SUCCESSFUL`: All cards completed without errors
/// - `ERRORED`: At least one card failed
enum AgentRunStatus: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    /// Workflow is currently executing
    case RUNNING
    /// Workflow completed successfully
    case SUCCESSFUL
    /// Workflow encountered an error
    case ERRORED

    // MARK: - Backward Compatible Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "running", "RUNNING": self = .RUNNING
        case "successful", "SUCCESSFUL": self = .SUCCESSFUL
        case "errored", "ERRORED": self = .ERRORED
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown AgentRunStatus: \(rawValue)"
                )
            )
        }
    }
}

// MARK: - Agent Run Model

/// SwiftData model tracking a single execution of an agent workflow.
///
/// Each time a user runs an agent, a new AgentRun instance is created.
/// The run tracks execution state, timing, and any errors encountered.
///
/// ## Error Tracking
/// When a run fails:
/// - `status` becomes `.errored`
/// - `errorMessage` contains the error description
/// - `errorCardId` identifies which card failed
/// This allows the UI to highlight the failing card and show the error.
///
/// ## Status Storage
/// Status is stored as `statusRaw` (String) for SwiftData compatibility,
/// with a computed `status` property for type-safe access.
@Model
class AgentRun: Identifiable, Codable {
    #Index<AgentRun>([\.agentId, \.projectId])

    enum CodingKeys: CodingKey {
        case id
        case agentId
        case projectId
        case createdAt
        case completedAt
        case statusRaw
        case errorMessage
        case errorCardId
    }

    var id = UUID()

    /// The agent that was executed
    var agentId = UUID()

    var agent: Agent?

    /// Project context for this run
    var projectId: UUID = Project.defaultProjectId

    /// When execution started
    var createdAt = Date()

    /// When execution finished (nil if still running)
    var completedAt: Date?

    /// Raw status string for SwiftData storage
    var statusRaw: String = AgentRunStatus.RUNNING.rawValue

    /// Error message if execution failed
    var errorMessage: String?

    /// Card that caused the failure (if applicable)
    var errorCardId: UUID?

    /// Type-safe access to run status.
    /// Converts between enum and raw string storage.
    var status: AgentRunStatus {
        get { AgentRunStatus(rawValue: statusRaw) ?? .RUNNING }
        set { statusRaw = newValue.rawValue }
    }

    /// Creates a new run instance for an agent.
    ///
    /// - Parameters:
    ///   - agentId: The agent being executed
    ///   - projectId: Project context
    init(
        agentId: UUID,
        projectId: UUID = Project.defaultProjectId
    ) {
        id = UUID()
        self.agentId = agentId
        self.projectId = projectId
        createdAt = Date()
        statusRaw = AgentRunStatus.RUNNING.rawValue
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        agentId = try container.decode(UUID.self, forKey: .agentId)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        statusRaw = try container.decodeIfPresent(String.self, forKey: .statusRaw) ?? AgentRunStatus.RUNNING.rawValue
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        errorCardId = try container.decodeIfPresent(UUID.self, forKey: .errorCardId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(agentId, forKey: .agentId)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(statusRaw, forKey: .statusRaw)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(errorCardId, forKey: .errorCardId)
    }
}
