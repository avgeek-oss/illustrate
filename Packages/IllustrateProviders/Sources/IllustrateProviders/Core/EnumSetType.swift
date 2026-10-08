// MARK: - EnumSetType.swift

import Foundation

// MARK: - Set Type Enumeration

/// Classifies the type of generation workflow that created a set.
///
/// Used to:
/// - Filter content in galleries
/// - Route to appropriate detail views
/// - Display appropriate icons and labels
public enum EnumSetType: String, Codable, CaseIterable, Identifiable, Sendable {
    public var id: String {
        rawValue
    }

    /// Standard image generation from text prompt
    case IMAGE_GENERATE
    /// Video generation from text or image
    case VIDEO_GENERATE
    /// Extending existing video with new content
    case VIDEO_EXTEND

    /// Returns the display label for this set type.
    /// Used in navigation menus and headers.
    public var label: String {
        switch self {
        case .IMAGE_GENERATE:
            "Generate Image"
        case .VIDEO_GENERATE:
            "Generate Video"
        case .VIDEO_EXTEND:
            "Extend Video"
        }
    }

    /// Returns a descriptive subtitle for this set type.
    /// Used in feature cards and onboarding.
    public var subLabel: String {
        switch self {
        case .IMAGE_GENERATE:
            "Imagine an image and generate in seconds"
        case .VIDEO_GENERATE:
            "Bring your ideas to life with audio"
        case .VIDEO_EXTEND:
            "Extend video with your imagination"
        }
    }

    /// Returns the SF Symbol icon name for this set type.
    /// Used throughout the UI for visual identification.
    public var icon: String {
        switch self {
        case .IMAGE_GENERATE:
            "wand.and.sparkles"
        case .VIDEO_GENERATE:
            "play"
        case .VIDEO_EXTEND:
            "forward.end"
        }
    }
}
