// MARK: - ImageGenerateView.swift

// Main view for image generation with full parameter controls.
//
// This is the primary interface for generating images. It provides:
// - Prompt input with character limit
// - Model selection (filtered by connected providers)
// - Dimension/aspect ratio selection
// - Quality, style, and variant options
// - Source image and mask support (for img2img/inpainting)
// - Reference images (for style transfer)
// - Advanced parameters (steps, guidance, seed)
//
// ## ViewModel
// Uses BaseImageViewModel to manage state and submit generations.
// The ViewModel handles model capability queries and queue submission.
//
// ## Preload Support
// Can be initialized with a GenerateImagePreload to pre-fill values
// when editing an existing generation.
//
// ## Mask Editing
// When maskEnabled is true and model supports masks, shows a
// drawing overlay for creating inpainting masks.

import AlertToast
import IllustrateProviders
import KeychainSwift
import PhotosUI
import SwiftData
import SwiftUI

/// Full-featured image generation view with all parameters.
struct ImageGenerateView: View {
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

    @StateObject private var viewModel: BaseImageViewModel = {
        let vm = BaseImageViewModel()
        vm.setType = .IMAGE_GENERATE
        return vm
    }()

    @FocusState private var focusedField: PromptField?

    @State private var maskEnabled = false
    @State private var maskPath = Path()
    @State private var canvasSize = CGSize.zero

    @State private var expandLeft = true
    @State private var expandRight = true
    @State private var expandTop = true
    @State private var expandBottom = true

    @State private var droppedSourceImage: PlatformImage?
    @State private var droppedReferenceImage: PlatformImage?
    @State private var showQueueEducation = false

    private var modelSupportsMask: Bool {
        viewModel.getSelectedModel()?.modelParams.supportsMask ?? false
    }

    private var modelSupportsExpandDirections: Bool {
        viewModel.getSelectedModel()?.modelParams.supportsExpandDirections ?? false
    }

    private var modelSupportsSourceImage: Bool {
        viewModel.getSelectedModel()?.modelParams.supportsSourceImage ?? false
    }

    private var selectedProvider: Provider? {
        guard let model = viewModel.getSelectedModel() else { return nil }
        return getProvider(providerId: model.providerId)
    }

    private var providerBalance: Double? {
        guard let model = viewModel.getSelectedModel() else { return nil }
        return balanceService.balance(for: model.providerId)
    }

    private var selectedProviderSecret: String? {
        guard let model = viewModel.getSelectedModel() else { return nil }
        let key = ProjectManager.keychainKey(
            projectId: projectManager.currentProjectId,
            providerId: model.providerId
        )
        return viewModel.keychain.get(key)
    }

    @ViewBuilder
    private var imageSection: some View {
        if maskEnabled && modelSupportsMask && modelSupportsSourceImage {
            PrimaryReferenceImageWithMaskSection(
                selectedImage: viewModel.selectedImage,
                colorPalette: viewModel.colorPalette,
                description: "Select an image and draw a mask over the area you want to edit. The model will regenerate the masked region based on your instructions.",
                maskPath: $maskPath,
                canvasSize: $canvasSize,
                onSelectImage: { viewModel.isPhotoPickerOpen = true },
                onClearMask: { maskPath = Path() },
                onRemoveImage: { viewModel.selectedImage = nil }
            )
        } else if modelSupportsSourceImage || modelSupportsExpandDirections {
            PrimaryReferenceImageSection(
                selectedImage: viewModel.selectedImage,
                colorPalette: viewModel.colorPalette,
                description: modelSupportsExpandDirections
                    ?
                    "Select the image you want to expand. Choose the directions to extend the canvas, and the model will generate new content to fill the expanded areas."
                    :
                    "Select the image you want to edit. The model will apply your instructions to modify the selected image.",
                onSelectImage: { viewModel.isPhotoPickerOpen = true },
                expandDirections: modelSupportsExpandDirections ? (
                    expandLeft: $expandLeft,
                    expandRight: $expandRight,
                    expandTop: $expandTop,
                    expandBottom: $expandBottom
                ) : nil,
                onImageDropped: { image in
                    droppedSourceImage = image
                },
                onRemoveImage: { viewModel.selectedImage = nil }
            )
        }
    }

    @ViewBuilder
    private var maskToggleSection: some View {
        if modelSupportsMask {
            Section {
                Toggle("Enable Mask Editing", isOn: $maskEnabled)
                    .onChange(of: maskEnabled) {
                        if !maskEnabled {
                            maskPath = Path()
                        }
                    }
            } footer: {
                Text("When enabled, you can draw a mask to specify which area of the image to edit.")
            }
        }
    }

    var body: some View {
        VStack {
            if viewModel.hasSupportedModel, !providerKeys.isEmpty {
                Form {
                    ModelSelectionSection(
                        selectedProviderId: $viewModel.selectedProviderId,
                        selectedModelId: $viewModel.selectedModelId,
                        providerKeys: providerKeys,
                        setType: .IMAGE_GENERATE,
                        onProviderChange: { viewModel.handleProviderChange() },
                        onModelChange: { viewModel.handleModelChange() }
                    )

                    imageSection

                    maskToggleSection

                    FocusedPromptSection(
                        model: viewModel.getSelectedModel(),
                        headerText: "What do you want to generate?",
                        promptPlaceholder: "Eg. Landscape view of a city",
                        searchPromptPlaceholder: "Eg. Collar tag",
                        negativePlaceholder: "Eg. Without any clouds",
                        prompt: $viewModel.prompt,
                        searchPrompt: $viewModel.searchPrompt,
                        negativePrompt: $viewModel.negativePrompt,
                        focusedField: $focusedField,
                        promptFieldValue: PromptField.prompt,
                        searchFieldValue: PromptField.searchPrompt,
                        negativeFieldValue: PromptField.negativePrompt
                    )

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
                                droppedReferenceImage = image
                            }
                        )
                    }

                    AvailableToolsSection(
                        model: viewModel.getSelectedModel(),
                        selectedTools: $viewModel.selectedTools
                    )

                    ModelParametersSection(
                        model: viewModel.getSelectedModel(),
                        dimensions: $viewModel.dimensions,
                        quality: $viewModel.quality,
                        variant: $viewModel.variant,
                        style: $viewModel.style,
                        inputFidelity: $viewModel.inputFidelity,
                        moderation: $viewModel.moderation,
                        selectedResolution: $viewModel.selectedResolution,
                        stepsValue: $viewModel.stepsValue,
                        guidanceValue: $viewModel.guidanceValue,
                        seedValue: $viewModel.seedValue,
                        safetyValue: $viewModel.safetyValue,
                        growMaskValue: $viewModel.growMaskValue,
                        modelPromptEnhance: $viewModel.modelPromptEnhance,
                        personGeneration: $viewModel.personGeneration
                    )

                    NumberOfGenerationsSection(
                        model: viewModel.getSelectedModel(),
                        numberOfItems: $viewModel.numberOfImages
                    )

                    EstimatedCostSection(
                        cost: (viewModel.getSelectedModel()?.modelCode ?? .OPENAI_DALLE3).formattedImageCost(
                            quality: viewModel.quality,
                            dimensions: viewModel.dimensions,
                            resolution: viewModel.selectedResolution,
                            numberOfImages: viewModel.numberOfImages,
                            hasSourceImage: viewModel.selectedImage != nil,
                            referenceImageCount: viewModel.referenceImages.count,
                            providerSecret: selectedProviderSecret
                        ),
                        estimatedCostValue: (viewModel.getSelectedModel()?.modelCode ?? .OPENAI_DALLE3).rawImageCost(
                            quality: viewModel.quality,
                            dimensions: viewModel.dimensions,
                            resolution: viewModel.selectedResolution,
                            numberOfImages: viewModel.numberOfImages,
                            hasSourceImage: viewModel.selectedImage != nil,
                            referenceImageCount: viewModel.referenceImages.count,
                            providerSecret: selectedProviderSecret
                        ),
                        balance: providerBalance,
                        creditCurrency: selectedProvider?.creditCurrency ?? .USD
                    )

                    SubmitGenerationButton(
                        title: "Generate Image",
                        isDisabled: !viewModel.canGenerate
                    ) {
                        focusedField = nil

                        if maskEnabled, !maskPath.isEmpty {
                            let clientMask = exportPathToImage(
                                path: maskPath,
                                size: canvasSize
                            )

                            viewModel.submitToQueue(
                                providerKeys: providerKeys,
                                projectId: projectManager.currentProjectId,
                                queueManager: queueManager,
                                modelContext: modelContext
                            ) { request in
                                request.clientMask = clientMask?.toBase64PNG()
                                request.numberOfImages = viewModel.numberOfImages
                            }
                        } else if modelSupportsExpandDirections {
                            viewModel.submitToQueue(
                                providerKeys: providerKeys,
                                projectId: projectManager.currentProjectId,
                                queueManager: queueManager,
                                modelContext: modelContext
                            ) { request in
                                request.editDirection = ImageEditDirection(
                                    left: expandLeft ? 500 : 0,
                                    right: expandRight ? 500 : 0,
                                    up: expandTop ? 500 : 0,
                                    down: expandBottom ? 500 : 0
                                )
                                request.numberOfImages = viewModel.numberOfImages
                            }
                        } else {
                            viewModel.submitToQueue(
                                providerKeys: providerKeys,
                                projectId: projectManager.currentProjectId,
                                queueManager: queueManager,
                                modelContext: modelContext
                            ) { request in
                                request.numberOfImages = viewModel.numberOfImages
                            }
                        }

                        if QueueEducationSheet.shouldShow {
                            showQueueEducation = true
                        }
                    }
                }
                .formStyle(.grouped)
                .transaction { $0.disablesAnimations = true }
                .safeAreaPadding(EdgeInsets(top: 0, leading: 0, bottom: 64, trailing: 0))
                .keyboardDoneToolbar { focusedField = nil }
                .imageSelection(
                    id: "editPrompt",
                    isPickerOpen: $viewModel.isPhotoPickerOpen,
                    enableCrop: true,
                    cropDimensions: viewModel.dimensions,
                    maxImagePixels: viewModel.getSelectedModel()?.modelParams.maxImagePixels,
                    maxImageSizeBytes: viewModel.getSelectedModel()?.modelParams.maxImageSizeBytes,
                    droppedImage: $droppedSourceImage,
                    onImageSelected: { image in
                        viewModel.selectedImage = image
                        Task.detached(priority: .userInitiated) {
                            let palette = dominantColorsFromImage(image, clusterCount: 6)
                            await MainActor.run { [weak viewModel] in viewModel?.colorPalette = palette }
                        }
                        maskPath = Path()
                    }
                )
                .imageSelection(
                    id: "referenceImage",
                    isPickerOpen: $viewModel.isReferenceImagePickerOpen,
                    droppedImage: $droppedReferenceImage,
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
                PendingProviderView(setType: .IMAGE_GENERATE)
            }
        }
        .onAppear {
            providerKeysCache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            viewModel.initialize(providerKeys: providerKeys)

            if let preload = navigationManager.generateImagePreload {
                viewModel.applyPreload(preload, providerKeys: providerKeys)
                navigationManager.clearGenerateImagePreload()
            }
        }
        .onChange(of: projectManager.currentProjectId) { _, newProjectId in
            providerKeysCache.loadIfNeeded(projectId: newProjectId, modelContext: modelContext, force: true)
        }
        .onChange(of: viewModel.selectedProviderId) { _, _ in
            viewModel.saveProviderSelection()
        }
        .onChange(of: viewModel.selectedModelId) { _, _ in
            viewModel.saveModelSelection()
        }
        .onChange(of: viewModel.dimensions) { _, _ in
            viewModel.saveDimensionsSelection()
        }
        .imageGenerationNavigation(
            isPresented: $viewModel.isNavigationActive,
            setId: $viewModel.selectedSetId,
            onDisappear: {
                focusedField = nil
                viewModel.resetNavigation()
            }
        )
        .sheet(isPresented: $showQueueEducation) {
            QueueEducationSheet()
        }
        #if os(macOS)
        .onExitCommand {
            dismiss()
        }
        #endif
        .navigationTitle(labelForItem(.imageGenerate))
    }
}
