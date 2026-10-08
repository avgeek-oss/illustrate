// MARK: - CanvasCardView.swift

// Card rendering components for the agent canvas.
//
// Provides the visual representation of cards on the canvas:
// - ConnectionDotView: Input/output connector dots
// - CanvasCardView: Container with drag, selection, connection handling
//
// ## Connection Dots
// - Input dot (top): Receives data from previous cards
// - Output dot (bottom): Sends data to next cards
// - Drag from output to input to create links
//
// ## Card Interactions
// - Drag to move cards on canvas
// - Click to select
// - Shift+click for multi-select
// - Hover to show connector dots

import SwiftData
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Connection point visual for card inputs/outputs.
struct ConnectionDotView: View {
    let type: ConnectionDotType
    let cardId: UUID
    let isVisible: Bool
    let isTargeted: Bool
    let scale: CGFloat
    let allowsDrag: Bool
    var onDragStart: ((CGPoint) -> Void)?
    var onDragUpdate: ((CGPoint) -> Void)?
    var onDragEnd: ((CGPoint) -> Void)?

    @State private var isDragging = false

    private let dotSize: CGFloat = 10
    private let hitAreaSize: CGFloat = 32

    private var isHighlighted: Bool {
        isDragging || isTargeted
    }

    var body: some View {
        Circle()
            .fill(dotFillColor)
            .frame(width: dotSize, height: dotSize)
            .overlay(Circle().stroke(dotStrokeColor, lineWidth: 2))
            .shadow(color: dotFillColor.opacity(0.4), radius: isHighlighted ? 6 : 2)
            .scaleEffect(isHighlighted ? 1.4 : 1.0)
            .frame(width: hitAreaSize, height: hitAreaSize)
            .contentShape(Circle())
            .gesture(
                allowsDrag ? dragGesture : nil
            )
            .opacity(isVisible || isDragging ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.15), value: isVisible)
            .animation(.easeInOut(duration: 0.1), value: isDragging)
            .animation(.easeInOut(duration: 0.1), value: isTargeted)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    onDragStart?(value.startLocation)
                }
                onDragUpdate?(value.location)
            }
            .onEnded { value in
                isDragging = false
                onDragEnd?(value.location)
            }
    }

    private var dotFillColor: Color {
        if isHighlighted {
            return .accentColor
        }
        return secondaryLabel
    }

    private var dotStrokeColor: Color {
        if isHighlighted {
            return .white
        }
        return .white.opacity(0.8)
    }
}

struct InputDropZoneView: View {
    let cardId: UUID
    let scale: CGFloat
    @Binding var isDropTarget: Bool
    let onDrop: (UUID) -> Void

    @ObservedObject private var connectionState = ConnectionStateManager.shared
    @State private var dropZoneFrame: CGRect = .zero
    @State private var pendingSourceCardId: UUID?
    @State private var wasTargetBeforeDragEnd = false

    private let baseDropZoneSize: CGFloat = 44

    private var dropZoneSize: CGFloat {
        max(baseDropZoneSize, baseDropZoneSize * scale)
    }

    var body: some View {
        Circle()
            .fill(isDropTarget ? Color.accentColor.opacity(0.2) : Color.clear)
            .frame(width: dropZoneSize, height: dropZoneSize)
            .overlay(Circle().stroke(isDropTarget ? Color.accentColor : Color.clear, lineWidth: 2))
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: FramePreferenceKey.self, value: geo.frame(in: .named("canvas")))
                }
            )
            .onPreferenceChange(FramePreferenceKey.self) { frame in
                dropZoneFrame = frame
            }
            .onChange(of: connectionState.dragState?.currentMousePosition) { _, newPosition in
                guard let dragState = connectionState.dragState,
                      dragState.isFromOutput,
                      dragState.sourceCardId != cardId
                else {
                    return
                }

                guard let position = newPosition else { return }

                let expandedFrame = dropZoneFrame.insetBy(dx: -12, dy: -12)
                let wasTarget = isDropTarget
                isDropTarget = expandedFrame.contains(position)

                if isDropTarget, !wasTarget {
                    pendingSourceCardId = dragState.sourceCardId
                } else if !isDropTarget {
                    pendingSourceCardId = nil
                }

                wasTargetBeforeDragEnd = isDropTarget
            }
            .onChange(of: connectionState.dragState) { oldState, newState in
                if let _ = oldState, newState == nil {
                    if wasTargetBeforeDragEnd || isDropTarget, let sourceId = pendingSourceCardId {
                        DispatchQueue.main.async {
                            onDrop(sourceId)
                        }
                    }
                }

                if newState == nil {
                    isDropTarget = false
                    pendingSourceCardId = nil
                    wasTargetBeforeDragEnd = false
                }
            }
    }
}

struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct CanvasCardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationManager: NavigationManager
    @Binding var card: AgentCard
    let scale: CGFloat
    let offset: CGPoint
    let isSelected: Bool
    let isPartOfMultiSelection: Bool
    let externalDragOffset: CGSize
    let hasOutputConnection: Bool
    let hasInputConnection: Bool
    let previousInput: PreviousCardInput
    let isAgentRunning: Bool
    let isLocked: Bool
    let onMove: (CGPoint) -> Void
    let onSelect: (EventModifiers) -> Void
    var onDelete: (() -> Void)?
    var onDuplicate: (() -> Void)?
    var onDisconnectAll: (() -> Void)?
    var onDragOffsetChange: ((CGSize) -> Void)?
    var onMultiDragStart: ((CGSize) -> Void)?
    var onMultiDragEnd: ((CGSize) -> Void)?

    @State private var isDragging = false
    @State private var localDragOffset: CGSize = .zero
    @State private var isInputDropTarget = false
    @State private var isHovering = false
    @State private var dragStartWorldPosition: CGPoint? = nil

    @ObservedObject private var connectionState = ConnectionStateManager.shared

    init(
        card: Binding<AgentCard>,
        scale: CGFloat,
        offset: CGPoint,
        isSelected: Bool = false,
        isPartOfMultiSelection: Bool = false,
        externalDragOffset: CGSize = .zero,
        hasOutputConnection: Bool = false,
        hasInputConnection: Bool = false,
        previousInput: PreviousCardInput = PreviousCardInput(),
        isAgentRunning: Bool = false,
        isLocked: Bool = false,
        onMove: @escaping (CGPoint) -> Void,
        onSelect: @escaping (EventModifiers) -> Void,
        onDelete: (() -> Void)? = nil,
        onDuplicate: (() -> Void)? = nil,
        onDisconnectAll: (() -> Void)? = nil,
        onDragOffsetChange: ((CGSize) -> Void)? = nil,
        onMultiDragStart: ((CGSize) -> Void)? = nil,
        onMultiDragEnd: ((CGSize) -> Void)? = nil
    ) {
        _card = card
        self.scale = scale
        self.offset = offset
        self.isSelected = isSelected
        self.isPartOfMultiSelection = isPartOfMultiSelection
        self.externalDragOffset = externalDragOffset
        self.hasOutputConnection = hasOutputConnection
        self.hasInputConnection = hasInputConnection
        self.previousInput = previousInput
        self.isAgentRunning = isAgentRunning
        self.isLocked = isLocked
        self.onMove = onMove
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
        self.onDisconnectAll = onDisconnectAll
        self.onDragOffsetChange = onDragOffsetChange
        self.onMultiDragStart = onMultiDragStart
        self.onMultiDragEnd = onMultiDragEnd
    }

    private var effectiveDragOffset: CGSize {
        isPartOfMultiSelection ? externalDragOffset : localDragOffset
    }

    private var screenPosition: CGPoint {
        let baseX = isDragging && dragStartWorldPosition != nil ? dragStartWorldPosition!.x : card.positionX
        let baseY = isDragging && dragStartWorldPosition != nil ? dragStartWorldPosition!.y : card.positionY

        return CGPoint(
            x: baseX * scale + offset.x + effectiveDragOffset.width,
            y: baseY * scale + offset.y + effectiveDragOffset.height
        )
    }

    private var showHighlight: Bool {
        isSelected || isInputDropTarget
    }

    private var shouldShowOutputDot: Bool {
        if hasOutputConnection { return false }
        if let dragState = connectionState.dragState, dragState.sourceCardId == card.id {
            return true
        }
        if connectionState.dragState != nil {
            return false
        }
        return isSelected
    }

    private var shouldShowInputDot: Bool {
        if hasInputConnection { return false }
        if let dragState = connectionState.dragState, dragState.sourceCardId == card.id {
            return false
        }
        if isBeingTargeted { return true }
        if connectionState.dragState != nil {
            return isInputDropTarget
        }
        return isSelected
    }

    private var isBeingTargeted: Bool {
        if hasInputConnection { return false }
        guard let dragState = connectionState.dragState else { return false }
        return dragState.isFromOutput && dragState.sourceCardId != card.id && card.cardType != .start
    }

    private var shouldDim: Bool {
        isAgentRunning && !card.isRunning
    }

    var body: some View {
        cardContentWithContextMenu
            .scaleEffect(scale)
            .overlay(connectionDotsOverlay)
            .position(screenPosition)
            .opacity(shouldDim ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: shouldDim)
            #if os(macOS)
            .simultaneousGesture(
                TapGesture()
                    .modifiers(.shift)
                    .onEnded { _ in
                        guard !isLocked else { return }
                        connectionState.clearLinkSelection()
                        onSelect(.shift)
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .modifiers(.command)
                    .onEnded { _ in
                        guard !isLocked else { return }
                        connectionState.clearLinkSelection()
                        onSelect(.command)
                    }
            )
            #endif
            .onTapGesture {
                guard !isLocked else { return }
                connectionState.clearLinkSelection()
                onSelect([])
            }
            .gesture(cardDragGesture)
            .onHover { hovering in
                isHovering = hovering
                connectionState.setHoveredCard(hovering ? card.id : nil)
            }
    }

    @ViewBuilder
    private var cardContentWithContextMenu: some View {
        if card.cardType != .start, !isPartOfMultiSelection, !isLocked {
            cardContent
                .contentShape(Rectangle())
                .contextMenu {
                    if let generation = generationForContextMenu() {
                        generationContextMenu(for: generation)
                        Divider()
                    }

                    if let onDuplicate {
                        Button {
                            onDuplicate()
                        } label: {
                            Label("Duplicate Card", systemImage: "doc.on.doc")
                        }
                    }

                    if hasInputConnection || hasOutputConnection, let onDisconnectAll {
                        Button {
                            onDisconnectAll()
                        } label: {
                            Label("Disconnect All", systemImage: "link.badge.minus")
                        }
                    }

                    if onDuplicate != nil || (hasInputConnection || hasOutputConnection) {
                        Divider()
                    }

                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Label("Delete Card", systemImage: "trash")
                    }
                }
        } else {
            cardContent
        }
    }

    @ViewBuilder
    private func generationContextMenu(for generation: Generation) -> some View {
        let mediaKind = generation.contentType == .VIDEO ? "video" : "image"

        Button {
            viewGeneration(generation)
        } label: {
            Label("View \(mediaKind)", systemImage: "eye")
        }

        Button {
            copyGeneration(generation)
        } label: {
            Label("Copy \(mediaKind)", systemImage: "doc.on.doc")
        }

        Button {
            downloadGeneration(generation)
        } label: {
            Label("Download \(mediaKind)", systemImage: "arrow.down")
        }

        Button {
            shareGeneration(generation)
        } label: {
            Label("Share \(mediaKind)", systemImage: "square.and.arrow.up")
        }
    }

    private func generationForContextMenu() -> Generation? {
        guard let generationId = card.generationId else { return nil }
        let descriptor = FetchDescriptor<Generation>(predicate: #Predicate { generation in
            generation.id == generationId
        })
        return try? modelContext.fetch(descriptor).first
    }

    private func viewGeneration(_ generation: Generation) {
        let destination: EnumNavigationItem = generation.contentType == .VIDEO
            ? .generationVideo(setId: generation.setId)
            : .generationImage(setId: generation.setId)
        navigationManager.pushDetail(destination)
    }

    private func copyGeneration(_ generation: Generation) {
        if generation.contentType == .IMAGE_2D, let image = loadImageFromiCloud(generation.id.uuidString) {
            #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
            #else
            UIPasteboard.general.image = image
            #endif
            showToast(.success("Copied to clipboard"))
            return
        }

        if generation.contentType == .VIDEO, let videoURL = loadVideoFromiCloud(generation.id.uuidString) {
            #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([videoURL as NSURL])
            #else
            UIPasteboard.general.url = videoURL
            #endif
            showToast(.success("Copied to clipboard"))
            return
        }

        copyTextToClipboard(generation.prompt)
    }

    private func downloadGeneration(_ generation: Generation) {
        if generation.contentType == .IMAGE_2D, let image = loadImageFromiCloud(generation.id.uuidString) {
            #if os(macOS)
            image.saveImageToDownloads(fileName: generation.id.uuidString)
            #else
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            showToast(.success("Saved to Photos"))
            #endif
            return
        }

        if generation.contentType == .VIDEO, let videoURL = loadVideoFromiCloud(generation.id.uuidString) {
            #if os(macOS)
            saveVideoToDownloads(url: videoURL, fileName: generation.id.uuidString)
            #else
            UISaveVideoAtPathToSavedPhotosAlbum(videoURL.path, nil, nil, nil)
            showToast(.success("Saved to Photos"))
            #endif
        }
    }

    private func shareGeneration(_ generation: Generation) {
        if generation.contentType == .IMAGE_2D, let image = loadImageFromiCloud(generation.id.uuidString) {
            #if os(macOS)
            image.shareImage()
            #else
            UIPasteboard.general.image = image
            showToast(.success("Copied to clipboard"))
            #endif
            return
        }

        if generation.contentType == .VIDEO, let videoURL = loadVideoFromiCloud(generation.id.uuidString) {
            #if os(macOS)
            shareVideo(url: videoURL)
            #else
            UIPasteboard.general.url = videoURL
            showToast(.success("Copied to clipboard"))
            #endif
        }
    }

    private func copyTextToClipboard(_ text: String) {
        guard !text.isEmpty else { return }
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
        showToast(.success("Copied to clipboard"))
    }

    private let dotOffset: CGFloat = 0

    private var connectionDotsOverlay: some View {
        GeometryReader { geometry in
            let originalWidth = cardFixedWidth
            let originalHeight = geometry.size.height

            let scaledWidth = originalWidth * scale

            let centerX = geometry.size.width / 2
            let centerY = originalHeight / 2

            let rightDotX = centerX + (scaledWidth / 2) + dotOffset
            let leftDotX = centerX - (scaledWidth / 2) - dotOffset

            if card.cardType == .start || card.cardType == .process {
                ConnectionDotView(
                    type: .output,
                    cardId: card.id,
                    isVisible: shouldShowOutputDot && !isLocked,
                    isTargeted: false,
                    scale: scale,
                    allowsDrag: !isLocked,
                    onDragStart: { position in
                        connectionState.startDragging(from: card.id, position: position, isOutput: true)
                    },
                    onDragUpdate: { position in
                        connectionState.updateDragPosition(position)
                    },
                    onDragEnd: { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            connectionState.endDragging()
                        }
                    }
                )
                .position(x: rightDotX, y: centerY)
            }

            if card.cardType != .start, !isLocked {
                ZStack {
                    InputDropZoneView(
                        cardId: card.id,
                        scale: scale,
                        isDropTarget: $isInputDropTarget
                    ) { sourceCardId in
                        NotificationCenter.default.post(
                            name: .connectionDropped,
                            object: nil,
                            userInfo: ["targetCardId": card.id, "sourceCardId": sourceCardId]
                        )
                    }

                    ConnectionDotView(
                        type: .input,
                        cardId: card.id,
                        isVisible: shouldShowInputDot,
                        isTargeted: isInputDropTarget,
                        scale: scale,
                        allowsDrag: false
                    )
                }
                .position(x: leftDotX, y: centerY)
            }
        }
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private var cardContent: some View {
        switch card.cardType {
        case .start:
            StartCardView(
                card: $card,
                isHovered: showHighlight,
                isRunning: card.isRunning,
                isErrored: card.isErrored,
                errorMessage: card.errorMessage,
                isLocked: isLocked
            )
        case .process:
            processCardContent
        case .output:
            OutputCardView(
                card: $card,
                isHovered: showHighlight,
                isRunning: card.isRunning,
                isErrored: card.isErrored,
                errorMessage: card.errorMessage,
                isLocked: isLocked
            )
        }
    }

    @ViewBuilder
    private var processCardContent: some View {
        if let processType = card.processCardType {
            switch processType {
            case .imageGeneration:
                ImageGenerateCardView(
                    card: $card,
                    isHovered: showHighlight,
                    isRunning: card.isRunning,
                    isErrored: card.isErrored,
                    errorMessage: card.errorMessage,
                    previousInput: previousInput,
                    isLocked: isLocked
                )
            case .videoGeneration:
                VideoGenerateCardView(
                    card: $card,
                    isHovered: showHighlight,
                    isRunning: card.isRunning,
                    isErrored: card.isErrored,
                    errorMessage: card.errorMessage,
                    previousInput: previousInput,
                    isLocked: isLocked
                )
            }
        } else {
            placeholderCard(title: "Process", icon: "gearshape", color: .blue)
        }
    }

    private func placeholderCard(title: String, icon: String, color: Color) -> some View {
        CardContainerView(
            isHovered: showHighlight,
            isRunning: card.isRunning,
            isErrored: card.isErrored,
            errorMessage: card.errorMessage
        ) {
            CardHeaderView(title: title, icon: icon, iconColor: color, hasGenerationId: card.generationId != nil)
        } content: {
            Text("Coming soon...")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 200)
        } footer: {
            CardFooterView()
        }
    }

    private var cardDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isLocked else { return }
                guard connectionState.dragState == nil else { return }

                if !isDragging {
                    dragStartWorldPosition = CGPoint(x: card.positionX, y: card.positionY)
                }
                isDragging = true

                if isPartOfMultiSelection {
                    onMultiDragStart?(value.translation)
                } else {
                    localDragOffset = value.translation
                    onDragOffsetChange?(value.translation)
                }
            }
            .onEnded { value in
                guard !isLocked else { return }
                guard connectionState.dragState == nil else { return }
                isDragging = false

                if isPartOfMultiSelection {
                    onMultiDragEnd?(value.translation)
                } else {
                    localDragOffset = .zero

                    let startX = dragStartWorldPosition?.x ?? card.positionX
                    let startY = dragStartWorldPosition?.y ?? card.positionY
                    let newWorldX = startX + value.translation.width / scale
                    let newWorldY = startY + value.translation.height / scale

                    onDragOffsetChange?(.zero)
                    onMove(CGPoint(x: newWorldX, y: newWorldY))
                }

                dragStartWorldPosition = nil
            }
    }
}

struct CanvasCardsLayer: View {
    @Binding var cards: [AgentCard]
    let scale: CGFloat
    let offset: CGPoint
    let selectedCardIds: Set<UUID>
    let cardDragOffsets: [UUID: CGSize]
    let onCardMove: (AgentCard, CGPoint) -> Void
    let onCardSelect: (AgentCard, EventModifiers) -> Void

    var body: some View {
        ForEach($cards) { $card in
            CanvasCardView(
                card: $card,
                scale: scale,
                offset: offset,
                isSelected: selectedCardIds.contains(card.id),
                isPartOfMultiSelection: selectedCardIds.count > 1 && selectedCardIds.contains(card.id),
                externalDragOffset: cardDragOffsets[card.id] ?? .zero,
                onMove: { newPosition in
                    onCardMove(card, newPosition)
                },
                onSelect: { modifiers in
                    onCardSelect(card, modifiers)
                }
            )
        }
    }
}
