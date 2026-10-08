// MARK: - CreativeStudioView.swift

// Main view for creative studio asset generation.
//
// CreativeStudioView provides a focused interface for generating brand-consistent
// assets. It automatically injects brand context (colors, personality, logos)
// into generation prompts.
//
// ## Layout
// - Top Section: Sticky header with prompt bar and model selection
// - Bottom Section: Scrollable grid of generated studio items
//
// ## Features
// - Asset type selection (Poster, Invitation, Social Media, etc.)
// - Automatic brand context injection
// - Grid display of generated assets
// - Edit via context menu for quick iterations

import AvgeekDesignSystem
import IllustrateProviders
import KeychainSwift
import OSLog
import SwiftData
import SwiftUI

/// Main container view for creative studio generation.
struct CreativeStudioView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var queueManager: QueueManager
    @StateObject private var brandKitManager = BrandKitManager.shared

    private let keychain: KeychainSwift = {
        let kc = KeychainSwift()
        kc.accessGroup = TEAM_KEYCHAIN_AG
        kc.synchronizable = true
        return kc
    }()

    @Query(sort: \CreativeStudio.createdAt, order: .reverse) private var allStudios: [CreativeStudio]
    @Query(sort: \CreativeStudioItem.createdAt, order: .reverse) private var allItems: [CreativeStudioItem]
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    @State private var editingItem: CreativeStudioItem?
    @State private var showEditSheet = false
    @State private var itemToDelete: CreativeStudioItem?
    @State private var showDeleteConfirmation = false
    @State private var attachedImages: [PlatformImage] = []
    @State private var isStudioDropTargeted = false

    @State private var studio: CreativeStudio?
    @State private var itemsForStudio: [CreativeStudioItem] = []

    private func updateStudioData() {
        studio = allStudios.first { $0.projectId == projectManager.currentProjectId }
        if let studio {
            itemsForStudio = allItems.filter { $0.studioId == studio.id }
        } else {
            itemsForStudio = []
        }
    }

    private var providerKeysForProject: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header section with prompt bar
            headerSection

            Divider()

            // Scrollable grid of studio items
            gridSection
        }
        .overlay {
            if isStudioDropTargeted {
                studioDropOverlay
            }
        }
        .imageDropTarget(isTargeted: $isStudioDropTargeted) { image in
            attachedImages.append(image)
        } onMultipleImagesDropped: { images in
            attachedImages.append(contentsOf: images)
        }
        .navigationTitle("Brand Studio")
        .onAppear {
            providerKeysCache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            brandKitManager.ensureBrandKitExists(modelContext: modelContext, projectId: projectManager.currentProjectId)
            ensureStudioExists()
            updateStudioData()
        }
        .onChange(of: allStudios) { _, _ in updateStudioData() }
        .onChange(of: allItems) { _, _ in updateStudioData() }
        .onChange(of: projectManager.currentProjectId) { _, newProjectId in
            providerKeysCache.loadIfNeeded(projectId: newProjectId, modelContext: modelContext)
            brandKitManager.ensureBrandKitExists(modelContext: modelContext, projectId: newProjectId)
            ensureStudioExists()
            updateStudioData()
            attachedImages = []
        }
        .sheet(isPresented: $showEditSheet) {
            if let item = editingItem {
                StudioEditSheet(
                    item: item,
                    brandKit: brandKitManager.currentBrandKit,
                    providerKeys: providerKeysForProject,
                    onGenerate: { userPrompt, fullPrompt, assetType, config in
                        submitEditGeneration(
                            sourceItem: item,
                            userPrompt: userPrompt,
                            fullPrompt: fullPrompt,
                            assetType: assetType,
                            config: config
                        )
                    }
                )
            }
        }
        .alert("Remove from Studio", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
            Button("Remove", role: .destructive) {
                if let item = itemToDelete {
                    deleteItem(item)
                }
                itemToDelete = nil
            }
        } message: {
            Text("Are you sure you want to remove this asset from the studio? This action cannot be undone.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Headline and instruction
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    "Creative Studio allows you to quickly generate brand-consistent assets like posters, invitations, and social media content. You don't need to specify the branding information, it will be automatically injected into the prompts and you can customize the context if needed."
                )
                .font(.body)
                .foregroundStyle(.secondary)
            }

            // Prompt bar
            if let studio {
                StudioPromptBar(
                    studio: studio,
                    providerKeys: providerKeysForProject,
                    brandKit: brandKitManager.currentBrandKit,
                    onSend: { userPrompt, fullPrompt, assetType, config, images, brandAssetSelection in
                        submitGeneration(
                            userPrompt: userPrompt,
                            fullPrompt: fullPrompt,
                            assetType: assetType,
                            config: config,
                            attachedImages: images,
                            brandAssetSelection: brandAssetSelection
                        )
                    },
                    attachedImages: $attachedImages
                )
            } else {
                // Loading state
                HStack {
                    Spacer()
                    GradientSpinner()
                    Spacer()
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(tertiarySystemFill)
    }

    // MARK: - Grid Section

    private var gridSection: some View {
        Group {
            if itemsForStudio.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 260, maximum: 340), spacing: 20),
                        ],
                        alignment: .leading,
                        spacing: 20
                    ) {
                        ForEach(itemsForStudio) { item in
                            StudioCardView(
                                item: item,
                                onEdit: {
                                    editingItem = item
                                    showEditSheet = true
                                },
                                onDelete: {
                                    itemToDelete = item
                                    showDeleteConfirmation = true
                                }
                            )
                        }
                    }
                    .padding(24)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        AvgeekEmptyStateView(
            icon: "wand.and.rays.inverse",
            title: "No generations yet",
            message: "Use the prompt bar to generate brand-consistent assets like posters, invitations, and social media content."
        )
        .frame(maxWidth: 400)
    }

    // MARK: - Drop Overlay

    private var studioDropOverlay: some View {
        ZStack {
            systemBackground.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                Text("Drop to attach")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                Text("Image will be added to reference images")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentColor.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Actions

    private func ensureStudioExists() {
        // Check if studio exists for current project
        if studio == nil {
            let newStudio = CreativeStudio(projectId: projectManager.currentProjectId)
            modelContext.insert(newStudio)
            try? modelContext.save()
        }
    }

    private func deleteItem(_ item: CreativeStudioItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func submitGeneration(
        userPrompt: String,
        fullPrompt: String,
        assetType: CreativeAssetType,
        config: ImageGenerationConfiguration,
        attachedImages: [PlatformImage],
        brandAssetSelection: BrandAssetSelection
    ) {
        guard let studio else { return }

        // Create studio item
        let item = CreativeStudioItem(
            studioId: studio.id,
            projectId: projectManager.currentProjectId,
            assetType: assetType,
            userPrompt: userPrompt,
            fullPrompt: fullPrompt
        )
        item.imageGenerationConfiguration = config
        modelContext.insert(item)

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to save studio item: \(error.localizedDescription, privacy: .public)")
            return
        }

        // Submit generation request
        Task {
            await submitGenerationRequest(
                item: item,
                config: config,
                attachedImages: attachedImages,
                brandAssetSelection: brandAssetSelection
            )
        }
    }

    private func submitEditGeneration(
        sourceItem: CreativeStudioItem,
        userPrompt: String,
        fullPrompt: String,
        assetType: CreativeAssetType,
        config: ImageGenerationConfiguration
    ) {
        guard let studio else { return }

        // Create new studio item for the edit
        let item = CreativeStudioItem(
            studioId: studio.id,
            projectId: projectManager.currentProjectId,
            assetType: assetType,
            userPrompt: userPrompt,
            fullPrompt: fullPrompt
        )
        item.imageGenerationConfiguration = config
        modelContext.insert(item)

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to save studio item: \(error.localizedDescription, privacy: .public)")
            return
        }

        // Submit generation request with source image
        Task {
            await submitGenerationRequest(
                item: item,
                config: config,
                sourceGenerationId: sourceItem.generationId
            )
        }

        showEditSheet = false
    }

    @MainActor
    private func submitGenerationRequest(
        item: CreativeStudioItem,
        config: ImageGenerationConfiguration,
        sourceGenerationId: UUID? = nil,
        attachedImages: [PlatformImage] = [],
        brandAssetSelection: BrandAssetSelection = BrandAssetSelection()
    ) async {
        guard let providerKey = providerKeysForProject.first(where: {
            $0.providerId.uuidString == config.selectedProviderId
        }) else {
            item.status = .FAILED
            item.errorMessage = "Provider not found"
            try? modelContext.save()
            return
        }

        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else {
            item.status = .FAILED
            item.errorMessage = "Provider not found"
            try? modelContext.save()
            return
        }

        // Get provider secret from keychain
        let keychainKey = ProjectManager.keychainKey(
            projectId: projectManager.currentProjectId,
            providerId: providerKey.providerId
        )
        guard let providerSecret = keychain.get(keychainKey) else {
            item.status = .FAILED
            item.errorMessage = "Provider secret not found"
            try? modelContext.save()
            return
        }

        // Get the model to check what it supports
        let model = ProviderService.shared.models(for: .IMAGE_GENERATE)
            .first { $0.modelId.uuidString == config.selectedModelId }
        let supportsSourceImage = model?.modelParams.supportsSourceImage ?? false
        let supportsReferenceImages = model?.modelParams.supportsReferenceImages ?? false
        let defaultRefType = model?.modelParams.supportedReferenceTypes.first ?? "style"

        // Prepare source/reference images
        var clientImage: String?
        var clientReferenceImages: [ReferenceImageData]?

        // Add source image if editing from existing generation
        if let sourceGenId = sourceGenerationId,
           let sourceImage = loadImageFromDocumentsDirectory(withName: sourceGenId.uuidString),
           let base64 = sourceImage.toBase64PNG()
        {
            if supportsSourceImage {
                clientImage = base64
            } else if supportsReferenceImages {
                clientReferenceImages = [ReferenceImageData(base64Image: base64, referenceType: defaultRefType)]
            }
        }

        // Add custom attached images as references
        if supportsReferenceImages, !attachedImages.isEmpty {
            var attachedRefs: [ReferenceImageData] = []
            for attachedImage in attachedImages {
                if let base64 = attachedImage.toBase64PNG() {
                    attachedRefs.append(ReferenceImageData(base64Image: base64, referenceType: defaultRefType))
                }
            }
            if clientReferenceImages == nil {
                clientReferenceImages = attachedRefs
            } else {
                clientReferenceImages?.append(contentsOf: attachedRefs)
            }
        }

        // Add brand images as references based on user selection
        if supportsReferenceImages, let brandKit = brandKitManager.currentBrandKit {
            var brandRefs: [ReferenceImageData] = []

            // Add light logo if selected
            if brandAssetSelection.includeLightLogo,
               let logoFileName = brandKit.imageFileName(for: .lightLogo),
               let logoImage = loadImageFromiCloud(logoFileName),
               let base64 = logoImage.toBase64PNG()
            {
                brandRefs.append(ReferenceImageData(base64Image: base64, referenceType: "style"))
            }

            // Add dark logo if selected
            if brandAssetSelection.includeDarkLogo,
               let logoFileName = brandKit.imageFileName(for: .darkLogo),
               let logoImage = loadImageFromiCloud(logoFileName),
               let base64 = logoImage.toBase64PNG()
            {
                brandRefs.append(ReferenceImageData(base64Image: base64, referenceType: "style"))
            }

            // Add selected model assets
            for asset in brandKit.modelAssets {
                if brandAssetSelection.selectedModelAssetIds.contains(asset.id),
                   let assetImage = loadImageFromiCloud(asset.fileName),
                   let base64 = assetImage.toBase64PNG()
                {
                    brandRefs.append(ReferenceImageData(base64Image: base64, referenceType: "style"))
                }
            }

            // Merge with existing references
            if clientReferenceImages == nil {
                clientReferenceImages = brandRefs
            } else {
                clientReferenceImages?.append(contentsOf: brandRefs)
            }

            // Respect model's max reference images limit
            if let maxRefs = model?.modelParams.maxReferenceImages,
               let refs = clientReferenceImages, refs.count > maxRefs
            {
                clientReferenceImages = Array(refs.prefix(maxRefs))
            }
        }

        let request = ImageGenerationRequest(
            modelId: config.selectedModelId,
            prompt: config.prompt,
            searchPrompt: config.searchPrompt.isEmpty ? nil : config.searchPrompt,
            negativePrompt: config.negativePrompt.isEmpty ? nil : config.negativePrompt,
            variant: config.selectedVariant,
            quality: config.selectedQuality,
            style: config.selectedStyle,
            dimensions: config.selectedDimensions,
            clientImage: clientImage,
            clientReferenceImages: clientReferenceImages,
            providerKey: providerKeyInfo,
            providerSecret: providerSecret,
            resolution: config.selectedResolution.isEmpty ? nil : config.selectedResolution,
            guidance: config.guidanceValue,
            seed: config.seedValue.isEmpty ? nil : Int(config.seedValue),
            safetyTolerance: Int(config.safetyValue),
            promptEnhance: config.modelPromptEnhance,
            inputFidelity: config.selectedInputFidelity.isEmpty ? nil : config.selectedInputFidelity,
            moderation: config.selectedModeration.isEmpty ? nil : config.selectedModeration,
            growMask: Int(config.growMaskValue),
            selectedTools: config.selectedTools.isEmpty ? nil : config.selectedTools,
            personGeneration: config.personGeneration.isEmpty ? nil : config.personGeneration
        )

        let queueItem = queueManager.submitImageGeneration(
            request: request,
            modelContext: modelContext,
            source: .CREATIVE_STUDIO
        )

        item.queueItemId = queueItem.id
        try? modelContext.save()

        // Monitor queue item for completion
        await monitorQueueItem(queueItem, for: item)
    }

    @MainActor
    private func monitorQueueItem(_ queueItem: QueueItem, for item: CreativeStudioItem) async {
        // Poll for status changes
        while queueItem.status == .IN_PROGRESS {
            try? await Task.sleep(for: .milliseconds(500))
        }

        if queueItem.status == .SUCCESSFUL {
            item.status = .GENERATED
            if let resultSetId = queueItem.resultSetId {
                let descriptor = FetchDescriptor<Generation>(predicate: #Predicate { $0.setId == resultSetId })
                if let generation = try? modelContext.fetch(descriptor).first {
                    item.generationId = generation.id
                }
            }
        } else {
            item.status = .FAILED
            item.errorMessage = queueItem.errorMessage ?? "Generation failed"
        }

        try? modelContext.save()
    }
}

// MARK: - Studio Edit Sheet

/// Sheet for editing/iterating on an existing studio item.
struct StudioEditSheet: View {
    let item: CreativeStudioItem
    let brandKit: BrandKit?
    let providerKeys: [ProviderKey]
    let onGenerate: (String, String, CreativeAssetType, ImageGenerationConfiguration) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = StudioEditSheetViewModel()

    @State private var promptText = ""
    @State private var selectedAssetType: CreativeAssetType = .generalPurpose
    @State private var sourceImage: PlatformImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Source image preview
                if let image = sourceImage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source Image")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        #if os(macOS)
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                        #else
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                        #endif
                    }
                }

                // Asset type picker
                HStack {
                    Text("Asset Type")
                        .font(.headline)
                    Spacer()
                    Picker("", selection: $selectedAssetType) {
                        ForEach(CreativeAssetType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Prompt input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Edit Instructions")
                        .font(.headline)

                    TextField("Describe your changes...", text: $promptText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(3 ... 6)
                        .padding(12)
                        .background(secondarySystemFill)
                        .cornerRadius(8)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Edit Asset")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        submitEdit()
                    }
                    .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .onAppear {
            loadSourceImage()
            selectedAssetType = item.assetTypeEnum
            viewModel.initialize(item: item, providerKeys: providerKeys)
        }
    }

    private func loadSourceImage() {
        guard let genId = item.generationId else { return }
        let fileName = genId.uuidString

        if let cached = ImageCache.shared.get(forKey: fileName) {
            sourceImage = cached
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                let image = loadImageFromiCloud(fileName)
                DispatchQueue.main.async {
                    if let img = image {
                        ImageCache.shared.set(img, forKey: fileName)
                        sourceImage = img
                    }
                }
            }
        }
    }

    private func submitEdit() {
        let trimmedPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        // Build full prompt with brand context
        let fullPrompt = buildBrandContextPrompt(userPrompt: trimmedPrompt)

        // Build configuration
        let config = viewModel.buildConfiguration(prompt: fullPrompt)

        onGenerate(trimmedPrompt, fullPrompt, selectedAssetType, config)
    }

    private func buildBrandContextPrompt(userPrompt: String) -> String {
        guard let kit = brandKit else {
            return userPrompt
        }

        var promptParts: [String] = []

        // Edit context
        promptParts
            .append(
                "Edit this \(selectedAssetType.promptDescription) for \(kit.brandName.isEmpty ? "the brand" : kit.brandName)."
            )

        // Brand context section
        var brandContext: [String] = []

        if !kit.brandAbout.isEmpty {
            brandContext.append("About: \(kit.brandAbout)")
        }

        if !kit.brandPersonality.isEmpty {
            brandContext.append("Personality: \(kit.brandPersonality)")
        }

        // Colors
        var colorDescriptions: [String] = []
        let primaryColor = kit.color(for: .primary)
        let secondaryColor = kit.color(for: .secondary)
        let accentColor = kit.color(for: .accent)

        if primaryColor != BrandColorType.primary.defaultColor {
            colorDescriptions.append("Primary (\(primaryColor))")
        }
        if secondaryColor != BrandColorType.secondary.defaultColor {
            colorDescriptions.append("Secondary (\(secondaryColor))")
        }
        if accentColor != BrandColorType.accent.defaultColor {
            colorDescriptions.append("Accent (\(accentColor))")
        }

        if !colorDescriptions.isEmpty {
            brandContext.append("Brand Colors: \(colorDescriptions.joined(separator: ", "))")
        }

        if let fontFace = kit.fontFace, !fontFace.isEmpty {
            brandContext.append("Font: \(fontFace)")
        }

        if !brandContext.isEmpty {
            promptParts.append("\nBrand Context:")
            for contextItem in brandContext {
                promptParts.append("- \(contextItem)")
            }
        }

        // User edit request
        promptParts.append("\nEdit Request:")
        promptParts.append(userPrompt)

        return promptParts.joined(separator: "\n")
    }
}

// MARK: - Edit Sheet View Model

@MainActor
class StudioEditSheetViewModel: ObservableObject {
    private let providerService = ProviderService.shared

    @Published var selectedProviderId = ""
    @Published var selectedModelId = ""
    @Published var dimensions = "1024x1024"
    @Published var quality = ""
    @Published var style = ""

    private var providerKeys: [ProviderKey] = []

    func initialize(item: CreativeStudioItem, providerKeys: [ProviderKey]) {
        self.providerKeys = providerKeys

        // Load from item's configuration
        let config = item.imageGenerationConfiguration
        selectedProviderId = config.selectedProviderId
        selectedModelId = config.selectedModelId
        dimensions = config.selectedDimensions.isEmpty ? "1024x1024" : config.selectedDimensions
        quality = config.selectedQuality
        style = config.selectedStyle
    }

    func buildConfiguration(prompt: String) -> ImageGenerationConfiguration {
        var config = ImageGenerationConfiguration()
        config.selectedProviderId = selectedProviderId
        config.selectedModelId = selectedModelId
        config.prompt = prompt
        config.selectedDimensions = dimensions
        config.selectedQuality = quality
        config.selectedStyle = style
        return config
    }
}
