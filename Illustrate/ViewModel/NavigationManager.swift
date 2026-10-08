// MARK: - NavigationManager.swift

// Manages app navigation state and inter-view data passing.
//
// NavigationManager coordinates navigation throughout the app, handling:
// - Primary navigation via sidebar/tabs
// - Detail navigation within sections
// - Data preloading for cross-view workflows
//
// ## Navigation Architecture
// The app uses a two-tier navigation system:
// - `selectedNavigationItem`: Primary view selection (sidebar/tab)
// - `detailNavigationItem`: Secondary navigation within a section
//
// ## Preload System
// When navigating between views with context (e.g., "Edit this image"),
// preload structs carry the necessary data:
// - `generateImagePreload`: Image data for "Generate Similar" flows
// - `extendVideoPreload`: Video data for "Extend Video" flows

import Foundation
import OSLog
import SwiftUI

// MARK: - Preload Data Structures

/// Data preload for navigating to image generation with context.
///
/// Used when user selects "Generate Similar" or "Edit" on an existing image.
/// Carries the source image and its metadata to pre-populate the generation form.
struct GenerateImagePreload {
    /// Source image to use as reference
    let image: PlatformImage
    /// Color palette extracted from source (for UI theming)
    let colorPalette: [String]
    /// Original dimensions to preserve
    let dimensions: String
    /// Original prompt to pre-fill
    let prompt: String?
    /// Original negative prompt to pre-fill
    let negativePrompt: String?
}

/// Protocol for video preload data shared between video workflows.
protocol GenerateVideoPreload {
    /// Source video identifier
    var videoId: String { get }
    /// Color palette from video (for UI theming)
    var colorPalette: [String] { get }
    /// Video dimensions
    var dimensions: String { get }
    /// Original prompt (if any)
    var prompt: String? { get }
    /// Original negative prompt (if any)
    var negativePrompt: String? { get }
}

/// Data preload for navigating to video extension.
///
/// Used when user selects "Extend" on a generated video.
/// Carries the source video data to initialize the extension form.
struct ExtendVideoPreload: GenerateVideoPreload {
    let videoId: String
    let colorPalette: [String]
    let dimensions: String
    let prompt: String?
    let negativePrompt: String?
    /// The original generation record (for metadata access)
    let generation: Generation?
}

// MARK: - Navigation Manager

/// Observable manager coordinating app-wide navigation state.
///
/// This class maintains the navigation state as a single source of truth,
/// enabling views to trigger navigation and pass data between screens.
///
/// ## Navigation Levels
/// - Primary: `selectedNavigationItem` - Which main section is active
/// - Detail: `detailNavigationItem` - Sub-navigation within a section
///
/// ## Data Passing
/// Preload properties carry data when navigating with context:
/// - Navigate to ImageGenerate with an image to edit
/// - Navigate to VideoExtend with a video to continue
///
/// Clear preloads after the target view consumes the data.
class NavigationManager: ObservableObject {
    /// SwiftUI NavigationPath for programmatic navigation
    @Published var navigationPath = NavigationPath()

    /// Currently selected primary navigation item
    @Published var selectedNavigationItem: EnumNavigationItem? = nil

    /// Currently selected detail/secondary navigation item
    @Published var detailNavigationItem: EnumNavigationItem? = nil

    /// Preloaded data for image generation (when editing existing images)
    @Published var generateImagePreload: GenerateImagePreload? = nil

    /// Preloaded data for video extension
    @Published var extendVideoPreload: ExtendVideoPreload? = nil

    /// Navigate to a primary navigation item.
    ///
    /// - Parameter item: The navigation destination
    func navigate(to item: EnumNavigationItem) {
        selectedNavigationItem = item
    }

    /// Convenience method to navigate to an image generation detail view.
    ///
    /// - Parameter setId: The ImageSet UUID to display
    func navigateToGeneration(setId: UUID) {
        navigate(to: .generationImage(setId: setId))
    }

    /// Navigate to image generation with preloaded source image.
    ///
    /// Used for "Generate Similar" or "Edit" flows where the user
    /// starts with an existing image.
    ///
    /// - Parameter preload: Source image data and metadata
    func navigateToGenerateImage(with preload: GenerateImagePreload) {
        generateImagePreload = preload
        navigate(to: .imageGenerate)
    }

    /// Clear image generation preload after consumption.
    func clearGenerateImagePreload() {
        generateImagePreload = nil
    }

    /// Navigate to video extension with preloaded source video.
    ///
    /// - Parameter preload: Source video data and metadata
    func navigateToExtendVideo(with preload: ExtendVideoPreload) {
        extendVideoPreload = preload
        navigate(to: .videoExtend)
    }

    /// Clear video extension preload after consumption.
    func clearExtendVideoPreload() {
        extendVideoPreload = nil
    }

    /// Push a detail view within the current section.
    ///
    /// - Parameter item: The detail navigation destination
    func pushDetail(_ item: EnumNavigationItem) {
        detailNavigationItem = item
    }

    /// Clear detail navigation state.
    func clearDetailNavigation() {
        detailNavigationItem = nil
    }
}
