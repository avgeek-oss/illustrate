// MARK: - FailedRequestsView.swift

// View for reviewing and debugging failed generation requests.
//
// Shows a table of all failed requests with:
// - Error message and status code
// - Model and prompt used
// - Creation timestamp
// - Raw API response
//
// ## Debugging Features
// - View raw response for error details
// - Retry generation with same parameters
//
// ## Bulk Actions
// - Clear all failed requests
// - Multi-select deletion

import AvgeekDesignSystem
import OSLog
import SwiftData
import SwiftUI

/// Table view of failed generation requests with debugging info.
struct FailedRequestsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var navigationManager: NavigationManager
    @Query(sort: \FailedRequest.createdAt, order: .reverse) private var allFailedRequests: [FailedRequest]

    @State private var selectedRequests: Set<FailedRequest.ID> = []
    @State private var showDeleteConfirmation = false
    @State private var sortOrder = [KeyPathComparator(\FailedRequest.createdAt, order: .reverse)]

    /// Popup states
    @State private var selectedRawResponse: IdentifiableString?

    private var failedRequests: [FailedRequest] {
        allFailedRequests.filter { $0.projectId == projectManager.currentProjectId }
    }

    private var shouldUseMobileList: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    var body: some View {
        VStack {
            if failedRequests.isEmpty {
                AvgeekEmptyStateView(
                    icon: "checkmark.circle",
                    title: "No failed requests",
                    message: "All your generation requests have been successful!"
                )
            } else if shouldUseMobileList {
                mobileListView
            } else {
                tableView
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if !failedRequests.isEmpty {
                    Button {
                        showDeleteConfirmation = true
                        selectedRequests = Set(failedRequests.map(\.id))
                    } label: {
                        Label("Clear All", systemImage: "trash")
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete \(selectedRequests.count) failed request\(selectedRequests.count > 1 ? "s" : "")?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteSelectedRequests()
            }
            Button("Cancel", role: .cancel) {
                showDeleteConfirmation = false
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(item: $selectedRawResponse) { item in
            DebugInfoPopup(
                title: "API Response",
                content: item.value,
                isPresented: Binding(
                    get: { selectedRawResponse != nil },
                    set: { if !$0 { selectedRawResponse = nil } }
                )
            )
        }
        .navigationTitle("Failed Requests")
    }

    private var mobileListView: some View {
        List {
            ForEach(failedRequests) { request in
                if let rawResponse = request.rawResponse, !rawResponse.isEmpty {
                    NavigationLink {
                        DebugInfoDetailView(title: "API Response", content: rawResponse)
                    } label: {
                        MobileFailedRequestRow(
                            request: request,
                            modelName: ProviderService.shared.model(by: request.modelId)?.modelName ?? "Unknown"
                        )
                    }
                    .contextMenu {
                        failedRequestContextMenu(for: request, includeRawResponseAction: false)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteRequest(request)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } else {
                    MobileFailedRequestRow(
                        request: request,
                        modelName: ProviderService.shared.model(by: request.modelId)?.modelName ?? "Unknown"
                    )
                    .contextMenu {
                        failedRequestContextMenu(for: request, includeRawResponseAction: false)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteRequest(request)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var tableView: some View {
        Table(of: FailedRequest.self, selection: $selectedRequests, sortOrder: $sortOrder) {
            TableColumn("Date", value: \.createdAt) { request in
                Text(request.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            .width(min: 160, ideal: 180, max: 200)

            TableColumn("Model", value: \.modelId) { request in
                Text(ProviderService.shared.model(by: request.modelId)?.modelName ?? "Unknown")
            }
            .width(min: 140, ideal: 180, max: 220)

            TableColumn("Prompt", value: \.prompt) { request in
                Text(request.prompt)
                    .lineLimit(2)
            }
            .width(min: 200, ideal: 300, max: 500)

            TableColumn("Error Info", value: \.errorMessage) { request in
                Text(request.errorMessage)
                    .lineLimit(5)
            }
            .width(min: 200, ideal: 300, max: 400)

            TableColumn("Actions") { request in
                HStack(spacing: 8) {
                    if let rawResponse = request.rawResponse, !rawResponse.isEmpty {
                        Button {
                            selectedRawResponse = IdentifiableString(value: rawResponse)
                        } label: {
                            Text("API Response")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .width(min: 220, ideal: 240, max: 280)
        } rows: {
            ForEach(failedRequests) { request in
                TableRow(request)
                    .contextMenu {
                        failedRequestContextMenu(for: request, includeRawResponseAction: true)
                    }
            }
        }
        .onChange(of: sortOrder) { _, _ in
            // Sort order changed
        }
    }

    @ViewBuilder
    private func failedRequestContextMenu(
        for request: FailedRequest,
        includeRawResponseAction: Bool
    ) -> some View {
        if includeRawResponseAction, let rawResponse = request.rawResponse, !rawResponse.isEmpty {
            Button {
                selectedRawResponse = IdentifiableString(value: rawResponse)
            } label: {
                Label("API Response", systemImage: "doc.text")
            }
        }

        Button {
            copyToClipboard(request.prompt)
            showToast(.success("Copied to clipboard"))
        } label: {
            Label("Copy Prompt", systemImage: "text.quote")
        }
        .disabled(request.prompt.isEmpty)

        Button {
            copyToClipboard(request.errorMessage)
            showToast(.success("Error copied to clipboard"))
        } label: {
            Label("Copy Error", systemImage: "exclamationmark.triangle")
        }
        .disabled(request.errorMessage.isEmpty)

        Divider()

        Button(role: .destructive) {
            deleteRequest(request)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func copyToClipboard(_ value: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #else
        UIPasteboard.general.string = value
        #endif
    }

    private func deleteRequest(_ request: FailedRequest) {
        let willClearAll = failedRequests.count == 1

        modelContext.delete(request)

        do {
            try modelContext.save()

            if willClearAll {
                navigationManager.navigate(to: .dashboard)
            }
        } catch {
            AppLogger.data.error("Error deleting failed request: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteSelectedRequests() {
        let requestsToDelete = failedRequests.filter { selectedRequests.contains($0.id) }
        let willClearAll = requestsToDelete.count == failedRequests.count

        for request in requestsToDelete {
            modelContext.delete(request)
        }

        selectedRequests.removeAll()

        do {
            try modelContext.save()

            if willClearAll {
                navigationManager.navigate(to: .dashboard)
            }
        } catch {
            AppLogger.data.error("Error deleting failed requests: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private struct MobileFailedRequestRow: View {
    let request: FailedRequest
    let modelName: String

    private var promptText: String {
        request.prompt.isEmpty ? "Prompt not added" : request.prompt
    }

    private var providerCode: String? {
        getProvider(modelId: request.modelId).map { "\($0.providerCode)".lowercased() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(promptText)
                .font(.headline)
                .foregroundStyle(request.prompt.isEmpty ? .secondary : .primary)
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

                Text(request.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.body)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

private struct DebugInfoDetailView: View {
    let title: String
    let content: String

    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                    #else
                    UIPasteboard.general.string = content
                    #endif
                    showToast(.success("Copied to clipboard"))
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        }
    }
}

// MARK: - Debug Info Popup

struct DebugInfoPopup: View {
    let title: String
    let content: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(title)
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
                        NSPasteboard.general.setString(content, forType: .string)
                        #else
                        UIPasteboard.general.string = content
                        #endif
                        showToast(.success("Copied to clipboard"))
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, idealWidth: 800, maxWidth: 1000)
        .frame(minHeight: 400, idealHeight: 600, maxHeight: 800)
        #endif
    }
}
