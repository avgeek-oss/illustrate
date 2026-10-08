// MARK: - Navigation.swift

// Central navigation definitions for the Illustrate app.
//
// This file defines the navigation structure including:
// - All navigable destinations (EnumNavigationItem)
// - Sidebar section organization (EnumNavigationSection)
// - Helper functions for labels, icons, and view routing
//
// ## Navigation Architecture
// The app uses a sidebar-based navigation pattern:
// - Sections group related navigation items
// - Items map to specific views
// - Some items have associated data (setId, providerId)
//
// ## Platform Differences
// Navigation adapts to platform:
// - macOS: Sidebar with NavigationSplitView
// - iOS: Tab bar with sheet presentations

import Foundation
import SwiftUI

// MARK: - Navigation Item Enumeration

/// All navigable destinations in the app.
///
/// Navigation items represent every screen users can navigate to.
/// Some items are static (dashboard), while others carry data
/// (generationImage with setId).
///
/// ## Categories
/// - **Workspace**: Main work areas (dashboard, agent canvas, Flow Canvas)
/// - **Brand**: Brand asset management
/// - **Quick Actions**: Direct generation shortcuts
/// - **History**: Past content and requests
/// - **Connections**: App configuration
/// - **Detail Views**: Content-specific views with associated IDs
enum EnumNavigationItem: Identifiable, Hashable {
    // MARK: Workspace Section

    /// Main dashboard/home screen
    case dashboard
    /// Agent workflow canvas
    case agentCanvas
    /// Live interactive Flow Canvas
    case flowCanvas
    /// Canvas-based image editing with layers
    case realtimeEdit
    /// Bulk image generation from CSV
    case bulkSessions
    case bulkEdits
    /// Chat-based iterative generation
    case chatThreads
    /// Multi-scene movie storyboard
    case storyboard

    // MARK: Brand Section

    /// Brand kit management
    case brandKit
    /// Creative studio for brand asset generation
    case creativeStudio
    /// Product listing photograph generation
    case productPhotoshoots
    /// Saved prompts with tags
    case promptGallery
    /// Product images with tags for photoshoots
    case productGallery

    // MARK: Quick Actions Section

    /// Image generation view
    case imageGenerate
    /// Video generation view
    case videoGenerate
    /// Video extension view
    case videoExtend

    // MARK: History Section

    /// Request history
    case historyRequests
    /// Failed request log
    case historyFailedRequests
    /// Image gallery browser
    case historyImageGallery
    /// Video gallery browser
    case historyVideoGallery

    // MARK: Connections Section

    /// Provider API key management
    case settingsProviders
    /// Storage management
    case settingsStorage
    /// Usage analytics
    case settingsUsageMetrics

    // MARK: Detail Views (with associated data)

    /// Image generation detail view for a specific set
    case generationImage(setId: UUID)
    /// Video generation detail view for a specific set
    case generationVideo(setId: UUID)

    /// Provider setup/edit view
    case addProvider(providerId: UUID)

    /// Unique identifier for navigation state management.
    /// Detail views include their UUID for uniqueness.
    var id: String {
        switch self {
        case let .generationImage(setId):
            "generationImage-\(setId.uuidString)"
        case let .generationVideo(setId):
            "generationVideo-\(setId.uuidString)"
        case let .addProvider(providerId):
            "addProvider-\(providerId.uuidString)"
        default:
            "\(self)"
        }
    }
}

// MARK: - Navigation Section Enumeration

/// Sidebar sections for organizing navigation items.
///
/// Each section groups related functionality:
/// - Workspace: Primary work areas
/// - Brand: Brand asset management
/// - QuickActions: Direct generation shortcuts
/// - History: Past content
/// - Connections: Configuration
enum EnumNavigationSection: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    case Workspace
    case Brand
    case QuickActions = "Quick Actions"
    case History
    case Project

    var title: String {
        switch self {
        case .Workspace:
            AppLocalization.string("Workspace")
        case .Brand:
            AppLocalization.string("Brand")
        case .QuickActions:
            AppLocalization.string("Quick Actions")
        case .History:
            AppLocalization.string("History")
        case .Project:
            AppLocalization.string("Project")
        }
    }
}

// MARK: - Section Item Mapping

/// Returns the navigation items belonging to a sidebar section.
///
/// This function defines the structure of the sidebar menu.
/// Platform-specific differences are handled with conditional compilation.
///
/// - Parameter section: The section to get items for
/// - Returns: Array of navigation items in that section
///
/// - Note: macOS shows historyRequests which is hidden on iOS
func sectionItems(section: EnumNavigationSection) -> [EnumNavigationItem] {
    switch section {
    case .Workspace:
        return [
            .dashboard,
            .agentCanvas,
            .chatThreads,
            .flowCanvas,
            .realtimeEdit,
            .bulkSessions,
            .bulkEdits,
            .storyboard,
            .productPhotoshoots,
        ]
    case .Brand:
        return [.brandKit, .creativeStudio, .promptGallery, .productGallery]
    case .QuickActions:
        return [
            .imageGenerate, .videoGenerate, .videoExtend,
        ]
    case .History:
        #if os(macOS)
        // macOS shows the full requests view
        return [.historyImageGallery, .historyVideoGallery, .historyRequests, .historyFailedRequests]
        #else
        // iOS hides detailed requests view for simpler UX
        return [.historyImageGallery, .historyVideoGallery, .historyRequests, .historyFailedRequests]
        #endif
    case .Project:
        return [.settingsProviders, .settingsStorage, .settingsUsageMetrics]
    }
}

// MARK: - Navigation Item Labels

/// Returns the display label for a navigation item.
/// Used in sidebar, navigation bars, and breadcrumbs.
func labelForItem(_ item: EnumNavigationItem) -> String {
    switch item {
    case .dashboard:
        AppLocalization.string("Dashboard")
    case .brandKit:
        AppLocalization.string("Brand Kit")
    case .creativeStudio:
        AppLocalization.string("Brand Studio")
    case .productPhotoshoots:
        AppLocalization.string("Product Photoshoots")
    case .promptGallery:
        AppLocalization.string("Prompt Gallery")
    case .productGallery:
        AppLocalization.string("Product Gallery")
    case .imageGenerate:
        labelForSetType(.IMAGE_GENERATE)
    case .bulkSessions:
        AppLocalization.string("Bulk Generate")
    case .bulkEdits:
        AppLocalization.string("Bulk Edits")
    case .videoGenerate:
        labelForSetType(.VIDEO_GENERATE)
    case .videoExtend:
        labelForSetType(.VIDEO_EXTEND)
    case .agentCanvas:
        AppLocalization.string("Agent Builder")
    case .flowCanvas:
        AppLocalization.string("Flow Canvas")
    case .realtimeEdit:
        AppLocalization.string("Realtime Edit")
    case .chatThreads:
        AppLocalization.string("Chat Threads")
    case .storyboard:
        AppLocalization.string("Storyboards")
    case .historyRequests:
        AppLocalization.string("Request History")
    case .historyFailedRequests:
        AppLocalization.string("Failed Requests")
    case .historyImageGallery:
        AppLocalization.string("Image Gallery")
    case .historyVideoGallery:
        AppLocalization.string("Video Gallery")
    case .settingsProviders:
        AppLocalization.string("Manage Providers")
    case .settingsStorage:
        AppLocalization.string("Manage Storage")
    case .settingsUsageMetrics:
        AppLocalization.string("Usage Metrics")
    case .generationImage:
        AppLocalization.string("Image Generation")
    case .generationVideo:
        AppLocalization.string("Video Generation")
    case .addProvider:
        AppLocalization.string("Add Provider")
    }
}

/// Returns a descriptive subtitle for a navigation item.
/// Used in feature cards, tooltips, and onboarding.
func subLabelForItem(_ item: EnumNavigationItem) -> String {
    switch item {
    case .dashboard:
        AppLocalization.string("Your go-to workplace dashboard")
    case .brandKit:
        AppLocalization.string("Manage your brand colors and logos")
    case .creativeStudio:
        AppLocalization.string("Generate brand-consistent creative assets")
    case .productPhotoshoots:
        AppLocalization.string("Create professional product listing photographs")
    case .promptGallery:
        AppLocalization.string("Save and organize your best prompts with tags")
    case .productGallery:
        AppLocalization.string("Store product images for quick use in photoshoots")
    case .imageGenerate:
        subLabelForSetType(.IMAGE_GENERATE)
    case .bulkSessions:
        AppLocalization.string("Generate images in bulk from CSV")
    case .bulkEdits:
        AppLocalization.string("Batch edit images with a common prompt")
    case .videoGenerate:
        subLabelForSetType(.VIDEO_GENERATE)
    case .videoExtend:
        subLabelForSetType(.VIDEO_EXTEND)
    case .agentCanvas:
        AppLocalization.string("Build agents to automate your workflows")
    case .flowCanvas:
        AppLocalization.string("Interactive canvas for quick generations")
    case .realtimeEdit:
        AppLocalization.string("Canvas-based image editing with layers")
    case .chatThreads:
        AppLocalization.string("Chat-based iterative image generation")
    case .storyboard:
        AppLocalization.string("Create multi-scene movies with seamless transitions")
    case .historyRequests:
        AppLocalization.string("View your generation requests")
    case .historyFailedRequests:
        AppLocalization.string("Debug failed generation requests")
    case .historyImageGallery:
        AppLocalization.string("Gallery for your generated images")
    case .historyVideoGallery:
        AppLocalization.string("Gallery for your generated videos")
    case .settingsProviders:
        AppLocalization.string("Link and manage your providers")
    case .settingsStorage:
        AppLocalization.string("Clear your Illustrate iCloud storage")
    case .settingsUsageMetrics:
        AppLocalization.string("View your generation usage metrics")
    case .generationImage:
        AppLocalization.string("View the generated image")
    case .generationVideo:
        AppLocalization.string("View the generated video")
    case .addProvider:
        AppLocalization.string("Add a new provider")
    }
}

/// Returns the SF Symbol icon name for a navigation item.
/// Used in sidebar, tab bars, and buttons.
func coverImageForItem(_ item: EnumNavigationItem) -> String? {
    switch item {
    case .dashboard: "cover_dashboard"
    case .agentCanvas: "cover_agent_builder"
    case .chatThreads: "cover_chat_threads"
    case .flowCanvas: "cover_flow_canvas"
    case .realtimeEdit: "cover_realtime_edit"
    case .bulkSessions: "cover_bulk_generate"
    case .bulkEdits: "cover_bulk_edits"
    case .storyboard: "cover_storyboards"
    case .brandKit: "cover_brand_kit"
    case .creativeStudio: "cover_creative_studio"
    case .productPhotoshoots: "cover_product_photoshoots"
    case .promptGallery: "cover_prompt_gallery"
    case .productGallery: "cover_product_gallery"
    case .imageGenerate: "cover_generate_image"
    case .videoGenerate: "cover_generate_video"
    case .videoExtend: "cover_extend_video"
    case .settingsProviders: "cover_manage_providers"
    case .settingsStorage: "cover_manage_storage"
    case .settingsUsageMetrics: "cover_usage_metrics"
    default: nil
    }
}

func iconForItem(_ item: EnumNavigationItem) -> String {
    switch item {
    case .dashboard:
        "house"
    case .brandKit:
        "briefcase"
    case .creativeStudio:
        "wand.and.rays.inverse"
    case .productPhotoshoots:
        "camera.aperture"
    case .promptGallery:
        "text.book.closed"
    case .productGallery:
        "lamp.floor"
    case .imageGenerate:
        iconForSetType(.IMAGE_GENERATE)
    case .bulkSessions:
        "square.stack.3d.up"
    case .bulkEdits:
        "sparkles.rectangle.stack"
    case .videoGenerate:
        iconForSetType(.VIDEO_GENERATE)
    case .videoExtend:
        iconForSetType(.VIDEO_EXTEND)
    case .agentCanvas:
        "square.and.pencil"
    case .flowCanvas:
        "point.topleft.down.to.point.bottomright.curvepath"
    case .realtimeEdit:
        "timer"
    case .chatThreads:
        "bubble.left.and.text.bubble.right"
    case .storyboard:
        "movieclapper"
    case .historyRequests:
        "list.triangle"
    case .historyFailedRequests:
        "exclamationmark.triangle"
    case .historyImageGallery:
        "photo"
    case .historyVideoGallery:
        "film"
    case .settingsProviders:
        "link"
    case .settingsStorage:
        "externaldrive"
    case .settingsUsageMetrics:
        "chart.bar"
    case .generationImage:
        "wand.and.sparkles"
    case .generationVideo:
        "video"
    case .addProvider:
        "plus"
    }
}

// MARK: - View Routing

/// Maps navigation items to their corresponding SwiftUI views.
///
/// This function is the central router for the navigation system.
/// It creates and returns the appropriate view for each navigation item.
///
/// ## Detail Views
/// Items with associated data (generationImage, addProvider) pass
/// their data to the created views as parameters.
///
/// - Parameter item: The navigation item to get a view for
/// - Returns: The SwiftUI view for that item
@ViewBuilder
func viewForItem(_ item: EnumNavigationItem) -> some View {
    switch item {
    case .dashboard:
        WorkspaceView()
    case .brandKit:
        BrandKitView()
    case .creativeStudio:
        CreativeStudioView()
    case .productPhotoshoots:
        ProductPhotoshootsView()
    case .promptGallery:
        PromptGalleryView()
    case .productGallery:
        ProductGalleryView()
    case .imageGenerate:
        ImageGenerateView()
    case .bulkSessions:
        BulkSessionsView()
    case .bulkEdits:
        BulkEditsView()
    case .videoGenerate:
        VideoGenerateView()
    case .videoExtend:
        VideoExtendView()
    case .agentCanvas:
        AgentCanvasView()
    case .flowCanvas:
        PlaygroundCanvasView()
    case .realtimeEdit:
        RealtimeEditView()
    case .chatThreads:
        ChatThreadsView()
    case .storyboard:
        StoryboardListView()
    case .historyRequests:
        RequestsView()
    case .historyFailedRequests:
        FailedRequestsView()
    case .historyImageGallery:
        GalleryImageView()
    case .historyVideoGallery:
        GalleryVideoView()
    case .settingsProviders:
        ProvidersView()
    case .settingsStorage:
        ManageStorageView()
    case .settingsUsageMetrics:
        UsageMetricsView()
    case let .generationImage(setId):
        GenerationImageView(setId: setId)
    case let .generationVideo(setId):
        GenerationVideoView(setId: setId)
    case let .addProvider(providerId):
        AddProviderView(providerId: providerId)
    }
}
