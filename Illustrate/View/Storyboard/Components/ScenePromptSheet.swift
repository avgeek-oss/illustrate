// MARK: - ScenePromptSheet.swift

// Sheet for adding or editing storyboard scenes.
//
// ScenePromptSheet provides a form for configuring scene content:
//
// ## Auto-Extend Mode
// - Prompt text field
// - Reference images (optional)
// - Extends from previous scene's video
//
// ## Frame-Based Mode
// - Prompt text field
// - First frame image
// - Last frame image
// - Reference images (optional)

import SwiftUI

/// Sheet for creating or editing a storyboard scene.
struct ScenePromptSheet: View {
    let mode: StoryboardMode
    let dimensions: String // Storyboard dimensions for cropping (e.g., "1920x1080")
    var existingPrompt = ""
    var existingNegativePrompt: String?
    var existingFirstFrame: UUID?
    var existingLastFrame: UUID?

    /// Fixed first frame from previous scene (cannot be changed)
    var fixedFirstFrame: PlatformImage?

    /// Callback with prompt, negative prompt, first frame image, last frame image, reference images
    let onAdd: (String, String?, PlatformImage?, PlatformImage?, [PlatformImage]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var prompt = ""
    @State private var negativePrompt = ""
    @State private var firstFrameImage: PlatformImage?
    @State private var lastFrameImage: PlatformImage?
    @State private var referenceImages: [PlatformImage] = []

    // Image picker states
    @State private var isFirstFramePickerOpen = false
    @State private var isLastFramePickerOpen = false
    @State private var isReferencePickerOpen = false

    // Dropped image states (for crop flow)
    @State private var droppedFirstFrameImage: PlatformImage?
    @State private var droppedLastFrameImage: PlatformImage?

    // Drop target states
    @State private var isFirstFrameDropTargeted = false
    @State private var isLastFrameDropTargeted = false
    @State private var isReferenceDropTargeted = false

    private var isEditing: Bool {
        !existingPrompt.isEmpty
    }

    private var canSubmit: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Prompt Section
                Section {
                    TextField("Describe what happens in this scene...", text: $prompt, axis: .vertical)
                        .lineLimit(3 ... 6)
                        #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                        .textSelection(.enabled)
                        .focusEffectDisabled()
                        #endif
                } header: {
                    Text("Scene Prompt")
                } footer: {
                    if mode == .AUTO_EXTEND {
                        Text("This scene will extend from the previous video.")
                    }
                }

                // Negative Prompt Section
                Section {
                    TextField("Elements to avoid...", text: $negativePrompt, axis: .vertical)
                        .lineLimit(2 ... 4)
                        #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                        .textSelection(.enabled)
                        .focusEffectDisabled()
                        #endif
                } header: {
                    Text("Negative Prompt")
                } footer: {
                    Text("Optional negative prompt to avoid certain elements in the generated image.")
                }

                // Frame Selection (frame-based mode only)
                if mode == .FRAME_BASED {
                    // First Frame
                    if fixedFirstFrame == nil {
                        Section {
                            FrameImagePicker(
                                label: "First Frame",
                                image: $firstFrameImage,
                                isPickerOpen: $isFirstFramePickerOpen,
                                isDropTargeted: $isFirstFrameDropTargeted,
                                droppedImage: $droppedFirstFrameImage
                            )
                        } header: {
                            Text("First Frame")
                        } footer: {
                            Text("Starting frame for this scene.")
                        }
                    }

                    // Last Frame
                    Section {
                        FrameImagePicker(
                            label: "Last Frame",
                            image: $lastFrameImage,
                            isPickerOpen: $isLastFramePickerOpen,
                            isDropTargeted: $isLastFrameDropTargeted,
                            droppedImage: $droppedLastFrameImage,
                            isOptional: true
                        )
                    } header: {
                        HStack {
                            Text("Last Frame")
                        }
                    } footer: {
                        Text("Ending frame for this scene (optional).")
                    }
                }

                // Reference Images Section
                Section {
                    ReferenceImagesGrid(
                        images: $referenceImages,
                        isPickerOpen: $isReferencePickerOpen,
                        isDropTargeted: $isReferenceDropTargeted
                    )
                } header: {
                    Text("Reference Images")
                } footer: {
                    Text("Optional images for AI style guidance.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Scene" : "Add New Scene")
            #if os(macOS)
            .frame(width: 520, height: mode == .FRAME_BASED ? 780 : 480)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedNegative = negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines)

                        let finalFirstFrame = fixedFirstFrame ?? firstFrameImage

                        onAdd(
                            trimmedPrompt,
                            trimmedNegative.isEmpty ? nil : trimmedNegative,
                            finalFirstFrame,
                            lastFrameImage,
                            referenceImages
                        )
                        dismiss()
                    }
                    .disabled(!canSubmit)
                }
            }
            // Image selection modifiers with crop enabled
            .imageSelection(
                id: "firstFrame",
                isPickerOpen: $isFirstFramePickerOpen,
                enableCrop: true,
                cropDimensions: dimensions,
                droppedImage: $droppedFirstFrameImage,
                onImageSelected: { image in
                    firstFrameImage = image
                }
            )
            .imageSelection(
                id: "lastFrame",
                isPickerOpen: $isLastFramePickerOpen,
                enableCrop: true,
                cropDimensions: dimensions,
                droppedImage: $droppedLastFrameImage,
                onImageSelected: { image in
                    lastFrameImage = image
                }
            )
            .imageSelection(
                id: "referenceImage",
                isPickerOpen: $isReferencePickerOpen,
                onImageSelected: { image in
                    referenceImages.append(image)
                }
            )
        }
        .onAppear {
            prompt = existingPrompt
            negativePrompt = existingNegativePrompt ?? ""
        }
    }
}

// MARK: - Frame Image Picker

/// Full-width clickable/droppable image picker for frame selection.
private struct FrameImagePicker: View {
    let label: String
    @Binding var image: PlatformImage?
    @Binding var isPickerOpen: Bool
    @Binding var isDropTargeted: Bool
    @Binding var droppedImage: PlatformImage?
    var isOptional = false

    var body: some View {
        VStack(spacing: 12) {
            // Image preview / drop area
            imageArea
                .imageDropTarget(isTargeted: $isDropTargeted) { dropped in
                    // Pass to droppedImage binding so the crop flow is triggered
                    droppedImage = dropped
                }
        }
    }

    // MARK: - Image Area

    @ViewBuilder
    private var imageArea: some View {
        if let image {
            // Show selected image
            selectedImageView(image)
        } else {
            // Empty state - clickable drop zone
            emptyDropZone
        }
    }

    private func selectedImageView(_ img: PlatformImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(platformImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity)
                .shadow(color: .black.opacity(0.2), radius: 4)

            // Clear button
            Button {
                image = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isPickerOpen = true
        }
    }

    private var emptyDropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "photo.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)

            Text(isDropTargeted ? "Drop to use" : "Click or drop image")
                .font(.caption)
                .foregroundStyle(isDropTargeted ? .accent : .secondary)
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isDropTargeted ? Color.accentColor : Color.secondary,
                    style: isDropTargeted
                        ? StrokeStyle(lineWidth: 2)
                        : StrokeStyle(lineWidth: 1, dash: [5])
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isPickerOpen = true
        }
    }
}

// MARK: - Reference Images Grid

/// Grid view for selecting multiple reference images.
private struct ReferenceImagesGrid: View {
    @Binding var images: [PlatformImage]
    @Binding var isPickerOpen: Bool
    @Binding var isDropTargeted: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(spacing: 12) {
            if images.isEmpty {
                emptyState
            } else {
                imagesGrid
            }
        }
        .imageDropTarget(isTargeted: $isDropTargeted) { image in
            images.append(image)
        } onMultipleImagesDropped: { droppedImages in
            images.append(contentsOf: droppedImages)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "photo.on.rectangle.angled")
                .font(.title2)
                .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)

            Text(isDropTargeted ? "Drop to add" : "Click or drop images")
                .font(.caption)
                .foregroundStyle(isDropTargeted ? .accent : .secondary)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isDropTargeted ? Color.accentColor : Color.secondary,
                    style: isDropTargeted
                        ? StrokeStyle(lineWidth: 2)
                        : StrokeStyle(lineWidth: 1, dash: [5])
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isPickerOpen = true
        }
    }

    private var imagesGrid: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(images.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(platformImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Button {
                            images.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                    }
                }

                // Add button
                Button {
                    isPickerOpen = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(Color.secondary.opacity(0.4))

                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 80, height: 80)
                }
                .buttonStyle(.plain)
            }

            Text("\(images.count) image\(images.count == 1 ? "" : "s") selected")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
