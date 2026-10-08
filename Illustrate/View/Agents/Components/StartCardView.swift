// MARK: - StartCardView.swift

// Card view for workflow start/input configuration.
//
// The start card defines the initial input for a workflow:
// - Text prompt input
// - Image selection (from picker or existing generation)
// - Input validation (at least one input required)
//
// ## Input Types
// - Text: Passed as {{input}} to downstream cards
// - Image: Used as reference/source for generation cards
// - Both: Combined for rich input workflows
//
// ## Run Integration
// Shows the last run's status and any error messages.
// Input from this card is passed to first process card.

import PhotosUI
import SwiftData
import SwiftUI

/// Card view for workflow entry point configuration.
struct StartCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var card: AgentCard
    var isHovered = false
    var isRunning = false
    var isErrored = false
    var errorMessage: String?
    var isLocked = false

    @State private var textInput = ""
    @State private var isImagePickerOpen = false
    @State private var selectedImage: PlatformImage?
    @State private var hasInitialized = false
    @State private var isLoadingImage = false
    @State private var inputGeneration: Generation?
    @State private var isImageDropTargeted = false
    @State private var isImagePickerHovered = false
    @State private var lastRun: AgentRun?

    private var isImagePickerHighlighted: Bool {
        isImageDropTargeted || isImagePickerHovered
    }

    private func fetchInputGeneration() {
        guard let genId = card.generationId else {
            inputGeneration = nil
            return
        }
        let descriptor = FetchDescriptor<Generation>(predicate: #Predicate { $0.id == genId })
        inputGeneration = try? modelContext.fetch(descriptor).first
    }

    private func fetchLastRun() {
        let agentId = card.agentId
        var descriptor = FetchDescriptor<AgentRun>(
            predicate: #Predicate { $0.agentId == agentId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        lastRun = try? modelContext.fetch(descriptor).first
    }

    private var hasAnyInput: Bool {
        !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            selectedImage != nil
    }

    var body: some View {
        CardContainerView(
            isHovered: isHovered,
            isRunning: isRunning,
            isErrored: isErrored,
            errorMessage: errorMessage
        ) {
            headerView
        } content: {
            bodyView
        } footer: {
            footerView
        }
        .task {
            fetchLastRun()
            fetchInputGeneration()
            await loadFromGenerationAsync()
        }
        .onChange(of: card.agentId) { _, _ in
            fetchLastRun()
        }
        .onChange(of: card.generationId) { _, _ in
            hasInitialized = false
            fetchInputGeneration()
            Task {
                await loadFromGenerationAsync()
            }
        }
        .onChange(of: textInput) { _, _ in
            guard hasInitialized else { return }
            updateGeneration()
        }
        .onChange(of: selectedImage) { _, _ in
            guard hasInitialized else { return }
            saveImageAndUpdateGeneration()
        }
        .imageSelection(
            id: "startCardImage",
            isPickerOpen: $isImagePickerOpen,
            onImageSelected: { image in
                selectedImage = image
            }
        )
    }

    private func loadFromGenerationAsync() async {
        guard !hasInitialized else { return }
        guard let generation = inputGeneration else {
            hasInitialized = true
            return
        }

        if !generation.prompt.isEmpty {
            textInput = generation.prompt
        }

        let genId = generation.id.uuidString
        isLoadingImage = true

        Task.detached(priority: .background) {
            let image = loadImageFromDocumentsDirectory(withName: genId)

            await MainActor.run {
                if let image {
                    selectedImage = image
                }
                isLoadingImage = false
                hasInitialized = true
            }
        }
    }

    private func updateGeneration() {
        guard let generation = inputGeneration else { return }
        generation.prompt = textInput
        try? modelContext.save()
    }

    private func saveImageAndUpdateGeneration() {
        guard let generation = inputGeneration else { return }

        guard let image = selectedImage else {
            deleteFileFromDocuments(withName: generation.id.uuidString, extension: "png")
            try? modelContext.save()
            return
        }

        let imageName = generation.id.uuidString

        #if os(macOS)
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:])
        {
            _ = saveImageToDocumentsDirectory(imageData: pngData, withName: imageName)
        }
        #else
        if let pngData = image.pngData() {
            _ = saveImageToDocumentsDirectory(imageData: pngData, withName: imageName)
        }
        #endif

        try? modelContext.save()
    }

    private func deleteFileFromDocuments(withName name: String, extension ext: String) {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = documentsURL.appendingPathComponent("\(name).\(ext)")
        try? fileManager.removeItem(at: fileURL)
    }

    private var headerView: some View {
        CardHeaderView(
            title: "Start",
            icon: "play.fill",
            iconColor: .green,
            hasGenerationId: card.generationId != nil
        )
    }

    private var bodyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            textInputField
            imageInputField
        }
        .disabled(isLocked)
    }

    private var textInputField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Text Input")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $textInput)
                .font(.system(size: 12))
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .padding(8)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var imageInputField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Image")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isLoadingImage {
                loadingPlaceholder
            } else if let platformImage = selectedImage {
                imagePreview(platformImage)
            } else {
                imagePickerButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingPlaceholder: some View {
        HStack {
            Spacer()
            GradientSpinner()
            Spacer()
        }
        .frame(height: 100)
        .background(secondarySystemFill)
        .cornerRadius(8)
    }

    private func imagePreview(_ platformImage: PlatformImage) -> some View {
        ZStack(alignment: .topTrailing) {
            #if os(macOS)
            Image(nsImage: platformImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .clipped()
                .cornerRadius(8)
                .opacity(isLocked ? 0.5 : 1.0)
            #else
            Image(uiImage: platformImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .clipped()
                .cornerRadius(8)
                .opacity(isLocked ? 0.5 : 1.0)
            #endif

            if !isLocked {
                Button {
                    selectedImage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var imagePickerButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isImagePickerHighlighted ? Color.accentColor.opacity(0.2) : secondarySystemFill)

            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isImagePickerHighlighted ? Color.accentColor : Color.secondary,
                    style: isImagePickerHighlighted
                        ? StrokeStyle(lineWidth: 2)
                        : StrokeStyle(lineWidth: 1, dash: [4])
                )

            VStack(spacing: 4) {
                Image(systemName: isImageDropTargeted ? "arrow.down.circle.fill" : "photo")
                    .font(.system(size: 16))
                Text(isImageDropTargeted ? "Drop to use" : "Select image")
                    .font(.caption2)
            }
            .foregroundStyle(isImagePickerHighlighted ? Color.accentColor : .secondary)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            isImagePickerOpen = true
        }
        .hoverTracking(isHovered: $isImagePickerHovered)
        .animation(.easeInOut(duration: 0.15), value: isImagePickerHighlighted)
        .imageDropTarget(isTargeted: $isImageDropTargeted) { image in
            selectedImage = image
        }
    }

    private func formatLastRun(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "<1 min"
        }
        return date.formatted(.relative(presentation: .named))
    }

    private var footerView: some View {
        HStack {
            Spacer()
            if let run = lastRun {
                Text("Last run: \(formatLastRun(run.createdAt))")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Not run yet")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
