// MARK: - AgentCanvasView.swift

// Main view for building and running agent workflows.
//
// AgentCanvasView is the container for the agent workflow editor.
// It provides:
// - Agent selection and management (create, rename, delete)
// - Canvas for workflow building (via FlowCanvasView)
// - Agent execution controls (run, reset)
// - Card configuration (via card selection callbacks)
//
// ## Agent Management
// - List of agents for current project
// - Create new agents with default Start card
// - Rename and delete agents
// - Remember last selected agent per project
//
// ## Canvas Integration
// Embeds FlowCanvasView and provides callbacks for:
// - Card movement and deletion
// - Link creation and deletion
// - Card selection for configuration
// - Tidy up (auto-layout)
//
// ## Agent Execution
// Uses AgentRunService to execute the workflow:
// 1. Get execution order from AgentGraphService
// 2. Execute cards sequentially
// 3. Track run status and errors
//
// ## Performance
// Cards and links are fetched on-demand when an agent is selected rather than
// using @Query for all records. This prevents memory issues when rapidly
// navigating between agents. The fetch task is tracked and cancelled when
// switching agents to avoid stale updates and resource leaks.

import AvgeekDesignSystem
import OSLog
import SwiftData
import SwiftUI

/// Container view for agent workflow building and execution.
struct AgentCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var queueManager: QueueManager
    @Query(sort: \Agent.createdAt, order: .reverse) private var allAgents: [Agent]
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    @State private var cardsForAgent: [AgentCard] = []
    @State private var linksForAgent: [CardLink] = []
    @State private var agentFetchTask: Task<Void, Never>?

    @State private var selectedAgent: Agent?
    @State private var showCreateSheet = false
    @State private var newAgentName = ""
    @State private var showRenameSheet = false
    @State private var renameAgentName = ""
    @State private var agentToRename: Agent?
    @State private var showDuplicateSheet = false
    @State private var duplicateAgentName = ""
    @State private var agentToDuplicate: Agent?
    @State private var canvasScale: CGFloat = 1.0
    @State private var canvasOffset: CGPoint = .zero
    @State private var canvasResetTrigger = false
    @State private var selectedCardIds: Set<UUID> = []
    @State private var runningAgentId: UUID?
    @State private var isLocked = false
    @State private var showGuide = false
    @State private var showRunGuide = false
    @State private var agents: [Agent] = []
    @State private var agentToDelete: Agent?
    @State private var showDeleteConfirmation = false
    @State private var showAgentBuilderIntro = false
    @AppStorage("hasSeenAgentBuilderFirstSessionGuide") private var hasSeenAgentBuilderFirstSessionGuide = false

    /// Whether the currently selected agent is running
    private var isRunning: Bool {
        guard let agentId = selectedAgent?.id else { return false }
        return runningAgentId == agentId
    }

    private let graphService = AgentGraphService.shared

    private func updateAgents() {
        agents = filteredAndSorted(allAgents, for: projectManager.currentProjectId)
    }

    private var lastSelectedAgentKey: String {
        "lastSelectedAgent_\(projectManager.currentProjectId.uuidString)"
    }

    private var cardsForSelectedAgent: [AgentCard] {
        cardsForAgent
    }

    private var linksForSelectedAgent: [CardLink] {
        linksForAgent
    }

    private var providerKeysForProject: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    private var cardsBinding: Binding<[AgentCard]> {
        Binding(
            get: { cardsForSelectedAgent },
            set: { _ in }
        )
    }

    private var linksBinding: Binding<[CardLink]> {
        Binding(
            get: { linksForSelectedAgent },
            set: { _ in }
        )
    }

    private var selectedCardIdsBinding: Binding<Set<UUID>> {
        Binding(
            get: { selectedCardIds },
            set: { newIds in
                selectedCardIds = newIds
            }
        )
    }

    private var selectedCard: AgentCard? {
        if selectedCardIds.count == 1, let id = selectedCardIds.first {
            return cardsForSelectedAgent.first { $0.id == id }
        }
        return nil
    }

    private var allCardsConnected: Bool {
        let cards = cardsForSelectedAgent
        guard cards.count > 1 else { return cards.count == 1 }

        let connectedCards = getConnectedCardsInOrder()
        return connectedCards.count == cards.count
    }

    private var hasRunState: Bool {
        cardsForSelectedAgent.contains { card in
            card.isErrored || card.errorMessage != nil || (card.cardType == .output && card.generationId != nil)
        }
    }

    // MARK: - Run Validation

    private var hasStartCard: Bool {
        cardsForSelectedAgent.contains { $0.cardType == .start }
    }

    private var hasOutputCard: Bool {
        cardsForSelectedAgent.contains { $0.cardType == .output }
    }

    private var allProcessCardsValid: Bool {
        cardsForSelectedAgent
            .filter { $0.cardType == .process }
            .allSatisfy { card in
                switch card.processCardType {
                case .imageGeneration:
                    let config = card.imageGenerationConfiguration
                    return !config.selectedProviderId.isEmpty
                        && !config.selectedModelId.isEmpty
                case .videoGeneration:
                    let config = card.videoGenerationConfiguration
                    return !config.selectedProviderId.isEmpty
                        && !config.selectedModelId.isEmpty
                case .none:
                    return false
                }
            }
    }

    private var canRun: Bool {
        hasStartCard && hasOutputCard && allCardsConnected && allProcessCardsValid && !isRunning
    }

    private func getConnectedCardsInOrder() -> [AgentCard] {
        let cards = cardsForSelectedAgent
        let links = linksForSelectedAgent

        guard let startCard = cards.first(where: { $0.cardType == .start }) else {
            return []
        }

        var orderedCards: [AgentCard] = [startCard]
        var currentCardId = startCard.id
        var visitedIds = Set<UUID>([startCard.id])

        while let link = links.first(where: { $0.sourceCardId == currentCardId }) {
            guard !visitedIds.contains(link.targetCardId),
                  let nextCard = cards.first(where: { $0.id == link.targetCardId })
            else {
                break
            }

            orderedCards.append(nextCard)
            visitedIds.insert(nextCard.id)
            currentCardId = nextCard.id
        }

        return orderedCards
    }

    var body: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            agentsSidebar
                .frame(width: 240)

            Divider()

            canvasArea
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        .navigationTitle("Agent Builder")
        .sheet(isPresented: $showCreateSheet) {
            createAgentSheet
        }
        .sheet(isPresented: $showRenameSheet) {
            renameAgentSheet
        }
        .sheet(isPresented: $showDuplicateSheet) {
            duplicateAgentSheet
        }
        .sheet(isPresented: $showAgentBuilderIntro) {
            AgentBuilderIntroSheet(isPresented: $showAgentBuilderIntro)
        }
        .onChange(of: selectedAgent) { oldAgent, newAgent in
            restoreCanvasState(from: newAgent, oldAgent: oldAgent)
            if let newAgent {
                UserDefaults.standard.set(newAgent.id.uuidString, forKey: lastSelectedAgentKey)
            }
            fetchCardsAndLinksForAgent(newAgent)
        }
        .onDisappear {
            saveCanvasState()
            agentFetchTask?.cancel()
            agentFetchTask = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                saveCanvasState()
            }
        }
        .onAppear {
            providerKeysCache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            updateAgents()
            restoreLastSelectedAgent()
        }
        .onChange(of: allAgents) { _, _ in updateAgents() }
        .onChange(of: projectManager.currentProjectId) { _, _ in updateAgents() }
        .onChange(of: agents) { _, newAgents in
            if selectedAgent == nil, !newAgents.isEmpty {
                restoreLastSelectedAgent()
            }
        }
        #else
        NavigationSplitView {
            agentsSidebar
        } detail: {
            canvasArea
        }
        .navigationTitle("Agent Builder")
        .sheet(isPresented: $showCreateSheet) {
            createAgentSheet
        }
        .sheet(isPresented: $showRenameSheet) {
            renameAgentSheet
        }
        .sheet(isPresented: $showDuplicateSheet) {
            duplicateAgentSheet
        }
        .sheet(isPresented: $showAgentBuilderIntro) {
            AgentBuilderIntroSheet(isPresented: $showAgentBuilderIntro)
        }
        .onChange(of: selectedAgent) { oldAgent, newAgent in
            restoreCanvasState(from: newAgent, oldAgent: oldAgent)
            if let newAgent {
                UserDefaults.standard.set(newAgent.id.uuidString, forKey: lastSelectedAgentKey)
            }
            fetchCardsAndLinksForAgent(newAgent)
        }
        .onDisappear {
            saveCanvasState()
            agentFetchTask?.cancel()
            agentFetchTask = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                saveCanvasState()
            }
        }
        .onAppear {
            providerKeysCache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            updateAgents()
            restoreLastSelectedAgent()
        }
        .onChange(of: allAgents) { _, _ in updateAgents() }
        .onChange(of: projectManager.currentProjectId) { _, _ in updateAgents() }
        .onChange(of: agents) { _, newAgents in
            if selectedAgent == nil, !newAgents.isEmpty {
                restoreLastSelectedAgent()
            }
        }
        #endif
    }

    private var agentsSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Agents")
                    .font(.headline)
                Spacer()
                Button {
                    newAgentName = ""
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create new agent")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if agents.isEmpty {
                emptyAgentsList
            } else {
                agentsList
            }
        }
        .background(tertiarySystemFill)
    }

    private var emptyAgentsList: some View {
        AvgeekEmptyStateView(
            icon: "square.and.pencil",
            title: "No agents yet",
            message: "Create an agent to get started with your workflow.",
            buttonTitle: "Create Agent"
        ) {
            newAgentName = ""
            showCreateSheet = true
        }
    }

    private var agentsList: some View {
        List(selection: $selectedAgent) {
            ForEach(agents) { agent in
                PinnableRowView(
                    item: agent,
                    onRename: {
                        agentToRename = agent
                        renameAgentName = agent.name
                        showRenameSheet = true
                    },
                    onTogglePin: {
                        togglePin(agent)
                    },
                    onDuplicate: {
                        agentToDuplicate = agent
                        duplicateAgentName = "\(agent.name) (Copy)"
                        showDuplicateSheet = true
                    },
                    onDelete: {
                        agentToDelete = agent
                        showDeleteConfirmation = true
                    }
                )
                .tag(agent)
            }
        }
        .listStyle(.sidebar)
        .alert("Delete Agent?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { agentToDelete = nil }
            Button("Delete", role: .destructive) {
                if let agent = agentToDelete { deleteAgent(agent); agentToDelete = nil }
            }
        } message: {
            Text("This agent and all its cards will be permanently deleted. This action cannot be undone.")
        }
    }

    private var canvasArea: some View {
        GeometryReader { geometry in
            if geometry.size.width < canvasMinWidth {
                ExpandWindowView()
            } else {
                Group {
                    if let agent = selectedAgent {
                        VStack(spacing: 0) {
                            HStack {
                                Text(agent.name)
                                    .font(.headline)
                                Spacer()

                                guideButton
                                runButton
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(tertiarySystemFill)

                            Divider()

                            FlowCanvasView(
                                currentScale: $canvasScale,
                                resetTrigger: $canvasResetTrigger,
                                currentOffset: $canvasOffset,
                                cards: cardsBinding,
                                links: linksBinding,
                                selectedCardIds: selectedCardIdsBinding,
                                agentId: agent.id,
                                onCardMove: { card, newPosition in
                                    moveCard(card, to: newPosition)
                                },
                                onCardsMove: { cards, translation in
                                    moveCards(cards, by: translation)
                                },
                                onAddCard: { cardType, position in
                                    addCard(type: cardType, at: position)
                                },
                                onAddOutputCard: { position in
                                    addOutputCard(at: position)
                                },
                                onLinkCreate: { sourceId, targetId in
                                    createLink(from: sourceId, to: targetId)
                                },
                                onLinkDelete: { linkId in
                                    deleteLink(linkId)
                                },
                                onCardDelete: { card in
                                    deleteCard(card)
                                },
                                onCardDuplicate: { card in
                                    duplicateCard(card)
                                },
                                onDisconnectAll: { card in
                                    disconnectAll(from: card)
                                },
                                onTidyUp: {
                                    tidyUpCards()
                                },
                                onResetRunState: {
                                    resetRunState()
                                },
                                canTidyUp: allCardsConnected,
                                canResetRunState: hasRunState,
                                isAgentRunning: isRunning,
                                isLocked: isLocked,
                                onToggleLock: {
                                    isLocked.toggle()
                                    saveCanvasState()
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
            icon: "cpu",
            title: "Select an agent",
            message: "Choose an agent from the sidebar or create a new one to start working on the canvas."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var guideButton: some View {
        GuidePopover(
            title: "Agent Builder Guide",
            sections: [
                GuideSection(
                    title: "What is Agent Builder?",
                    content: "Agent Builder helps generate multi-shot iterations in a single click which are reused everyday."
                ),
                GuideSection(
                    title: "How to Use",
                    content: "Agent Builder needs Start and Output cards to function. There can be multiple intermediary cards attached between them. All cards need to be linked to run the agent. Use {{input}} in a process prompt to insert the previous card's input or prompt text."
                ),
                GuideSection(
                    title: "Quick Reference",
                    items: [
                        GuideItem(
                            icon: "plus.square",
                            text: "To add a card, use the right-click context menu > Add card."
                        ),
                        GuideItem(
                            icon: "trash",
                            text: "To remove a card, select the card and right-click context menu > Delete card."
                        ),
                        GuideItem(
                            icon: "link",
                            text: "To link a card to the next card, select the card and select the dot in the right center, then drag to attach to the next card."
                        ),
                        GuideItem(
                            icon: "curlybraces",
                            text: "When connecting Start to an empty process prompt, {{input}} is added automatically. You can also type {{input}} anywhere in a prompt."
                        ),
                        GuideItem(
                            icon: "scissors",
                            text: "To unlink cards, click on the connection line to select it (turns red), then click again to delete the link."
                        ),
                        GuideItem(
                            icon: "hand.draw",
                            text: "To move the canvas, simply drag with the mouse. Cards can also be dragged to move in the canvas."
                        ),
                        GuideItem(
                            icon: "plus.magnifyingglass",
                            text: "To zoom in or out, use ⌘ + scroll, or use the -/+ buttons at the bottom left."
                        ),
                        GuideItem(icon: "lock", text: "To lock the canvas, use the lock button at the bottom right."),
                        GuideItem(
                            icon: "rectangle.3.group",
                            text: "To tidy up the cards or reset run state, use the buttons at the bottom right."
                        ),
                    ]
                ),
            ],
            isPresented: $showGuide,
            height: 480
        )
    }

    private var runButton: some View {
        runButtonLabel
            .popover(isPresented: $showRunGuide, arrowEdge: .bottom) {
                runGuidePopover
            }
    }

    private var runButtonLabel: some View {
        Button {
            if canRun {
                Task { await runAgent() }
            } else {
                showRunGuide.toggle()
            }
        } label: {
            if isRunning {
                Label("Running...", systemImage: "stop.fill")
            } else {
                Label("Run", systemImage: "play.fill")
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(!canRun ? .secondary : nil)
        .opacity(!canRun && !isRunning ? 0.7 : 1)
        .disabled(isRunning)
    }

    private var runGuidePopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Run Requirements")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                runRequirementRow(met: hasStartCard, text: "Add a Start card")
                runRequirementRow(met: hasOutputCard, text: "Add an Output card")
                runRequirementRow(met: allCardsConnected, text: "Connect all cards in sequence")
                runRequirementRow(met: allProcessCardsValid, text: "Configure all process cards (provider & model)")
            }

            if !hasStartCard || !hasOutputCard || !allCardsConnected || !allProcessCardsValid {
                Text(runButtonHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(minWidth: 280)
    }

    private func runRequirementRow(met: Bool, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? .green : .secondary)
                .font(.callout)
            Text(text)
                .font(.callout)
                .foregroundStyle(met ? .primary : .secondary)
        }
    }

    private var runButtonHelpText: String {
        if isRunning {
            return "Agent is currently running"
        }
        if !hasStartCard {
            return "Missing Start card"
        }
        if !hasOutputCard {
            return "Missing Output card"
        }
        if !allCardsConnected {
            return "Not all cards are connected in sequence"
        }
        if !allProcessCardsValid {
            return "Some process cards are not fully configured (missing provider or model)"
        }
        return "Run the agent"
    }

    private func runAgent() async {
        guard let agent = selectedAgent, canRun else { return }

        let wasLocked = isLocked
        runningAgentId = agent.id
        isLocked = true

        let orderedCards = getConnectedCardsInOrder()

        _ = await AgentRunService.shared.executeRun(
            agent: agent,
            orderedCards: orderedCards,
            links: linksForSelectedAgent,
            providerKeys: providerKeysForProject,
            queueManager: queueManager,
            modelContext: modelContext
        )

        // Clear running state only if this agent is still the one running
        if runningAgentId == agent.id {
            runningAgentId = nil
        }
        isLocked = wasLocked
    }

    private var createAgentSheet: some View {
        NameInputSheet(
            title: "Create New Agent",
            placeholder: "Agent Name",
            actionTitle: "Create",
            name: $newAgentName,
            isPresented: $showCreateSheet,
            onAction: createAgent
        )
    }

    private var renameAgentSheet: some View {
        NameInputSheet(
            title: "Rename Agent",
            placeholder: "Agent Name",
            actionTitle: "Rename",
            name: $renameAgentName,
            isPresented: $showRenameSheet,
            onAction: renameAgent,
            onCancel: { agentToRename = nil }
        )
    }

    private var duplicateAgentSheet: some View {
        NameInputSheet(
            title: "Duplicate Agent",
            placeholder: "Agent Name",
            actionTitle: "Duplicate",
            name: $duplicateAgentName,
            isPresented: $showDuplicateSheet,
            onAction: {
                if let agent = agentToDuplicate {
                    duplicateAgent(agent, name: duplicateAgentName)
                }
            },
            onCancel: { agentToDuplicate = nil }
        )
    }

    private func restoreLastSelectedAgent() {
        guard selectedAgent == nil else { return }

        if let savedId = UserDefaults.standard.string(forKey: lastSelectedAgentKey),
           let uuid = UUID(uuidString: savedId),
           let agent = agents.first(where: { $0.id == uuid })
        {
            selectedAgent = agent
            restoreCanvasState(from: agent, oldAgent: nil)
        }
    }

    private func fetchCardsAndLinksForAgent(_ agent: Agent?) {
        agentFetchTask?.cancel()

        guard let agent else {
            cardsForAgent = []
            linksForAgent = []
            return
        }

        let agentId = agent.id

        agentFetchTask = Task { @MainActor in
            guard !Task.isCancelled else { return }

            var cardDescriptor = FetchDescriptor<AgentCard>(
                predicate: #Predicate { $0.agentId == agentId },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            cardDescriptor.fetchLimit = 500

            var linkDescriptor = FetchDescriptor<CardLink>(
                predicate: #Predicate { $0.agentId == agentId },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            linkDescriptor.fetchLimit = 1000

            do {
                let cards = try modelContext.fetch(cardDescriptor)
                guard !Task.isCancelled else { return }

                let links = try modelContext.fetch(linkDescriptor)
                guard !Task.isCancelled else { return }

                cardsForAgent = cards
                linksForAgent = links
            } catch {
                AppLogger.agent
                    .error("Failed to fetch cards/links for agent: \(error.localizedDescription, privacy: .public)")
                cardsForAgent = []
                linksForAgent = []
            }
        }
    }

    private func createAgent() {
        let trimmedName = newAgentName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let agent = Agent.createWithDefaultCard(
            name: trimmedName,
            projectId: projectManager.currentProjectId,
            modelContext: modelContext
        )

        do {
            try modelContext.save()
            selectedAgent = agent
            showFirstAgentGuideIfNeeded()
        } catch {
            AppLogger.agent.error("Failed to save agent: \(error.localizedDescription, privacy: .public)")
        }

        showCreateSheet = false
    }

    private func renameAgent() {
        guard let agent = agentToRename else { return }
        let trimmedName = renameAgentName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        agent.name = trimmedName

        do {
            try modelContext.save()
        } catch {
            AppLogger.agent.error("Failed to rename agent: \(error.localizedDescription, privacy: .public)")
        }

        showRenameSheet = false
        agentToRename = nil
    }

    private func duplicateAgent(_ agent: Agent, name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newAgent = Agent(name: trimmedName, projectId: agent.projectId)
        newAgent.isPinned = false
        modelContext.insert(newAgent)

        do {
            try modelContext.save()
            updateAgents()
            agentToDuplicate = nil
        } catch {
            AppLogger.agent.error("Failed to duplicate agent: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteAgent(_ agent: Agent) {
        if selectedAgent?.id == agent.id {
            selectedAgent = nil
            cardsForAgent = []
            linksForAgent = []
        }

        modelContext.delete(agent)

        do {
            try modelContext.save()
        } catch {
            AppLogger.agent.error("Failed to delete agent: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func togglePin(_ agent: Agent) {
        agent.isPinned.toggle()

        do {
            try modelContext.save()
        } catch {
            AppLogger.agent.error("Failed to toggle pin for agent: \(error.localizedDescription, privacy: .public)")
        }

        updateAgents()
    }

    private func restoreCanvasState(from newAgent: Agent?, oldAgent: Agent?) {
        if let old = oldAgent {
            old.canvasScale = canvasScale
            old.canvasOffsetX = canvasOffset.x
            old.canvasOffsetY = canvasOffset.y
            old.isLocked = isLocked
            try? modelContext.save()
        }

        guard let agent = newAgent else {
            canvasScale = 1.0
            canvasOffset = .zero
            isLocked = false
            return
        }

        canvasScale = agent.canvasScale
        canvasOffset = CGPoint(x: agent.canvasOffsetX, y: agent.canvasOffsetY)
        isLocked = agent.isLocked
    }

    private func saveCanvasState() {
        guard let agent = selectedAgent else { return }

        agent.canvasScale = canvasScale
        agent.canvasOffsetX = canvasOffset.x
        agent.canvasOffsetY = canvasOffset.y
        agent.isLocked = isLocked

        do {
            try modelContext.save()
        } catch {
            AppLogger.agent.error("Failed to save canvas state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func moveCard(_ card: AgentCard, to newPosition: CGPoint) {
        card.position = newPosition

        do {
            try modelContext.save()
        } catch {
            AppLogger.agent.error("Failed to move card: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func moveCards(_ cards: [AgentCard], by translation: CGSize) {
        for card in cards {
            let newX = card.positionX + translation.width / canvasScale
            let newY = card.positionY + translation.height / canvasScale
            card.position = CGPoint(x: newX, y: newY)
        }

        do {
            try modelContext.save()
        } catch {
            AppLogger.agent.error("Failed to move cards: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func tidyUpCards() {
        let orderedCards = getConnectedCardsInOrder()
        guard orderedCards.count == cardsForSelectedAgent.count else { return }

        let spacing: CGFloat = 48
        let cardWidth: CGFloat = cardFixedWidth

        for (index, card) in orderedCards.enumerated() {
            let xPosition = CGFloat(index) * (cardWidth + spacing)
            card.position = CGPoint(x: xPosition, y: 0)
        }

        do {
            try modelContext.save()
        } catch {
            AppLogger.agent.error("Failed to tidy up cards: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func resetRunState() {
        for card in cardsForSelectedAgent {
            card.isRunning = false
            card.isErrored = false
            card.errorMessage = nil

            if card.cardType == .process || card.cardType == .output {
                card.generationId = nil
            }
        }

        do {
            try modelContext.save()
        } catch {
            AppLogger.agent.error("Failed to reset run state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func addCard(type: ProcessCardType, at position: CGPoint) {
        guard let agent = selectedAgent else { return }

        let newCard = AgentCard.createProcessCard(
            agentId: agent.id,
            processType: type,
            position: position
        )

        modelContext.insert(newCard)

        do {
            try modelContext.save()
            cardsForAgent.append(newCard)
            selectedCardIds = [newCard.id]
        } catch {
            AppLogger.agent.error("Failed to add card: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func addOutputCard(at position: CGPoint) {
        guard let agent = selectedAgent else { return }

        let hasOutputCard = cardsForSelectedAgent.contains { $0.cardType == .output }
        guard !hasOutputCard else { return }

        let newCard = AgentCard.createOutputCard(
            agentId: agent.id,
            position: position
        )

        modelContext.insert(newCard)

        do {
            try modelContext.save()
            cardsForAgent.append(newCard)
            selectedCardIds = [newCard.id]
        } catch {
            AppLogger.agent.error("Failed to add output card: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func createLink(from sourceId: UUID, to targetId: UUID) {
        guard let agent = selectedAgent else { return }

        let link = graphService.addLink(
            from: sourceId,
            to: targetId,
            agentId: agent.id,
            cards: cardsForSelectedAgent,
            links: linksForSelectedAgent,
            modelContext: modelContext
        )

        if let link {
            seedInputTemplateIfNeeded(sourceId: sourceId, targetId: targetId)

            do {
                try modelContext.save()
                linksForAgent.append(link)
            } catch {
                AppLogger.agent.error("Failed to save link: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func seedInputTemplateIfNeeded(sourceId: UUID, targetId: UUID) {
        guard let sourceCard = cardsForSelectedAgent.first(where: { $0.id == sourceId }),
              sourceCard.cardType == .start,
              let targetCard = cardsForSelectedAgent.first(where: { $0.id == targetId }),
              targetCard.cardType == .process
        else {
            return
        }

        switch targetCard.processCardType {
        case .imageGeneration:
            var config = targetCard.imageGenerationConfiguration
            guard config.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            config.prompt = "{{input}}"
            targetCard.imageGenerationConfiguration = config
        case .videoGeneration:
            var config = targetCard.videoGenerationConfiguration
            guard config.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            config.prompt = "{{input}}"
            targetCard.videoGenerationConfiguration = config
        case .none:
            return
        }
    }

    private func showFirstAgentGuideIfNeeded() {
        guard !hasSeenAgentBuilderFirstSessionGuide else { return }
        hasSeenAgentBuilderFirstSessionGuide = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showAgentBuilderIntro = true
        }
    }

    private func deleteLink(_ linkId: UUID) {
        let success = graphService.removeLink(
            linkId,
            links: linksForSelectedAgent,
            modelContext: modelContext
        )

        if success {
            do {
                try modelContext.save()
                linksForAgent.removeAll { $0.id == linkId }
            } catch {
                AppLogger.agent.error("Failed to delete link: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func duplicateCard(_ card: AgentCard) {
        guard card.cardType != .start else { return }

        let offset: CGFloat = 50
        let newPosition = CGPoint(
            x: card.positionX + offset,
            y: card.positionY + offset
        )

        let newCard = AgentCard(
            agentId: card.agentId,
            cardType: card.cardType,
            processCardType: card.processCardType,
            position: newPosition,
            title: card.title
        )
        newCard.generationId = card.generationId

        modelContext.insert(newCard)
        try? modelContext.save()
        cardsForAgent.append(newCard)
    }

    private func disconnectAll(from card: AgentCard) {
        let linksToRemove = linksForSelectedAgent.filter {
            $0.sourceCardId == card.id || $0.targetCardId == card.id
        }

        for link in linksToRemove {
            modelContext.delete(link)
        }

        do {
            try modelContext.save()
            linksForAgent.removeAll { linksToRemove.contains($0) }
        } catch {
            AppLogger.agent.error("Failed to disconnect card: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteCard(_ card: AgentCard) {
        guard card.cardType != .start else { return }

        let linksToRemove = linksForSelectedAgent.filter {
            $0.sourceCardId == card.id || $0.targetCardId == card.id
        }
        let linkIdsToRemove = Set(linksToRemove.map(\.id))

        for link in linksToRemove {
            modelContext.delete(link)
        }

        selectedCardIds.remove(card.id)

        modelContext.delete(card)

        do {
            try modelContext.save()
            cardsForAgent.removeAll { $0.id == card.id }
            linksForAgent.removeAll { linkIdsToRemove.contains($0.id) }
        } catch {
            AppLogger.agent.error("Failed to delete card: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private struct AgentBuilderIntroSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                introRow(
                    icon: "play.circle",
                    text: "Start cards provide the first input. Process cards generate images or videos. Output cards collect the final result."
                )
                introRow(
                    icon: "link",
                    text: "Drag from the right connector dot to the next card's left side to link the workflow."
                )
                introRow(
                    icon: "curlybraces",
                    text: "Use {{input}} in a process prompt to insert the previous card's input or prompt text."
                )
                introRow(
                    icon: "cursorarrow.click.2",
                    text: "Right-click output cards to view, copy, download, or share the generated result."
                )
            }
            .padding(24)
            .navigationTitle("Agent Builder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") {
                        isPresented = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(maxWidth: 440)
        #endif
    }

    private func introRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)

            Text(text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
