// MARK: - GalleryImageView.swift

// Gallery tab for viewing generated images.
//
// Displays all generated images in a grid with:
// - Filter by set type (generate, edit, upscale, etc.)
// - Display mode toggle (fit/fill)
// - Async thumbnail loading via GalleryCache
//
// ## Data Source
// Uses GalleryCache for pre-loaded, project-scoped data
// to avoid expensive SwiftData queries on every view.

import IllustrateProviders
import SwiftData
import SwiftUI

/// Grid gallery view for generated images.
struct GalleryImageView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager
    @ObservedObject private var cache = GalleryCache.shared

    @State private var selectedSetType: EnumSetType? = nil
    @AppStorage("galleryDisplayMode") private var displayMode: GalleryDisplayMode = .fill

    @State private var filteredSets: [ImageSet] = []
    @State private var filteredGenerations: [Generation] = []

    private func updateFilteredData() {
        let sets = cache.imageSets
        let generations = cache.imageGenerations

        let newFilteredSets: [ImageSet] = if let selectedSetType {
            sets.filter { $0.setType == selectedSetType }
        } else {
            sets
        }

        let filteredSetIds = Set(newFilteredSets.map(\.id))
        filteredSets = newFilteredSets
        filteredGenerations = generations.filter { filteredSetIds.contains($0.setId) }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if !cache.isLoaded {
                    ProgressView("Loading gallery...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredGenerations.isEmpty {
                    Text("No images generated.")
                        .opacity(0.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        GalleryGridView(
                            sets: filteredSets,
                            generations: filteredGenerations,
                            contentType: .IMAGE_2D,
                            availableWidth: geometry.size.width,
                            displayMode: displayMode
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            cache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            updateFilteredData()
        }
        .onChange(of: projectManager.currentProjectId) { _, newProjectId in
            cache.loadIfNeeded(projectId: newProjectId, modelContext: modelContext, force: true)
        }
        .onChange(of: cache.isLoaded) { _, _ in
            updateFilteredData()
        }
        .onChange(of: cache.imageGenerations.count) { _, _ in
            updateFilteredData()
        }
        .onChange(of: selectedSetType) { _, _ in
            updateFilteredData()
        }
        .refreshable {
            cache.refresh(projectId: projectManager.currentProjectId, modelContext: modelContext)
        }
        .navigationTitle(labelForItem(.historyImageGallery))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(GalleryDisplayMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                displayMode = mode
                            }
                        } label: {
                            Label(mode.rawValue, systemImage: mode.icon)
                        }
                        .disabled(displayMode == mode)
                    }
                } label: {
                    Label("Display Mode", systemImage: displayMode.icon)
                }
                .help("Toggle between Fit and Fill display modes")
            }
        }
    }
}
