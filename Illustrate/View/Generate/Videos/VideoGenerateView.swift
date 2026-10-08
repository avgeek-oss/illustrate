// MARK: - VideoGenerateView.swift

// Main view for video generation with full parameter controls.
//
// Similar to ImageGenerateView but for video generation:
// - Model selection (video generation models)
// - Prompt input
// - Duration, FPS, resolution options
// - Source image for image-to-video
// - Audio generation toggle
//
// ## ViewModel
// Uses BaseVideoViewModel to manage state and submit generations.
//
// ## Supported Models
// - Sora 2 / Sora 2 Pro (OpenAI)
// - Veo 2 / Veo 3 (Google)
// - Stability Image to Video
// - Seedance (Replicate)

import AlertToast
import KeychainSwift
import PhotosUI
import SwiftData
import SwiftUI

/// Full-featured video generation view with all parameters.
struct VideoGenerateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var queueManager: QueueManager
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var balanceService: BalanceService
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    private var providerKeys: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    @StateObject private var viewModel: BaseVideoViewModel = {
        let vm = BaseVideoViewModel()
        vm.setType = .VIDEO_GENERATE
        return vm
    }()

    @FocusState private var focusedField: PromptField?

    @State private var showQueueEducation = false

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

                    FocusedPromptSection(
                        model: viewModel.getSelectedModel(),
                        headerText: "Describe your video",
                        promptPlaceholder: "Eg. A cinematic shot of a golden retriever running through a meadow at sunset...",
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

                    if viewModel.supportsSourceImage(), !viewModel.usesLumaMultiKeyframes() {
                        PrimaryReferenceImageSection(
                            selectedImage: viewModel.selectedImage,
                            colorPalette: viewModel.colorPalette,
                            description: "Upload an image to use as the primary reference image for your video.",
                            onSelectImage: { viewModel.isPhotoPickerOpen = true },
                            onImageDropped: { image in
                                viewModel.processSelectedImage(image: image)
                            },
                            onRemoveImage: { viewModel.selectedImage = nil }
                        )
                    }

                    if viewModel.supportsLastFrame(), !viewModel.usesLumaMultiKeyframes() {
                        ImageFrameSection(
                            headerText: "Last Frame Image",
                            selectedImage: viewModel.selectedLastFrame,
                            colorPalette: viewModel.colorPalette,
                            buttonLabel: "Select Last Frame",
                            changeLabel: "Change Last Frame",
                            isDisabled: viewModel.selectedImage == nil,
                            onSelectImage: { viewModel.isLastFramePickerOpen = true },
                            onRemoveImage: { viewModel.selectedLastFrame = nil },
                            onImageDropped: { image in
                                viewModel.processSelectedLastFrame(image: image)
                            }
                        )
                    }

                    if viewModel.usesLumaMultiKeyframes() {
                        LumaKeyframeImagesSection(
                            keyframes: viewModel.lumaKeyframes,
                            maxFrameIndex: viewModel.lumaKeyframeMaxFrameIndex,
                            validationMessage: viewModel.lumaKeyframeValidationMessage(),
                            canAddMore: viewModel.canAddMoreLumaKeyframes(),
                            onAddImage: { viewModel.isReferenceImagePickerOpen = true },
                            onRemoveImage: { id in viewModel.removeLumaKeyframe(id: id) },
                            onUpdateFrameIndex: { id, frameIndex in
                                viewModel.updateLumaKeyframeFrameIndex(id: id, frameIndex: frameIndex)
                            },
                            onImageDropped: { image in
                                viewModel.processSelectedLumaKeyframeImage(image: image)
                            }
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
                        cost: (viewModel.getSelectedModel()?.modelCode ?? .GOOGLE_VEO_2).formattedVideoCost(
                            durationSeconds: viewModel.durationSeconds,
                            numberOfVideos: 1,
                            dimensions: viewModel.dimensions,
                            resolution: viewModel.selectedResolution,
                            generateAudio: viewModel.generateAudio,
                            hasSourceImage: viewModel.selectedImage != nil,
                            referenceImageCount: viewModel.referenceImages.count,
                            lumaHDR: viewModel.lumaHDR,
                            lumaEXRExport: viewModel.lumaEXRExport,
                            lumaLoop: viewModel.lumaLoop,
                            providerSecret: selectedProviderSecret
                        ),
                        estimatedCostValue: (viewModel.getSelectedModel()?.modelCode ?? .GOOGLE_VEO_2).rawVideoCost(
                            durationSeconds: viewModel.durationSeconds,
                            numberOfVideos: 1,
                            dimensions: viewModel.dimensions,
                            resolution: viewModel.selectedResolution,
                            generateAudio: viewModel.generateAudio,
                            hasSourceImage: viewModel.selectedImage != nil,
                            referenceImageCount: viewModel.referenceImages.count,
                            lumaHDR: viewModel.lumaHDR,
                            lumaEXRExport: viewModel.lumaEXRExport,
                            lumaLoop: viewModel.lumaLoop,
                            providerSecret: selectedProviderSecret
                        ),
                        balance: providerBalance,
                        creditCurrency: selectedProvider?.creditCurrency ?? .USD
                    )

                    SubmitGenerationButton(
                        title: "Generate Video",
                        isDisabled: !viewModel.canGenerate
                    ) {
                        focusedField = nil
                        viewModel.submitToQueue(
                            providerKeys: providerKeys,
                            projectId: projectManager.currentProjectId,
                            queueManager: queueManager,
                            modelContext: modelContext
                        )

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
                    id: "sourceImage",
                    isPickerOpen: $viewModel.isPhotoPickerOpen,
                    onImageSelected: { image in
                        viewModel.processSelectedImage(image: image)
                    }
                )
                .sheet(isPresented: $viewModel.isCropSheetOpen) {
                    if let selectedImage = viewModel.selectedImage {
                        ImageCropAdapter(
                            image: selectedImage,
                            cropDimensions: viewModel.dimensions,
                            flexibleDimensions: true,
                            sessionId: viewModel.cropSessionId,
                            onCropConfirm: { image in
                                viewModel.handleCropConfirm(image: image)
                            },
                            onCropCancel: {
                                viewModel.handleCropCancel()
                            }
                        )
                    }
                }
                .imageSelection(
                    id: "referenceImage",
                    isPickerOpen: $viewModel.isReferenceImagePickerOpen,
                    onImageSelected: { image in
                        if viewModel.usesLumaMultiKeyframes() {
                            viewModel.processSelectedLumaKeyframeImage(image: image)
                        } else {
                            viewModel.processSelectedReferenceImage(image: image)
                        }
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
                                if viewModel.usesLumaMultiKeyframes() {
                                    viewModel.handleLumaKeyframeCropConfirm(image: image)
                                } else {
                                    viewModel.handleReferenceImageCropConfirm(image: image)
                                }
                            },
                            onCropCancel: {
                                viewModel.cancelReferenceImageCropping()
                            }
                        )
                    }
                }
                .imageSelection(
                    id: "lastFrame",
                    isPickerOpen: $viewModel.isLastFramePickerOpen,
                    onImageSelected: { image in
                        viewModel.processSelectedLastFrame(image: image)
                    }
                )
                .sheet(isPresented: $viewModel.isLastFrameCropSheetOpen) {
                    if let lastFrame = viewModel.selectedLastFrame {
                        ImageCropAdapter(
                            image: lastFrame,
                            cropDimensions: viewModel.dimensions,
                            flexibleDimensions: true,
                            sessionId: viewModel.lastFrameCropSessionId,
                            onCropConfirm: { image in
                                viewModel.handleLastFrameCropping(image: image)
                            },
                            onCropCancel: {
                                viewModel.cancelLastFrameCropping()
                            }
                        )
                    }
                }
            } else {
                PendingProviderView(setType: .VIDEO_GENERATE)
            }
        }
        .onAppear {
            providerKeysCache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            viewModel.initialize(providerKeys: providerKeys)
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
        .onChange(of: viewModel.durationSeconds) { _, _ in
            viewModel.clampLumaKeyframesToCurrentDuration()
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
        .sheet(isPresented: $showQueueEducation) {
            QueueEducationSheet()
        }
        .navigationTitle(labelForItem(.videoGenerate))
    }
}

private struct LumaKeyframeImagesSection: View {
    let keyframes: [VideoKeyframeImage]
    let maxFrameIndex: Int
    let validationMessage: String?
    let canAddMore: Bool
    let onAddImage: () -> Void
    let onRemoveImage: (UUID) -> Void
    let onUpdateFrameIndex: (UUID, Int) -> Void
    let onImageDropped: (PlatformImage) -> Void

    @State private var isDropTargeted = false

    #if os(macOS)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]
    #else
    private let columns = [GridItem(.flexible(), spacing: 12)]
    #endif

    var body: some View {
        Section(header: Text("Timeline Keyframes")) {
            if keyframes.isEmpty {
                Button {
                    onAddImage()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "photo.badge.plus")
                            .font(.largeTitle)
                        Text(isDropTargeted ? "Drop keyframe" : "Add keyframe")
                            .font(.callout)
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isDropTargeted ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6])
                            )
                    )
                }
                .buttonStyle(.plain)
                .imageDropTarget(isTargeted: $isDropTargeted) { image in
                    onImageDropped(image)
                }
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(keyframes) { keyframe in
                        LumaKeyframeCard(
                            keyframe: keyframe,
                            maxFrameIndex: maxFrameIndex,
                            onRemove: { onRemoveImage(keyframe.id) },
                            onUpdateFrameIndex: { frameIndex in
                                onUpdateFrameIndex(keyframe.id, frameIndex)
                            }
                        )
                    }

                    if canAddMore {
                        AddLumaKeyframeCard(
                            onAdd: onAddImage,
                            onImageDropped: onImageDropped
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                Text("\(keyframes.count) of 64 keyframes")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("0-\(maxFrameIndex) frames")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct LumaKeyframeCard: View {
    let keyframe: VideoKeyframeImage
    let maxFrameIndex: Int
    let onRemove: () -> Void
    let onUpdateFrameIndex: (Int) -> Void

    private var timeLabel: String {
        String(format: "%.2fs", Double(keyframe.frameIndex) / 24.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                #if os(macOS)
                Image(nsImage: keyframe.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                #else
                Image(uiImage: keyframe.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                #endif

                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .red.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel("Remove keyframe")
            }

            Stepper(
                value: Binding(
                    get: { keyframe.frameIndex },
                    set: { onUpdateFrameIndex($0) }
                ),
                in: 0 ... maxFrameIndex,
                step: 1
            ) {
                HStack {
                    Text("Frame \(keyframe.frameIndex)")
                    Spacer()
                    Text(timeLabel)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}

private struct AddLumaKeyframeCard: View {
    let onAdd: () -> Void
    let onImageDropped: (PlatformImage) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        Button {
            onAdd()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "plus")
                    .font(.title2)
                Text(isDropTargeted ? "Drop" : "Add")
                    .font(.caption)
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDropTargeted ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isDropTargeted ? Color.accentColor : Color.secondary,
                        style: StrokeStyle(lineWidth: 2, dash: [6])
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .imageDropTarget(isTargeted: $isDropTargeted) { image in
            onImageDropped(image)
        }
    }
}
