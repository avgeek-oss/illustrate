// MARK: - GenerationVideoView.swift

// Detail view for a single video generation.
//
// Shows comprehensive details and actions for a generated video:
// - Video player with playback controls
// - Generation metadata (prompt, model, duration, cost)
// - Source image/video (if applicable)
// - Actions: save, share, extend, delete
//
// ## Video Playback
// Uses AVKit's VideoPlayer for native playback controls.
// Video loaded async from iCloud via ICloudVideoLoader.
//
// ## Extend Video
// If video has required metadata (soraVideoId, veoGeneratedUri),
// shows "Extend" action to continue the video.
//
// ## Platform Differences
// - macOS: Save to file
// - iOS: Share sheet, save to Photos

import AVFoundation
import IllustrateProviders
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

#if !os(macOS)
import Photos
import UIKit

/// iOS share sheet wrapper for video sharing.
struct VideoShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]?

    func makeUIViewController(context _: UIViewControllerRepresentableContext<VideoShareSheet>)
        -> UIActivityViewController
    {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(
        _: UIActivityViewController,
        context _: UIViewControllerRepresentableContext<VideoShareSheet>
    ) {}
}
#endif

private func formatVideoMetadataKey(_ key: String) -> String {
    var result = key
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)

    result = result.split(separator: " ").map { word in
        word.prefix(1).uppercased() + word.dropFirst().lowercased()
    }.joined(separator: " ")

    return result
}

struct GenerationVideoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var navigationManager: NavigationManager

    #if os(macOS)
    /// Indicates if this view is displayed in a standalone preview window
    @Environment(\.isPreviewWindow) private var isPreviewWindow
    #endif

    @State var setId: UUID
    @State private var imageSet: ImageSet?
    @State private var generations: [Generation] = []
    @State private var generationIndex = 0

    @State private var showDeleteConfirmation = false
    @State private var showAddToPromptGallery = false
    @State private var showShareSheet = false
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    private let providerService = ProviderService.shared

    private var canShowVideoExtendActions: Bool {
        #if os(macOS)
        !isPreviewWindow
        #else
        true
        #endif
    }

    private func getVideoAspectRatio(from dimensions: String?) -> CGFloat {
        guard let dimensions else { return 16.0 / 9.0 }

        if dimensions.contains(":") {
            let parts = dimensions.split(separator: ":")
            guard parts.count == 2,
                  let width = Double(parts[0]),
                  let height = Double(parts[1]),
                  height > 0
            else {
                return 16.0 / 9.0
            }
            return width / height
        }

        let parts = dimensions.lowercased().split(separator: "x")
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1]),
              height > 0
        else {
            return 16.0 / 9.0
        }
        return width / height
    }

    private var currentGeneration: Generation? {
        if generationIndex >= 0, generationIndex < generations.count {
            return generations[generationIndex]
        }
        return nil
    }

    func deleteImageSet() async {
        for generation in generations {
            deleteICloudDocuments(containingSubstring: generation.id.uuidString)
        }
        modelContext.delete(imageSet!)
        try? modelContext.save()

        DispatchQueue.main.async {
            presentationMode.wrappedValue.dismiss()
        }
    }

    var body: some View {
        Form {
            if currentGeneration != nil || imageSet != nil {
                Section {
                    ZStack {
                        if let colorPalette = currentGeneration?.colorPalette {
                            SmoothAnimatedGradientView(colors: colorPalette.compactMap { hex in
                                Color(getUniversalColorFromHex(hexString: hex))
                            })
                        }

                        ICloudVideoLoader(videoName: "\(currentGeneration!.id.uuidString)") { videoUrl in
                            if let videoUrl {
                                #if os(macOS)
                                SafeVideoPlayerView(url: videoUrl)
                                    .aspectRatio(
                                        getVideoAspectRatio(from: currentGeneration?.dimensions),
                                        contentMode: .fit
                                    )
                                    .frame(maxHeight: 500)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(color: .black.opacity(0.4), radius: 8)
                                    .frame(maxWidth: .infinity)
                                    .contextMenu { videoContextMenu(url: videoUrl) }
                                #else
                                SafeVideoPlayerView(url: videoUrl)
                                    .aspectRatio(
                                        getVideoAspectRatio(from: currentGeneration?.dimensions),
                                        contentMode: .fit
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .contextMenu { videoContextMenu(url: videoUrl) }
                                #endif
                            }
                        }
                        .id("video_\(currentGeneration!.id.uuidString)")
                        .padding(.vertical, 8)
                    }

                    if generations.count > 1 {
                        Picker("Select Video", selection: $generationIndex) {
                            ForEach(0 ..< generations.count, id: \.self) { index in
                                Text("\(index + 1)").tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                    }

                    #if os(macOS)
                    HStack(spacing: 12) {
                        KeyboardShortcutView(
                            keys: ["⌘", "C"],
                            description: "Copy",
                            keyEquivalent: "c"
                        ) {
                            if let currentGeneration,
                               let videoURL = loadVideoFromiCloud(currentGeneration.id.uuidString)
                            {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.writeObjects([videoURL as NSURL])
                                showToast(.success("Copied to clipboard"))
                            }
                        }

                        KeyboardShortcutView(
                            keys: ["⌘", "J"],
                            description: "Download",
                            keyEquivalent: "j"
                        ) {
                            if let currentGeneration,
                               let videoURL = loadVideoFromiCloud(currentGeneration.id.uuidString)
                            {
                                saveVideoToDownloads(url: videoURL, fileName: currentGeneration.id.uuidString)
                            }
                        }

                        if let currentGeneration,
                           canShowVideoExtendActions,
                           hasCompatibleVideoExtendModel(for: currentGeneration)
                        {
                            KeyboardShortcutView(
                                keys: ["⌘", "⌥", "X"],
                                description: videoExtendActionTitle(for: currentGeneration),
                                keyEquivalent: "x",
                                modifiers: [.command, .option]
                            ) {
                                navigateToVideoExtend(generation: currentGeneration)
                            }
                        }

                        if generationIndex > 0 {
                            KeyboardShortcutView(
                                keys: ["←"],
                                description: "Previous",
                                keyEquivalent: .leftArrow,
                                modifiers: []
                            ) {
                                generationIndex -= 1
                            }
                        }

                        if generationIndex < generations.count - 1 {
                            KeyboardShortcutView(
                                keys: ["→"],
                                description: "Next",
                                keyEquivalent: .rightArrow,
                                modifiers: []
                            ) {
                                generationIndex += 1
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    #endif
                }

                ReferenceMediaSection(generationId: currentGeneration!.id)

                if let prompt = currentGeneration?.prompt,
                   !prompt.isEmpty
                {
                    Section("User Prompts") {
                        SectionKeyValueView(
                            icon: "text.quote",
                            key: "Requested Prompt",
                            value: prompt,
                            multilineValue: true
                        )
                        if let negativePrompt = currentGeneration?.negativePrompt,
                           !negativePrompt.isEmpty
                        {
                            SectionKeyValueView(
                                icon: "text.badge.minus",
                                key: "Negative Prompt",
                                value: negativePrompt,
                                multilineValue: true
                            )
                        }
                        if let searchPrompt = currentGeneration?.searchPrompt,
                           !searchPrompt.isEmpty
                        {
                            SectionKeyValueView(
                                icon: "rectangle.and.text.magnifyingglass",
                                key: "Search Prompt",
                                value: searchPrompt,
                                multilineValue: true
                            )
                        }
                        Button {
                            showAddToPromptGallery = true
                        } label: {
                            Text("Add Prompt to Prompt Gallery")
                        }
                    }
                }

                Section("Model Response") {
                    if let provider = getProvider(modelId: currentGeneration!.modelId) {
                        SectionKeyValueView(
                            icon: "link",
                            key: "Provider",
                            value: "",
                            customValueView: ProviderLabel(provider: provider)
                        )
                    }
                    if let model = ProviderService.shared.model(by: currentGeneration!.modelId) {
                        SectionKeyValueView(
                            icon: "network",
                            key: "Model",
                            value: "",
                            customValueView: ModelLabel(model: model)
                        )
                    }
                    SectionKeyValueView(
                        icon: "wand.and.sparkles",
                        key: "Auto-enhance opted",
                        value: currentGeneration!.promptEnhanceOpted ? "Yes" : "No"
                    )
                    if let promptEnhanceOpted = currentGeneration?.promptEnhanceOpted,
                       let promptAfterEnhance = currentGeneration?.promptAfterEnhance,
                       !promptAfterEnhance.isEmpty,
                       promptEnhanceOpted
                    {
                        SectionKeyValueView(
                            icon: "text.quote",
                            key: "Enhanced Prompt",
                            value: currentGeneration!.promptAfterEnhance,
                            multilineValue: true
                        )
                    }
                    if let modelRevisedPrompt = currentGeneration?.modelRevisedPrompt,
                       !modelRevisedPrompt.isEmpty
                    {
                        SectionKeyValueView(
                            icon: "text.quote",
                            key: "Response Prompt",
                            value: modelRevisedPrompt,
                            multilineValue: true
                        )
                    }
                    SectionKeyValueView(
                        icon: "dollarsign",
                        key: "Cost",
                        value: "\(String(format: "%.3f", currentGeneration!.creditUsed).replacingOccurrences(of: ".000", with: "")) \(getProvider(modelId: currentGeneration!.modelId)?.creditCurrency.rawValue ?? "Credits")"
                    )
                }

                Section("Video Metadata") {
                    SectionKeyValueView(
                        icon: "aspectratio.fill",
                        key: "Video Dimensions",
                        value: currentGeneration!.dimensions.replacingOccurrences(of: "x", with: " x "),
                        monospaced: true
                    )
                    if let requestedDimensions = currentGeneration!.metadata["requested_dimensions"],
                       !requestedDimensions.isEmpty
                    {
                        SectionKeyValueView(
                            icon: "rectangle.dashed",
                            key: "Requested Dimensions",
                            value: requestedDimensions.replacingOccurrences(of: "x", with: " x "),
                            monospaced: true
                        )
                    }
                    SectionKeyValueView(
                        icon: "internaldrive.fill",
                        key: "Video Size",
                        value: String(format: "%.2f MB", Double(currentGeneration!.size) / 1_000_000.0),
                        monospaced: true
                    )
                    if !currentGeneration!.style.isEmpty {
                        SectionKeyValueView(
                            icon: "paintpalette.fill",
                            key: "Color Style",
                            value: currentGeneration!.style
                        )
                    }
                    if !currentGeneration!.variant.isEmpty {
                        SectionKeyValueView(
                            icon: "paintbrush.fill",
                            key: "Variant",
                            value: currentGeneration!.variant
                        )
                    }
                    if !currentGeneration!.quality.isEmpty {
                        SectionKeyValueView(
                            icon: "photo",
                            key: "Video Quality",
                            value: currentGeneration!.quality
                        )
                    }
                    if let audioGenerated = currentGeneration!.metadata["audio_generated"],
                       !audioGenerated.isEmpty
                    {
                        SectionKeyValueView(
                            icon: "speaker.wave.2.fill",
                            key: "Audio Generated",
                            value: audioGenerated
                        )
                    }
                    if let durationStr = currentGeneration!.metadata["duration_seconds"],
                       let duration = Int(durationStr)
                    {
                        SectionKeyValueView(
                            icon: "clock.fill",
                            key: "Duration",
                            value: "\(duration) seconds",
                            monospaced: true
                        )
                    }
                    if let resolution = currentGeneration!.metadata["resolution"], !resolution.isEmpty {
                        SectionKeyValueView(
                            icon: "arrow.up.right.and.arrow.down.left.rectangle",
                            key: "Resolution",
                            value: resolution,
                            monospaced: true
                        )
                    }
                    if let fpsStr = currentGeneration!.metadata["fps"],
                       let fps = Int(fpsStr)
                    {
                        SectionKeyValueView(
                            icon: "film",
                            key: "Frame Rate",
                            value: "\(fps) FPS",
                            monospaced: true
                        )
                    }
                }

                VideoGenerationSettingsSection(generation: currentGeneration!)

                Section("System Information") {
                    SectionKeyValueView(
                        icon: "calendar",
                        key: "Created",
                        value: currentGeneration!.createdAt.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                    SectionKeyValueView(
                        icon: "doc.text",
                        key: "Content Type",
                        value: currentGeneration!.contentType.rawValue.replacingOccurrences(of: "_", with: " ")
                    )
                    SectionKeyValueView(
                        icon: "number",
                        key: "Generation ID",
                        value: currentGeneration!.id.uuidString,
                        monospaced: true
                    )
                }

                AdditionalMetadataSection(metadata: currentGeneration!.metadata)
                Section("Notice something wrong?") {
                    HStack {
                        Text("Send an email")
                        Spacer()
                        Link("Submit Feedback", destination: getFeedbackLink())
                    }
                }
            } else {
                Section("Video Details") {
                    Text("Loading...")
                }
                .onAppear {
                    loadData()
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showAddToPromptGallery) {
            if let generation = currentGeneration {
                PromptGalleryEditSheet(
                    mode: .create,
                    onSave: { title, prompt, tags in
                        let item = PromptGalleryItem(
                            projectId: generation.projectId,
                            title: title,
                            prompt: prompt,
                            tags: tags
                        )
                        modelContext.insert(item)
                    },
                    prefillPrompt: generation.prompt,
                    prefillTags: autoTags(for: generation)
                )
            }
        }
        .toolbar {
            if imageSet != nil {
                ToolbarItem(placement: .automatic) {
                    Button("Download", systemImage: "arrow.down") {
                        let videoURL: URL? = loadVideoFromiCloud("\(currentGeneration!.id.uuidString)")
                        if let videoURL {
                            #if os(macOS)
                            saveVideoToDownloads(url: videoURL, fileName: "\(currentGeneration!.id.uuidString)")
                            #else
                            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                                DispatchQueue.main.async {
                                    if status == .authorized || status == .limited {
                                        PHPhotoLibrary.shared().performChanges({
                                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                                        }) { success, error in
                                            DispatchQueue.main.async {
                                                if success {
                                                    showSaveSuccess = true
                                                } else {
                                                    saveErrorMessage = error?
                                                        .localizedDescription ?? "Failed to save video"
                                                    showSaveError = true
                                                }
                                            }
                                        }
                                    } else {
                                        saveErrorMessage =
                                            "Photo library access denied. Please enable access in Settings."
                                        showSaveError = true
                                    }
                                }
                            }
                            #endif
                        }
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Share", systemImage: "square.and.arrow.up") {
                        let videoURL: URL? = loadVideoFromiCloud("\(currentGeneration!.id.uuidString)")
                        if let videoURL {
                            Task {
                                #if os(macOS)
                                shareVideo(url: videoURL)
                                #else
                                DispatchQueue.main.async {
                                    showShareSheet = true
                                }
                                #endif
                            }
                        }
                    }
                }
                if let currentGeneration,
                   canShowVideoExtendActions,
                   hasCompatibleVideoExtendModel(for: currentGeneration)
                {
                    ToolbarItem(placement: .automatic) {
                        Button(videoExtendActionTitle(for: currentGeneration), systemImage: "wand.and.sparkles") {
                            navigateToVideoExtend(generation: currentGeneration)
                        }
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        DispatchQueue.main.async {
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
        }
        #if !os(macOS)
        .sheet(isPresented: $showShareSheet) {
            if imageSet != nil {
                let videoURL: URL? = loadVideoFromiCloud("\(currentGeneration?.id.uuidString ?? "")")
                if let videoURL {
                    VideoShareSheet(activityItems: [videoURL])
                }
            }
        }
        .alert("Saved to Photos", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Video has been saved to your photo library.")
        }
        .alert("Save Failed", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        #endif
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Confirm Deletion"),
                message: Text("Are you sure you want to delete this image set?"),
                primaryButton: .destructive(Text("Delete")) {
                    Task {
                        await deleteImageSet()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .navigationTitle(labelForItem(.generationVideo(setId: setId)))
    }

    @ViewBuilder
    private func videoContextMenu(url: URL) -> some View {
        Button {
            #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([url as NSURL])
            showToast(.success("Copied to clipboard"))
            #else
            UIPasteboard.general.url = url
            showToast(.success("Copied to clipboard"))
            #endif
        } label: {
            Label("Copy video", systemImage: "doc.on.doc")
        }

        Button {
            #if os(macOS)
            saveVideoToDownloads(url: url, fileName: currentGeneration?.id.uuidString ?? "video")
            #else
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                        }) { success, _ in
                            DispatchQueue.main.async {
                                if success { showSaveSuccess = true }
                            }
                        }
                    }
                }
            }
            #endif
        } label: {
            Label("Download video", systemImage: "arrow.down")
        }

        Button {
            #if os(macOS)
            shareVideo(url: url)
            #else
            showShareSheet = true
            #endif
        } label: {
            Label("Share video", systemImage: "square.and.arrow.up")
        }

        if let currentGeneration,
           canShowVideoExtendActions,
           hasCompatibleVideoExtendModel(for: currentGeneration)
        {
            Button {
                navigateToVideoExtend(generation: currentGeneration)
            } label: {
                Label(videoExtendActionTitle(for: currentGeneration), systemImage: "wand.and.sparkles")
            }
        }

        Divider()

        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func autoTags(for generation: Generation) -> [String] {
        var tags: [String] = []
        if let model = ProviderService.shared.model(by: generation.modelId) {
            tags.append(model.modelName.lowercased())
        }
        if let provider = getProvider(modelId: generation.modelId) {
            tags.append(provider.providerCode.rawValue.lowercased())
        }
        tags.append(generation.contentType == .VIDEO ? "video" : "image")
        if generation.promptEnhanceOpted {
            tags.append("enhanced")
        }
        return tags
    }

    private func navigateToVideoExtend(generation: Generation) {
        let preload = ExtendVideoPreload(
            videoId: generation.id.uuidString,
            colorPalette: generation.colorPalette,
            dimensions: generation.dimensions,
            prompt: nil,
            negativePrompt: nil,
            generation: generation
        )
        navigationManager.navigateToExtendVideo(with: preload)
    }

    private func hasCompatibleVideoExtendModel(for generation: Generation) -> Bool {
        providerService.models(for: .VIDEO_EXTEND).contains { model in
            let requiredKeys = model.modelParams.requiredMetadata
            guard !requiredKeys.isEmpty else { return false }
            return requiredKeys.allSatisfy { key in
                generation.metadata[key]?.isEmpty == false
            }
        }
    }

    private func videoExtendActionTitle(for generation: Generation) -> String {
        if generation.metadata[GeminiInteractionMetadataKey.interactionId]?.isEmpty == false {
            return "Edit Video"
        }
        return "Extend Video"
    }

    private func loadData() {
        // Try cache first for faster lookup
        let cache = GalleryCache.shared
        if cache.isLoaded {
            if let cachedSet = cache.imageSets.first(where: { $0.id == setId }) {
                imageSet = cachedSet
                generations = cache.videoGenerations.filter { $0.setId == setId }
                    .sorted { $0.createdAt > $1.createdAt }
                if !generations.isEmpty {
                    return
                }
            }
        }

        // Fallback to database fetch
        let imageSetDescriptor = FetchDescriptor<ImageSet>(predicate: #Predicate { $0.id == setId })
        let generationsDescriptor = FetchDescriptor<Generation>(
            predicate: #Predicate { $0.setId == setId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            imageSet = try modelContext.fetch(imageSetDescriptor).first
            generations = try modelContext.fetch(generationsDescriptor)
        } catch {
            AppLogger.data.error("Error fetching data: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Reference Media Section

struct ReferenceMediaSection: View {
    let generationId: UUID

    @State private var referenceVideoURL: URL?
    @State private var hasLoadedVideo = false

    var body: some View {
        ReferenceMediaContent(
            generationId: generationId,
            referenceVideoURL: referenceVideoURL
        )
        .task(id: generationId) {
            await loadReferenceVideo()
        }
    }

    private func loadReferenceVideo() async {
        let videoURL = await Task.detached {
            loadVideoFromiCloud(".\(generationId.uuidString)_refvideo")
        }.value
        await MainActor.run {
            referenceVideoURL = videoURL
            hasLoadedVideo = true
        }
    }
}

struct ReferenceMediaContent: View {
    let generationId: UUID
    let referenceVideoURL: URL?

    private var clientImageName: String {
        ".\(generationId.uuidString)_client"
    }

    private var lastFrameImageName: String {
        ".\(generationId.uuidString)_lastframe"
    }

    var body: some View {
        ICloudImageLoader(imageName: clientImageName, showLoading: false) { clientImage in
            ICloudImageLoader(imageName: lastFrameImageName, showLoading: false) { lastFrameImage in
                ReferenceImagesLoader(generationId: generationId) { referenceImages in
                    ReferenceMediaInnerContent(
                        clientImage: clientImage,
                        lastFrameImage: lastFrameImage,
                        referenceImages: referenceImages,
                        referenceVideoURL: referenceVideoURL
                    )
                }
            }
        }
    }
}

struct ReferenceMediaInnerContent: View {
    let clientImage: PlatformImage?
    let lastFrameImage: PlatformImage?
    let referenceImages: [PlatformImage]
    let referenceVideoURL: URL?

    private var hasAnyMedia: Bool {
        clientImage != nil || lastFrameImage != nil || !referenceImages.isEmpty || referenceVideoURL != nil
    }

    var body: some View {
        if hasAnyMedia {
            Section("Reference Media") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        if let referenceVideoURL {
                            ReferenceVideoItem(
                                videoURL: referenceVideoURL,
                                label: "Primary Reference Video"
                            )
                        }

                        if let clientImage {
                            ReferenceMediaItem(
                                image: clientImage,
                                label: lastFrameImage != nil ? "First Frame" : "Primary Reference Image"
                            )
                        }

                        if let lastFrameImage {
                            ReferenceMediaItem(
                                image: lastFrameImage,
                                label: "Last Frame"
                            )
                        }

                        ForEach(Array(referenceImages.enumerated()), id: \.offset) { index, image in
                            ReferenceMediaItem(
                                image: image,
                                label: "Reference \(index + 1)"
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

struct ReferenceImagesLoader<Content: View>: View {
    let generationId: UUID
    let content: ([PlatformImage]) -> Content

    @State private var referenceImages: [PlatformImage] = []
    @State private var hasLoaded = false

    var body: some View {
        content(referenceImages)
            .task(id: generationId) {
                await loadReferenceImages()
            }
    }

    private func loadReferenceImages() async {
        let images = await Task.detached {
            var refs: [PlatformImage] = []
            for i in 0 ..< 10 {
                if let refImage = loadImageFromiCloud(".\(generationId.uuidString)_ref\(i)") {
                    refs.append(refImage)
                } else {
                    break
                }
            }
            return refs
        }.value
        await MainActor.run {
            referenceImages = images
            hasLoaded = true
        }
    }
}

struct ReferenceMediaItem: View {
    let image: PlatformImage
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            #if os(macOS)
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 150, maxHeight: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.2), radius: 4)
            #else
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 150, maxHeight: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.2), radius: 4)
            #endif

            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct ReferenceVideoItem: View {
    let videoURL: URL
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            SafeVideoPlayerView(url: videoURL)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(width: 180, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.2), radius: 4)

            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Additional Settings Section

private struct VideoGenerationSettingsSection: View {
    let generation: Generation

    private var hasGenerationSettings: Bool {
        let metadata = generation.metadata
        return metadata["motion"] != nil ||
            metadata["stickyness"] != nil ||
            metadata["seed"] != nil ||
            metadata["steps"] != nil ||
            metadata["guidance"] != nil ||
            metadata["safety_tolerance"] != nil ||
            metadata["prompt_enhance"] != nil
    }

    var body: some View {
        if hasGenerationSettings {
            Section("Additional Settings") {
                if let motion = generation.metadata["motion"], let motionValue = Int(motion) {
                    SectionKeyValueView(
                        icon: "figure.walk.motion",
                        key: "Motion Intensity",
                        value: "\(motionValue)",
                        monospaced: true
                    )
                }
                if let stickyness = generation.metadata["stickyness"], let stickynessValue = Int(stickyness) {
                    SectionKeyValueView(
                        icon: "pin.fill",
                        key: "Stickyness",
                        value: "\(stickynessValue)",
                        monospaced: true
                    )
                }
                if let seed = generation.metadata["seed"], !seed.isEmpty {
                    SectionKeyValueView(
                        icon: "dice.fill",
                        key: "Seed",
                        value: seed,
                        monospaced: true
                    )
                }
                if let steps = generation.metadata["steps"], let stepsValue = Int(steps) {
                    SectionKeyValueView(
                        icon: "stairs",
                        key: "Steps",
                        value: "\(stepsValue)",
                        monospaced: true
                    )
                }
                if let guidance = generation.metadata["guidance"], !guidance.isEmpty {
                    SectionKeyValueView(
                        icon: "slider.horizontal.3",
                        key: "Guidance Scale",
                        value: guidance,
                        monospaced: true
                    )
                }
                if let safetyTolerance = generation.metadata["safety_tolerance"],
                   let toleranceValue = Int(safetyTolerance)
                {
                    SectionKeyValueView(
                        icon: "shield.fill",
                        key: "Safety Tolerance",
                        value: "\(toleranceValue)",
                        monospaced: true
                    )
                }
                if let promptEnhance = generation.metadata["prompt_enhance"], !promptEnhance.isEmpty {
                    SectionKeyValueView(
                        icon: "wand.and.rays.inverse",
                        key: "Prompt Enhancement",
                        value: promptEnhance
                    )
                }
            }
        }
    }
}

// MARK: - Additional Metadata Section

private struct AdditionalMetadataSection: View {
    let metadata: [String: String]

    private let displayedKeys: Set = [
        "duration_seconds",
        "resolution",
        "fps",
        "audio_generated",
        "motion",
        "stickyness",
        "seed",
        "steps",
        "guidance",
        "safety_tolerance",
        "prompt_enhance",
        "requested_dimensions",
    ]

    private var additionalMetadata: [(key: String, value: String)] {
        metadata
            .filter { !displayedKeys.contains($0.key) && !$0.value.isEmpty }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        if !additionalMetadata.isEmpty {
            Section("Additional Metadata") {
                ForEach(additionalMetadata, id: \.key) { key, value in
                    SectionKeyValueView(
                        icon: iconForMetadataKey(key),
                        key: formatVideoMetadataKey(key),
                        value: value,
                        monospaced: shouldBeMonospaced(key)
                    )
                }
            }
        }
    }

    private func iconForMetadataKey(_ key: String) -> String {
        let lowercased = key.lowercased()
        if lowercased.contains("id") || lowercased.contains("uri") {
            return "link"
        } else if lowercased.contains("video") {
            return "play.fill"
        } else if lowercased.contains("duration") || lowercased.contains("time") {
            return "clock.fill"
        } else if lowercased.contains("resolution") || lowercased.contains("dimension") {
            return "aspectratio.fill"
        } else {
            return "tag"
        }
    }

    private func shouldBeMonospaced(_ key: String) -> Bool {
        let lowercased = key.lowercased()
        return lowercased.contains("id") ||
            lowercased.contains("uri") ||
            lowercased.contains("seed") ||
            lowercased.contains("step")
    }
}
