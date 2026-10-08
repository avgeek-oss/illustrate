// MARK: - RequestsView.swift

// Table view of all generation requests with details.
//
// Shows comprehensive data table of all generations:
// - Date, provider, model
// - Prompt, dimensions, size
// - Estimated cost incurred
// - Quality, style, variant
//
// ## Features
// - Sortable columns
// - Multi-select for bulk delete
// - Filter by set type
// - Navigate to detail view
//
// ## Platform
// Primarily for macOS with Table view.

import IllustrateProviders
import OSLog
import SwiftData
import SwiftUI

/// Data table of all generation requests.
struct RequestsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var navigationManager: NavigationManager
    @ObservedObject private var cache = GalleryCache.shared

    @State private var selectedSetType: EnumSetType? = nil

    private var sets: [ImageSet] {
        cache.imageSets
    }

    @State private var allGenerations: [Generation] = []

    private var generations: [Generation] {
        allGenerations
    }

    @State private var isLoaded = false
    @State private var selectedGenerations: Set<Generation.ID> = []
    @State private var showDeleteConfirmation = false
    @State private var filteredGenerations: [Generation] = []
    @State private var filteredSetIdsCache: Set<UUID> = []

    @State private var sortOrder = [KeyPathComparator(\Generation.createdAt, order: .reverse)]

    // MARK: - Lookup Caches (precomputed for performance)

    @State private var modelNameCache: [String: String] = [:]
    @State private var creditCurrencyCache: [String: String] = [:]

    private func updateAllGenerations() {
        allGenerations = cache.imageGenerations + cache.videoGenerations
    }

    private func buildLookupCaches() {
        var modelNames: [String: String] = [:]
        var creditCurrencies: [String: String] = [:]

        for generation in generations {
            let modelId = generation.modelId
            guard modelNames[modelId] == nil else { continue }

            let model = ProviderService.shared.model(by: modelId)
            let provider = providersById[model?.providerId ?? UUID()]

            modelNames[modelId] = model?.modelName ?? "N/A"
            creditCurrencies[modelId] = provider?.creditCurrency.rawValue ?? "Credits"
        }

        modelNameCache = modelNames
        creditCurrencyCache = creditCurrencies
    }

    private func updateFilteredGenerations() {
        let newFilteredSetIds: Set<UUID> = if let selectedSetType {
            Set(sets.filter { $0.setType == selectedSetType }.map(\.id))
        } else {
            Set(sets.map(\.id))
        }

        // Only recalculate if the set IDs changed
        if newFilteredSetIds != filteredSetIdsCache {
            filteredSetIdsCache = newFilteredSetIds
            filteredGenerations = Array(
                generations.filter { newFilteredSetIds.contains($0.setId) }
                    .sorted(using: sortOrder)
                    .prefix(500)
            )
        }
    }

    @TableColumnBuilder<Generation, KeyPathComparator<Generation>>
    var prefixColumns: some TableColumnContent<Generation, KeyPathComparator<Generation>> {
        TableColumn("Date", value: \.createdAt) { generation in
            Text(generation.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
        .width(min: 180, ideal: 180, max: 180)
    }

    @TableColumnBuilder<Generation, KeyPathComparator<Generation>>
    var modelInfoColumns: some TableColumnContent<Generation, KeyPathComparator<Generation>> {
        TableColumn("Model", value: \.modelId) { generation in
            Text(modelNameCache[generation.modelId] ?? "N/A")
        }
        .width(min: 140, ideal: 180, max: 220)
    }

    @TableColumnBuilder<Generation, KeyPathComparator<Generation>>
    var promptColumns: some TableColumnContent<Generation, KeyPathComparator<Generation>> {
        TableColumn("Prompt", value: \.prompt) { generation in
            if !generation.prompt.isEmpty {
                Text(generation.prompt)
            } else {
                Text("Prompt not added")
                    .opacity(0.5)
            }
        }
        .width(min: 400, ideal: 400, max: 800)
    }

    @TableColumnBuilder<Generation, KeyPathComparator<Generation>>
    var generationInfoColumns: some TableColumnContent<Generation, KeyPathComparator<Generation>> {
        TableColumn("Dimensions", value: \.dimensions) { generation in
            Text("\(generation.dimensions.replacingOccurrences(of: "x", with: " x "))")
                .monospaced()
        }
        .width(min: 120, ideal: 140, max: 160)
        TableColumn("Est. Incurred Cost", value: \.creditUsed) { generation in
            Text(
                "\(String(format: "%.3f", generation.creditUsed).replacingOccurrences(of: ".000", with: "")) \(creditCurrencyCache[generation.modelId] ?? "Credits")"
            )
        }
        .width(min: 120, ideal: 140, max: 160)
    }

    @TableColumnBuilder<Generation, KeyPathComparator<Generation>>
    var actionColumns: some TableColumnContent<Generation, KeyPathComparator<Generation>> {
        TableColumn("Actions", value: \.id) { generation in
            #if os(macOS)
            RequestsViewActionCell(
                generation: generation,
                onNavigateToDetails: { setId, isVideo in
                    navigationManager.detailNavigationItem = isVideo
                        ? .generationVideo(setId: setId)
                        : .generationImage(setId: setId)
                }
            )
            #else
            NavigationLink(
                value: generation.contentType == .IMAGE_2D ? EnumNavigationItem
                    .generationImage(setId: generation.setId) : EnumNavigationItem
                    .generationVideo(setId: generation.setId)
            ) {
                Text("Preview")
            }
            .buttonStyle(BorderedButtonStyle())
            #endif
        }
        .width(min: 120, ideal: 120, max: 120)
    }

    private func deleteSelectedGenerations() {
        let generationsToDelete = filteredGenerations.filter { selectedGenerations.contains($0.id) }
        deleteGenerations(generationsToDelete)
    }

    private func deleteGeneration(_ generation: Generation) {
        deleteGenerations([generation])
    }

    private func deleteGenerations(_ generationsToDelete: [Generation]) {
        guard !generationsToDelete.isEmpty else { return }

        let setIdsToCheck = Set(generationsToDelete.map(\.setId))
        let generationIdsToDelete = Set(generationsToDelete.map(\.id))

        for generation in generationsToDelete {
            deleteGenerationFiles(generation: generation)
            filteredGenerations.removeAll { $0.id == generation.id }
            modelContext.delete(generation)
        }

        for setId in setIdsToCheck {
            let remainingGenerations = generations
                .filter { $0.setId == setId && !generationIdsToDelete.contains($0.id) }
            if remainingGenerations.isEmpty {
                if let imageSet = sets.first(where: { $0.id == setId }) {
                    modelContext.delete(imageSet)
                }
            }
        }

        selectedGenerations.removeAll()

        do {
            try modelContext.save()
        } catch {
            AppLogger.data.error("Error saving context after deletion: \(error.localizedDescription, privacy: .public)")
        }
    }

    private var shouldUseMobileList: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private func deleteGenerationFiles(generation: Generation) {
        let fileManager = FileManager.default

        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
        else {
            let localDocuments = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            deleteFilesWithPrefix(in: localDocuments, prefix: ".\(generation.id.uuidString)")
            return
        }

        deleteFilesWithPrefix(in: containerURL, prefix: ".\(generation.id.uuidString)")
    }

    private func deleteFilesWithPrefix(in directory: URL?, prefix: String) {
        guard let directory else { return }

        let fileManager = FileManager.default

        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in files where file.lastPathComponent.hasPrefix(prefix) {
                try fileManager.removeItem(at: file)
            }
        } catch {
            AppLogger.storage.error("Error deleting files: \(error.localizedDescription, privacy: .public)")
        }
    }

    var body: some View {
        VStack {
            if !isLoaded {
                GradientSpinner()
            } else if filteredGenerations.isEmpty {
                Text("No generations requested.")
                    .opacity(0.5)
            } else if shouldUseMobileList {
                mobileListView
            } else {
                Table(of: Generation.self, selection: $selectedGenerations, sortOrder: $sortOrder) {
                    prefixColumns
                    modelInfoColumns
                    promptColumns
                    generationInfoColumns
                    actionColumns
                } rows: {
                    ForEach(filteredGenerations) { generation in
                        TableRow(generation)
                            .contextMenu {
                                NavigationLink(
                                    value: generation.contentType == .IMAGE_2D ? EnumNavigationItem
                                        .generationImage(setId: generation.setId) : EnumNavigationItem
                                        .generationVideo(setId: generation.setId)
                                ) {
                                    Label(
                                        generation.contentType == .VIDEO ? "View video" : "View image",
                                        systemImage: "eye"
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    #if os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(generation.prompt, forType: .string)
                                    #else
                                    UIPasteboard.general.string = generation.prompt
                                    #endif
                                    showToast(.success("Copied to clipboard"))
                                } label: {
                                    Label("Copy Prompt", systemImage: "text.quote")
                                }
                                .disabled(generation.prompt.isEmpty)

                                Divider()

                                Button(role: .destructive) {
                                    selectedGenerations = [generation.id]
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .onChange(of: sortOrder) { _, _ in
                    filteredGenerations.sort(using: sortOrder)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if !selectedGenerations.isEmpty {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label(
                            "Delete \(selectedGenerations.count) item\(selectedGenerations.count > 1 ? "s" : "")",
                            systemImage: "trash"
                        )
                    }
                    .tint(.red)
                }
            }
        }
        .confirmationDialog(
            "Delete \(selectedGenerations.count) item\(selectedGenerations.count > 1 ? "s" : "")?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteSelectedGenerations()
            }
            Button("Cancel", role: .cancel) {
                showDeleteConfirmation = false
            }
        } message: {
            Text(
                "This action cannot be undone. The selected items and their associated images will be permanently removed."
            )
        }
        .onAppear {
            cache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            updateAllGenerations()
            buildLookupCaches()
            updateFilteredGenerations()
            isLoaded = cache.isLoaded
        }
        .onChange(of: cache.isLoaded) { _, loaded in
            if loaded {
                updateAllGenerations()
                buildLookupCaches()
                updateFilteredGenerations()
                isLoaded = true
            }
        }
        .onChange(of: selectedSetType) { _, _ in
            updateFilteredGenerations()
        }
        .refreshable {
            cache.refresh(projectId: projectManager.currentProjectId, modelContext: modelContext)
        }
        .navigationTitle(labelForItem(.historyRequests))
    }

    private var mobileListView: some View {
        List {
            ForEach(filteredGenerations) { generation in
                NavigationLink(
                    value: generation.contentType == .IMAGE_2D
                        ? EnumNavigationItem.generationImage(setId: generation.setId)
                        : EnumNavigationItem.generationVideo(setId: generation.setId)
                ) {
                    MobileRequestHistoryRow(
                        generation: generation,
                        modelName: modelNameCache[generation.modelId] ?? "N/A"
                    )
                }
                .contextMenu {
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(generation.prompt, forType: .string)
                        #else
                        UIPasteboard.general.string = generation.prompt
                        #endif
                        showToast(.success("Copied to clipboard"))
                    } label: {
                        Label("Copy Prompt", systemImage: "text.quote")
                    }
                    .disabled(generation.prompt.isEmpty)

                    Button(role: .destructive) {
                        deleteGeneration(generation)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteGeneration(generation)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .onChange(of: sortOrder) { _, _ in
            filteredGenerations.sort(using: sortOrder)
        }
    }
}

private struct MobileRequestHistoryRow: View {
    let generation: Generation
    let modelName: String

    private var promptText: String {
        generation.prompt.isEmpty ? "Prompt not added" : generation.prompt
    }

    private var providerCode: String? {
        getProvider(modelId: generation.modelId).map { "\($0.providerCode)".lowercased() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(promptText)
                .font(.headline)
                .foregroundStyle(generation.prompt.isEmpty ? .secondary : .primary)
                .lineLimit(3)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 4) {
                    if let providerCode {
                        Image(providerArtworkName(code: providerCode, variant: .square))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    }
                    Text(modelName)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(generation.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.body)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Action Cell with Popover (macOS)

#if os(macOS)
/// Custom action cell view that handles popover state per row
private struct RequestsViewActionCell: View {
    let generation: Generation
    let onNavigateToDetails: (UUID, Bool) -> Void
    @State private var showPopover = false

    var body: some View {
        Button("Preview") {
            showPopover = true
        }
        .buttonStyle(BorderedButtonStyle())
        .popover(isPresented: $showPopover) {
            GenerationPreviewPopover(
                setId: generation.setId,
                generationId: generation.id,
                isVideo: generation.contentType == .VIDEO,
                isPresented: $showPopover,
                onNavigateToDetails: {
                    onNavigateToDetails(generation.setId, generation.contentType == .VIDEO)
                }
            )
        }
    }
}
#endif
