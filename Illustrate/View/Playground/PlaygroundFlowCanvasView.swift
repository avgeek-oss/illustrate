// MARK: - PlaygroundFlowCanvasView.swift

// Flow canvas implementation for playground exploration.
//
// Similar to FlowCanvasView but for playground cards:
// - Zoomable, pannable canvas
// - Card rendering with selection
// - Visual links between cards
// - Context menu for new generations
//
// ## Key Differences from Agent Builder
// - Simpler card types (image/video results only)
// - Links are visual indicators, not data flow
// - Iteration-focused context actions
//
// ## Context Actions
// - Generate new image/video at position
// - Edit from existing card
// - Create video from image
// - Combine multiple cards

import SwiftUI

/// Flow canvas for interactive playground exploration.
struct PlaygroundFlowCanvasView: View {
    @Binding var currentScale: CGFloat
    @Binding var resetTrigger: Bool
    @Binding var currentOffset: CGPoint
    let flowCanvasId: UUID?
    let cards: [PlaygroundCard]
    let links: [PlaygroundLink]
    @Binding var selectedCardIds: Set<UUID>
    var isLocked = false
    var onCardMove: ((PlaygroundCard, CGPoint) -> Void)?
    var onCardDelete: ((PlaygroundCard) -> Void)?
    var onGenerateImage: ((CGPoint) -> Void)?
    var onGenerateVideo: ((CGPoint) -> Void)?
    var onEditImage: ((PlaygroundCard) -> Void)?
    var onCreateVideoFromImage: ((PlaygroundCard) -> Void)?
    var onEditWithMultipleImages: (([PlaygroundCard]) -> Void)?
    var onCombineToVideo: (([PlaygroundCard]) -> Void)?
    var onTidyUp: (() -> Void)?
    var canTidyUp = false
    var onToggleLock: (() -> Void)?
    var onRegenerate: ((PlaygroundCard) -> Void)?
    var onDuplicate: ((PlaygroundCard) -> Void)?
    var onShowPreview: ((PlaygroundCard) -> Void)?

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGPoint = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGPoint = .zero
    @State private var contextMenuWorldPosition: CGPoint = .zero
    @State private var viewSize: CGSize = .zero
    @State private var cardDragOffsets: [UUID: CGSize] = [:]
    @State private var selectedLinkId: UUID?
    @State private var marqueeSelection: MarqueeSelectionState?
    @State private var showTidyUpConfirmation = false
    @State private var showDeleteConfirmation = false

    @ObservedObject private var connectionState = ConnectionStateManager.shared

    /// Check if a card has outgoing links (is a source of any link)
    private func cardHasOutgoingLinks(_ card: PlaygroundCard) -> Bool {
        links.contains { $0.sourceCardId == card.id }
    }

    private let minScale: CGFloat = CanvasConstants.minScale
    private let maxScale: CGFloat = CanvasConstants.maxScale

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid background
                CanvasGridView(scale: scale, offset: offset)
                    .contentShape(Rectangle())
                    .contextMenu {
                        canvasContextMenu
                    }

                // Links layer
                linksLayer(geometry: geometry)

                // Cards layer
                cardsLayer(geometry: geometry)

                // Marquee selection layer
                marqueeSelectionLayer

                // Controls
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
            .coordinateSpace(name: "playgroundCanvas")
            .contentShape(Rectangle())
            .gesture(canvasDragGesture(geometry: geometry))
            .onTapGesture {
                selectedCardIds.removeAll()
                selectedLinkId = nil
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
                case .ended:
                    break
                }
            }
            .onKeyPress(.return) {
                guard !selectedCardIds.isEmpty else { return .ignored }
                // Open preview for the first selected card
                if let firstSelectedId = selectedCardIds.first,
                   let card = cards.first(where: { $0.id == firstSelectedId }),
                   card.status == .GENERATED
                {
                    onShowPreview?(card)
                    return .handled
                }
                return .ignored
            }
            .confirmationDialog(
                "Delete Selected Cards",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteSelectedCards()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Are you sure you want to delete \(selectedCardIds.count) card(s)? This will also remove any links to or from these cards."
                )
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
        .onChange(of: flowCanvasId) { _, _ in
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
        .frame(minWidth: 200)
        .layoutPriority(-1)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var canvasContextMenu: some View {
        Button {
            onGenerateImage?(contextMenuWorldPosition)
        } label: {
            Label("Generate Image", systemImage: "photo.fill")
        }
        .disabled(isLocked)

        Button {
            onGenerateVideo?(contextMenuWorldPosition)
        } label: {
            Label("Generate Video", systemImage: "video.fill")
        }
        .disabled(isLocked)

        Divider()

        Button {
            resetCanvas()
        } label: {
            Label("Reset Zoom", systemImage: "arrow.counterclockwise")
        }

        if canTidyUp {
            Button {
                showTidyUpConfirmation = true
            } label: {
                Label("Tidy Up", systemImage: "rectangle.3.group")
            }
            .disabled(isLocked)
        }

        Divider()

        Button {
            onToggleLock?()
        } label: {
            Label(isLocked ? "Unlock Canvas" : "Lock Canvas", systemImage: isLocked ? "lock.open" : "lock")
        }
    }

    // MARK: - Links Layer

    @ViewBuilder
    private func linksLayer(geometry: GeometryProxy) -> some View {
        let centerOffset = CGPoint(
            x: geometry.size.width / 2 + offset.x,
            y: geometry.size.height / 2 + offset.y
        )

        ForEach(links, id: \.id) { link in
            if let sourceCard = cards.first(where: { $0.id == link.sourceCardId }),
               let targetCard = cards.first(where: { $0.id == link.targetCardId })
            {
                let startPoint = CanvasCoordinateHelper.getBottomPosition(
                    for: sourceCard.positionX,
                    positionY: sourceCard.positionY,
                    centerOffset: centerOffset,
                    scale: scale,
                    cardHeight: playgroundCardHeight,
                    dragOffset: cardDragOffsets[sourceCard.id] ?? .zero
                )
                let endPoint = CanvasCoordinateHelper.getTopPosition(
                    for: targetCard.positionX,
                    positionY: targetCard.positionY,
                    centerOffset: centerOffset,
                    scale: scale,
                    cardHeight: playgroundCardHeight,
                    dragOffset: cardDragOffsets[targetCard.id] ?? .zero
                )

                let isConnectedToSelected = selectedCardIds.contains(link.sourceCardId) ||
                    selectedCardIds.contains(link.targetCardId)

                ConnectionLineView(
                    startPoint: startPoint,
                    endPoint: endPoint,
                    isSelected: selectedLinkId == link.id,
                    isAnimating: false,
                    isLocked: isLocked,
                    isVertical: true,
                    isConnectedToSelectedCard: isConnectedToSelected,
                    onTap: {
                        if selectedLinkId == link.id {
                            selectedLinkId = nil
                        } else {
                            selectedLinkId = link.id
                        }
                    }
                )
            }
        }
    }

    // MARK: - Cards Layer

    private var selectedCards: [PlaygroundCard] {
        cards.filter { selectedCardIds.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    @ViewBuilder
    private func cardsLayer(geometry: GeometryProxy) -> some View {
        let centerOffset = CGPoint(
            x: geometry.size.width / 2 + offset.x,
            y: geometry.size.height / 2 + offset.y
        )

        ForEach(cards) { card in
            let isSelected = selectedCardIds.contains(card.id)
            let canRegenerate = !cardHasOutgoingLinks(card) || card.status == .FAILED

            PlaygroundCardView(
                card: card,
                scale: scale,
                centerOffset: centerOffset,
                isSelected: isSelected,
                externalDragOffset: cardDragOffsets[card.id] ?? .zero,
                isLocked: isLocked,
                selectedCardCount: selectedCardIds.count,
                canRegenerate: canRegenerate,
                onMove: { newPosition in
                    onCardMove?(card, newPosition)
                },
                onSelect: { modifiers in
                    handleCardSelection(card: card, modifiers: modifiers)
                },
                onDelete: {
                    onCardDelete?(card)
                },
                onEdit: {
                    if card.cardType == .IMAGE, card.status == .GENERATED {
                        onEditImage?(card)
                    }
                },
                onCreateVideo: {
                    if card.cardType == .IMAGE, card.status == .GENERATED {
                        onCreateVideoFromImage?(card)
                    }
                },
                onEditWithMultipleImages: {
                    let validCards = selectedCards.filter { $0.cardType == .IMAGE && $0.status == .GENERATED }
                    if !validCards.isEmpty {
                        onEditWithMultipleImages?(validCards)
                    }
                },
                onCombineToVideo: {
                    let validCards = selectedCards.filter { $0.cardType == .IMAGE && $0.status == .GENERATED }
                    if validCards.count == 2 {
                        onCombineToVideo?(validCards)
                    }
                },
                onDragOffsetChange: { dragOffset in
                    if dragOffset == .zero {
                        cardDragOffsets.removeValue(forKey: card.id)
                    } else {
                        cardDragOffsets[card.id] = dragOffset
                    }
                },
                onRegenerate: {
                    onRegenerate?(card)
                },
                onDuplicate: {
                    onDuplicate?(card)
                },
                onShowPreview: {
                    onShowPreview?(card)
                }
            )
        }
    }

    // MARK: - Controls

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
                .disabled(isLocked)
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
        }
    }

    // MARK: - Helpers

    private func screenToWorld(screenPosition: CGPoint, viewSize: CGSize) -> CGPoint {
        CanvasCoordinateHelper.screenToWorld(
            screenPosition: screenPosition,
            viewSize: viewSize,
            offset: offset,
            scale: scale
        )
    }

    private func handleCardSelection(card: PlaygroundCard, modifiers: EventModifiers) {
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
            }
        } else {
            if selectedCardIds.contains(card.id) {
                selectedCardIds.remove(card.id)
            } else {
                selectedCardIds = [card.id]
            }
        }
    }

    private func deleteSelectedCards() {
        let cardsToDelete = cards.filter { selectedCardIds.contains($0.id) }
        for card in cardsToDelete {
            onCardDelete?(card)
        }
        selectedCardIds.removeAll()
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

    // MARK: - Marquee Selection

    private var marqueeSelectionLayer: some View {
        MarqueeSelectionOverlay(marquee: marqueeSelection)
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
            let cardHeight: CGFloat = playgroundCardHeight * scale

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

    // MARK: - Gestures

    private func canvasDragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
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
