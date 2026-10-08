// MARK: - IllustrateApp.swift

// Main entry point for the Illustrate application.
//
// Illustrate is a multi-platform (macOS/iOS) AI-powered image and video generation app
// that integrates with multiple AI providers including OpenAI, Stability AI, Google Cloud,
// Replicate, and Fal AI. Users can generate images/videos using text prompts, build
// automated agent workflows on an infinite canvas, and manage their generated content.
//
// Architecture Overview:
// - SwiftData for persistence with iCloud sync support
// - MVVM pattern with ObservableObject view models
// - Provider-based adapter pattern for multi-provider API integration
// - Environment-based dependency injection for services

import AvgeekLocalizationUI
import Combine
import IllustrateProviders
import OSLog
import SwiftData
import SwiftUI

// MARK: - Model Container Configuration

/// Creates a configured ModelContainer with optimized settings for concurrent access.
///
/// This configuration addresses:
/// - WAL checkpoint contention by using appropriate autosave settings
/// - iCloud sync compatibility
/// - Concurrent read/write operations from multiple views and background tasks
private func createModelContainer() -> ModelContainer {
    let allModels: [any PersistentModel.Type] = [
        Provider.self,
        ProviderKey.self,
        ProviderModel.self,
        Generation.self,
        ImageSet.self,
        Project.self,
        BrandKit.self,
        Agent.self,
        AgentCard.self,
        CardLink.self,
        AgentRun.self,
        FailedRequest.self,
        Playground.self,
        PlaygroundCard.self,
        PlaygroundLink.self,
        ChatThread.self,
        ChatMessage.self,
        RealtimeEditSession.self,
        RealtimeEditLayer.self,
        CreativeStudio.self,
        CreativeStudioItem.self,
        Storyboard.self,
        StoryboardScene.self,
        StoryboardAsset.self,
        BulkSession.self,
        BulkSessionItem.self,
        BulkEditSession.self,
        BulkEditItem.self,
        ProductPhotoshoot.self,
        ProductPhotoshootItem.self,
        PromptGalleryItem.self,
        ProductGalleryItem.self,
    ]

    let schema = Schema(allModels)
    let configuration = ModelConfiguration(isStoredInMemoryOnly: false, allowsSave: true)

    do {
        return try ModelContainer(for: schema, configurations: [configuration])
    } catch {
        AppLogger.app.fault(
            "Failed to open the SwiftData store without modifying it: \(error.localizedDescription)"
        )
        fatalError("Could not open the existing SwiftData store; user data was left intact: \(error)")
    }
}

// MARK: - App Version Manager

/// Manages first-launch detection for onboarding flows.
///
/// This singleton-style class tracks whether the app has been launched before using
/// UserDefaults. It's used to show welcome/onboarding screens on first launch.
///
/// Usage:
/// - Injected as an environment object in the app root
/// - Views can observe `isTheFirstLaunch` to conditionally show onboarding
final class AppVersionManager: ObservableObject {
    /// Indicates whether this is the user's first time launching the app.
    /// Set to `false` after the first launch is detected.
    @Published var isTheFirstLaunch = true

    init() {
        checkFirstLaunch()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let firstLaunch = isTheFirstLaunch
        AppLogger.app
            .notice(
                "Illustrate launched - version \(version, privacy: .public) (\(build, privacy: .public)), firstLaunch: \(firstLaunch, privacy: .public)"
            )
    }

    /// Checks UserDefaults for previous launch history and updates the flag.
    /// On first launch, sets the "hasLaunchedBefore" key to persist the state.
    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        isTheFirstLaunch = !hasLaunchedBefore

        if !hasLaunchedBefore {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }
}

// MARK: - Main App Entry Point

/// The main application struct serving as the entry point for Illustrate.
///
/// This struct configures the entire application environment including:
/// - Global service singletons (ProviderService, ProjectManager, BalanceService)
/// - SwiftData model container with all persistent entities
/// - Platform-specific window constraints (macOS minimum size)
///
/// ## Dependency Injection Strategy
/// Services are injected in two ways for flexibility:
/// 1. As `@EnvironmentObject` for ObservableObject protocol access
/// 2. As custom `@Environment` keys for cleaner property wrapper syntax
///
/// ## SwiftData Schema
/// The model container registers all SwiftData models:
/// - **Provider Management**: Provider, ProviderKey, ProviderModel
/// - **Content Generation**: Generation, ImageSet
/// - **Project Organization**: Project, BrandKit
/// - **Agent Workflows**: Agent, AgentCard, CardLink, AgentRun
/// - **Flow Canvas**: Playground, PlaygroundCard, PlaygroundLink
/// - **Chat Threads**: ChatThread, ChatMessage
/// - **Creative Studio**: CreativeStudio, CreativeStudioItem
/// - **Error Tracking**: FailedRequest
@main
enum IllustrateEntryPoint {
    static func main() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
        {
            IllustrateTestHost.main()
        } else {
            IllustrateApp.main()
        }
    }
}

/// Hosted unit tests supply their own stores; never construct the production app.
private struct IllustrateTestHost: App {
    var body: some Scene {
        WindowGroup { Color.clear }
    }
}

struct IllustrateApp: App {
    /// Tracks first launch for onboarding flows
    @StateObject private var appVersionManager = AppVersionManager()

    /// Central service for managing AI provider models and their configurations
    @StateObject private var providerService = ProviderService.shared

    /// Manages project selection and multi-project workflows
    @StateObject private var projectManager = ProjectManager.shared

    /// Handles provider balance/credit checking for supported providers
    @StateObject private var balanceService = BalanceService.shared

    /// Stores the selected app language and follows the first supported system language on first launch
    @StateObject private var appLanguageSettings = IllustrateLanguageSettings.shared

    /// Configured model container for SwiftData persistence
    private let modelContainer = createModelContainer()

    init() {
        configureProviderDependencies()
        #if os(macOS)
        GenerationNotificationService.shared.requestAuthorizationIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            LocalizedSceneContent(languageController: appLanguageSettings) {
                MainView()
                    .environmentObject(appLanguageSettings)
                    // Inject services as environment objects for ObservableObject access
                    .environmentObject(appVersionManager)
                    .environmentObject(providerService)
                    .environmentObject(projectManager)
                    .environmentObject(balanceService)
                    // Also inject via custom environment keys for cleaner syntax
                    .environment(\.providerService, providerService)
                    .environment(\.projectManager, projectManager)
                    .environment(\.balanceService, balanceService)
                    .modelContainer(modelContainer)
                    #if os(macOS)
                    // Enforce minimum window size on macOS for proper UI layout
                    .frame(
                        minWidth: 1200,
                        maxWidth: .infinity,
                        minHeight: 800,
                        maxHeight: .infinity
                    )
                    #endif
            }
        }
        #if os(macOS)
        .commands {
            SupportedModelsCommands()
        }
        #endif

        #if os(macOS)
        // Standalone window for viewing generation details without navigation
        WindowGroup(for: GenerationWindowData.self) { $data in
            if let data {
                LocalizedSceneContent(languageController: appLanguageSettings) {
                    GenerationWindowView(data: data)
                        .environmentObject(appLanguageSettings)
                        .environmentObject(projectManager)
                        .environmentObject(NavigationManager())
                        .modelContainer(modelContainer)
                }
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 700)

        // Supported Models reference window
        Window("Supported Models", id: "supported-models") {
            LocalizedSceneContent(languageController: appLanguageSettings) {
                SupportedModelsView()
                    .environmentObject(appLanguageSettings)
                    .environmentObject(providerService)
                    .environment(\.providerService, providerService)
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 700)

        // Erase & Reset Application window
        Window("Erase & Reset Application", id: "erase-reset") {
            LocalizedSceneContent(languageController: appLanguageSettings) {
                EraseResetView()
                    .environmentObject(appLanguageSettings)
                    .environmentObject(projectManager)
                    .modelContainer(modelContainer)
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 500)

        // Menu Bar quick generate
        MenuBarExtra {
            LocalizedSceneContent(languageController: appLanguageSettings) {
                MenuBarGenerateView()
                    .environmentObject(appLanguageSettings)
                    .environmentObject(providerService)
                    .environmentObject(projectManager)
                    .modelContainer(modelContainer)
            }
        } label: {
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
