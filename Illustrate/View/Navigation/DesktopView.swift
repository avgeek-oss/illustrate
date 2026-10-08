// MARK: - DesktopView.swift

// Main layout for iPad and macOS with three-column navigation.
//
// Uses NavigationSplitView to provide:
// - Sidebar: Project selector and navigation sections
// - Detail: Selected view content
// - Inspector: Generation queue (always visible)
//
// ## Navigation Structure
// - Project selector at top
// - Sections: Quick Actions, Explore, History, Connections
// - Detail view changes based on selected sidebar item
//
// ## Queue Inspector
// The right panel shows the generation queue (QueueSidebarView)
// with pending, in-progress, and completed generations.
//
// ## NavigationManager Integration
// Listens for programmatic navigation requests via NavigationManager
// and updates the selection/path accordingly.

import Foundation
import SwiftUI

/// Three-column desktop layout with sidebar, detail, and queue inspector.
struct DesktopView: View {
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var queueManager = QueueManager.shared
    @State private var selectedItem: EnumNavigationItem? = .dashboard
    @State private var desktopNavigationPath = NavigationPath()
    private let queueColumnWidth: CGFloat = 280

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                Section {
                    ProjectSelectorView()
                }

                ForEach(EnumNavigationSection.allCases, id: \.self) { section in
                    Section(section.title) {
                        ForEach(sectionItems(section: section), id: \.self) { item in
                            NavigationLink(value: item) {
                                Label(labelForItem(item), systemImage: iconForItem(item))
                            }
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 240, max: 240)
        } detail: {
            #if os(macOS)
            // Nested workspace views can report an intrinsic height larger than the window.
            // Pinning the detail to its split-view allocation keeps the sidebar's viewport stable.
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    navigationContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    QueueSidebarView(queueManager: queueManager)
                        .frame(
                            minWidth: queueColumnWidth,
                            idealWidth: queueColumnWidth,
                            maxWidth: queueColumnWidth,
                            maxHeight: .infinity
                        )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            #else
            navigationContent
            #endif
        }
        #if os(iOS)
        .inspector(isPresented: .constant(true)) {
            QueueSidebarView(queueManager: queueManager)
                .inspectorColumnWidth(
                    min: queueColumnWidth,
                    ideal: queueColumnWidth,
                    max: queueColumnWidth
                )
                .navigationTitle("Generation Queue")
                .interactiveDismissDisabled()
        }
        #endif
        .environmentObject(navigationManager)
        .environmentObject(queueManager)
        .withGlobalToast()
        .onChange(of: navigationManager.selectedNavigationItem) { _, newValue in
            if let newValue {
                desktopNavigationPath = NavigationPath()
                selectedItem = newValue
                navigationManager.selectedNavigationItem = nil
            }
        }
        .onChange(of: navigationManager.detailNavigationItem) { _, newValue in
            if let newValue {
                desktopNavigationPath.append(newValue)
                navigationManager.clearDetailNavigation()
            }
        }
    }

    private var navigationContent: some View {
        NavigationStack(path: $desktopNavigationPath) {
            if let currentItem = selectedItem {
                viewForItem(currentItem)
                    .navigationDestination(for: EnumNavigationItem.self) { item in
                        viewForItem(item)
                    }
            } else {
                Text("Select an item")
            }
        }
    }
}
