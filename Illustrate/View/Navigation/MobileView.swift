// MARK: - MobileView.swift

// Main layout for iPhone with tab-based navigation.
//
// Uses TabView to provide:
// - Workspace: Dashboard and quick actions
// - Brand: Brand kit management
// - Gallery: Image/video galleries and failed requests
// - Connections: App configuration (includes Project switching)
// - Queue: Generation queue (with badge)
//
// ## Navigation
// Each tab has its own NavigationStack for independent navigation.
// Uses viewForItem() to resolve navigation destinations.
//
// ## Platform
// iOS/iPadOS only - macOS uses DesktopView instead.

import Foundation
import SwiftUI

/// Mobile tab identifiers for programmatic tab switching.
private enum MobileTab: Hashable {
    case workspace
    case brand
    case queue
    case gallery
    case project
}

/// Tab-based navigation layout for iPhone.
struct MobileView: View {
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var queueManager = QueueManager.shared
    @State private var selectedTab: MobileTab = .workspace
    @State private var homeNavigationPath = NavigationPath()
    @State private var brandNavigationPath = NavigationPath()
    @State private var galleryNavigationPath = NavigationPath()
    @State private var settingsNavigationPath = NavigationPath()

    private let brandItems: Set<EnumNavigationItem> = [
        .brandKit,
        .promptGallery,
        .productGallery,
    ]

    /// Connections-related navigation items that should navigate within the Connections tab.
    private let connectionsItems: Set<EnumNavigationItem> = [
        .settingsProviders,
        .settingsStorage,
        .settingsUsageMetrics,
    ]

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homeNavigationPath) {
                WorkspaceView()
                    .navigationDestination(for: EnumNavigationItem.self) { item in
                        viewForItem(item)
                    }
            }
            .tabItem {
                Label("Workspace", systemImage: "sparkle")
            }
            .tag(MobileTab.workspace)

            #if !os(macOS)
            NavigationStack(path: $brandNavigationPath) {
                BrandDashboardView()
                    .navigationDestination(for: EnumNavigationItem.self) { item in
                        viewForItem(item)
                    }
            }
            .tabItem {
                Label("Brand", systemImage: "briefcase")
            }
            .tag(MobileTab.brand)

            NavigationStack(path: $galleryNavigationPath) {
                GalleryView()
                    .navigationDestination(for: EnumNavigationItem.self) { item in
                        viewForItem(item)
                    }
            }
            .tabItem {
                Label("Gallery", systemImage: "photo")
            }
            .tag(MobileTab.gallery)
            #endif

            NavigationStack(path: $settingsNavigationPath) {
                ConnectionsView()
                    .navigationDestination(for: EnumNavigationItem.self) { item in
                        viewForItem(item)
                    }
            }
            .tabItem {
                Label("Project", systemImage: "folder")
            }
            .tag(MobileTab.project)

            #if !os(macOS)
            MobileQueueView()
                .tabItem {
                    Label("Queue", systemImage: "tray.fill")
                }
                .badge(queueManager.totalCount > 0 ? queueManager.totalCount : 0)
                .tag(MobileTab.queue)
            #endif
        }
        .environmentObject(navigationManager)
        .environmentObject(queueManager)
        .withGlobalToast()
        .onChange(of: navigationManager.selectedNavigationItem) { _, newItem in
            guard let item = newItem else { return }

            if connectionsItems.contains(item) {
                selectedTab = .project
                settingsNavigationPath.append(item)
            } else {
                #if !os(macOS)
                if brandItems.contains(item) {
                    selectedTab = .brand
                    brandNavigationPath.append(item)
                } else {
                    homeNavigationPath.append(item)
                }
                #else
                homeNavigationPath.append(item)
                #endif
            }

            navigationManager.selectedNavigationItem = nil
        }
        .onChange(of: navigationManager.detailNavigationItem) { _, newItem in
            guard let item = newItem else { return }

            switch selectedTab {
            case .brand:
                brandNavigationPath.append(item)
            case .gallery:
                galleryNavigationPath.append(item)
            case .project:
                settingsNavigationPath.append(item)
            case .workspace, .queue:
                homeNavigationPath.append(item)
            }

            navigationManager.clearDetailNavigation()
        }
    }
}
