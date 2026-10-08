// MARK: - ExtendGenerationVideoPicker.swift

// Picker for selecting videos eligible for extension.
//
// Video extension requires specific metadata from the original
// generation (e.g., soraVideoId for Sora, veoGeneratedUri for Veo).
// This picker filters generations to only show those with the
// required metadata.
//
// ## Metadata Requirements
// - Sora: Requires "soraVideoId"
// - Veo: Requires "veoGeneratedUri"
// - Luma: Requires "lumaGenerationId"
//
// ## Features
// - Filters by required metadata keys
// - Video thumbnail previews
// - Model-specific labeling

import AvgeekDesignSystem
import IllustrateProviders
import SwiftData
import SwiftUI

/// Picker for selecting videos with required metadata for extension.
struct ExtendGenerationVideoPicker: View {
    let requiredMetadataKeys: [String]
    let onVideoSelected: (Generation) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager
    @ObservedObject private var cache = GalleryCache.shared

    private var eligibleGenerations: [Generation] {
        cache.videoGenerations.filter { generation in
            for key in requiredMetadataKeys {
                if generation.metadata[key] == nil || generation.metadata[key]?.isEmpty == true {
                    return false
                }
            }
            return true
        }
    }

    private func videoTypeDisplayName(for keys: [String]) -> String {
        switch true {
        case keys.contains("soraVideoId"):
            "Sora"
        case keys.contains("veoGeneratedUri"):
            "Veo"
        case keys.contains("lumaGenerationId"):
            "Luma"
        case keys.contains(GeminiInteractionMetadataKey.interactionId):
            "Gemini Omni"
        default:
            "Video"
        }
    }

    private var modelName: String {
        videoTypeDisplayName(for: requiredMetadataKeys)
    }

    private var navigationTitle: String {
        "Select \(modelName) Video"
    }

    private var emptyStateMessage: String {
        "No \(modelName) videos available"
    }

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if eligibleGenerations.isEmpty {
                    AvgeekEmptyStateView(
                        icon: "play.slash",
                        title: emptyStateMessage,
                        message: "Generate videos first to extend them here."
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(eligibleGenerations, id: \.id) { generation in
                                ExtendVideoThumbnailCard(generation: generation) {
                                    onVideoSelected(generation)
                                    dismiss()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                cache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 400, maxHeight: 640)
        #endif
    }
}

struct ExtendVideoThumbnailCard: View {
    let generation: Generation
    let onTap: () -> Void

    @State private var thumbnail: PlatformImage?
    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    if let thumbnail {
                        #if os(macOS)
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 100)
                            .clipped()
                        #else
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 100)
                            .clipped()
                        #endif
                    } else {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 100)
                            .overlay {
                                GradientSpinner()
                            }
                    }

                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(generation.prompt)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    Text(generation.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovering ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(color: isHovering ? Color.accentColor.opacity(0.3) : Color.clear, radius: 8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .task {
            thumbnail = loadImageFromiCloud(generation.id.uuidString)
        }
    }
}

/// A form section for selecting a generated video with provider-specific metadata.
struct VeoVideoSourceSection: View {
    let headerText: String
    var sourceDisplayName = "Veo"
    var actionDisplayName = "extend"
    var helpText: String?
    let selectedGeneration: Generation?
    let hasVideo: Bool
    let onSelectVideo: () -> Void
    let onRemoveVideo: () -> Void

    @State private var thumbnail: PlatformImage?

    var body: some View {
        Section(header: Text(headerText)) {
            if hasVideo, let generation = selectedGeneration {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        if let thumbnail {
                            #if os(macOS)
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 100)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            #else
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 100)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            #endif
                        } else {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 120, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    GradientSpinner()
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(generation.prompt)
                                .font(.callout)
                                .lineLimit(2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(generation.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)

                                if let model = ProviderService.shared.model(by: generation.modelId) {
                                    Text(model.modelName)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()
                    }

                    HStack {
                        Button("Change Video") {
                            onSelectVideo()
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            onRemoveVideo()
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .task {
                    thumbnail = loadImageFromiCloud(generation.id.uuidString)
                }
            } else {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("Select a \(sourceDisplayName)-generated video to \(actionDisplayName)")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Select Video") {
                        onSelectVideo()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Text(
                helpText ??
                    "Select a previously generated \(sourceDisplayName) video to extend. The model will continue the video from where it ended."
            )
            .multilineTextAlignment(.leading)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}

/// A form section for selecting a Sora-generated video
struct SoraVideoSourceSection: View {
    let headerText: String
    let selectedGeneration: Generation?
    let hasVideo: Bool
    let onSelectVideo: () -> Void
    let onRemoveVideo: () -> Void

    @State private var thumbnail: PlatformImage?

    var body: some View {
        Section(header: Text(headerText)) {
            if hasVideo, let generation = selectedGeneration {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        if let thumbnail {
                            #if os(macOS)
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 100)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            #else
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 100)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            #endif
                        } else {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 120, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    GradientSpinner()
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(generation.prompt)
                                .font(.callout)
                                .lineLimit(2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(generation.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)

                                if let model = ProviderService.shared.model(by: generation.modelId) {
                                    Text(model.modelName)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()
                    }

                    HStack {
                        Button("Change Video") {
                            onSelectVideo()
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            onRemoveVideo()
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .task {
                    thumbnail = loadImageFromiCloud(generation.id.uuidString)
                }
            } else {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("Select a Sora-generated video to remix")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Select Video") {
                        onSelectVideo()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Text(
                "Select a previously generated Sora video to remix. The model will use the video as a reference for creating new variations."
            )
            .multilineTextAlignment(.leading)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}

/// A form section for selecting a Gemini Omni generated video.
struct GeminiVideoEditSourceSection: View {
    let selectedGeneration: Generation?
    let hasVideo: Bool
    let onSelectVideo: () -> Void
    let onRemoveVideo: () -> Void

    @State private var thumbnail: PlatformImage?

    var body: some View {
        Section(header: Text("Source Video (Gemini Omni Generated)")) {
            if hasVideo, let generation = selectedGeneration {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        if let thumbnail {
                            #if os(macOS)
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 100)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            #else
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 100)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            #endif
                        } else {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 120, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    GradientSpinner()
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(generation.prompt)
                                .font(.callout)
                                .lineLimit(2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(generation.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)

                                if let model = ProviderService.shared.model(by: generation.modelId) {
                                    Text(model.modelName)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()
                    }

                    HStack {
                        Button("Change Video") {
                            onSelectVideo()
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            onRemoveVideo()
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .task {
                    thumbnail = loadImageFromiCloud(generation.id.uuidString)
                }
            } else {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("Select a Gemini Omni video to edit")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Select Video") {
                        onSelectVideo()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Text(
                "Select a previously generated Gemini Omni video. The model will apply your edit while preserving the rest of the video."
            )
            .multilineTextAlignment(.leading)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}
