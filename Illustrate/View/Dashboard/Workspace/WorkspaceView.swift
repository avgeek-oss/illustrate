// MARK: - WorkspaceView.swift

// Dashboard/home view showing project overview and quick actions.
//
// WorkspaceView is the landing page showing:
// - Time-based greeting
// - Project name and stats
// - Workspace shortcuts
// - Brand shortcuts
// - Quick action shortcuts
// - Onboarding prompts (if needed)
//
// ## Onboarding
// If no providers are connected or no generations exist, shows
// onboarding cards to help users get started.

import IllustrateProviders
import SwiftData
import SwiftUI

/// Dashboard view with project overview and quick actions.
struct WorkspaceView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @EnvironmentObject private var projectManager: ProjectManager
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    @State private var activeProjectSheet: WorkspaceProjectSheet?
    @State private var showDeleteConfirmation = false
    @State private var newProjectName = ""
    @State private var renameProjectName = ""

    private var providerKeys: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    var timeBasedGreeting: String {
        let hour: Int = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 18 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    private func columns(for width: CGFloat) -> [GridItem] {
        #if os(macOS)
        var columnCount = 5
        if width < 500 {
            columnCount = 1
        } else if width < 650 {
            columnCount = 2
        } else if width < 800 {
            columnCount = 3
        } else if width < 1150 {
            columnCount = 4
        }
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
        #else
        return Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: UIDevice.current.userInterfaceIdiom == .pad ? 3 : 1
        )
        #endif
    }

    private var shouldShowOnboarding: Bool {
        providerKeys.isEmpty
    }

    private var isDefaultProject: Bool {
        projectManager.currentProject?.isDefault ?? true
    }

    private var homeWorkspaceItems: [EnumNavigationItem] {
        [
            .agentCanvas,
            .chatThreads,
            .flowCanvas,
            .realtimeEdit,
            .bulkSessions,
            .bulkEdits,
            .storyboard,
            .productPhotoshoots,
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(timeBasedGreeting), let's Illustrate ✍🏼")
                            .fontWeight(.semibold)
                        Text("What do you want to generate today?")
                    }

                    if shouldShowOnboarding {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Welcome, let's get you started.")
                                .font(.caption)
                                .textCase(.uppercase)
                                .opacity(0.5)
                            OnboardingView(width: geometry.size.width)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quick Actions")
                            .font(.caption)
                            .textCase(.uppercase)
                            .opacity(0.5)
                        LazyVGrid(columns: columns(for: geometry.size.width), spacing: 12) {
                            ForEach(sectionItems(section: EnumNavigationSection.QuickActions), id: \.self) {
                                item in
                                WorkspaceGenerateShortcut(item: item)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Workspace")
                            .font(.caption)
                            .textCase(.uppercase)
                            .opacity(0.5)
                        LazyVGrid(columns: columns(for: geometry.size.width), spacing: 12) {
                            ForEach(homeWorkspaceItems, id: \.self) { item in
                                WorkspaceGenerateShortcut(item: item)
                            }
                        }
                    }

                    #if os(macOS)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Brand")
                            .font(.caption)
                            .textCase(.uppercase)
                            .opacity(0.5)
                        LazyVGrid(columns: columns(for: geometry.size.width), spacing: 12) {
                            ForEach(sectionItems(section: EnumNavigationSection.Brand), id: \.self) { item in
                                WorkspaceGenerateShortcut(item: item)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Project")
                            .font(.caption)
                            .textCase(.uppercase)
                            .opacity(0.5)
                        LazyVGrid(columns: columns(for: geometry.size.width), spacing: 12) {
                            ForEach(sectionItems(section: EnumNavigationSection.Project), id: \.self) { item in
                                WorkspaceGenerateShortcut(item: item)
                            }
                        }
                    }
                    #endif
                }
                .padding(.all, 16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .navigationTitle("Illustrate")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button {
                        newProjectName = ""
                        activeProjectSheet = .create
                    } label: {
                        Label("New Project", systemImage: "plus")
                    }

                    Divider()

                    Button {
                        if let currentProject: Project = projectManager.currentProject {
                            renameProjectName = currentProject.name
                            activeProjectSheet = .rename
                        }
                    } label: {
                        Label("Rename Project", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Project", systemImage: "trash")
                    }
                    .disabled(isDefaultProject)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $activeProjectSheet) { sheet in
            switch sheet {
            case .create:
                CreateProjectSheet(
                    projectName: $newProjectName,
                    onCancel: { activeProjectSheet = nil },
                    onCreate: {
                        if !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           let newProject = projectManager.createProject(
                               name: newProjectName,
                               modelContext: modelContext
                           )
                        {
                            projectManager.switchProject(to: newProject)
                        }
                        activeProjectSheet = nil
                    }
                )
            case .rename:
                RenameProjectSheet(
                    projectName: $renameProjectName,
                    onCancel: { activeProjectSheet = nil },
                    onRename: {
                        if let project: Project = projectManager.currentProject,
                           !renameProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        {
                            _ = projectManager.renameProject(
                                project, to: renameProjectName, modelContext: modelContext
                            )
                        }
                        activeProjectSheet = nil
                    }
                )
            }
        }
        .confirmationDialog(
            "Delete Project?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let project: Project = projectManager.currentProject {
                    _ = projectManager.deleteProject(project, modelContext: modelContext)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This will permanently delete the project '\(projectManager.currentProject?.name ?? "")' along with all its provider keys, generations, and associated files."
            )
        }
        .onAppear {
            providerKeysCache.loadIfNeeded(
                projectId: projectManager.currentProjectId, modelContext: modelContext
            )
        }
        .onChange(of: projectManager.currentProjectId) { _, newProjectId in
            providerKeysCache.loadIfNeeded(
                projectId: newProjectId, modelContext: modelContext, force: true
            )
        }
    }
}

private enum WorkspaceProjectSheet: Identifiable {
    case create
    case rename

    var id: String {
        switch self {
        case .create:
            "create"
        case .rename:
            "rename"
        }
    }
}

struct WorkspaceGenerateShortcut: View {
    @EnvironmentObject private var navigationManager: NavigationManager

    var item: EnumNavigationItem
    @State private var isHovered = false

    private var coverImage: String? {
        coverImageForItem(item)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let coverImage: String {
                Image(coverImage)
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(21.0 / 9.0, contentMode: .fit)
                    .clipped()
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(labelForItem(item))
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                Text(subLabelForItem(item))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(0.8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .frame(minHeight: coverImage != nil ? nil : 72, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.accentColor.opacity(isHovered ? 0.1 : 0))
        .background(tertiarySystemFill)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(labelForItem(item))
        .accessibilityHint(subLabelForItem(item))
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            navigationManager.navigate(to: item)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct WorkspaceProviderShortcut: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    private var providerKeys: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    @State var isProviderDetailsOpen = false
    @State private var isHovered = false

    var item: Provider
    var setType: EnumSetType?
    var showModels: Bool

    var isConnected: Bool {
        providerKeys.contains { $0.providerId == item.providerId }
    }

    func getModelsForProvider() -> [ProviderModel] {
        if setType != nil {
            ProviderService.shared.models(for: setType!).filter { $0.providerId == item.providerId }
        } else {
            ProviderService.shared.models(for: item.providerId)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(providerArtworkName(code: item.providerCode, variant: .square))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text(item.providerName)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            let modelCount = getModelsForProvider().count
            Text("\(modelCount) model\(modelCount == 1 ? "" : "s")")
                .multilineTextAlignment(.leading)
                .opacity(0.7)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(minHeight: 72, maxHeight: .infinity, alignment: .topLeading)
        .background(
            Color.mint.opacity(
                isConnected ? (isHovered ? 0.2 : 0.1) : (isHovered ? 0.1 : 0)
            )
        )
        .background(tertiarySystemFill)
        .cornerRadius(8)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.providerName), \(getModelsForProvider().count) models")
        .accessibilityHint(isConnected ? "Connected" : "Not connected")
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            DispatchQueue.main.async {
                isProviderDetailsOpen = true
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .sheet(isPresented: $isProviderDetailsOpen) {
            ProviderDetailsView(isPresented: $isProviderDetailsOpen, selectedProvider: item)
        }
    }
}
