// MARK: - PhotoshootStudioView.swift

// Studio view for configuring and generating product photographs.
//
// PhotoshootStudioView provides the main workspace for creating product photos:
// - Top: Product description editor
// - Main: Backdrop with object preview
// - Side: Backdrop selection (asset library + custom upload)
// - Bottom: Camera angle, product positioning, and generate button
//
// ## Backdrop Assets
// Assets follow naming pattern: shoots_bg_{dimension}_{index}
// e.g., shoots_bg_9_16_001, shoots_bg_16_9_001
//
// ## Object Upload
// Users can upload up to 3 product objects (1 main + 2 additional)
// that are composed onto the backdrop.

import IllustrateProviders
import KeychainSwift
import SwiftData
import SwiftUI

/// Main studio workspace for product photoshoot generation.
struct PhotoshootStudioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var queueManager: QueueManager
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared
    @StateObject private var backdropsManager = PodiumBackdropsManager.shared

    let photoshoot: ProductPhotoshoot

    private let keychain: KeychainSwift = {
        let kc = KeychainSwift()
        kc.accessGroup = TEAM_KEYCHAIN_AG
        kc.synchronizable = true
        return kc
    }()

    // State
    @State private var productDescription = ""
    @State private var selectedBackdropIndex: Int?
    @State private var customBackdrop: PlatformImage?
    @State private var loadedBackdropImage: PlatformImage?
    @State private var loadedBackdropIndex: Int?
    @State private var previewBackdropImage: PlatformImage?
    @State private var productObjects: [PlatformImage] = []
    @State private var showBackdropPicker = false
    @State private var showObjectPicker = false
    @State private var isGenerating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showGenerationUnderwayAlert = false
    @State private var backdropPersistenceId = UUID()
    @State private var productObjectsPersistenceId = UUID()
    @State private var isRestoringPersistedState = false
    @State private var hasActivatedBackdropRail = false
    @State private var productPositionSaveTask: Task<Void, Never>?
    @AppStorage("hasShownPhotoshootGenerationUnderwayAlert")
    private var hasShownGenerationUnderwayAlert = false

    // Camera and positioning
    @State private var selectedCameraAngle: PhotoshootCameraAngle = .center
    @State private var selectedProductPosition: PhotoshootProductPosition = .onGround

    // Backdrop crop state
    @State private var pendingBackdropImage: IdentifiableImage?
    @State private var backdropCropSessionId = UUID()

    /// Hover state
    @State private var isObjectZoneHovered = false

    private var providerKeysForProject: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    /// Available backdrop indices for the current dimension (1-250)
    private var backdropIndices: [Int] {
        Array(1 ... backdropsManager.imagesPerFolder)
    }

    /// Whether we can generate (have backdrop and at least one object)
    private var canGenerate: Bool {
        (selectedBackdropIndex != nil || customBackdrop != nil) && !productObjects.isEmpty
            && !isGenerating
    }

    private var shouldUseCompactMobileLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    var body: some View {
        Group {
            if shouldUseCompactMobileLayout {
                compactStudioLayout
            } else {
                desktopStudioLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadPersistedState()
            providerKeysCache.loadIfNeeded(
                projectId: projectManager.currentProjectId, modelContext: modelContext
            )
            // Trigger backdrop download for this dimension if not already downloaded
            backdropsManager.downloadIfNeeded(for: photoshoot.dimensionsEnum)
        }
        .task(id: photoshoot.id) {
            if !hasActivatedBackdropRail {
                await Task.yield()
                guard !Task.isCancelled else { return }
                hasActivatedBackdropRail = true
            }

            // Load images asynchronously after view appears
            await loadPersistedImages()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Generation Underway", isPresented: $showGenerationUnderwayAlert) {
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(
                "Your product photograph is being generated. It will appear in the Gallery tab once it's ready."
            )
        }
        .onChange(of: selectedCameraAngle) { _, _ in
            guard !isRestoringPersistedState else { return }
            saveCameraAngle()
        }
        .onChange(of: selectedProductPosition) { _, _ in
            guard !isRestoringPersistedState else { return }
            scheduleProductPositionSave()
        }
        .onChange(of: selectedBackdropIndex) { _, newIndex in
            guard !isRestoringPersistedState else { return }
            if let index: Int = newIndex {
                loadBackdropImageAsync(index: index)
            } else {
                loadedBackdropImage = nil
                loadedBackdropIndex = nil
            }
        }
        .onChange(of: customBackdrop) { _, newBackdrop in
            if newBackdrop != nil {
                loadedBackdropImage = nil
                loadedBackdropIndex = nil
                previewBackdropImage = newBackdrop
            }
        }
        .imageSelection(
            id: "photoshoot_custom_backdrop",
            isPickerOpen: $showBackdropPicker,
            enableCrop: false,
            onImageSelected: { image in
                pendingBackdropImage = IdentifiableImage(image: image)
                backdropCropSessionId = UUID()
            }
        )
        .imageSelection(
            id: "photoshoot_object_picker",
            isPickerOpen: $showObjectPicker,
            enableCrop: false,
            onImageSelected: { image in
                if productObjects.count < 3 {
                    productObjects.append(image)
                    saveProductObjects()
                }
            }
        )
        .sheet(item: $pendingBackdropImage) { item in
            ImageCropAdapter(
                image: item.image,
                cropDimensions: photoshoot.dimensionsEnum.pixelDimensions,
                sessionId: backdropCropSessionId,
                onCropConfirm: { croppedImage in
                    customBackdrop = croppedImage
                    selectedBackdropIndex = nil
                    pendingBackdropImage = nil
                    saveBackdropSelection()
                },
                onCropCancel: {
                    pendingBackdropImage = nil
                }
            )
        }
    }

    private var desktopStudioLayout: some View {
        VStack(spacing: 0) {
            mainStudioArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(0)

            Divider()

            if hasActivatedBackdropRail {
                backdropSelectionRail
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            } else {
                Color.clear
                    .frame(height: 80)
                    .layoutPriority(1)
            }

            Divider()

            bottomControlsBar
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
    }

    private var compactStudioLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                compactPreviewSection

                compactBackdropSection

                compactControlsSection
            }
        }
        .background(systemBackground)
    }

    // MARK: - Main Studio Area

    private var mainStudioArea: some View {
        backdropPreviewSection
    }

    // MARK: - Backdrop Preview

    private var backdropPreviewSection: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                backdropImageView(size: size)

                objectsOverlayView
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func calculatePreviewSize(
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        aspectRatio: CGFloat
    ) -> CGSize {
        let widthBasedHeight = availableWidth / aspectRatio
        let heightBasedWidth = availableHeight * aspectRatio

        if widthBasedHeight <= availableHeight {
            return CGSize(width: availableWidth, height: widthBasedHeight)
        } else {
            return CGSize(width: heightBasedWidth, height: availableHeight)
        }
    }

    @ViewBuilder
    private func backdropImageView(size: CGSize) -> some View {
        if let customBackdrop {
            backdropPreviewImage(customBackdrop, size: size)
        } else if selectedBackdropIndex != nil, let image = previewBackdropImage {
            // Use cached backdrop image loaded asynchronously.
            backdropPreviewImage(image, size: size)
        } else if selectedBackdropIndex != nil {
            // Placeholder while backdrop is loading (no spinner)
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(width: size.width, height: size.height)
        } else {
            // Empty backdrop placeholder (no text)
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .overlay(
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .foregroundStyle(.tertiary)
                )
                .frame(width: size.width, height: size.height)
        }
    }

    private func backdropPreviewImage(_ image: PlatformImage, size: CGSize) -> some View {
        ZStack {
            platformImageView(image, contentMode: .fill, size: size)
                .blur(radius: 28)
                .scaleEffect(1.08)
                .overlay(.black.opacity(0.12))

            platformImageView(image, contentMode: .fit, size: size)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private func platformImageView(_ image: PlatformImage, contentMode: ContentMode, size: CGSize)
        -> some View
    {
        #if os(macOS)
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: contentMode)
            .frame(width: size.width, height: size.height)
            .clipped()
        #else
        Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: contentMode)
            .frame(width: size.width, height: size.height)
            .clipped()
        #endif
    }

    // MARK: - Objects Overlay

    private var objectsOverlayView: some View {
        Group {
            if productObjects.isEmpty {
                // Empty object upload zone - compact
                emptyObjectUploadZone
            } else {
                // Show uploaded objects with add more button
                objectsPreviewGrid
            }
        }
    }

    private var emptyObjectUploadZone: some View {
        Button {
            showObjectPicker = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.accent)
                Text("Add Subject")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 120, height: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(isObjectZoneHovered ? 0.25 : 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(isObjectZoneHovered ? 0.6 : 0.4), lineWidth: 2)
            )
            .animation(.easeInOut(duration: 0.15), value: isObjectZoneHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isObjectZoneHovered = hovering
        }
    }

    private var compactPreviewSection: some View {
        backdropPreviewSection
            .frame(height: photoshoot.dimensionsEnum.isPortrait ? 320 : 220)
    }

    @ViewBuilder
    private var objectsPreviewGrid: some View {
        if photoshoot.dimensionsEnum.isPortrait {
            // Vertical layout for portrait
            VStack(spacing: 8) {
                ForEach(Array(productObjects.enumerated()), id: \.offset) { index, image in
                    objectThumbnail(image: image, index: index)
                }

                // Add more button if less than 3
                if productObjects.count < 3 {
                    addMoreObjectButton
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 2)
            )
        } else {
            // Horizontal layout for landscape
            HStack(spacing: 8) {
                ForEach(Array(productObjects.enumerated()), id: \.offset) { index, image in
                    objectThumbnail(image: image, index: index)
                }

                // Add more button if less than 3
                if productObjects.count < 3 {
                    addMoreObjectButton
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 2)
            )
        }
    }

    private func objectThumbnail(image: PlatformImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            #if os(macOS)
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            #else
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            #endif

            // Remove button
            Button {
                productObjects.remove(at: index)
                saveProductObjects()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
        }
    }

    @State private var isAddMoreHovered = false

    private var addMoreObjectButton: some View {
        Button {
            showObjectPicker = true
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(isAddMoreHovered ? 0.3 : 0.2))
                .frame(width: 70, height: 70)
                .overlay(
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                )
                .animation(.easeInOut(duration: 0.15), value: isAddMoreHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isAddMoreHovered = hovering
        }
    }

    // MARK: - Bottom Controls Bar

    private var bottomControlsBar: some View {
        VStack(spacing: 10) {
            TextField(
                "Description",
                text: $productDescription,
                prompt: Text("Describe your subject (e.g., organic sunscreen bottle, luxury skincare...)"),
                axis: .vertical
            )
            .lineLimit(1 ... 2)
            .textFieldStyle(.roundedBorder)
            .onChange(of: productDescription) { _, newValue in
                photoshoot.productDescription = newValue
                try? modelContext.save()
            }

            HStack(spacing: 24) {
                HStack(spacing: 8) {
                    Text("Camera Angle")
                        .foregroundStyle(.secondary)
                    Picker("", selection: $selectedCameraAngle) {
                        ForEach(PhotoshootCameraAngle.allCases) { angle in
                            Label(angle.displayName, systemImage: angle.icon)
                                .tag(angle)
                        }
                    }
                    .frame(width: 120)
                }
                HStack(spacing: 8) {
                    Text("Position")
                        .foregroundStyle(.secondary)
                    Picker("", selection: $selectedProductPosition) {
                        ForEach(PhotoshootProductPosition.allCases) { position in
                            Label(position.displayName, systemImage: position.icon)
                                .tag(position)
                        }
                    }
                    .frame(width: 160)
                }

                Spacer()

                // Generate button
                Button {
                    generatePhotograph()
                } label: {
                    HStack(spacing: 6) {
                        if isGenerating {
                            GradientSpinner()
                        }
                        Text(isGenerating ? "Queuing..." : "Generate Photograph")
                    }
                }
                .disabled(!canGenerate)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(tertiarySystemFill)
    }

    private var compactControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Describe Viewfinder")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField(
                        "Describe your subject (e.g., organic sunscreen bottle, luxury skincare...)",
                        text: $productDescription,
                        axis: .vertical
                    )
                    .lineLimit(2 ... 4)
                    .onChange(of: productDescription) { _, newValue in
                        photoshoot.productDescription = newValue
                        try? modelContext.save()
                    }
                }
                .padding(16)

                Divider()

                LabeledContent("Camera Angle") {
                    Picker("Camera Angle", selection: $selectedCameraAngle) {
                        ForEach(PhotoshootCameraAngle.allCases) { angle in
                            Text(angle.displayName).tag(angle)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                LabeledContent("Position") {
                    Picker("Position", selection: $selectedProductPosition) {
                        ForEach(PhotoshootProductPosition.allCases) { position in
                            Text(position.displayName).tag(position)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                Button {
                    generatePhotograph()
                } label: {
                    HStack(spacing: 8) {
                        Spacer()
                        if isGenerating {
                            GradientSpinner()
                        }
                        Text(isGenerating ? "Queuing..." : "Generate")
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canGenerate)
                .padding(16)
            }
            .background(tertiarySystemFill)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(
                canGenerate
                    ? "Backdrop and subjects are ready."
                    : "Add a backdrop and at least one subject."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.all, 16)
    }

    // MARK: - Backdrop Selection Rail

    private var backdropSelectionRail: some View {
        Group {
            if backdropsManager.isReady(for: photoshoot.dimensionsEnum) {
                backdropLibraryRail
            } else {
                backdropDownloadStateRail
            }
        }
        .background(tertiarySystemFill)
    }

    @ViewBuilder
    private var backdropDownloadStateRail: some View {
        let dimension: PhotoshootDimension = photoshoot.dimensionsEnum
        let state: BackdropDownloadState = backdropsManager.state(for: dimension)
        let progress: Double = backdropsManager.progress(for: dimension)

        switch state {
        case .notDownloaded:
            Group {
                if shouldUseCompactMobileLayout {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Download Backdrops", systemImage: "photo.on.rectangle.angled")
                            .font(.body)

                        Text(dimension.backdropDownloadDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            backdropsManager.downloadIfNeeded(for: dimension)
                        } label: {
                            Label("Download", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundStyle(.secondary)

                        Text(dimension.backdropDownloadDescription)
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            backdropsManager.downloadIfNeeded(for: dimension)
                        } label: {
                            Label("Download Backdrops", systemImage: "arrow.down.circle")
                        }
                    }
                }
            }
            .frame(minHeight: 56)

        case .downloading, .extracting:
            Group {
                if shouldUseCompactMobileLayout {
                    VStack(alignment: .leading, spacing: 12) {
                        ProgressView(value: progress) {
                            Text(state.statusMessage)
                                .font(.subheadline)
                        } currentValueLabel: {
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .progressViewStyle(.linear)
                    }
                } else {
                    HStack(spacing: 12) {
                        ProgressView(value: progress) {
                            Text(state.statusMessage)
                                .font(.subheadline)
                        } currentValueLabel: {
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 360)
                    }
                }
            }
            .frame(minHeight: 56, alignment: .center)

        case let .failed(error):
            Group {
                if shouldUseCompactMobileLayout {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Backdrop download failed", systemImage: "exclamationmark.triangle")
                            .font(.body)
                            .foregroundStyle(.red)

                        Text(error)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            backdropsManager.retry(for: dimension)
                        } label: {
                            Label("Try Again", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.red)

                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            backdropsManager.retry(for: dimension)
                        } label: {
                            Label("Try Again", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
            .frame(minHeight: 56)

        case .ready:
            EmptyView()
        }
    }

    @ViewBuilder
    private var backdropLibraryRail: some View {
        let thumbnailHeight: CGFloat = shouldUseCompactMobileLayout ? 80 : 64
        let spacing: CGFloat = 0

        #if os(macOS)
        let scrollbarReserve: CGFloat = 12
        #else
        let scrollbarReserve: CGFloat = 0
        #endif

        ScrollView(.horizontal) {
            LazyHStack(spacing: spacing) {
                uploadBackdropTile(height: thumbnailHeight)

                ForEach(backdropIndices, id: \.self) { index in
                    backdropAssetThumbnail(index: index, height: thumbnailHeight)
                }
            }
            .padding(.bottom, scrollbarReserve)
        }
        .scrollIndicators(.visible)
        .frame(height: thumbnailHeight + scrollbarReserve)
        .id(photoshoot.dimensionsEnum)
        .background(tertiarySystemFill)
    }

    private var compactBackdropSection: some View {
        Group {
            if hasActivatedBackdropRail {
                if backdropsManager.isReady(for: photoshoot.dimensionsEnum) {
                    backdropLibraryRail
                } else {
                    backdropDownloadStateRail
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(systemBackground)
                }
            } else {
                Color.clear
                    .frame(height: 80)
                    .overlay(GradientSpinner())
            }
        }
    }

    private func uploadBackdropTile(height: CGFloat) -> some View {
        Button {
            showBackdropPicker = true
        } label: {
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
                .frame(width: backdropThumbnailWidth(for: height), height: height)
                .overlay {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
        }
        .buttonStyle(.plain)
    }

    private func backdropAssetThumbnail(index: Int, height: CGFloat) -> some View {
        Button {
            selectedBackdropIndex = index
            customBackdrop = nil
            saveBackdropSelection()
        } label: {
            BackdropThumbnailImage(
                dimension: photoshoot.dimensionsEnum,
                index: index,
                isSelected: selectedBackdropIndex == index
            )
            .frame(width: backdropThumbnailWidth(for: height), height: height)
        }
        .buttonStyle(.plain)
    }

    private func backdropThumbnailWidth(for height: CGFloat) -> CGFloat {
        let naturalWidth = height * photoshoot.dimensionsEnum.aspectRatio

        if photoshoot.dimensionsEnum.isPortrait {
            return naturalWidth
        }

        return max(64, naturalWidth)
    }

    // MARK: - Generation

    private func generatePhotograph() {
        guard canGenerate else { return }

        isGenerating = true

        // Get provider key
        guard
            let providerKey = providerKeysForProject.first(where: {
                $0.providerId.uuidString == photoshoot.providerId
            })
        else {
            showError(message: "Provider not found")
            isGenerating = false
            return
        }

        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else {
            showError(message: "Provider not found")
            isGenerating = false
            return
        }

        // Get provider secret
        let keychainKey = ProjectManager.keychainKey(
            projectId: projectManager.currentProjectId,
            providerId: providerKey.providerId
        )
        guard let providerSecret = keychain.get(keychainKey) else {
            showError(message: "Provider secret not found")
            isGenerating = false
            return
        }

        // Create photoshoot item
        let backdropAssetName: String? = selectedBackdropIndex.map { index in
            String(format: "pod_%@_%05d", photoshoot.dimensionsEnum.podiumFolderName, index)
        }
        let item = ProductPhotoshootItem(
            photoshootId: photoshoot.id,
            projectId: projectManager.currentProjectId,
            backdropAssetName: backdropAssetName
        )

        let prompt = buildPrompt()
        let model = ProviderService.shared.model(by: photoshoot.modelId)
        let generationDimensions = photoshoot.dimensionsEnum.generationDimension(
            supportedDimensions: model?.modelParams.effectiveDimensions ?? []
        )
        var config = ImageGenerationConfiguration()
        config.selectedProviderId = photoshoot.providerId
        config.selectedModelId = photoshoot.modelId
        config.prompt = prompt
        config.selectedDimensions = generationDimensions
        item.imageGenerationConfiguration = config

        modelContext.insert(item)
        try? modelContext.save()

        // Get model info
        let defaultRefType = model?.modelParams.supportedReferenceTypes.first ?? "style"
        let maxReferenceImages = model?.modelParams.maxReferenceImages
        let selectedBackdropIndex = selectedBackdropIndex
        let backdropImage =
            customBackdrop ?? (loadedBackdropIndex == selectedBackdropIndex ? loadedBackdropImage : nil)
        let dimension = photoshoot.dimensionsEnum
        let productObjects = productObjects

        showGenerationUnderwayAlertIfNeeded()

        Task {
            let referenceImages = await buildReferenceImages(
                backdropImage: backdropImage,
                selectedBackdropIndex: selectedBackdropIndex,
                dimension: dimension,
                productObjects: productObjects,
                defaultRefType: defaultRefType,
                maxReferenceImages: maxReferenceImages
            )

            submitPreparedGeneration(
                item: item,
                prompt: prompt,
                dimensions: generationDimensions,
                referenceImages: referenceImages,
                providerKeyInfo: providerKeyInfo,
                providerSecret: providerSecret
            )
        }
    }

    private func buildReferenceImages(
        backdropImage: PlatformImage?,
        selectedBackdropIndex: Int?,
        dimension: PhotoshootDimension,
        productObjects: [PlatformImage],
        defaultRefType: String,
        maxReferenceImages: Int?
    ) async -> [ReferenceImageData] {
        await Task.detached(priority: .userInitiated) {
            var referenceImages: [ReferenceImageData] = []

            let backdropCacheKey: String? = selectedBackdropIndex.map { index in
                "backdrop_\(dimension.podiumFolderName)_\(index)"
            }

            let resolvedBackdropImage =
                backdropImage
                    ?? selectedBackdropIndex.flatMap { index in
                        PodiumBackdropsManager.loadImage(for: dimension, index: index)
                    }

            if let backdropBase64 = resolvedBackdropImage?.toBase64PNG() {
                referenceImages.append(
                    ReferenceImageData(
                        base64Image: backdropBase64,
                        referenceType: defaultRefType,
                        cacheKey: backdropCacheKey
                    )
                )
            }

            for object in productObjects {
                if let base64 = object.toBase64PNG() {
                    referenceImages.append(
                        ReferenceImageData(
                            base64Image: base64,
                            referenceType: defaultRefType,
                            cacheKey: nil
                        )
                    )
                }
            }

            if let maxReferenceImages, referenceImages.count > maxReferenceImages {
                referenceImages = Array(referenceImages.prefix(maxReferenceImages))
            }

            return referenceImages
        }.value
    }

    @MainActor
    private func submitPreparedGeneration(
        item: ProductPhotoshootItem,
        prompt: String,
        dimensions: String,
        referenceImages: [ReferenceImageData],
        providerKeyInfo: ProviderKeyInfo,
        providerSecret: String
    ) {
        let request = ImageGenerationRequest(
            modelId: photoshoot.modelId,
            prompt: prompt,
            dimensions: dimensions,
            clientReferenceImages: referenceImages.isEmpty ? nil : referenceImages,
            providerKey: providerKeyInfo,
            providerSecret: providerSecret
        )

        let queueItem = queueManager.submitImageGeneration(
            request: request,
            modelContext: modelContext,
            source: .PRODUCT_PHOTOSHOOTS
        )

        item.queueItemId = queueItem.id
        try? modelContext.save()

        isGenerating = false

        // Monitor queue item in background
        Task {
            await monitorQueueItem(queueItem, for: item)
        }
    }

    private func showGenerationUnderwayAlertIfNeeded() {
        guard !hasShownGenerationUnderwayAlert else { return }

        hasShownGenerationUnderwayAlert = true
        showGenerationUnderwayAlert = true
    }

    private func buildPrompt() -> String {
        var parts: [String] = []

        parts.append("Generate a professional product photograph.")

        // Product description with context
        if !productDescription.isEmpty {
            parts.append("Subject: \(productDescription).")
        }

        // Camera angle with professional photography context
        switch selectedCameraAngle {
        case .left:
            parts.append(
                "Camera: Full left profile view at 90 degrees, capturing the side silhouette with dramatic side lighting that emphasizes depth and texture."
            )
        case .left45:
            parts.append(
                "Camera: Three-quarter view from the left at 45 degrees, the classic hero angle that shows both front face and side depth with balanced lighting."
            )
        case .center:
            parts.append(
                "Camera: Direct frontal view, symmetrical composition with even studio lighting, perfect for showcasing labels, branding, and front-facing details."
            )
        case .right45:
            parts.append(
                "Camera: Three-quarter view from the right at 45 degrees, dynamic hero angle revealing front and side dimensions with professional rim lighting."
            )
        case .right:
            parts.append(
                "Camera: Full right profile view at 90 degrees, side-on perspective highlighting the product's depth profile with accent side lighting."
            )
        case .top:
            parts.append(
                "Camera: Overhead flat-lay view looking straight down, perfect for showcasing packaging design, product shape, and arrangement from above with soft diffused lighting."
            )
        }

        // Product positioning with physics and composition context
        switch selectedProductPosition {
        case .onGround:
            parts.append(
                "Placement: Product resting naturally on the surface with realistic shadow contact, grounded composition suggesting stability and premium quality."
            )
        case .floatingStraight:
            parts.append(
                "Placement: Product levitating upright in mid-air with subtle shadow below, clean suspended composition with perfect vertical alignment suggesting weightlessness and elegance."
            )
        case .floatingTilted:
            parts.append(
                "Placement: Product floating dynamically with artistic tilt angle, energetic suspended pose with drop shadow creating depth, conveying motion and modern appeal."
            )
        }

        // Multiple subjects handling
        if productObjects.count > 1 {
            parts.append(
                "Composition includes \(productObjects.count) subjects arranged harmoniously, maintaining visual hierarchy with the primary subject prominent and secondary items complementing the scene."
            )
        }

        // Quality and style guidance
        parts
            .append(
                "Render with sharp focus, professional studio lighting, clean background integration, and high-end commercial polish."
            )

        return parts.joined(separator: " ")
    }

    @MainActor
    private func monitorQueueItem(_ queueItem: QueueItem, for item: ProductPhotoshootItem) async {
        // Poll for status changes
        while queueItem.status == .IN_PROGRESS {
            try? await Task.sleep(for: .milliseconds(500))
        }

        if queueItem.status == .SUCCESSFUL {
            item.status = .GENERATED
            if let resultSetId = queueItem.resultSetId {
                let descriptor = FetchDescriptor<Generation>(
                    predicate: #Predicate { $0.setId == resultSetId }
                )
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

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - State Persistence

    /// Loads persisted state from the photoshoot model (lightweight, main thread safe)
    private func loadPersistedState() {
        isRestoringPersistedState = true
        productDescription = photoshoot.productDescription
        selectedBackdropIndex = photoshoot.selectedBackdropIndex
        selectedCameraAngle = photoshoot.cameraAngleEnum
        selectedProductPosition = photoshoot.productPositionEnum

        Task { @MainActor in
            await Task.yield()
            isRestoringPersistedState = false
        }
    }

    /// Loads persisted images asynchronously to avoid blocking the main thread.
    private func loadPersistedImages() async {
        let backdropData = photoshoot.customBackdropData
        let objectsData = photoshoot.productObjectsData

        // Decode images on background thread
        let (backdrop, objects) = await Task.detached(priority: .userInitiated) {
            let decodedBackdrop: PlatformImage? =
                if let data = backdropData {
                    #if os(macOS)
                    NSImage(data: data)
                    #else
                    UIImage(data: data)
                    #endif
                } else {
                    nil
                }

            let decodedObjects: [PlatformImage] = objectsData.compactMap { data in
                #if os(macOS)
                NSImage(data: data)
                #else
                UIImage(data: data)
                #endif
            }

            return (decodedBackdrop, decodedObjects)
        }.value

        // Update UI on main thread
        customBackdrop = backdrop
        productObjects = objects
        if let backdrop {
            previewBackdropImage = backdrop
        }

        if customBackdrop == nil, let selectedBackdropIndex {
            loadBackdropImageAsync(index: selectedBackdropIndex)
        }

        // Library backdrops are loaded explicitly here because initial state restore
        // suppresses onChange work to keep session switching responsive.
    }

    /// Loads a backdrop image from the library asynchronously.
    /// This avoids synchronous disk I/O in the view body.
    private func loadBackdropImageAsync(index: Int) {
        let dimension = photoshoot.dimensionsEnum

        Task.detached(priority: .userInitiated) {
            let image = PodiumBackdropsManager.loadImage(for: dimension, index: index)
            await MainActor.run {
                // Only update if the index is still selected (avoid race conditions)
                if selectedBackdropIndex == index {
                    loadedBackdropImage = image
                    loadedBackdropIndex = index
                    previewBackdropImage = image
                }
            }
        }
    }

    /// Saves the selected backdrop index to the model
    private func saveBackdropSelection() {
        let saveId = UUID()
        let backdropIndex = selectedBackdropIndex
        let backdropImage = customBackdrop

        backdropPersistenceId = saveId
        photoshoot.selectedBackdropIndex = selectedBackdropIndex

        guard let backdropImage else {
            photoshoot.customBackdropData = nil
            try? modelContext.save()
            return
        }

        Task {
            let data = await Task.detached(priority: .utility) {
                backdropImage.toPNGData()
            }.value

            await MainActor.run {
                guard backdropPersistenceId == saveId else { return }

                photoshoot.selectedBackdropIndex = backdropIndex
                photoshoot.customBackdropData = data
                try? modelContext.save()
            }
        }
    }

    /// Saves the product objects to the model
    private func saveProductObjects() {
        let saveId = UUID()
        let objects = productObjects

        productObjectsPersistenceId = saveId

        Task {
            let objectData = await Task.detached(priority: .utility) {
                objects.compactMap { $0.toPNGData() }
            }.value

            await MainActor.run {
                guard productObjectsPersistenceId == saveId else { return }

                photoshoot.productObjectsData = objectData
                try? modelContext.save()
            }
        }
    }

    /// Saves the camera angle to the model
    private func saveCameraAngle() {
        photoshoot.cameraAngleEnum = selectedCameraAngle
        try? modelContext.save()
    }

    /// Defers the SwiftData write until after the picker has closed.
    private func scheduleProductPositionSave() {
        productPositionSaveTask?.cancel()
        let position = selectedProductPosition

        productPositionSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            photoshoot.productPositionEnum = position
            try? modelContext.save()
        }
    }

    // MARK: - Google File Cache Pre-warming

    /// Gets the Google Cloud API key if available.
    private func getGoogleApiKey() -> String? {
        let googleProviderId = EnumProviderCode.GOOGLE_CLOUD.providerId
        guard providerKeysForProject.contains(where: { $0.providerId == googleProviderId }) else {
            return nil
        }
        let keychainKey = ProjectManager.keychainKey(
            projectId: projectManager.currentProjectId,
            providerId: googleProviderId
        )
        return keychain.get(keychainKey)
    }

    /// Pre-warms the Google file cache with the current backdrop image.
    /// All heavy work (image loading, PNG encoding) runs in background.
    private func prewarmBackdropCache() {
        guard let apiKey = getGoogleApiKey() else { return }

        let dimension = photoshoot.dimensionsEnum
        let backdropIndex = selectedBackdropIndex
        let customBackdropImage = customBackdrop

        Task.detached(priority: .utility) {
            if let index = backdropIndex,
               let image = PodiumBackdropsManager.loadImage(for: dimension, index: index),
               let imageData = image.toPNGData()
            {
                // Use explicit cache key for library backdrops (static)
                let cacheKey = "backdrop_\(dimension.podiumFolderName)_\(index)"
                GeminiFileUriCache.shared.prewarm(
                    cacheKey: cacheKey,
                    imageData: imageData,
                    apiKey: apiKey,
                    displayName: "backdrop_\(index)"
                )
            } else if let customBackdrop = customBackdropImage,
                      let imageData = customBackdrop.toPNGData()
            {
                // Custom backdrop uses content hash (cacheKey nil)
                GeminiFileUriCache.shared.prewarm(
                    cacheKey: nil,
                    imageData: imageData,
                    apiKey: apiKey,
                    displayName: "custom_backdrop"
                )
            }
        }
    }

    /// Pre-warms the Google file cache with a product object image.
    /// All heavy work (PNG encoding) runs in background.
    private func prewarmObjectCache(image: PlatformImage) {
        guard let apiKey = getGoogleApiKey() else { return }

        Task.detached(priority: .utility) {
            guard let imageData = image.toPNGData() else { return }

            // Objects use content hash for caching (cacheKey nil)
            GeminiFileUriCache.shared.prewarm(
                cacheKey: nil,
                imageData: imageData,
                apiKey: apiKey,
                displayName: "product_object"
            )
        }
    }

    /// Pre-warms the Google file cache with all current product objects.
    private func prewarmAllObjectsCache() {
        for image in productObjects {
            prewarmObjectCache(image: image)
        }
    }

    private func compactSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

// MARK: - BackdropThumbnailImage

/// Async-loading thumbnail for backdrop images in the library grid.
///
/// Uses thumbnail versions for fast loading in the grid preview.
/// Full-size images are loaded separately when selected for the backdrop center.
struct BackdropThumbnailImage: View {
    let dimension: PhotoshootDimension
    let index: Int
    let isSelected: Bool

    @State private var image: PlatformImage?

    var body: some View {
        Group {
            if let image {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                #else
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                #endif
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .overlay(
                        GradientSpinner()
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .task(id: index) {
            await loadThumbnail()
        }
    }

    @MainActor
    private func loadThumbnail() async {
        // Load thumbnail URL from manager for faster grid loading
        guard let url = PodiumBackdropsManager.shared.thumbnailURL(for: dimension, index: index) else {
            return
        }

        let loadedImage: PlatformImage? = await Task.detached(priority: .medium) {
            #if os(macOS)
            return NSImage(contentsOf: url)
            #else
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
            #endif
        }.value

        image = loadedImage
    }
}
