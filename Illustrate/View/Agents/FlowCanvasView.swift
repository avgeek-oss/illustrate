// MARK: - FlowCanvasView.swift

// Core flow canvas component for agent workflow building.
//
// This view implements a zoomable, pannable canvas where users can:
// - Place and arrange workflow cards
// - Create connections between cards
// - Select multiple cards with marquee selection
// - Delete cards and links
// - Context menu for adding new cards
//
// ## Coordinate Systems
// The canvas uses two coordinate systems:
// - Screen space: Pixels on the display
// - World space: Virtual canvas coordinates
// Helper functions convert between them based on scale and offset.
//
// ## Interaction Modes
// - Pan: Click and drag on empty space
// - Zoom: Scroll wheel or pinch gesture
// - Select: Click on card
// - Multi-select: Shift+click or marquee drag
// - Connect: Drag from card connector
// - Context menu: Right-click on empty space
//
// ## State Management
// - Cards and links passed as bindings from parent
// - Callbacks for all mutations (move, delete, link)
// - Selection state tracked locally

import SwiftUI

// Connection components are imported from View/Canvas/ConnectionComponents.swift

/// Flow canvas view for building visual workflows.
struct FlowCanvasView: View {
    @Binding var currentScale: CGFloat
    @Binding var resetTrigger: Bool
    @Binding var currentOffset: CGPoint
    @Binding var cards: [AgentCard]
    @Binding var links: [CardLink]
    @Binding var selectedCardIds: Set<UUID>

    var agentId: UUID?
    var onCardMove: ((AgentCard, CGPoint) -> Void)?
    var onCardsMove: (([AgentCard], CGSize) -> Void)?
    var onCardSelect: ((AgentCard) -> Void)?
    var onAddCard: ((ProcessCardType, CGPoint) -> Void)?
    var onAddOutputCard: ((CGPoint) -> Void)?
    var onLinkCreate: ((UUID, UUID) -> Void)?
    var onLinkDelete: ((UUID) -> Void)?
    var onCardDelete: ((AgentCard) -> Void)?
    var onCardDuplicate: ((AgentCard) -> Void)?
    var onDisconnectAll: ((AgentCard) -> Void)?
    var onTidyUp: (() -> Void)?
    var onResetRunState: (() -> Void)?
    var canTidyUp = false
    var canResetRunState = false
    var isAgentRunning = false
    var isLocked = false
    var onToggleLock: (() -> Void)?

    private var hasOutputCard: Bool {
        cards.contains { $0.cardType == .output }
    }

    private var cardsCacheKey: [String] {
        cards.map { "\($0.id)-\($0.generationId?.uuidString ?? "")-\($0.processCardType?.rawValue ?? "")" }
    }

    private var runningCardId: UUID? {
        cards.first(where: { $0.isRunning })?.id
    }

    private var linksCacheKey: [String] {
        links.map { "\($0.id)-\($0.sourceCardId)-\($0.targetCardId)" }
    }

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGPoint = .zero

    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGPoint = .zero

    @State private var contextMenuWorldPosition: CGPoint = .zero
    @State private var viewSize: CGSize = .zero

    @ObservedObject private var connectionState = ConnectionStateManager.shared
    @State private var selectedLinkId: UUID?

    @State private var cardDragOffsets: [UUID: CGSize] = [:]
    @State private var marqueeSelection: MarqueeSelectionState?
    @State private var isMultiDragging = false
    @State private var multiDragStartPosition: CGPoint = .zero
    @State private var cachedPreviousInputs: [UUID: PreviousCardInput] = [:]
    @State private var showTidyUpConfirmation = false

    init(
        currentScale: Binding<CGFloat> = .constant(1.0),
        resetTrigger: Binding<Bool> = .constant(false),
        currentOffset: Binding<CGPoint> = .constant(.zero),
        cards: Binding<[AgentCard]> = .constant([]),
        links: Binding<[CardLink]> = .constant([]),
        selectedCardIds: Binding<Set<UUID>> = .constant([]),
        agentId: UUID? = nil,
        onCardMove: ((AgentCard, CGPoint) -> Void)? = nil,
        onCardsMove: (([AgentCard], CGSize) -> Void)? = nil,
        onCardSelect: ((AgentCard) -> Void)? = nil,
        onAddCard: ((ProcessCardType, CGPoint) -> Void)? = nil,
        onAddOutputCard: ((CGPoint) -> Void)? = nil,
        onLinkCreate: ((UUID, UUID) -> Void)? = nil,
        onLinkDelete: ((UUID) -> Void)? = nil,
        onCardDelete: ((AgentCard) -> Void)? = nil,
        onCardDuplicate: ((AgentCard) -> Void)? = nil,
        onDisconnectAll: ((AgentCard) -> Void)? = nil,
        onTidyUp: (() -> Void)? = nil,
        onResetRunState: (() -> Void)? = nil,
        canTidyUp: Bool = false,
        canResetRunState: Bool = false,
        isAgentRunning: Bool = false,
        isLocked: Bool = false,
        onToggleLock: (() -> Void)? = nil
    ) {
        _currentScale = currentScale
        _resetTrigger = resetTrigger
        _currentOffset = currentOffset
        _cards = cards
        _links = links
        _selectedCardIds = selectedCardIds
        self.agentId = agentId
        self.onCardMove = onCardMove
        self.onCardsMove = onCardsMove
        self.onCardSelect = onCardSelect
        self.onAddCard = onAddCard
        self.onAddOutputCard = onAddOutputCard
        self.onLinkCreate = onLinkCreate
        self.onLinkDelete = onLinkDelete
        self.onCardDelete = onCardDelete
        self.onCardDuplicate = onCardDuplicate
        self.onDisconnectAll = onDisconnectAll
        self.onTidyUp = onTidyUp
        self.onResetRunState = onResetRunState
        self.canTidyUp = canTidyUp
        self.canResetRunState = canResetRunState
        self.isAgentRunning = isAgentRunning
        self.isLocked = isLocked
        self.onToggleLock = onToggleLock
    }

    private let minScale: CGFloat = CanvasConstants.minScale
    private let maxScale: CGFloat = CanvasConstants.maxScale

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CanvasGridView(scale: scale, offset: offset)
                    .contentShape(Rectangle())
                    .contextMenu {
                        canvasContextMenu
                    }

                linksLayer(geometry: geometry)

                cardsLayer(geometry: geometry)

                draggingLineLayer(geometry: geometry)

                marqueeSelectionLayer

                VStack {
                    Spacer()
                    HStack {
                        zoomControls
                            .padding(.leading, 16)
                            .padding(.bottom, 16)
                        Spacer()
                        canvasControls
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                    }
                }
            }
            .coordinateSpace(name: "canvas")
            .contentShape(Rectangle())
            .gesture(canvasDragGesture(geometry: geometry))
            .onTapGesture {
                selectedLinkId = nil
                selectedCardIds.removeAll()
                connectionState.clearLinkSelection()
                #if os(macOS)
                NSApp.keyWindow?.makeFirstResponder(nil)
                #endif
            }
            #if os(macOS)
            .overlay {
                ScrollWheelCaptureView(
                    scale: $scale,
                    lastScale: $lastScale,
                    offset: $offset,
                    lastOffset: $lastOffset,
                    minScale: minScale,
                    maxScale: maxScale,
                    viewSize: geometry.size
                )
            }
            .onContinuousHover { phase in
                switch phase {
                case let .active(location):
                    contextMenuWorldPosition = screenToWorld(screenPosition: location, viewSize: geometry.size)
                    if connectionState.dragState != nil {
                        connectionState.updateDragPosition(location)
                    }
                case .ended:
                    break
                }
            }
            #else
            .gesture(magnificationGesture)
            #endif
            .onAppear {
                viewSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
            }
        }
        .onChange(of: scale) { _, newValue in
            currentScale = newValue
        }
        .onChange(of: offset) { _, newValue in
            currentOffset = newValue
        }
        .onChange(of: resetTrigger) { _, _ in
            resetCanvas()
        }
        .onChange(of: connectionState.selectedLinkId) { _, newValue in
            selectedLinkId = newValue
        }
        .onChange(of: agentId) { _, _ in
            scale = currentScale
            lastScale = currentScale
            offset = currentOffset
            lastOffset = currentOffset
        }
        .onAppear {
            scale = currentScale
            lastScale = currentScale
            offset = currentOffset
            lastOffset = currentOffset
        }
        .task {
            try? await Task.sleep(for: .milliseconds(50))
            rebuildPreviousInputsCache()
        }
        .onChange(of: cardsCacheKey) { _, _ in
            rebuildPreviousInputsCache()
        }
        .onChange(of: linksCacheKey) { _, _ in
            rebuildPreviousInputsCache()
        }
        .onChange(of: runningCardId) { _, newRunningCardId in
            if !isLocked, let cardId = newRunningCardId {
                centerOnCard(cardId: cardId)
            }
        }
        .frame(minWidth: 200)
        .layoutPriority(-1)
    }

    private var marqueeSelectionLayer: some View {
        MarqueeSelectionOverlay(marquee: marqueeSelection)
    }

    @ViewBuilder
    private var canvasContextMenu: some View {
        Menu("Add Card") {
            ForEach(ProcessCardType.allCases) { cardType in
                Button {
                    onAddCard?(cardType, contextMenuWorldPosition)
                } label: {
                    Label(cardType.displayName, systemImage: cardType.icon)
                }
            }
        }
        .disabled(isLocked)

        Button {
            onAddOutputCard?(contextMenuWorldPosition)
        } label: {
            Label("Add Output", systemImage: "square.and.arrow.up.fill")
        }
        .disabled(hasOutputCard || isLocked)

        Divider()

        Button {
            resetCanvas()
        } label: {
            Label("Reset Zoom", systemImage: "arrow.counterclockwise")
        }

        Button {
            showTidyUpConfirmation = true
        } label: {
            Label("Tidy Up", systemImage: "rectangle.3.group")
        }
        .disabled(!canTidyUp || isLocked)

        Divider()

        Button {
            onToggleLock?()
        } label: {
            Label(isLocked ? "Unlock Canvas" : "Lock Canvas", systemImage: isLocked ? "lock.open" : "lock")
        }
    }

    private var zoomControls: some View {
        CanvasZoomControls(
            scale: $scale,
            lastScale: $lastScale,
            offset: $offset,
            lastOffset: $lastOffset,
            onScaleChange: { newScale in
                currentScale = newScale
            },
            onOffsetChange: { newOffset in
                currentOffset = newOffset
            }
        )
    }

    private var canvasControls: some View {
        HStack(spacing: 8) {
            CanvasLockButton(isLocked: isLocked) {
                onToggleLock?()
            }

            if canTidyUp {
                CanvasActionButton(
                    icon: "rectangle.3.group",
                    helpText: "Tidy up cards"
                ) {
                    showTidyUpConfirmation = true
                }
                .confirmationDialog(
                    "Tidy Up Cards",
                    isPresented: $showTidyUpConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Tidy Up", role: .destructive) {
                        onTidyUp?()
                        resetCanvas()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will rearrange all cards on the canvas. This action cannot be undone.")
                }
            }

            if canResetRunState {
                CanvasActionButton(
                    icon: "arrow.counterclockwise",
                    helpText: "Reset run state"
                ) {
                    onResetRunState?()
                }
            }
        }
    }

    private func screenToWorld(screenPosition: CGPoint, viewSize: CGSize) -> CGPoint {
        let centerX = viewSize.width / 2
        let centerY = viewSize.height / 2

        let screenRelativeX = screenPosition.x - centerX - offset.x
        let screenRelativeY = screenPosition.y - centerY - offset.y

        return CGPoint(
            x: screenRelativeX / scale,
            y: screenRelativeY / scale
        )
    }

    @ViewBuilder
    private func linksLayer(geometry: GeometryProxy) -> some View {
        let centerOffset = CGPoint(
            x: geometry.size.width / 2 + offset.x,
            y: geometry.size.height / 2 + offset.y
        )

        ForEach(links, id: \.id) { link in
            let startPoint = getOutputPosition(for: link.sourceCardId, centerOffset: centerOffset)
            let endPoint = getInputPosition(for: link.targetCardId, centerOffset: centerOffset)

            if let start = startPoint, let end = endPoint {
                let isConnectedToSelected = selectedCardIds.contains(link.sourceCardId) ||
                    selectedCardIds.contains(link.targetCardId)

                ConnectionLineView(
                    startPoint: start,
                    endPoint: end,
                    isSelected: selectedLinkId == link.id,
                    isAnimating: isAgentRunning,
                    isLocked: isLocked,
                    isConnectedToSelectedCard: isConnectedToSelected,
                    onTap: {
                        if selectedLinkId == link.id {
                            onLinkDelete?(link.id)
                            selectedLinkId = nil
                            connectionState.clearLinkSelection()
                        } else {
                            selectedLinkId = link.id
                            connectionState.selectLink(link.id)
                        }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func draggingLineLayer(geometry: GeometryProxy) -> some View {
        if let dragState = connectionState.dragState {
            let centerOffset = CGPoint(
                x: geometry.size.width / 2 + offset.x,
                y: geometry.size.height / 2 + offset.y
            )

            let startPoint: CGPoint = if dragState.isFromOutput {
                getOutputPosition(for: dragState.sourceCardId, centerOffset: centerOffset) ?? dragState
                    .currentMousePosition
            } else {
                getInputPosition(for: dragState.sourceCardId, centerOffset: centerOffset) ?? dragState
                    .currentMousePosition
            }

            BezierCurveShape(
                startPoint: startPoint,
                endPoint: dragState.currentMousePosition
            )
            .stroke(
                Color.accentColor,
                style: StrokeStyle(
                    lineWidth: 2,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [8, 4]
                )
            )
        }
    }

    @ViewBuilder
    private func cardsLayer(geometry: GeometryProxy) -> some View {
        let centerOffset = CGPoint(
            x: geometry.size.width / 2 + offset.x,
            y: geometry.size.height / 2 + offset.y
        )

        ForEach($cards) { $card in
            let hasOutputConnection = links.contains { $0.sourceCardId == card.id }
            let hasInputConnection = links.contains { $0.targetCardId == card.id }
            let previousInput = cachedPreviousInputs[card.id] ?? PreviousCardInput()
            let isSelected = selectedCardIds.contains(card.id)

            CanvasCardView(
                card: $card,
                scale: scale,
                offset: centerOffset,
                isSelected: isSelected,
                isPartOfMultiSelection: selectedCardIds.count > 1 && isSelected,
                externalDragOffset: cardDragOffsets[card.id] ?? .zero,
                hasOutputConnection: hasOutputConnection,
                hasInputConnection: hasInputConnection,
                previousInput: previousInput,
                isAgentRunning: isAgentRunning,
                isLocked: isLocked,
                onMove: { newPosition in
                    if selectedCardIds.count <= 1 || !isSelected {
                        onCardMove?(card, newPosition)
                    }
                },
                onSelect: { modifiers in
                    handleCardSelection(card: card, modifiers: modifiers)
                },
                onDelete: {
                    onCardDelete?(card)
                },
                onDuplicate: {
                    onCardDuplicate?(card)
                },
                onDisconnectAll: {
                    onDisconnectAll?(card)
                },
                onDragOffsetChange: { dragOffset in
                    handleCardDragOffset(card: card, offset: dragOffset)
                },
                onMultiDragStart: { translation in
                    if selectedCardIds.count > 1, isSelected {
                        startMultiDrag(initiatingCard: card, translation: translation)
                    }
                },
                onMultiDragEnd: { translation in
                    if selectedCardIds.count > 1, isSelected {
                        endMultiDrag(translation: translation)
                    }
                }
            )
            .onReceive(NotificationCenter.default.publisher(for: .connectionDropped)) { notification in
                if let targetId = notification.userInfo?["targetCardId"] as? UUID,
                   let sourceId = notification.userInfo?["sourceCardId"] as? UUID,
                   targetId == card.id
                {
                    handleConnectionDrop(sourceCardId: sourceId, targetCardId: targetId)
                }
            }
        }
    }

    private func handleCardSelection(card: AgentCard, modifiers: EventModifiers) {
        selectedLinkId = nil
        connectionState.clearLinkSelection()

        #if os(macOS)
        let isMultiSelectModifier = modifiers.contains(.shift) || modifiers.contains(.command)
        #else
        let isMultiSelectModifier = modifiers.contains(.shift)
        #endif

        if isMultiSelectModifier {
            if selectedCardIds.contains(card.id) {
                selectedCardIds.remove(card.id)
            } else {
                selectedCardIds.insert(card.id)
                onCardSelect?(card)
            }
        } else {
            if selectedCardIds.count == 1, selectedCardIds.contains(card.id) {
                selectedCardIds.removeAll()
            } else {
                selectedCardIds = [card.id]
                onCardSelect?(card)
            }
        }
    }

    private func handleCardDragOffset(card: AgentCard, offset: CGSize) {
        if offset == .zero {
            cardDragOffsets.removeValue(forKey: card.id)
        } else {
            if selectedCardIds.count > 1, selectedCardIds.contains(card.id) {
                for selectedId in selectedCardIds {
                    cardDragOffsets[selectedId] = offset
                }
            } else {
                cardDragOffsets[card.id] = offset
            }
        }
    }

    private func startMultiDrag(initiatingCard: AgentCard, translation: CGSize) {
        isMultiDragging = true
        for selectedId in selectedCardIds {
            cardDragOffsets[selectedId] = translation
        }
    }

    private func endMultiDrag(translation: CGSize) {
        isMultiDragging = false

        let selectedCards = cards.filter { selectedCardIds.contains($0.id) }
        onCardsMove?(selectedCards, translation)

        for selectedId in selectedCardIds {
            cardDragOffsets.removeValue(forKey: selectedId)
        }
    }

    private func rebuildPreviousInputsCache() {
        var quickCache: [UUID: PreviousCardInput] = [:]

        for card in cards {
            guard let incomingLink = links.first(where: { $0.targetCardId == card.id }) else {
                continue
            }

            guard let sourceCard = cards.first(where: { $0.id == incomingLink.sourceCardId }) else {
                continue
            }

            var input = PreviousCardInput()

            if sourceCard.cardType == .start {
                input.text = "{{input}}"
                input.isImagePlaceholder = true
            } else if sourceCard.cardType == .process {
                input.isImagePlaceholder = true
            }

            quickCache[card.id] = input
        }

        cachedPreviousInputs = quickCache

        Task.detached(priority: .background) { [cards, links] in
            var newCache: [UUID: PreviousCardInput] = [:]

            for card in cards {
                guard let incomingLink = links.first(where: { $0.targetCardId == card.id }) else {
                    continue
                }

                guard let sourceCard = cards.first(where: { $0.id == incomingLink.sourceCardId }) else {
                    continue
                }

                var input = PreviousCardInput()

                if let genId = sourceCard.generationId {
                    let cacheKey = "flow_\(genId.uuidString)"
                    if let image = loadImageFromDocumentsDirectory(withName: genId.uuidString) {
                        input.image = image
                        ImageCache.shared.set(image, forKey: cacheKey)
                    }

                    if let videoURL = loadVideoUrlFromDocumentsDirectory(withName: genId.uuidString) {
                        input.video = videoURL
                    }
                }

                if sourceCard.cardType == .start {
                    input.text = "{{input}}"
                }

                if input.image == nil, input.video == nil {
                    input.isImagePlaceholder = true
                }

                newCache[card.id] = input
            }

            let finalCache = newCache
            await MainActor.run {
                cachedPreviousInputs = finalCache
            }
        }
    }

    private func getPreviousInput(for card: AgentCard) -> PreviousCardInput {
        guard let incomingLink = links.first(where: { $0.targetCardId == card.id }) else {
            return PreviousCardInput()
        }

        guard let sourceCard = cards.first(where: { $0.id == incomingLink.sourceCardId }) else {
            return PreviousCardInput()
        }

        var input = PreviousCardInput()

        if let genId = sourceCard.generationId {
            let cacheKey = "flow_\(genId.uuidString)"
            if let cached = ImageCache.shared.get(forKey: cacheKey) {
                input.image = cached
            } else if let image = loadImageFromDocumentsDirectory(withName: genId.uuidString) {
                input.image = image
                ImageCache.shared.set(image, forKey: cacheKey)
            }
            if let videoURL = loadVideoUrlFromDocumentsDirectory(withName: genId.uuidString) {
                input.video = videoURL
            }
        }

        if sourceCard.cardType == .start {
            input.text = "{{input}}"
        }

        if input.image == nil, input.video == nil {
            input.isImagePlaceholder = true
        }

        return input
    }

    private func getOutputPosition(for cardId: UUID, centerOffset: CGPoint) -> CGPoint? {
        guard let card = cards.first(where: { $0.id == cardId }) else { return nil }

        let dragOffset = cardDragOffsets[cardId] ?? .zero

        let cardScreenX = card.positionX * scale + centerOffset.x + dragOffset.width
        let cardScreenY = card.positionY * scale + centerOffset.y + dragOffset.height

        let cardHalfWidth: CGFloat = (cardFixedWidth / 2) * scale

        return CGPoint(x: cardScreenX + cardHalfWidth, y: cardScreenY)
    }

    private func getInputPosition(for cardId: UUID, centerOffset: CGPoint) -> CGPoint? {
        guard let card = cards.first(where: { $0.id == cardId }) else { return nil }

        let dragOffset = cardDragOffsets[cardId] ?? .zero

        let cardScreenX = card.positionX * scale + centerOffset.x + dragOffset.width
        let cardScreenY = card.positionY * scale + centerOffset.y + dragOffset.height

        let cardHalfWidth: CGFloat = (cardFixedWidth / 2) * scale

        return CGPoint(x: cardScreenX - cardHalfWidth, y: cardScreenY)
    }

    private func handleConnectionDrop(sourceCardId: UUID, targetCardId: UUID) {
        guard !isLocked else { return }
        guard sourceCardId != targetCardId else {
            return
        }

        onLinkCreate?(sourceCardId, targetCardId)
    }

    private func resetCanvas() {
        withAnimation(.easeOut(duration: CanvasConstants.resetAnimationDuration)) {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
            currentScale = 1.0
            currentOffset = .zero
        }
    }

    private func centerOnCard(cardId: UUID) {
        guard let card = cards.first(where: { $0.id == cardId }) else { return }

        let newOffset = CGPoint(
            x: -card.positionX * scale,
            y: -card.positionY * scale
        )

        withAnimation(.easeInOut(duration: 0.4)) {
            offset = newOffset
            lastOffset = newOffset
        }
    }

    private func deleteSelectedCards() {
        let cardsToDelete = cards.filter { selectedCardIds.contains($0.id) && $0.cardType != .start }
        for card in cardsToDelete {
            onCardDelete?(card)
        }
        selectedCardIds.removeAll()
    }

    private func canvasDragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                #if os(macOS)
                let isMarqueeModifier = NSEvent.modifierFlags.contains(.command)
                #else
                let isMarqueeModifier = false
                #endif

                if isMarqueeModifier || marqueeSelection != nil {
                    if marqueeSelection == nil {
                        marqueeSelection = MarqueeSelectionState(
                            startPoint: value.startLocation,
                            currentPoint: value.location
                        )
                    } else {
                        marqueeSelection?.currentPoint = value.location
                    }

                    updateMarqueeSelection(geometry: geometry)
                } else if !isLocked {
                    offset = CGPoint(
                        x: lastOffset.x + value.translation.width,
                        y: lastOffset.y + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                if marqueeSelection != nil {
                    marqueeSelection = nil
                } else if !isLocked {
                    lastOffset = offset
                }
            }
    }

    private func updateMarqueeSelection(geometry: GeometryProxy) {
        guard let marquee = marqueeSelection else { return }

        let centerOffset = CGPoint(
            x: geometry.size.width / 2 + offset.x,
            y: geometry.size.height / 2 + offset.y
        )

        var newSelection = Set<UUID>()

        for card in cards {
            let cardScreenX = card.positionX * scale + centerOffset.x
            let cardScreenY = card.positionY * scale + centerOffset.y
            let cardWidth = cardFixedWidth * scale
            let cardHeight: CGFloat = 150 * scale

            let cardRect = CGRect(
                x: cardScreenX - cardWidth / 2,
                y: cardScreenY - cardHeight / 2,
                width: cardWidth,
                height: cardHeight
            )

            if marquee.rect.intersects(cardRect) {
                newSelection.insert(card.id)
            }
        }

        selectedCardIds = newSelection
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGPoint(
                    x: lastOffset.x + value.translation.width,
                    y: lastOffset.y + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }
}
