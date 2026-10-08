// MARK: - VideoGenerateCardView.swift

// Card view for video generation workflow steps.
//
// Similar to ImageGenerateCardView but for video generation:
// - Model selection (video generation models)
// - Prompt input with {{input}} template support
// - Duration, FPS, resolution controls
// - Source image from previous card
// - Output video preview when complete
//
// ## ViewModel
// Uses AgentVideoCardViewModel to manage card configuration
// with auto-save to AgentCard.videoGenerationConfiguration.

import AVFoundation
import SwiftData
import SwiftUI

/// Card view for video generation workflow configuration.
struct VideoGenerateCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var card: AgentCard
    var isHovered = false
    var isRunning = false
    var isErrored = false
    var errorMessage: String?
    var previousInput = PreviousCardInput()
    var isLocked = false

    @EnvironmentObject private var projectManager: ProjectManager
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared
    @StateObject private var viewModel = AgentVideoCardViewModel()
    @State private var sourceImageThumbnail: PlatformImage?
    @State private var isOutputExpanded = false
    @State private var outputVideoURL: URL?
    @State private var isLoadingOutput = false
    @State private var outputGeneration: Generation?

    private var providerKeys: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    private func fetchOutputGeneration() {
        guard let genId = card.generationId else {
            outputGeneration = nil
            return
        }
        let descriptor = FetchDescriptor<Generation>(predicate: #Predicate { $0.id == genId })
        outputGeneration = try? modelContext.fetch(descriptor).first
    }

    private var selectedModel: ProviderModel? {
        viewModel.getSelectedModel()
    }

    private func seedInputTemplatePromptIfNeeded() {
        guard previousInput.hasText,
              viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }

        viewModel.prompt = "{{input}}"
    }

    private var inputImageIdentifier: ObjectIdentifier? {
        guard let image = previousInput.image else { return nil }
        return ObjectIdentifier(image)
    }

    var body: some View {
        CardContainerView(
            isHovered: isHovered,
            isRunning: isRunning,
            isErrored: isErrored,
            errorMessage: errorMessage
        ) {
            CardHeaderView(
                title: "Video Generation",
                icon: "video.fill",
                iconColor: label,
                hasGenerationId: card.generationId != nil
            )
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                modelSelectionSection
                sourceImageSection
                promptSection
                toolsSection
                parametersSection
            }
            .disabled(isLocked)
        } footer: {
            outputFooterView
        }
        .onAppear {
            viewModel.bind(to: card, providerKeys: providerKeys)
            seedInputTemplatePromptIfNeeded()
            if viewModel.usePreviousImageAsSourceImage { generateSourceThumbnail() }
            fetchOutputGeneration()
            loadOutputVideoIfNeeded()
        }
        .onChange(of: previousInput.text) { _, _ in
            seedInputTemplatePromptIfNeeded()
        }
        .onChange(of: card.generationId) { _, _ in
            fetchOutputGeneration()
            loadOutputVideoIfNeeded()
        }
        .onChange(of: inputImageIdentifier) { _, _ in
            if viewModel.usePreviousImageAsSourceImage {
                sourceImageThumbnail = nil
                generateSourceThumbnail()
            }
        }
    }

    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardDropdownPicker(
                label: "Provider",
                selection: $viewModel.selectedProviderId,
                options: viewModel.getSupportedProviders(providerKeys: providerKeys).map(\.providerId.uuidString),
                displayName: { id in
                    UUID(uuidString: id).flatMap { providersById[$0]?.providerName } ?? "Select Provider"
                },
                iconName: { id in
                    guard let provider = UUID(uuidString: id).flatMap({ providersById[$0] }) else { return "" }
                    return providerArtworkName(code: provider.providerCode, variant: .square)
                },
                placeholder: "Select Provider",
                emptyOption: "",
                onChange: { viewModel.handleProviderChange() }
            )

            if !viewModel.selectedProviderId.isEmpty {
                CardDropdownPicker(
                    label: "Model",
                    selection: $viewModel.selectedModelId,
                    options: viewModel.getSupportedModels().map(\.modelId.uuidString),
                    displayName: { id in
                        viewModel.getSupportedModels().first { $0.modelId.uuidString == id }?
                            .modelName ?? "Select Model"
                    },
                    placeholder: "Select Model",
                    emptyOption: "",
                    onChange: { viewModel.handleModelChange() }
                )
            }
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardPromptField(
                label: "Prompt",
                text: $viewModel.prompt,
                hint: "{{input}} inserts the previous card input"
            )

            if selectedModel?.modelParams.supportsNegativePrompt == true {
                CardPromptField(
                    label: "Negative Prompt",
                    text: $viewModel.negativePrompt,
                    minHeight: 40,
                    maxHeight: 60
                )
            }
        }
    }

    @ViewBuilder
    private var sourceImageSection: some View {
        if viewModel.supportsSourceImage(), previousInput.canProvideImage {
            VStack(alignment: .leading, spacing: 12) {
                CardSectionLabel(text: "Source Image")

                Toggle(isOn: $viewModel.usePreviousImageAsSourceImage) {
                    Text("Use Input as Source Image").font(.callout)
                }
                #if os(macOS)
                .toggleStyle(.checkbox)
                #endif
                .onChange(of: viewModel.usePreviousImageAsSourceImage) { _, isOn in
                    if isOn { generateSourceThumbnail() }
                }

                if viewModel.usePreviousImageAsSourceImage {
                    HStack(spacing: 8) {
                        if previousInput.isImagePlaceholder {
                            CardInputPlaceholderCell(isLocked: isLocked)
                        } else if let thumbnail = sourceImageThumbnail {
                            CardInputImageCell(image: thumbnail, isLocked: isLocked)
                        } else if let image = previousInput.image {
                            CardInputImageCell(image: image, isLocked: isLocked)
                        }

                        Text("The input image will be used as the first frame for video generation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var toolsSection: some View {
        if selectedModel?.modelParams.supportsTools == true {
            let tools = viewModel.supportedTools()
            if !tools.isEmpty {
                CardToolsPicker(
                    label: "Available Tools",
                    selection: $viewModel.selectedTools,
                    tools: tools
                )
            }
        }
    }

    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let dimensions = selectedModel?.modelParams.effectiveDimensions, !dimensions.isEmpty {
                CardStringDropdown(
                    label: "Dimensions",
                    selection: $viewModel.dimensions,
                    options: dimensions,
                    capitalize: false
                )
            }

            let durations = viewModel.supportedVideoDurations()
            if !durations.isEmpty {
                CardIntDropdown(
                    label: "Duration (seconds)",
                    selection: $viewModel.durationSeconds,
                    options: durations
                )
            }

            let resolutions = viewModel.supportedVideoResolutions()
            if !resolutions.isEmpty {
                CardStringDropdown(
                    label: "Resolution",
                    selection: $viewModel.selectedResolution,
                    options: resolutions,
                    capitalize: false
                )
            }

            let fpsOptions = viewModel.supportedVideoFPS()
            if !fpsOptions.isEmpty {
                CardIntDropdown(
                    label: "FPS",
                    selection: $viewModel.selectedFPS,
                    options: fpsOptions
                )
            }

            if viewModel.supportsAudio() {
                CardToggle(label: "Generate Audio", isOn: $viewModel.generateAudio)
            }

            if let guidanceRange = selectedModel?.modelParams.supportedGuidanceRange {
                CardSlider(
                    label: "Guidance Scale",
                    value: $viewModel.guidanceValue,
                    range: guidanceRange.min ... guidanceRange.max,
                    step: 0.1,
                    valueFormatter: { String(format: "%.1f", $0) }
                )
            }

            if let safetyRange = selectedModel?.modelParams.supportedSafetyRange {
                CardSlider(
                    label: "Safety Tolerance",
                    value: $viewModel.safetyValue,
                    range: Double(safetyRange.min) ... Double(safetyRange.max)
                )
            }

            if selectedModel?.modelParams.supportsSeed == true {
                CardSeedField(label: "Seed", value: $viewModel.seedValue)
            }

            if selectedModel?.modelParams.supportsPromptEnhance == true {
                CardToggle(label: "Enhance Prompt", isOn: $viewModel.modelPromptEnhance)
            }
        }
    }

    private func generateSourceThumbnail() {
        guard let inputImage = previousInput.image else { return }
        Task.detached(priority: .userInitiated) {
            let thumbnail = inputImage.resizedToFit(maxPixels: 96 * 96)
            await MainActor.run {
                sourceImageThumbnail = thumbnail
            }
        }
    }

    private func loadOutputVideoIfNeeded() {
        guard let generation = outputGeneration else {
            outputVideoURL = nil
            return
        }

        guard outputVideoURL == nil else { return }

        isLoadingOutput = true
        let genId = generation.id.uuidString

        Task.detached(priority: .background) {
            let fileManager = FileManager.default
            let videoURL: URL? = {
                guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    return nil
                }
                let url = documentsURL.appendingPathComponent("\(genId).mp4")
                return fileManager.fileExists(atPath: url.path) ? url : nil
            }()

            await MainActor.run {
                outputVideoURL = videoURL
                isLoadingOutput = false
            }
        }
    }

    private func formatLastRun(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "<1 min"
        }
        return date.formatted(.relative(presentation: .named))
    }

    private var outputFooterView: some View {
        VStack(spacing: 0) {
            Button {
                if outputGeneration != nil {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isOutputExpanded.toggle()
                    }
                }
            } label: {
                HStack {
                    if outputGeneration != nil {
                        Image(systemName: isOutputExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        Text("Output")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let date = outputGeneration?.createdAt {
                        Text(formatLastRun(date))
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("Not run yet")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(outputGeneration == nil)

            if isOutputExpanded, outputGeneration != nil {
                outputPreviewSection
                    .padding(.top, 10)
            }
        }
    }

    private var outputPreviewSection: some View {
        VStack(spacing: 10) {
            if isLoadingOutput {
                HStack {
                    Spacer()
                    GradientSpinner()
                    Spacer()
                }
                .frame(height: 150)
                .background(secondarySystemFill)
                .cornerRadius(8)
            } else if let videoURL = outputVideoURL {
                CardVideoPlayer(url: videoURL)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 24))
                            .foregroundStyle(.tertiary)
                        Text("Video not found")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .frame(height: 80)
                .background(secondarySystemFill)
                .cornerRadius(8)
            }
        }
    }
}

private struct CardVideoPlayer: View {
    let url: URL

    @State private var player: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            if let player {
                SafeVideoPlayer(player: player)
                    .onDisappear {
                        player.pause()
                    }
            } else {
                Rectangle()
                    .fill(secondarySystemFill)
                    .overlay {
                        VStack(spacing: 8) {
                            GradientSpinner()
                            Text("Loading video...")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            if !isPlaying, player != nil {
                Button {
                    player?.play()
                    isPlaying = true
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white, .black.opacity(0.4))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            player = AVPlayer(url: url)

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { _ in
                isPlaying = false
                player?.seek(to: .zero)
            }
        }
    }
}

struct CardIntDropdown: View {
    let label: String
    @Binding var selection: Int
    let options: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text("\(option)").tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
