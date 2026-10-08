// MARK: - StoryboardEditorView.swift

// Main editor view for storyboard movie creation.
//
// StoryboardEditorView provides a professional editor layout:
// - Top: Header with title, params, and model info
// - Center: Video player with playback controls (max height)
// - Bottom: Timeline with scene blocks
//
// ## Layout
// ```
// +----------------------------------------------------------+
// |    Header: Title | Mode • Dimensions • Duration | Model   |
// +----------------------------------------------------------+
// |              Player (centered, max height)                |
// |         with native playback controls                     |
// +----------------------------------------------------------+
// |              Timeline (full width, docked bottom)         |
// +----------------------------------------------------------+
// ```
//
// ## Keyboard Shortcuts
// - ←/→: Previous/next scene
// - ⌘N: Add new scene

import SwiftData
import SwiftUI

/// Main editor view for storyboard creation.
struct StoryboardEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var queueManager: QueueManager

    let storyboard: Storyboard
    @StateObject private var viewModel: StoryboardViewModel

    init(storyboard: Storyboard) {
        self.storyboard = storyboard
        _viewModel = StateObject(wrappedValue: StoryboardViewModel(storyboard: storyboard))
    }

    private var isCompactLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    var body: some View {
        editorLayout
            .toolbar {
                if !isCompactLayout {
                    toolbarContent
                }
            }
            .sheet(isPresented: $viewModel.showAddSceneSheet) {
                ScenePromptSheet(
                    mode: storyboard.mode,
                    dimensions: storyboard.dimensions,
                    fixedFirstFrame: storyboard.mode == .FRAME_BASED
                        ? viewModel.getPreviousSceneLastFrame() : nil,
                    onAdd: { prompt, negativePrompt, firstFrameImage, lastFrameImage, referenceImages in
                        Task {
                            await viewModel.addScene(
                                prompt: prompt,
                                negativePrompt: negativePrompt,
                                firstFrameImage: firstFrameImage,
                                lastFrameImage: lastFrameImage,
                                referenceImages: referenceImages,
                                projectId: projectManager.currentProjectId,
                                queueManager: queueManager,
                                modelContext: modelContext
                            )
                        }
                    }
                )
            }
            .alert("Error", isPresented: $viewModel.showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Export Successful", isPresented: $viewModel.showExportSuccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your storyboard video has been saved successfully.")
            }
            .onAppear {
                viewModel.loadData(modelContext: modelContext)
            }
            .focusedSceneValue(\.storyboardViewModel, viewModel)
            #if os(macOS)
            .onKeyPress(.leftArrow) {
                viewModel.previousScene()
                return .handled
            }
            .onKeyPress(.rightArrow) {
                viewModel.nextScene()
                return .handled
            }
            #endif
    }

    // MARK: - Editor Layout

    private var editorLayout: some View {
        GeometryReader { geometry in
            if geometry.size.width < canvasMinWidth, !isCompactLayout {
                ExpandWindowView()
            } else {
                if isCompactLayout {
                    compactEditorLayout
                } else {
                    VStack(spacing: 0) {
                        headerView

                        Divider()

                        StoryboardPlayerView(viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Divider()

                        StoryboardTimelineView(viewModel: viewModel, isCompactLayout: false)
                    }
                }
            }
        }
    }

    private var compactEditorLayout: some View {
        VStack(spacing: 0) {
            StoryboardPlayerView(viewModel: viewModel)
                .frame(maxWidth: .infinity)
                .frame(height: 280)
            Divider()
            ScrollView {
                if let selectedScene: StoryboardScene = viewModel.selectedScene {
                    compactSelectedSceneSection(scene: selectedScene)
                }
            }
            Divider()
            StoryboardTimelineView(viewModel: viewModel, isCompactLayout: true)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Export video
            Button {
                Task {
                    await viewModel.exportVideo()
                }
            } label: {
                if viewModel.isExporting {
                    GradientSpinner()
                } else {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
            #if os(macOS)
            .help("Export Storyboard Video (⌘E)")
            #endif
            .keyboardShortcut("e", modifiers: .command)
            .disabled(!viewModel.canExport || viewModel.isExporting)

            // Add scene
            Button {
                viewModel.showAddSceneSheet = true
            } label: {
                Label("Add Scene", systemImage: "plus")
            }
            #if os(macOS)
            .help("Add New Scene (⌘N)")
            #endif
            .keyboardShortcut("n", modifiers: .command)
            .disabled(!viewModel.canAddScene)
        }
    }

    private func compactSelectedSceneSection(scene: StoryboardScene) -> some View {
        List {
            Section("Scene Description") {
                LabeledContent("Scene", value: "Scene \(scene.orderIndex + 1)")

                LabeledContent("Prompt") {
                    Text(scene.prompt)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Image(systemName: scene.status.icon)
                            .font(.callout)
                        Text(compactStatusText(scene.status))
                            .font(.body)
                    }
                    .foregroundStyle(scene.status.color)
                }
            }
            .padding(.top, 8)
        }
        .frame(width: .infinity, height: 800)
    }

    private func compactStatusText(_ status: StoryboardSceneStatus) -> String {
        switch status {
        case .PENDING:
            "Pending"
        case .GENERATING:
            "Generating"
        case .COMPLETED:
            "Ready"
        case .FAILED:
            "Failed"
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            // Title
            Text(storyboard.name)
                .font(.headline)

            Spacer()

            // Parameters
            HStack(spacing: 8) {
                parameterTag(storyboard.mode.displayName)
                parameterTag(storyboard.dimensions)
                parameterTag("\(Int(storyboard.sceneDuration))s / scene")
                if !storyboard.resolution.isEmpty {
                    parameterTag(storyboard.resolution)
                }
            }

            Divider()
                .frame(height: 20)

            // Model with provider logo
            HStack(spacing: 6) {
                if let providerCode {
                    Image(providerArtworkName(code: providerCode, variant: .square))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
                if let modelName {
                    Text(modelName)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(tertiarySystemFill)
    }

    private func parameterTag(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var modelName: String? {
        let modelId = storyboard.modelId
        guard !modelId.isEmpty else { return nil }
        return ProviderService.shared.model(by: modelId)?.modelName
    }

    private var providerCode: String? {
        let providerId = storyboard.providerId
        guard !providerId.isEmpty,
              let uuid = UUID(uuidString: providerId),
              let provider = providersById[uuid]
        else { return nil }
        return "\(provider.providerCode)"
    }
}

// MARK: - Focus Key

extension FocusedValues {
    var storyboardViewModel: StoryboardViewModel? {
        get { self[StoryboardViewModelKey.self] }
        set { self[StoryboardViewModelKey.self] = newValue }
    }

    private struct StoryboardViewModelKey: FocusedValueKey {
        typealias Value = StoryboardViewModel
    }
}
