// MARK: - QueueSidebarView.swift

// Sidebar view displaying the generation queue.
//
// Shows all queued, in-progress, completed, and failed generations
// in a scrollable list. Appears in the right inspector panel on desktop.
//
// ## Sections
// - In Progress: Currently generating items with progress
// - Completed: Successfully generated items (tap to view)
// - Failed: Failed items with error details
//
// ## Features
// - Cancel in-progress items
// - Navigate to completed results
// - View raw API response for debugging
// - Clear completed/failed items
//
// ## Queue Item States
// - .submitted: Waiting to start
// - .IN_PROGRESS: Currently generating
// - .succeeded: Completed successfully
// - .FAILED: Generation failed
// - .cancelled: User cancelled

import AvgeekDesignSystem
import AvgeekLocalizationCore
import AvgeekLocalizationUI
import SwiftUI

/// Queue display view showing all generation requests by status.
struct QueueSidebarView: View {
    @ObservedObject var queueManager: QueueManager
    @EnvironmentObject var navigationManager: NavigationManager

    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    @State private var hoveredItemId: UUID?
    @State private var selectedErrorItem: QueueItem?

    var body: some View {
        VStack(spacing: 0) {
            if queueManager.items.isEmpty {
                AvgeekEmptyStateView(
                    icon: "tray",
                    title: "No items in queue",
                    message: "Once you request for media generation, it will appear in the queue."
                )
            } else {
                queueListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(systemBackground)
        .sheet(item: $selectedErrorItem) { item in
            ErrorDetailsSheet(
                item: item,
                isPresented: Binding(
                    get: { selectedErrorItem != nil },
                    set: { if !$0 { selectedErrorItem = nil } }
                )
            )
        }
    }

    private var queueListView: some View {
        let partitioned = queueManager.partitionedItems

        return ScrollView {
            LazyVStack(spacing: 16, pinnedViews: []) {
                if !partitioned.inProgress.isEmpty {
                    QueueSection(
                        title: "In Progress",
                        items: partitioned.inProgress,
                        hoveredItemId: $hoveredItemId,
                        onItemTap: { _ in },
                        onItemRemove: { item in
                            queueManager.cancelItem(item)
                        }
                    )
                }

                if !partitioned.successful.isEmpty {
                    QueueSection(
                        title: "Completed",
                        items: partitioned.successful,
                        hoveredItemId: $hoveredItemId,
                        onItemTap: { item in
                            #if os(macOS)
                            if item.isVideoGeneration, let setId = item.resultVideoSetId {
                                let windowData = GenerationWindowData(isVideo: true, setId: setId)
                                openWindow(value: windowData)
                            } else if let setId = item.resultSetId {
                                let windowData = GenerationWindowData(isVideo: false, setId: setId)
                                openWindow(value: windowData)
                            }
                            #else
                            if item.isVideoGeneration, let setId = item.resultVideoSetId {
                                navigationManager.pushDetail(.generationVideo(setId: setId))
                            } else if let setId = item.resultSetId {
                                navigationManager.pushDetail(.generationImage(setId: setId))
                            }
                            #endif
                        },
                        onItemRemove: { item in
                            queueManager.removeItem(item)
                        },
                        showClearAll: true,
                        onClearAll: {
                            queueManager.clearAllCompleted()
                        }
                    )
                }

                if !partitioned.failed.isEmpty {
                    QueueSection(
                        title: "Failed",
                        items: partitioned.failed,
                        hoveredItemId: $hoveredItemId,
                        onItemTap: { _ in },
                        onItemRemove: { item in
                            queueManager.removeItem(item)
                        },
                        onShowError: { item in
                            selectedErrorItem = item
                        },
                        showClearAll: true,
                        onClearAll: {
                            queueManager.clearAllFailed()
                        }
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .scrollContentBackground(.hidden)
    }
}

struct QueueSection: View {
    let title: String
    let items: [QueueItem]
    @Binding var hoveredItemId: UUID?
    let onItemTap: (QueueItem) -> Void
    let onItemRemove: (QueueItem) -> Void
    var onShowError: ((QueueItem) -> Void)?
    var showClearAll = false
    var onClearAll: (() -> Void)?

    @AppLocalized private var localize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader

            ForEach(items, id: \.id) { item in
                QueueItemRow(
                    data: QueueItemRowData(from: item),
                    isHovered: hoveredItemId == item.id,
                    onTap: { onItemTap(item) },
                    onRemove: { onItemRemove(item) },
                    onShowError: { onShowError?(item) }
                )
                .id(item.id)
                .onHover { isHovered in
                    if isHovered {
                        hoveredItemId = item.id
                    } else if hoveredItemId == item.id {
                        hoveredItemId = nil
                    }
                }
            }
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(localize(title))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text("(\(items.count))")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Spacer()

            if showClearAll, let clearAll = onClearAll {
                Button(role: .destructive) {
                    clearAll()
                } label: {
                    Image(systemName: "trash")
                }
                .font(.subheadline)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
    }
}

struct QueueItemRowData: Equatable {
    let id: UUID
    let status: QueueItemStatus
    let prompt: String
    let errorMessage: String?
    let rawResponse: String?
    let isVideoGeneration: Bool
    let progress: Int?
    let resultSetId: UUID?
    let resultVideoSetId: UUID?
    let resultGenerationId: UUID?

    init(from item: QueueItem) {
        id = item.id
        status = item.status
        prompt = item.prompt
        errorMessage = item.errorMessage
        rawResponse = item.rawResponse
        isVideoGeneration = item.isVideoGeneration
        progress = item.progress
        resultSetId = item.resultSetId
        resultVideoSetId = item.resultVideoSetId
        resultGenerationId = item.resultGenerationId
    }
}

struct QueueItemRow: View, Equatable {
    let data: QueueItemRowData
    let isHovered: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    let onShowError: () -> Void

    @State private var showPreviewPopover = false

    static func == (lhs: QueueItemRow, rhs: QueueItemRow) -> Bool {
        lhs.data == rhs.data && lhs.isHovered == rhs.isHovered
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            statusIcon

            Text(data.prompt)
                .font(.body)
                .lineLimit(1)
                .foregroundStyle(.primary)
                .textSelection(.disabled)

            Spacer(minLength: 4)

            if data.status == .SUCCESSFUL {
                #if os(macOS)
                if let setId = data.isVideoGeneration ? data.resultVideoSetId : data.resultSetId,
                   let generationId = data.resultGenerationId
                {
                    Button("Preview") {
                        showPreviewPopover = true
                    }
                    .font(.body)
                    .buttonStyle(.bordered)
                    .popover(isPresented: $showPreviewPopover) {
                        GenerationPreviewPopover(
                            setId: setId,
                            generationId: generationId,
                            isVideo: data.isVideoGeneration,
                            isPresented: $showPreviewPopover,
                            onNavigateToDetails: { onTap() }
                        )
                    }
                } else {
                    Button(data.isVideoGeneration ? "View video" : "View image") {
                        onTap()
                    }
                    .font(.body)
                    .buttonStyle(.bordered)
                }
                #else
                Button("Preview") {
                    onTap()
                }
                .font(.body)
                .buttonStyle(.bordered)
                #endif
            }

            if data.status == .FAILED {
                Button("Error") {
                    onShowError()
                }
                .font(.body)
                .buttonStyle(.bordered)
            }

            if data.status == .IN_PROGRESS {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.body)
                        .foregroundStyle(isHovered ? Color.primary : .clear)
                }
                .buttonStyle(.plain)
                .help("Cancel")
            }
        }
        .padding(.all, 8)
        .background(backgroundFill, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch data.status {
        case .IN_PROGRESS:
            if let progress = data.progress, progress > 0 {
                ZStack {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 3)

                    Circle()
                        .trim(from: 0, to: CGFloat(progress) / 100.0)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: progress)

                    Text("\(progress)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                .frame(width: 18, height: 18)
            } else {
                GradientSpinner()
            }
        case .SUCCESSFUL:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 18, height: 18)
        case .FAILED:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.red)
                .frame(width: 18, height: 18)
        }
    }

    private var backgroundFill: Color {
        switch data.status {
        case .IN_PROGRESS:
            Color.accentColor.opacity(isHovered ? 0.2 : 0.1)
        case .SUCCESSFUL:
            Color.green.opacity(isHovered ? 0.1 : 0.06)
        case .FAILED:
            Color.red.opacity(isHovered ? 0.1 : 0.06)
        }
    }
}

// MARK: - Error Details Sheet

struct ErrorDetailsSheet: View {
    let item: QueueItem
    @Binding var isPresented: Bool

    private var fullContent: String {
        var content = ""
        if let error = item.errorMessage {
            content += "Error: \(error)\n\n"
        }
        if let response = item.rawResponse, !response.isEmpty {
            content += "API Response:\n\(response)"
        }
        return content
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let error = item.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Error Message")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            Text(error)
                                .font(.body)
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                        }
                    }

                    if let response = item.rawResponse, !response.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Response")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            Text(response)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Error Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(fullContent, forType: .string)
                        #else
                        UIPasteboard.general.string = fullContent
                        #endif
                        showToast(.success("Copied to clipboard"))
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, idealWidth: 700, maxWidth: 900)
        .frame(minHeight: 350, idealHeight: 500, maxHeight: 700)
        #endif
    }
}
