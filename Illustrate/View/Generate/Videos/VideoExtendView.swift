// MARK: - VideoExtendView.swift

// View for extending existing videos with AI.
//
// Allows users to extend previously generated videos by:
// - Selecting a source video (from eligible generations)
// - Providing a new prompt for the extension
// - Configuring duration and other parameters
//
// ## Metadata Requirements
// Video extension requires specific metadata from the original
// generation. Only videos with required metadata are selectable:
// - Sora: soraVideoId
// - Veo: veoGeneratedUri
//
// ## Preload Support
// Can be initialized via NavigationManager.extendVideoPreload
// when extending from GenerationVideoView.

import AlertToast
import KeychainSwift
import PhotosUI
import SwiftData
import SwiftUI

/// Video extension view for continuing existing videos.
struct VideoExtendView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var queueManager: QueueManager
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var navigationManager: NavigationManager
    @EnvironmentObject private var balanceService: BalanceService
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    private var providerKeys: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    @StateObject private var viewModel: BaseVideoViewModel = {
        let vm = BaseVideoViewModel()
        vm.setType = .VIDEO_EXTEND
        return vm
    }()

    @FocusState private var focusedField: PromptField?

    private var selectedProvider: Provider? {
        guard let model = viewModel.getSelectedModel() else { return nil }
        return getProvider(providerId: model.providerId)
    }

    private var providerBalance: Double? {
        guard let model = viewModel.getSelectedModel() else { return nil }
        return balanceService.balance(for: model.providerId, projectId: projectManager.currentProjectId)
    }

    private var lumaActionDisplayName: String {
        if viewModel.usesLumaVideoReframe() { return "reframe" }
        if viewModel.usesLumaVideoEdit() { return "edit" }
        return "extend"
    }

    private var lumaHelpText: String? {
        if viewModel.usesLumaVideoReframe() {
            return "Select a previously generated Luma video to reframe."
        }
        if viewModel.usesLumaVideoEdit() {
            return "Select a previously generated Luma video to edit. The model will transform the video using your prompt."
        }
        return nil
    }

    private var promptHeaderText: String {
        if viewModel.usesLumaVideoReframe() { return "Reframe Instructions" }
        if viewModel.usesLumaVideoEdit() { return "Edit Instructions" }
        return "Extension Instructions"
    }

    private var promptPlaceholderText: String {
        if viewModel.usesLumaVideoReframe() {
            return "Eg. Widen the shot into a cinematic landscape frame while keeping the aircraft centered..."
        }
        if viewModel.usesLumaVideoEdit() {
            return "Eg. Restyle the scene as moonlit 35mm film footage while preserving the camera move..."
        }
        return "Eg. Continue with the camera panning right to reveal a mountain range..."
    }

    private var submitTitle: String {
        if viewModel.usesLumaVideoReframe() { return "Reframe Video" }
        if viewModel.usesLumaVideoEdit() { return "Edit Video" }
        return "Extend Video"
    }

    var body: some View {
        VStack {
            if viewModel.hasSupportedModel, !providerKeys.isEmpty {
                Form {
                    CustomModelSelectionSection(
                        selectedProviderId: $viewModel.selectedProviderId,
                        selectedModelId: $viewModel.selectedModelId,
                        supportedProviders: viewModel.getSupportedProviders(providerKeys: providerKeys),
                        supportedModels: viewModel.getSupportedModels(),
                        onProviderChange: { viewModel.handleProviderChange() },
                        onModelChange: { viewModel.handleModelChange() }
                    )

                    if viewModel.requiresVeoGeneratedVideo() {
                        VeoVideoSourceSection(
                            headerText: "Source Video (Veo Generated)",
                            selectedGeneration: viewModel.selectedPreviousGeneration,
                            hasVideo: viewModel.selectedPreviousGeneration != nil,
                            onSelectVideo: { viewModel.isPreviousGenerationVideoPickerOpen = true },
                            onRemoveVideo: { viewModel.clearGeneratedVideoSelection() }
                        )
                    }

                    if viewModel.requiresSoraGeneratedVideo() {
                        SoraVideoSourceSection(
                            headerText: "Source Video (Sora Generated)",
                            selectedGeneration: viewModel.selectedPreviousGeneration,
                            hasVideo: viewModel.selectedPreviousGeneration != nil,
                            onSelectVideo: { viewModel.isPreviousGenerationVideoPickerOpen = true },
                            onRemoveVideo: { viewModel.clearGeneratedVideoSelection() }
                        )
                    }

                    if viewModel.requiresGeminiInteractionVideo() {
                        GeminiVideoEditSourceSection(
                            selectedGeneration: viewModel.selectedPreviousGeneration,
                            hasVideo: viewModel.selectedPreviousGeneration != nil,
                            onSelectVideo: { viewModel.isPreviousGenerationVideoPickerOpen = true },
                            onRemoveVideo: { viewModel.clearGeneratedVideoSelection() }
                        )
                    }

                    if viewModel.requiresLumaGeneratedVideo() {
                        VeoVideoSourceSection(
                            headerText: "Source Video (Luma Generated)",
                            sourceDisplayName: "Luma",
                            actionDisplayName: lumaActionDisplayName,
                            helpText: lumaHelpText,
                            selectedGeneration: viewModel.selectedPreviousGeneration,
                            hasVideo: viewModel.selectedPreviousGeneration != nil,
                            onSelectVideo: { viewModel.isPreviousGenerationVideoPickerOpen = true },
                            onRemoveVideo: { viewModel.clearGeneratedVideoSelection() }
                        )
                    }

                    if viewModel.supportsVideoUpload() {
                        VideoSourceSection(
                            headerText: "Source Video",
                            selectedVideoURL: viewModel.selectedVideoURL,
                            isProcessing: viewModel.isProcessingVideo,
                            hasVideo: viewModel.selectedVideoURL != nil,
                            onSelectVideo: { viewModel.isVideoPickerOpen = true },
                            onRemoveVideo: { viewModel.clearVideo() }
                        )
                    }

                    if viewModel.supportsReferenceImages() {
                        AdditionalReferenceImagesSection(
                            referenceImages: viewModel.referenceImages,
                            maxReferenceImages: viewModel.maxReferenceImages(),
                            supportedReferenceTypes: viewModel.supportedReferenceTypes(),
                            onAddImage: { viewModel.isReferenceImagePickerOpen = true },
                            onRemoveImage: { id in viewModel.removeReferenceImage(id: id) },
                            onUpdateType: { id, newType in
                                viewModel.updateReferenceImageType(id: id, newType: newType)
                            },
                            onImageDropped: { image in
                                viewModel.processSelectedReferenceImage(image: image)
                            }
                        )
                    }

                    FocusedPromptSection(
                        model: viewModel.getSelectedModel(),
                        headerText: promptHeaderText,
                        promptPlaceholder: promptPlaceholderText,
                        searchPromptPlaceholder: "Eg. Collar tag",
                        negativePlaceholder: "Eg. Don't include any text",
                        prompt: $viewModel.prompt,
                        searchPrompt: $viewModel.searchPrompt,
                        negativePrompt: $viewModel.negativePrompt,
                        focusedField: $focusedField,
                        promptFieldValue: PromptField.prompt,
                        searchFieldValue: PromptField.searchPrompt,
                        negativeFieldValue: PromptField.negativePrompt
                    )

                    AvailableToolsSection(
                        model: viewModel.getSelectedModel(),
                        selectedTools: $viewModel.selectedTools
                    )

                    VideoParametersSection(
                        model: viewModel.getSelectedModel(),
                        dimensions: $viewModel.dimensions,
                        selectedResolution: $viewModel.selectedResolution,
                        selectedFPS: $viewModel.selectedFPS,
                        durationSeconds: $viewModel.durationSeconds,
                        generateAudio: $viewModel.generateAudio,
                        motion: .constant(0),
                        stickyness: .constant(0),
                        quality: $viewModel.quality,
                        variant: $viewModel.variant,
                        style: $viewModel.style,
                        inputFidelity: $viewModel.inputFidelity,
                        moderation: $viewModel.moderation,
                        guidanceValue: $viewModel.guidanceValue,
                        safetyValue: $viewModel.safetyValue,
                        seedValue: $viewModel.seedValue,
                        modelPromptEnhance: $viewModel.modelPromptEnhance
                    )

                    LumaVideoOutputControlsSection(
                        hdr: $viewModel.lumaHDR,
                        exrExport: $viewModel.lumaEXRExport,
                        loop: $viewModel.lumaLoop,
                        supportsHDR: viewModel.supportsLumaHDR(),
                        supportsLoop: viewModel.supportsLumaLoop(),
                        validationMessage: viewModel.lumaOutputControlsValidationMessage()
                    )

                    EstimatedCostSection(
                        cost: (viewModel.getSelectedModel()?.modelCode ?? .GOOGLE_VEO_31).formattedVideoCost(
                            durationSeconds: viewModel.durationSeconds,
                            numberOfVideos: 1,
                            dimensions: viewModel.dimensions,
                            resolution: viewModel.selectedResolution,
                            lumaHDR: viewModel.lumaHDR,
                            lumaEXRExport: viewModel.lumaEXRExport,
                            lumaLoop: viewModel.lumaLoop
                        ),
                        estimatedCostValue: (viewModel.getSelectedModel()?.modelCode ?? .GOOGLE_VEO_31).rawVideoCost(
                            durationSeconds: viewModel.durationSeconds,
                            numberOfVideos: 1,
                            dimensions: viewModel.dimensions,
                            resolution: viewModel.selectedResolution,
                            lumaHDR: viewModel.lumaHDR,
                            lumaEXRExport: viewModel.lumaEXRExport,
                            lumaLoop: viewModel.lumaLoop
                        ),
                        balance: providerBalance,
                        creditCurrency: selectedProvider?.creditCurrency ?? .USD
                    )

                    SubmitGenerationButton(
                        title: submitTitle,
                        isDisabled: !viewModel.canGenerate
                    ) {
                        focusedField = nil
                        viewModel.submitToQueue(
                            providerKeys: providerKeys,
                            projectId: projectManager.currentProjectId,
                            queueManager: queueManager,
                            modelContext: modelContext
                        )
                    }
                }
                .formStyle(.grouped)
                .transaction { $0.disablesAnimations = true }
                .safeAreaPadding(EdgeInsets(top: 0, leading: 0, bottom: 64, trailing: 0))
                .keyboardDoneToolbar { focusedField = nil }
                .photosPicker(
                    isPresented: $viewModel.isVideoPickerOpen,
                    selection: $viewModel.selectedVideoItem,
                    matching: .videos
                )
                .onChange(of: viewModel.selectedVideoItem) {
                    Task {
                        await viewModel.processSelectedVideo()
                    }
                }
                .sheet(isPresented: $viewModel.isPreviousGenerationVideoPickerOpen) {
                    ExtendGenerationVideoPicker(
                        requiredMetadataKeys: viewModel.getRequiredMetadataKeys()
                    ) { generation in
                        viewModel.selectGeneratedVideo(generation)
                    }
                }
                .imageSelection(
                    id: "referenceImage",
                    isPickerOpen: $viewModel.isReferenceImagePickerOpen,
                    onImageSelected: { image in
                        viewModel.processSelectedReferenceImage(image: image)
                    }
                )
                .sheet(isPresented: $viewModel.isReferenceImageCropSheetOpen) {
                    if let pendingImage = viewModel.pendingReferenceImage {
                        ImageCropAdapter(
                            image: pendingImage,
                            cropDimensions: viewModel.dimensions,
                            flexibleDimensions: viewModel.supportsFlexibleReferenceDimensions(),
                            sessionId: viewModel.referenceImageCropSessionId,
                            onCropConfirm: { image in
                                viewModel.handleReferenceImageCropConfirm(image: image)
                            },
                            onCropCancel: {
                                viewModel.cancelReferenceImageCropping()
                            }
                        )
                    }
                }

            } else {
                PendingProviderView(setType: .VIDEO_EXTEND)
            }
        }
        .onAppear {
            providerKeysCache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            viewModel.initialize(providerKeys: providerKeys)

            if let preload = navigationManager.extendVideoPreload {
                Task {
                    await viewModel.applyPreload(preload, providerKeys: providerKeys)
                }
                navigationManager.clearExtendVideoPreload()
            }
        }
        .onChange(of: projectManager.currentProjectId) { _, newProjectId in
            providerKeysCache.loadIfNeeded(projectId: newProjectId, modelContext: modelContext, force: true)
        }
        .onChange(of: viewModel.durationSeconds) { _, _ in
            viewModel.enforceLumaOutputConstraints()
        }
        .onChange(of: viewModel.selectedResolution) { _, _ in
            viewModel.enforceLumaOutputConstraints()
        }
        .onChange(of: viewModel.lumaHDR) { _, _ in
            viewModel.enforceLumaOutputConstraints()
        }
        .onChange(of: viewModel.lumaEXRExport) { _, _ in
            viewModel.enforceLumaOutputConstraints()
        }
        .onChange(of: viewModel.lumaLoop) { _, _ in
            viewModel.enforceLumaOutputConstraints()
        }
        .videoGenerationNavigation(
            isPresented: $viewModel.isNavigationActive,
            setId: $viewModel.selectedSetId,
            onDisappear: { viewModel.resetNavigation() }
        )
        #if os(macOS)
        .onExitCommand {
            dismiss()
        }
        #endif
        .navigationTitle(labelForItem(.videoExtend))
    }
}
