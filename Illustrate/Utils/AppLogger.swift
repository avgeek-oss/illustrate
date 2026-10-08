// MARK: - AppLogger.swift

// Centralized logging infrastructure using Apple's unified logging system (OSLog).
//
// AppLogger provides categorized loggers for different parts of the application,
// enabling structured, performant logging with proper privacy controls.
//
// ## Usage
// ```swift
// AppLogger.network.info("Request started: \(url, privacy: .public)")
// AppLogger.generation.error("Generation failed: \(error, privacy: .public)")
// ```
//
// ## Privacy Guidelines
// - NEVER log API keys, secrets, or tokens
// - Use `.private` for user-generated content (prompts, personal data)
// - Use `.public` for system data (model IDs, status codes, dimensions)
//
// ## Log Levels
// - `debug`: Detailed tracing (stripped in release builds)
// - `info`: Normal operation milestones
// - `notice`: Important state changes worth highlighting
// - `error`: Recoverable errors
// - `fault`: Critical failures requiring immediate attention
//
// ## Viewing Logs
// Use Console.app on macOS or Xcode console to view logs.
// Filter by subsystem "so.illustrate" or specific categories.

import OSLog

/// Centralized logging configuration for the Illustrate app.
///
/// Provides categorized loggers for different subsystems, enabling
/// structured logging with appropriate privacy levels.
enum AppLogger {
    /// Bundle identifier used as the logging subsystem
    private static let subsystem = "so.illustrate"

    // MARK: - Application Lifecycle

    /// Logger for app lifecycle events (launch, terminate, scene changes)
    static let app = Logger(subsystem: subsystem, category: "app")

    // MARK: - Network & API

    /// Logger for HTTP network operations and API communications
    static let network = Logger(subsystem: subsystem, category: "network")

    /// Logger for AI provider-specific operations (OpenAI, Stability, Google, etc.)
    static let provider = Logger(subsystem: subsystem, category: "provider")

    // MARK: - Generation

    /// Logger for image and video generation lifecycle
    static let generation = Logger(subsystem: subsystem, category: "generation")

    /// Logger for agent workflow execution
    static let agent = Logger(subsystem: subsystem, category: "agent")

    // MARK: - Data & Storage

    /// Logger for caching operations (memory, disk, URI cache)
    static let cache = Logger(subsystem: subsystem, category: "cache")

    /// Logger for file storage operations (iCloud, local documents)
    static let storage = Logger(subsystem: subsystem, category: "storage")

    /// Logger for SwiftData and database operations
    static let data = Logger(subsystem: subsystem, category: "data")

    // MARK: - UI & User Actions

    /// Logger for significant UI events and user actions
    static let ui = Logger(subsystem: subsystem, category: "ui")

    // MARK: - Queue Management

    /// Logger for generation queue operations
    static let queue = Logger(subsystem: subsystem, category: "queue")
}
