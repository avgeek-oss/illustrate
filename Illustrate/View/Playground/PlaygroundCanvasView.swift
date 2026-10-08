// MARK: - PlaygroundCanvasView.swift

// Main view for Flow Canvas
//
// PlaygroundCanvasView is similar to AgentCanvasView but for
// exploratory, interactive generation rather than workflows.
//
// ## Key Differences from Agents
// - Cards represent individual generations (not workflow steps)
// - Links are visual only (no data flow)
// - Parent-child relationships for iteration history
// - Generation popover for quick image/video creation
//
// ## Features
// - Create, rename, delete Flow Canvas
// - Flow Canvas with zoom/pan
// - Add new generation cards
// - Iterate from existing cards
// - Combine images to video
//
// ## Performance
// Cards and links are fetched on-demand when a Flow Canvas is selected rather
// than using @Query for all records. This prevents memory issues when rapidly
// navigating between Flow Canvases. The fetch task is tracked and cancelled when
// switching Flow Canvases to avoid stale updates and resource leaks.

import AvgeekDesignSystem
import IllustrateProviders
import KeychainSwift
import OSLog
import SwiftData
import SwiftUI

/// Configuration for the generation popover.
struct GenerationPopoverConfig: Identifiable {
    let id = UUID()
    let generationType: PlaygroundCardType
    let position: CGPoint
    let parentCard: PlaygroundCard?
    let parentCards: [PlaygroundCard]
    let isCombineToVideo: Bool
}

/// Main container view for interactive Flow Canvas.
struct PlaygroundCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var queueManager: QueueManager

    private let keychain: KeychainSwift = {
        let kc = KeychainSwift()
        kc.accessGroup = TEAM_KEYCHAIN_AG
        kc.synchronizable = true
        return kc
    }()

    @Query(sort: \Playground.createdAt, order: .reverse) private var allPlaygrounds: [Playground]
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    @State private var cardsForPlayground: [PlaygroundCard] = []
    @State private var linksForPlayground: [PlaygroundLink] = []
    @State private var playgroundFetchTask: Task<Void, Never>?

    @State private var selectedPlayground: Playground?
    @State private var showCreateSheet = false
    @State private var newPlaygroundName = ""
    @State private var showRenameSheet = false
    @State private var renamePlaygroundName = ""
    @State private var playgroundToRename: Playground?
    @State private var showDuplicateSheet = false
    @State private var duplicatePlaygroundName = ""
    @State private var playgroundToDuplicate: Playground?
    @State private var canvasScale: CGFloat = 1.0
    @State private var canvasOffset: CGPoint = .zero
    @State private var canvasResetTrigger = false
    @State private var selectedCardIds: Set<UUID> = []
    @State private var isLocked = false
    @State private var showGuide = false
    @State private var previewCard: PlaygroundCard?

    /// Generation popover state
    @State private var generationPopoverConfig: GenerationPopoverConfig?

    @State private var playgrounds: [Playground] = []

    private func updatePlaygrounds() {
        playgrounds = filteredAndSorted(allPlaygrounds, for: projectManager.currentProjectId)
    }

    private var lastSelectedPlaygroundKey: String {
        "lastSelectedPlayground_\(projectManager.currentProjectId.uuidString)"
    }

    private var cardsForSelectedPlayground: [PlaygroundCard] {
        cardsForPlayground
    }

    private var linksForSelectedPlayground: [PlaygroundLink] {
        linksForPlayground
    }

    private var providerKeysForProject: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    var body: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            playgroundsSidebar
                .frame(width: 240)

            Divider()

            canvasArea
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        .navigationTitle("Flow Canvas")
        .sheet(isPresented: $showCreateSheet) {
            createPlaygroundSheet
        }
        .sheet(isPresented: $showRenameSheet) {
            renamePlaygroundSheet
        }
        .sheet(isPresented: $showDuplicateSheet) {
            duplicatePlaygroundSheet
        }
        .sheet(item: $generationPopoverConfig) { config in
            GenerationPopoverView(
                isPresented: Binding(
                    get: { generationPopoverConfig != nil },
                    set: { if !$0 { generationPopoverConfig = nil } }
                ),
                generationType: config.generationType,
                position: config.position,
                parentCard: config.parentCard,
                parentCards: config.parentCards,
                isCombineToVideo: config.isCombineToVideo,
                providerKeys: providerKeysForProject,
                onGenerate: { type, position, genConfig in
                    createAndSubmitGeneration(type: type, position: position, config: genConfig)
                }
            )
        }
        .sheet(item: $previewCard) { card in
            if let genId = card.generationId {
                ExpandedImageView(
                    imageName: genId.uuidString,
                    isPresented: Binding(
                        get: { previewCard != nil },
                        set: { if !$0 { previewCard = nil } }
                    )
                )
            }
        }
        .onChange(of: selectedPlayground) { oldPlayground, newPlayground in
            restoreCanvasState(from: newPlayground, oldPlayground: oldPlayground)
            if let newPlayground {
                UserDefaults.standard.set(newPlayground.id.uuidString, forKey: lastSelectedPlaygroundKey)
            }
            fetchCardsAndLinksForPlayground(newPlayground)
        }
        .onDisappear {
            saveCanvasState()
            playgroundFetchTask?.cancel()
            playgroundFetchTask = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                saveCanvasState()
            }
        }
        .onAppear {
            providerKeysCache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            updatePlaygrounds()
            restoreLastSelectedPlayground()
        }
        .onChange(of: allPlaygrounds) { _, _ in updatePlaygrounds() }
        .onChange(of: projectManager.currentProjectId) { _, _ in updatePlaygrounds() }
        #else
        NavigationSplitView {
            playgroundsSidebar
        } detail: {
            canvasArea
        }
        .navigationTitle("Flow Canvas")
        .sheet(isPresented: $showCreateSheet) {
            createPlaygroundSheet
        }
        .sheet(isPresented: $showRenameSheet) {
            renamePlaygroundSheet
        }
        .sheet(isPresented: $showDuplicateSheet) {
            duplicatePlaygroundSheet
        }
        .sheet(item: $generationPopoverConfig) { config in
            GenerationPopoverView(
                isPresented: Binding(
                    get: { generationPopoverConfig != nil },
                    set: { if !$0 { generationPopoverConfig = nil } }
                ),
                generationType: config.generationType,
                position: config.position,
                parentCard: config.parentCard,
                parentCards: config.parentCards,
                isCombineToVideo: config.isCombineToVideo,
                providerKeys: providerKeysForProject,
                onGenerate: { type, position, genConfig in
                    createAndSubmitGeneration(type: type, position: position, config: genConfig)
                }
            )
        }
        .fullScreenCover(item: $previewCard) { card in
            if let genId = card.generationId {
                ExpandedImageView(
                    imageName: genId.uuidString,
                    isPresented: Binding(
                        get: { previewCard != nil },
                        set: { if !$0 { previewCard = nil } }
                    )
                )
            }
        }
        .onChange(of: selectedPlayground) { oldPlayground, newPlayground in
            restoreCanvasState(from: newPlayground, oldPlayground: oldPlayground)
            if let newPlayground {
                UserDefaults.standard.set(newPlayground.id.uuidString, forKey: lastSelectedPlaygroundKey)
            }
            fetchCardsAndLinksForPlayground(newPlayground)
        }
        .onDisappear {
            saveCanvasState()
            playgroundFetchTask?.cancel()
            playgroundFetchTask = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                saveCanvasState()
            }
        }
        .onAppear {
            providerKeysCache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            updatePlaygrounds()
            restoreLastSelectedPlayground()
        }
        .onChange(of: allPlaygrounds) { _, _ in updatePlaygrounds() }
        .onChange(of: projectManager.currentProjectId) { _, _ in updatePlaygrounds() }
        #endif
    }

    // MARK: - Sidebar

    private var playgroundsSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Flow Canvas")
                    .font(.headline)
                Spacer()
                Button {
                    newPlaygroundName = ""
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create new playground")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if playgrounds.isEmpty {
                emptyPlaygroundsList
            } else {
                playgroundsList
            }
        }
        .background(tertiarySystemFill)
    }

    private var emptyPlaygroundsList: some View {
        AvgeekEmptyStateView(
            icon: "point.topleft.down.to.point.bottomright.curvepath",
            title: "No playground canvases yet",
            message: "Create a playground canvas to start generating images and videos interactively.",
            buttonTitle: "Create Flow Canvas"
        ) {
            newPlaygroundName = ""
            showCreateSheet = true
        }
    }

    private var playgroundsList: some View {
        List(selection: $selectedPlayground) {
            ForEach(playgrounds) { playground in
                PinnableRowView(
                    item: playground,
                    onRename: {
                        playgroundToRename = playground
                        renamePlaygroundName = playground.name
                        showRenameSheet = true
                    },
                    onTogglePin: {
                        togglePin(playground)
                    },
                    onDuplicate: {
                        playgroundToDuplicate = playground
                        duplicatePlaygroundName = "\(playground.name) (Copy)"
                        showDuplicateSheet = true
                    },
                    onDelete: {
                        deletePlayground(playground)
                    }
                )
                .tag(playground)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Canvas Area

    private var canvasArea: some View {
        GeometryReader { geometry in
            if geometry.size.width < canvasMinWidth {
                ExpandWindowView()
            } else {
                Group {
                    if let playground = selectedPlayground {
                        VStack(spacing: 0) {
                            HStack {
                                Text(playground.name)
                                    .font(.headline)
                                Spacer()

                                guideButton
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(tertiarySystemFill)

                            Divider()

                            PlaygroundFlowCanvasView(
                                currentScale: $canvasScale,
                                resetTrigger: $canvasResetTrigger,
                                currentOffset: $canvasOffset,
                                flowCanvasId: playground.id,
                                cards: cardsForSelectedPlayground,
                                links: linksForSelectedPlayground,
                                selectedCardIds: $selectedCardIds,
                                isLocked: isLocked,
                                onCardMove: { card, newPosition in
                                    moveCard(card, to: newPosition)
                                },
                                onCardDelete: { card in
                                    deleteCard(card)
                                },
                                onGenerateImage: { position in
                                    generationPopoverConfig = GenerationPopoverConfig(
                                        generationType: .IMAGE,
                                        position: position,
                                        parentCard: nil,
                                        parentCards: [],
                                        isCombineToVideo: false
                                    )
                                },
                                onGenerateVideo: { position in
                                    generationPopoverConfig = GenerationPopoverConfig(
                                        generationType: .VIDEO,
                                        position: position,
                                        parentCard: nil,
                                        parentCards: [],
                                        isCombineToVideo: false
                                    )
                                },
                                onEditImage: { card in
                                    generationPopoverConfig = GenerationPopoverConfig(
                                        generationType: .IMAGE,
                                        position: CGPoint(
                                            x: card.positionX,
                                            y: card.positionY + playgroundCardHeight + playgroundCardSpacing
                                        ),
                                        parentCard: card,
                                        parentCards: [],
                                        isCombineToVideo: false
                                    )
                                },
                                onCreateVideoFromImage: { card in
                                    generationPopoverConfig = GenerationPopoverConfig(
                                        generationType: .VIDEO,
                                        position: CGPoint(
                                            x: card.positionX,
                                            y: card.positionY + playgroundCardHeight + playgroundCardSpacing
                                        ),
                                        parentCard: card,
                                        parentCards: [],
                                        isCombineToVideo: false
                                    )
                                },
                                onEditWithMultipleImages: { cards in
                                    guard let lastCard = cards.last else { return }
                                    generationPopoverConfig = GenerationPopoverConfig(
                                        generationType: .IMAGE,
                                        position: CGPoint(
                                            x: lastCard.positionX,
                                            y: lastCard.positionY + playgroundCardHeight + playgroundCardSpacing
                                        ),
                                        parentCard: nil,
                                        parentCards: cards,
                                        isCombineToVideo: false
                                    )
                                },
                                onCombineToVideo: { cards in
                                    guard cards.count == 2, let lastCard = cards.last else { return }
                                    generationPopoverConfig = GenerationPopoverConfig(
                                        generationType: .VIDEO,
                                        position: CGPoint(
                                            x: lastCard.positionX,
                                            y: lastCard.positionY + playgroundCardHeight + playgroundCardSpacing
                                        ),
                                        parentCard: nil,
                                        parentCards: cards,
                                        isCombineToVideo: true
                                    )
                                },
                                onTidyUp: {
                                    tidyUpCards()
                                },
                                canTidyUp: !cardsForSelectedPlayground.isEmpty,
                                onToggleLock: {
                                    isLocked.toggle()
                                    saveCanvasState()
                                },
                                onRegenerate: { card in
                                    regenerateCard(card)
                                },
                                onDuplicate: { card in
                                    duplicateCard(card)
                                },
                                onShowPreview: { card in
                                    previewCard = card
                                }
                            )
                            .clipped()
                        }
                    } else {
                        emptyCanvasState
                    }
                }
            }
        }
    }

    private var emptyCanvasState: some View {
        AvgeekEmptyStateView(
            icon: "point.topleft.down.to.point.bottomright.curvepath",
            title: "Select a playground",
            message: "Choose a playground from the sidebar or create a new one to start generating."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Guide Button

    private var guideButton: some View {
        GuidePopover(
            title: "Flow Canvas Guide",
            sections: [
                GuideSection(
                    title: "What is Flow Canvas?",
                    content: "Flow Canvas is an interactive canvas for quick image and video generation. Generate content directly on the canvas and iterate by editing generated images."
                ),
                GuideSection(
                    title: "Quick Reference",
                    items: [
                        GuideItem(
                            icon: "plus.square",
                            text: "Right-click on the canvas to generate a new image or video."
                        ),
                        GuideItem(
                            icon: "pencil",
                            text: "Right-click on a generated image to edit it and create a new iteration."
                        ),
                        GuideItem(icon: "hand.draw", text: "Drag to pan the canvas. Cards can be moved by dragging."),
                        GuideItem(icon: "plus.magnifyingglass", text: "Use ⌘ + scroll to zoom in or out."),
                    ]
                ),
            ],
            isPresented: $showGuide
        )
    }

    // MARK: - Sheets

    private var createPlaygroundSheet: some View {
        NameInputSheet(
            title: "Create New Canvas",
            placeholder: "Canvas Name",
            actionTitle: "Create",
            name: $newPlaygroundName,
            isPresented: $showCreateSheet,
            onAction: createPlayground
        )
    }

    private var renamePlaygroundSheet: some View {
        NameInputSheet(
            title: "Rename Canvas",
            placeholder: "Canvas Name",
            actionTitle: "Rename",
            name: $renamePlaygroundName,
            isPresented: $showRenameSheet,
            onAction: renamePlayground,
            onCancel: { playgroundToRename = nil }
        )
    }

    private var duplicatePlaygroundSheet: some View {
        NameInputSheet(
            title: "Duplicate Canvas",
            placeholder: "Canvas Name",
            actionTitle: "Duplicate",
            name: $duplicatePlaygroundName,
            isPresented: $showDuplicateSheet,
            onAction: {
                if let playground = playgroundToDuplicate {
                    duplicatePlayground(playground, name: duplicatePlaygroundName)
                }
            },
            onCancel: { playgroundToDuplicate = nil }
        )
    }

    // MARK: - Actions

    private func restoreLastSelectedPlayground() {
        guard selectedPlayground == nil else { return }

        if let savedId = UserDefaults.standard.string(forKey: lastSelectedPlaygroundKey),
           let uuid = UUID(uuidString: savedId),
           let playground = playgrounds.first(where: { $0.id == uuid })
        {
            selectedPlayground = playground
            restoreCanvasState(from: playground, oldPlayground: nil)
        }
    }

    private func fetchCardsAndLinksForPlayground(_ playground: Playground?) {
        playgroundFetchTask?.cancel()

        guard let playground else {
            cardsForPlayground = []
            linksForPlayground = []
            return
        }

        let flowCanvasId = playground.id

        playgroundFetchTask = Task { @MainActor in
            guard !Task.isCancelled else { return }

            var cardDescriptor = FetchDescriptor<PlaygroundCard>(
                predicate: #Predicate { $0.flowCanvasId == flowCanvasId },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            cardDescriptor.fetchLimit = 500

            var linkDescriptor = FetchDescriptor<PlaygroundLink>(
                predicate: #Predicate { $0.flowCanvasId == flowCanvasId },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            linkDescriptor.fetchLimit = 1000

            do {
                let cards = try modelContext.fetch(cardDescriptor)
                guard !Task.isCancelled else { return }

                let links = try modelContext.fetch(linkDescriptor)
                guard !Task.isCancelled else { return }

                cardsForPlayground = cards
                linksForPlayground = links
            } catch {
                AppLogger.ui
                    .error(
                        "Failed to fetch cards/links for playground: \(error.localizedDescription, privacy: .public)"
                    )
                cardsForPlayground = []
                linksForPlayground = []
            }
        }
    }

    private func createPlayground() {
        let trimmedName = newPlaygroundName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let playground = Playground(name: trimmedName, projectId: projectManager.currentProjectId)
        modelContext.insert(playground)

        do {
            try modelContext.save()
            selectedPlayground = playground
        } catch {
            AppLogger.ui.error("Failed to save playground: \(error.localizedDescription, privacy: .public)")
        }

        showCreateSheet = false
    }

    private func renamePlayground() {
        guard let playground = playgroundToRename else { return }
        let trimmedName = renamePlaygroundName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        playground.name = trimmedName

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to rename playground: \(error.localizedDescription, privacy: .public)")
        }

        showRenameSheet = false
        playgroundToRename = nil
    }

    private func togglePin(_ playground: Playground) {
        playground.isPinned.toggle()

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to toggle pin for playground: \(error.localizedDescription, privacy: .public)")
        }

        updatePlaygrounds()
    }

    private func duplicatePlayground(_ playground: Playground, name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newPlayground = Playground(name: trimmedName, projectId: playground.projectId)
        newPlayground.isPinned = false
        modelContext.insert(newPlayground)

        do {
            try modelContext.save()
            updatePlaygrounds()
            playgroundToDuplicate = nil
        } catch {
            AppLogger.data.error("Failed to duplicate playground: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deletePlayground(_ playground: Playground) {
        if selectedPlayground?.id == playground.id {
            selectedPlayground = nil
            cardsForPlayground = []
            linksForPlayground = []
        }

        modelContext.delete(playground)

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to delete playground: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func restoreCanvasState(from newPlayground: Playground?, oldPlayground: Playground?) {
        if let old = oldPlayground {
            old.canvasScale = canvasScale
            old.canvasOffsetX = canvasOffset.x
            old.canvasOffsetY = canvasOffset.y
            old.isLocked = isLocked
            try? modelContext.save()
        }

        guard let playground = newPlayground else {
            canvasScale = 1.0
            canvasOffset = .zero
            isLocked = false
            return
        }

        canvasScale = playground.canvasScale
        canvasOffset = CGPoint(x: playground.canvasOffsetX, y: playground.canvasOffsetY)
        isLocked = playground.isLocked
    }

    private func saveCanvasState() {
        guard let playground = selectedPlayground else { return }

        playground.canvasScale = canvasScale
        playground.canvasOffsetX = canvasOffset.x
        playground.canvasOffsetY = canvasOffset.y
        playground.isLocked = isLocked

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to save canvas state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func moveCard(_ card: PlaygroundCard, to newPosition: CGPoint) {
        card.position = newPosition

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to move card: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteCard(_ card: PlaygroundCard) {
        // Delete links associated with this card
        let linksToDelete = linksForSelectedPlayground.filter {
            $0.sourceCardId == card.id || $0.targetCardId == card.id
        }
        let linkIdsToDelete = Set(linksToDelete.map(\.id))

        for link in linksToDelete {
            modelContext.delete(link)
        }

        selectedCardIds.remove(card.id)
        modelContext.delete(card)

        do {
            try modelContext.save()
            cardsForPlayground.removeAll { $0.id == card.id }
            linksForPlayground.removeAll { linkIdsToDelete.contains($0.id) }
        } catch {
            AppLogger.ui.error("Failed to delete card: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Arranges cards in a tree layout with connections flowing downward.
    ///
    /// The algorithm:
    /// 1. Find root cards (cards that are not targets of any link)
    /// 2. Build a tree structure from links
    /// 3. Position cards level by level, centering children under parents
    private func tidyUpCards() {
        let cards = cardsForSelectedPlayground
        let links = linksForSelectedPlayground

        guard !cards.isEmpty else { return }

        // Build adjacency list: parent -> children
        var childrenMap: [UUID: [UUID]] = [:]
        var targetIds = Set<UUID>()

        for link in links {
            childrenMap[link.sourceCardId, default: []].append(link.targetCardId)
            targetIds.insert(link.targetCardId)
        }

        // Find root cards (not a target of any link)
        let rootCards = cards.filter { !targetIds.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }

        // If no roots found (isolated cards or cycles), use all cards as roots
        let effectiveRoots = rootCards.isEmpty ? cards.sorted { $0.createdAt < $1.createdAt } : rootCards

        // Build levels using BFS
        var levels: [[PlaygroundCard]] = []
        var visited = Set<UUID>()
        var currentLevel = effectiveRoots

        while !currentLevel.isEmpty {
            levels.append(currentLevel)
            for card in currentLevel {
                visited.insert(card.id)
            }

            var nextLevel: [PlaygroundCard] = []
            for card in currentLevel {
                let childIds = childrenMap[card.id] ?? []
                for childId in childIds {
                    if !visited.contains(childId),
                       let childCard = cards.first(where: { $0.id == childId })
                    {
                        nextLevel.append(childCard)
                        visited.insert(childId)
                    }
                }
            }
            currentLevel = nextLevel.sorted { $0.createdAt < $1.createdAt }
        }

        // Add any unvisited cards (disconnected) to the first level
        let unvisited = cards.filter { !visited.contains($0.id) }
        if !unvisited.isEmpty {
            if levels.isEmpty {
                levels.append(unvisited)
            } else {
                levels[0].append(contentsOf: unvisited)
            }
        }

        // Layout constants
        let horizontalSpacing: CGFloat = 48
        let verticalSpacing: CGFloat = playgroundCardSpacing
        let cardWidth: CGFloat = cardFixedWidth

        // Calculate positions for each level
        // First pass: calculate subtree widths
        var subtreeWidths: [UUID: CGFloat] = [:]

        func calculateSubtreeWidth(_ cardId: UUID) -> CGFloat {
            let childIds = childrenMap[cardId] ?? []
            if childIds.isEmpty {
                subtreeWidths[cardId] = cardWidth
                return cardWidth
            }

            let childrenWidth = childIds.reduce(CGFloat(0)) { sum, childId in
                sum + calculateSubtreeWidth(childId) + horizontalSpacing
            } - horizontalSpacing

            let width = max(cardWidth, childrenWidth)
            subtreeWidths[cardId] = width
            return width
        }

        for root in effectiveRoots {
            _ = calculateSubtreeWidth(root.id)
        }

        // Second pass: position cards
        var cardPositions: [UUID: CGPoint] = [:]

        func positionSubtree(_ cardId: UUID, centerX: CGFloat, y: CGFloat) {
            cardPositions[cardId] = CGPoint(x: centerX, y: y)

            let childIds = childrenMap[cardId] ?? []
            guard !childIds.isEmpty else { return }

            // Calculate total width of children
            let childrenTotalWidth = childIds.reduce(CGFloat(0)) { sum, childId in
                sum + (subtreeWidths[childId] ?? cardWidth) + horizontalSpacing
            } - horizontalSpacing

            // Position children centered under parent
            var currentX = centerX - childrenTotalWidth / 2
            let childY = y + playgroundCardHeight + verticalSpacing

            for childId in childIds {
                let childWidth = subtreeWidths[childId] ?? cardWidth
                let childCenterX = currentX + childWidth / 2
                positionSubtree(childId, centerX: childCenterX, y: childY)
                currentX += childWidth + horizontalSpacing
            }
        }

        // Position root cards
        let totalRootWidth = effectiveRoots.reduce(CGFloat(0)) { sum, card in
            sum + (subtreeWidths[card.id] ?? cardWidth) + horizontalSpacing
        } - (effectiveRoots.isEmpty ? 0 : horizontalSpacing)

        var currentRootX = -totalRootWidth / 2
        for root in effectiveRoots {
            let rootWidth = subtreeWidths[root.id] ?? cardWidth
            let rootCenterX = currentRootX + rootWidth / 2
            positionSubtree(root.id, centerX: rootCenterX, y: 0)
            currentRootX += rootWidth + horizontalSpacing
        }

        // Apply positions to cards
        for card in cards {
            if let position = cardPositions[card.id] {
                card.position = position
            }
        }

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to tidy up cards: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func createAndSubmitGeneration(type: PlaygroundCardType, position: CGPoint, config: Any) {
        guard let playground = selectedPlayground else { return }

        // Get parent card from popover config
        let parentCard = generationPopoverConfig?.parentCard
        let parentCards = generationPopoverConfig?.parentCards ?? []

        // Create the card
        let card = PlaygroundCard(
            flowCanvasId: playground.id,
            cardType: type,
            position: position,
            parentCardId: parentCard?.id
        )

        modelContext.insert(card)

        // Track new links for local state update
        var newLinks: [PlaygroundLink] = []

        // Create link if this is an edit operation (single parent)
        if let parentCard {
            let link = PlaygroundLink(
                flowCanvasId: playground.id,
                sourceCardId: parentCard.id,
                targetCardId: card.id
            )
            modelContext.insert(link)
            newLinks.append(link)
        }

        // Create links for multiple parent cards
        for pCard in parentCards {
            let link = PlaygroundLink(
                flowCanvasId: playground.id,
                sourceCardId: pCard.id,
                targetCardId: card.id
            )
            modelContext.insert(link)
            newLinks.append(link)
        }

        do {
            try modelContext.save()
            cardsForPlayground.append(card)
            linksForPlayground.append(contentsOf: newLinks)
        } catch {
            AppLogger.ui.error("Failed to save card: \(error.localizedDescription, privacy: .public)")
            return
        }

        if type == .IMAGE, let imageConfig = config as? ImageGenerationConfiguration {
            submitImageGeneration(card: card, config: imageConfig, parentCard: parentCard, parentCards: parentCards)
        } else if type == .VIDEO, let videoConfig = config as? VideoGenerationConfiguration {
            submitVideoGeneration(card: card, config: videoConfig, parentCard: parentCard, parentCards: parentCards)
        }
    }

    private func submitImageGeneration(
        card: PlaygroundCard,
        config: ImageGenerationConfiguration,
        parentCard: PlaygroundCard?,
        parentCards: [PlaygroundCard]
    ) {
        guard let providerKey = providerKeysForProject.first(where: {
            $0.providerId.uuidString == config.selectedProviderId
        }) else {
            card.status = .FAILED
            card.errorMessage = "Provider not found"
            try? modelContext.save()
            return
        }

        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else {
            card.status = .FAILED
            card.errorMessage = "Provider not found"
            try? modelContext.save()
            return
        }

        // Get provider secret from keychain
        let keychainKey = ProjectManager.keychainKey(
            projectId: projectManager.currentProjectId,
            providerId: providerKey.providerId
        )
        guard let providerSecret = keychain.get(keychainKey) else {
            card.status = .FAILED
            card.errorMessage = "Provider secret not found"
            try? modelContext.save()
            return
        }

        // Get the model to check what it supports
        let model = ProviderService.shared.models(for: .IMAGE_GENERATE)
            .first { $0.modelId.uuidString == config.selectedModelId }
        let supportsSourceImage = model?.modelParams.supportsSourceImage ?? false
        let supportsReferenceImages = model?.modelParams.supportsReferenceImages ?? false
        let defaultRefType = model?.modelParams.supportedReferenceTypes.first ?? "style"

        // Combine all parent cards
        var allParentCards: [PlaygroundCard] = []
        if let single = parentCard {
            allParentCards.append(single)
        }
        allParentCards.append(contentsOf: parentCards)

        // Determine how to use the parent images
        var clientImage: String? = nil
        var clientReferenceImages: [ReferenceImageData]? = nil

        if !allParentCards.isEmpty {
            if supportsSourceImage, supportsReferenceImages, allParentCards.count > 1 {
                // First image as source, rest as reference images
                if let firstCard = allParentCards.first,
                   let genId = firstCard.generationId,
                   let sourceImage = loadImageFromDocumentsDirectory(withName: genId.uuidString)
                {
                    clientImage = sourceImage.toBase64PNG()
                }

                // Rest as reference images
                let restCards = Array(allParentCards.dropFirst())
                var refs: [ReferenceImageData] = []
                for pCard in restCards {
                    if let genId = pCard.generationId,
                       let refImage = loadImageFromDocumentsDirectory(withName: genId.uuidString),
                       let base64 = refImage.toBase64PNG()
                    {
                        refs.append(ReferenceImageData(base64Image: base64, referenceType: defaultRefType))
                    }
                }
                if !refs.isEmpty {
                    clientReferenceImages = refs
                }
            } else if supportsSourceImage {
                // Use first image as source only
                if let firstCard = allParentCards.first,
                   let genId = firstCard.generationId,
                   let sourceImage = loadImageFromDocumentsDirectory(withName: genId.uuidString)
                {
                    clientImage = sourceImage.toBase64PNG()
                }
            } else if supportsReferenceImages {
                // Use all as reference images
                var refs: [ReferenceImageData] = []
                for pCard in allParentCards {
                    if let genId = pCard.generationId,
                       let refImage = loadImageFromDocumentsDirectory(withName: genId.uuidString),
                       let base64 = refImage.toBase64PNG()
                    {
                        refs.append(ReferenceImageData(base64Image: base64, referenceType: defaultRefType))
                    }
                }
                if !refs.isEmpty {
                    clientReferenceImages = refs
                }
            }
        }

        // Add additional reference images from config (user-added)
        if !config.referenceImages.isEmpty {
            let additionalRefs = config.referenceImages.compactMap { refConfig -> ReferenceImageData? in
                let imageName = "imggen_ref_\(card.id.uuidString)_\(refConfig.id.uuidString)"
                if let image = loadImageFromDocumentsDirectory(withName: imageName),
                   let base64 = image.toBase64PNG()
                {
                    return ReferenceImageData(base64Image: base64, referenceType: refConfig.referenceType)
                }
                return nil
            }
            if clientReferenceImages == nil {
                clientReferenceImages = additionalRefs
            } else {
                clientReferenceImages?.append(contentsOf: additionalRefs)
            }
        }

        let request = ImageGenerationRequest(
            modelId: config.selectedModelId,
            prompt: config.prompt,
            searchPrompt: config.searchPrompt.isEmpty ? nil : config.searchPrompt,
            negativePrompt: config.negativePrompt.isEmpty ? nil : config.negativePrompt,
            variant: config.selectedVariant,
            quality: config.selectedQuality,
            style: config.selectedStyle,
            dimensions: config.selectedDimensions,
            clientImage: clientImage,
            clientReferenceImages: clientReferenceImages,
            providerKey: providerKeyInfo,
            providerSecret: providerSecret,
            resolution: config.selectedResolution.isEmpty ? nil : config.selectedResolution,
            guidance: config.guidanceValue,
            seed: config.seedValue.isEmpty ? nil : Int(config.seedValue),
            safetyTolerance: Int(config.safetyValue),
            promptEnhance: config.modelPromptEnhance,
            inputFidelity: config.selectedInputFidelity.isEmpty ? nil : config.selectedInputFidelity,
            moderation: config.selectedModeration.isEmpty ? nil : config.selectedModeration,
            growMask: Int(config.growMaskValue),
            selectedTools: config.selectedTools.isEmpty ? nil : Array(config.selectedTools),
            personGeneration: config.personGeneration.isEmpty ? nil : config.personGeneration
        )

        // Store config in card
        card.imageGenerationConfiguration = config

        Task {
            let queueItem = queueManager.submitImageGeneration(
                request: request,
                modelContext: modelContext,
                source: .FLOW_CANVAS
            )

            await MainActor.run {
                card.queueItemId = queueItem.id
                try? modelContext.save()
            }

            // Monitor queue item for completion
            await monitorQueueItem(queueItem, for: card)
        }
    }

    private func submitVideoGeneration(
        card: PlaygroundCard,
        config: VideoGenerationConfiguration,
        parentCard: PlaygroundCard?,
        parentCards: [PlaygroundCard]
    ) {
        guard let providerKey = providerKeysForProject.first(where: {
            $0.providerId.uuidString == config.selectedProviderId
        }) else {
            card.status = .FAILED
            card.errorMessage = "Provider not found"
            try? modelContext.save()
            return
        }

        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else {
            card.status = .FAILED
            card.errorMessage = "Provider not found"
            try? modelContext.save()
            return
        }

        // Get provider secret from keychain
        let keychainKey = ProjectManager.keychainKey(
            projectId: projectManager.currentProjectId,
            providerId: providerKey.providerId
        )
        guard let providerSecret = keychain.get(keychainKey) else {
            card.status = .FAILED
            card.errorMessage = "Provider secret not found"
            try? modelContext.save()
            return
        }

        // Get source image (first frame) - from single parent or first of multiple parents
        var clientImage: String? = nil
        if let parentCard,
           let parentGenId = parentCard.generationId,
           let sourceImage = loadImageFromDocumentsDirectory(withName: parentGenId.uuidString)
        {
            clientImage = sourceImage.toBase64PNG()
        } else if let firstParent = parentCards.first,
                  let parentGenId = firstParent.generationId,
                  let sourceImage = loadImageFromDocumentsDirectory(withName: parentGenId.uuidString)
        {
            clientImage = sourceImage.toBase64PNG()
        }

        // Get last frame image (for combine to video with 2 images)
        var clientLastFrame: String? = nil
        if parentCards.count == 2,
           let lastParent = parentCards.last,
           let lastGenId = lastParent.generationId,
           let lastImage = loadImageFromDocumentsDirectory(withName: lastGenId.uuidString)
        {
            clientLastFrame = lastImage.toBase64PNG()
        }

        let request = VideoGenerationRequest(
            modelId: config.selectedModelId,
            prompt: config.prompt.isEmpty ? nil : config.prompt,
            negativePrompt: config.negativePrompt.isEmpty ? nil : config.negativePrompt,
            dimensions: config.selectedDimensions,
            clientImage: clientImage,
            clientLastFrame: clientLastFrame,
            providerKey: providerKeyInfo,
            providerSecret: providerSecret,
            durationSeconds: config.durationSeconds,
            resolution: config.selectedResolution.isEmpty ? nil : config.selectedResolution,
            fps: config.selectedFPS,
            generateAudio: config.generateAudio,
            guidance: config.guidanceValue,
            seed: config.seedValue.isEmpty ? nil : Int(config.seedValue),
            safetyTolerance: Int(config.safetyValue),
            promptEnhance: config.modelPromptEnhance
        )

        // Store config in card
        card.videoGenerationConfiguration = config

        Task {
            let queueItem = queueManager.submitVideoGeneration(
                request: request,
                modelContext: modelContext,
                source: .FLOW_CANVAS
            )

            await MainActor.run {
                card.queueItemId = queueItem.id
                try? modelContext.save()
            }

            // Monitor queue item for completion
            await monitorQueueItem(queueItem, for: card)
        }
    }

    @MainActor
    private func monitorQueueItem(_ queueItem: QueueItem, for card: PlaygroundCard) async {
        // Poll for status changes
        while queueItem.status == .IN_PROGRESS {
            try? await Task.sleep(for: .milliseconds(500))
        }

        if queueItem.status == .SUCCESSFUL {
            card.status = .GENERATED
            if let resultSetId = queueItem.resultSetId {
                // Find the generation from the result set using a direct fetch
                let descriptor = FetchDescriptor<Generation>(predicate: #Predicate { $0.setId == resultSetId })
                if let generation = try? modelContext.fetch(descriptor).first {
                    card.generationId = generation.id
                }
            } else if let resultVideoSetId = queueItem.resultVideoSetId {
                let descriptor = FetchDescriptor<Generation>(predicate: #Predicate { $0.setId == resultVideoSetId })
                if let generation = try? modelContext.fetch(descriptor).first {
                    card.generationId = generation.id
                }
            }
        } else {
            card.status = .FAILED
            card.errorMessage = queueItem.errorMessage ?? "Generation failed"
        }

        try? modelContext.save()
    }

    // MARK: - Regenerate Card

    /// Regenerates the card using its stored configuration.
    /// Resets the card status and resubmits the generation request.
    private func regenerateCard(_ card: PlaygroundCard) {
        // Reset card state
        card.status = .PROCESSING
        card.generationId = nil
        card.errorMessage = nil
        card.queueItemId = nil

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to reset card for regeneration: \(error.localizedDescription, privacy: .public)")
            return
        }

        // Get parent card for reference image (from incoming links)
        let incomingLink = linksForSelectedPlayground.first { $0.targetCardId == card.id }
        let parentCard = incomingLink.flatMap { link in
            cardsForSelectedPlayground.first { $0.id == link.sourceCardId }
        }

        // Get all parent cards (for multi-reference generation)
        let allIncomingLinks = linksForSelectedPlayground.filter { $0.targetCardId == card.id }
        let parentCards = allIncomingLinks.compactMap { link in
            cardsForSelectedPlayground.first { $0.id == link.sourceCardId }
        }

        // Resubmit generation based on type
        if card.cardType == .IMAGE {
            let config = card.imageGenerationConfiguration
            submitImageGeneration(
                card: card,
                config: config,
                parentCard: parentCards.count == 1 ? parentCard : nil,
                parentCards: parentCards.count > 1 ? parentCards : []
            )
        } else {
            let config = card.videoGenerationConfiguration
            submitVideoGeneration(
                card: card,
                config: config,
                parentCard: parentCards.count == 1 ? parentCard : nil,
                parentCards: parentCards.count > 1 ? parentCards : []
            )
        }
    }

    // MARK: - Duplicate Card

    /// Creates a duplicate of the card with the same generation ID but no links.
    /// The duplicate is placed slightly offset from the original.
    private func duplicateCard(_ card: PlaygroundCard) {
        guard let playground = selectedPlayground else { return }

        // Create new card with same type and offset position
        let newCard = PlaygroundCard(
            flowCanvasId: playground.id,
            cardType: card.cardType,
            position: CGPoint(
                x: card.positionX + 24,
                y: card.positionY + 24
            ),
            parentCardId: nil // No parent link for duplicates
        )

        // Copy generation data if available
        if let genId = card.generationId {
            newCard.generationId = genId
            newCard.status = .GENERATED
        } else {
            newCard.status = card.status
        }

        // Copy configuration
        newCard.configurationData = card.configurationData
        newCard.errorMessage = card.errorMessage

        modelContext.insert(newCard)

        do {
            try modelContext.save()
            cardsForPlayground.append(newCard)
            selectedCardIds = [newCard.id]
        } catch {
            AppLogger.ui.error("Failed to duplicate card: \(error.localizedDescription, privacy: .public)")
        }
    }
}
