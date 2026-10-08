// MARK: - MainView.swift

// Root view that selects between mobile and desktop layouts.
//
// MainView is the first view rendered after app launch. It:
// 1. Detects device size class (compact vs regular)
// 2. Shows MobileView or DesktopView accordingly
// 3. Presents first-launch welcome sheet
// 4. Initializes default project and loads provider keys
// 5. Pre-warms the gallery cache for faster preview loading
// 6. Fetches provider balances
//
// ## Responsive Layout
// - `horizontalSizeClass == .compact`: iPhones in portrait
// - Otherwise: iPads, iPhones in landscape, macOS
//
// ## Initialization
// On appear, ensures the default project exists and loads
// cached provider keys for the current project.

import SwiftData
import SwiftUI

/// Root view that adapts layout based on device size class.
struct MainView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appVersionManager: AppVersionManager
    @EnvironmentObject var projectManager: ProjectManager
    @EnvironmentObject var balanceService: BalanceService
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    private var providerKeys: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                MobileView()
                    .sheet(isPresented: $appVersionManager.isTheFirstLaunch) {
                        WelcomeView(
                            action: { appVersionManager.isTheFirstLaunch = false }
                        )
                    }
            } else {
                DesktopView()
                    .sheet(isPresented: $appVersionManager.isTheFirstLaunch) {
                        WelcomeView(
                            action: { appVersionManager.isTheFirstLaunch = false }
                        )
                    }
            }
        }
        .installFocusDismissHandler()
        .onAppear {
            projectManager.ensureDefaultProjectExists(modelContext: modelContext)
            providerKeysCache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            GalleryCache.shared.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
        }
        .onChange(of: projectManager.currentProjectId) { _, newProjectId in
            providerKeysCache.loadIfNeeded(projectId: newProjectId, modelContext: modelContext, force: true)
            GalleryCache.shared.loadIfNeeded(projectId: newProjectId, modelContext: modelContext, force: true)
        }
        .task {
            await balanceService.fetchAllBalances(
                providerKeys: providerKeys,
                projectId: projectManager.currentProjectId
            )
        }
    }
}
