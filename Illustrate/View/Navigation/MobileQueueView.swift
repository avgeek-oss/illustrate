// MARK: - MobileQueueView.swift

// Generation queue tab for mobile devices.
//
// Full-screen queue view for iPhone/iPad:
// - In-progress generations with progress
// - Completed generations (tap to view)
// - Failed generations
// - Tap completed to navigate to result
//
// ## Platform
// iOS only - macOS uses QueueSidebarView in inspector.

import AvgeekDesignSystem
import AvgeekLocalizationCore
import AvgeekLocalizationUI
import SwiftUI

private let mobileDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd MMM, HH:mm"
    return formatter
}()

#if !os(macOS)
/// Full-screen generation queue for mobile devices.
struct MobileQueueView: View {
    @EnvironmentObject var queueManager: QueueManager
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                if queueManager.items.isEmpty {
                    AvgeekEmptyStateView(
                        icon: "tray",
                        title: "No items in queue",
                        message: "Submit a prompt and the results will appear here."
                    )
                } else {
                    queueListView
                }
            }
            .navigationTitle("Queue")
            .navigationDestination(for: EnumNavigationItem.self) { item in
                viewForItem(item)
            }
        }
    }

    private var queueListView: some View {
        let partitioned = queueManager.partitionedItems

        return List {
            if !partitioned.inProgress.isEmpty {
                Section {
                    ForEach(partitioned.inProgress, id: \.id) { item in
                        MobileQueueItemRow(item: item)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            queueManager.cancelItem(partitioned.inProgress[index])
                        }
                    }
                } header: {
                    MobileQueueSectionHeader(title: "In Progress", count: partitioned.inProgress.count)
                }
            }

            if !partitioned.successful.isEmpty {
                Section {
                    ForEach(partitioned.successful, id: \.id) { item in
                        MobileQueueItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if item.isVideoGeneration, let setId = item.resultVideoSetId {
                                    navigationPath.append(EnumNavigationItem.generationVideo(setId: setId))
                                } else if let setId = item.resultSetId {
                                    navigationPath.append(EnumNavigationItem.generationImage(setId: setId))
                                }
                                queueManager.removeItem(item)
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            queueManager.removeItem(partitioned.successful[index])
                        }
                    }
                } header: {
                    HStack {
                        MobileQueueSectionHeader(title: "Completed", count: partitioned.successful.count)
                        Spacer()
                        Button(role: .destructive) {
                            queueManager.clearAllCompleted()
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                        .font(.subheadline)
                    }
                }
            }

            if !partitioned.failed.isEmpty {
                Section {
                    ForEach(partitioned.failed, id: \.id) { item in
                        MobileQueueItemRow(item: item)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            queueManager.removeItem(partitioned.failed[index])
                        }
                    }
                } header: {
                    HStack {
                        MobileQueueSectionHeader(title: "Failed", count: partitioned.failed.count)
                        Spacer()
                        Button(role: .destructive) {
                            queueManager.clearAllFailed()
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
#endif

struct MobileQueueSectionHeader: View {
    let title: String
    let count: Int

    @AppLocalized private var localize

    var body: some View {
        HStack(spacing: 4) {
            Text(localize(title))
            Text("(\(count))")
                .foregroundStyle(.tertiary)
        }
    }
}

struct MobileQueueItemRow: View {
    @ObservedObject var item: QueueItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            statusIcon
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.prompt)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(mobileDateFormatter.string(from: item.createdAt))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let error = item.errorMessage, item.status == .FAILED {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            if item.status == .SUCCESSFUL {
                Image(systemName: "chevron.right")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                    .padding(.trailing, 8)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .IN_PROGRESS:
            if let progress = item.progress, progress > 0 {
                ZStack {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 3)

                    Circle()
                        .trim(from: 0, to: CGFloat(progress) / 100.0)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: progress)

                    Text("\(progress)")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                .frame(width: 32, height: 32)
            } else {
                GradientSpinner()
            }
        case .SUCCESSFUL:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        case .FAILED:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.red)
        }
    }
}
