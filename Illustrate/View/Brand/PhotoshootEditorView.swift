// MARK: - PhotoshootEditorView.swift

// Main editor view for product photoshoot creation.
//
// PhotoshootEditorView provides a tabbed interface:
// - Studio: Configuration, backdrop selection, object upload, generation
// - Gallery: View generated photographs
//
// ## Layout
// ```
// +----------------------------------------------------------+
// |  Title | Dimensions | [Studio][Gallery] | Model           |
// +----------------------------------------------------------+
// |              Content Area (Studio or Gallery)             |
// +----------------------------------------------------------+
// ```

import OSLog
import SwiftData
import SwiftUI

/// Editing mode tabs for the photoshoot editor.
enum PhotoshootEditorTab: String, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    case studio = "Photo Studio"
    case gallery = "Gallery"

    var icon: String {
        switch self {
        case .studio: "camera.aperture"
        case .gallery: "photo.on.rectangle"
        }
    }
}

/// Main editor view for product photoshoot creation.
struct PhotoshootEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var queueManager: QueueManager

    let photoshoot: ProductPhotoshoot

    @State private var selectedTab: PhotoshootEditorTab = .studio

    private var shouldUseCompactMobileLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top: Header with title, params, tab picker, model
            headerView
                .zIndex(1)

            Divider()
                .zIndex(1)

            // Content area based on selected tab
            contentArea
                .contentShape(Rectangle())
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .clipped()
    }

    // MARK: - Header

    private var headerView: some View {
        Group {
            if shouldUseCompactMobileLayout {
                VStack(alignment: .leading, spacing: 0) {
                    Picker("", selection: $selectedTab) {
                        ForEach(PhotoshootEditorTab.allCases) { tab in
                            Label(tab.rawValue, systemImage: tab.icon)
                                .tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } else {
                HStack(spacing: 16) {
                    Text(photoshoot.name)
                        .font(.headline)

                    Spacer()

                    Picker("", selection: $selectedTab) {
                        ForEach(PhotoshootEditorTab.allCases) { tab in
                            Label(tab.rawValue, systemImage: tab.icon)
                                .tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    Divider()
                        .frame(height: 20)

                    HStack(spacing: 8) {
                        parameterTag(photoshoot.dimensionsEnum.displayName)
                    }

                    Divider()
                        .frame(height: 20)

                    HStack(spacing: 6) {
                        if let providerCode {
                            Image(providerArtworkName(code: providerCode, variant: .square))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                        }
                        if let modelName {
                            Text(modelName)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(tertiarySystemFill)
    }

    private func parameterTag(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var modelName: String? {
        let modelId = photoshoot.modelId
        guard !modelId.isEmpty else { return nil }
        return ProviderService.shared.model(by: modelId)?.modelName
    }

    private var providerCode: String? {
        let providerId = photoshoot.providerId
        guard !providerId.isEmpty,
              let uuid = UUID(uuidString: providerId),
              let provider = providersById[uuid]
        else { return nil }
        return "\(provider.providerCode)"
    }

    // MARK: - Content Area

    private var contentArea: some View {
        Group {
            if shouldUseCompactMobileLayout {
                switch selectedTab {
                case .studio:
                    PhotoshootStudioView(photoshoot: photoshoot)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .gallery:
                    PhotoshootGalleryView(
                        photoshoot: photoshoot,
                        isActive: true
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ZStack {
                    PhotoshootStudioView(photoshoot: photoshoot)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(selectedTab == .studio ? 1 : 0)
                        .allowsHitTesting(selectedTab == .studio)
                        .accessibilityHidden(selectedTab != .studio)

                    PhotoshootGalleryView(
                        photoshoot: photoshoot,
                        isActive: selectedTab == .gallery
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == .gallery ? 1 : 0)
                    .allowsHitTesting(selectedTab == .gallery)
                    .accessibilityHidden(selectedTab != .gallery)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
