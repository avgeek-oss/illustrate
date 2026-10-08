// MARK: - AgentRunService.swift

// Service for executing agent workflows card-by-card.
//
// AgentRunService is the runtime engine for agent workflows. Given an ordered
// sequence of cards (from AgentGraphService.topologicalSort), it executes
// each card in sequence, passing outputs to the next card.
//
// ## Execution Flow
// 1. Create AgentRun to track execution
// 2. Reset all card states (clear previous results/errors)
// 3. For each card in order:
//    a. Set card.isRunning = true
//    b. Execute based on card type:
//       - Start: Extract input generation
//       - Process: Run image/video generation
//       - Output: Capture final result
//    c. On error: Mark card errored, stop execution
//    d. On success: Store result, continue
// 4. Mark run as successful or errored
//
// ## Template Variables
// Process card prompts support `{{input}}` placeholder which is replaced
// with the previous card's prompt. This enables chaining prompts.
//
// ## Previous Image Usage
// Cards can use outputs from previous cards:
// - `usePreviousImageAsReference`: Use as reference image
// - `usePreviousImageAsSourceImage`: Use as source for editing/video

import Foundation
import IllustrateProviders
import KeychainSwift
import OSLog
import SwiftData

/// Result from executing a single process card.
struct ProcessCardResult {
    /// Generation ID if successful
    var generationId: UUID?
    /// Error message if failed
    var error: String?
}

/// Singleton service for executing agent workflows.
///
/// This service runs agent workflows sequentially, processing each card
/// and passing results to downstream cards. It handles both image and
/// video generation cards.
@MainActor
class AgentRunService {
    /// Shared singleton instance
    static let shared = AgentRunService()

    private init() {}

    func executeRun(
        agent: Agent,
        orderedCards: [AgentCard],
        links: [CardLink],
        providerKeys: [ProviderKey],
        queueManager: QueueManager,
        modelContext: ModelContext
    ) async -> AgentRun {
        AppLogger.agent
            .info(
                "Starting agent run for agent: \(agent.id.uuidString, privacy: .public) with \(orderedCards.count, privacy: .public) cards"
            )

        let run = AgentRun(agentId: agent.id, projectId: agent.projectId)
        modelContext.insert(run)
        try? modelContext.save()

        for card in orderedCards where card.cardType != .start {
            card.generationId = nil
            card.isRunning = false
            card.isErrored = false
            card.errorMessage = nil
        }

        if let startCard = orderedCards.first(where: { $0.cardType == .start }) {
            startCard.isRunning = false
            startCard.isErrored = false
            startCard.errorMessage = nil
        }
        try? modelContext.save()

        var previousGenerationId: UUID? = nil

        for (index, card) in orderedCards.enumerated() {
            if index > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            card.isRunning = true
            try? modelContext.save()

            switch card.cardType {
            case .start:
                previousGenerationId = card.generationId

            case .process:
                let previousGeneration = await fetchGeneration(id: previousGenerationId, modelContext: modelContext)

                let result = await executeProcessCard(
                    card: card,
                    previousGenerationId: previousGenerationId,
                    previousGeneration: previousGeneration,
                    runId: run.id,
                    agentId: agent.id,
                    projectId: agent.projectId,
                    providerKeys: providerKeys,
                    queueManager: queueManager,
                    modelContext: modelContext
                )

                if let error = result.error {
                    card.isRunning = false
                    card.isErrored = true
                    card.errorMessage = error
                    run.status = .ERRORED
                    run.errorMessage = error
                    run.errorCardId = card.id
                    try? modelContext.save()
                    return run
                }

                card.generationId = result.generationId
                previousGenerationId = result.generationId

            case .output:
                card.generationId = previousGenerationId
            }

            card.isRunning = false
            try? modelContext.save()
        }

        run.status = .SUCCESSFUL
        run.completedAt = Date()
        try? modelContext.save()

        AppLogger.agent.notice("Agent run completed successfully - runId: \(run.id.uuidString, privacy: .public)")
        return run
    }

    private func fetchGeneration(id: UUID?, modelContext: ModelContext) async -> Generation? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<Generation>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func executeProcessCard(
        card: AgentCard,
        previousGenerationId: UUID?,
        previousGeneration: Generation?,
        runId: UUID,
        agentId: UUID,
        projectId: UUID,
        providerKeys: [ProviderKey],
        queueManager: QueueManager,
        modelContext: ModelContext
    ) async -> ProcessCardResult {
        guard let processType = card.processCardType else {
            return ProcessCardResult(error: "Invalid process card type")
        }

        switch processType {
        case .imageGeneration:
            return await executeImageGeneration(
                card: card,
                previousGenerationId: previousGenerationId,
                previousGeneration: previousGeneration,
                runId: runId,
                agentId: agentId,
                projectId: projectId,
                providerKeys: providerKeys,
                queueManager: queueManager,
                modelContext: modelContext
            )
        case .videoGeneration:
            return await executeVideoGeneration(
                card: card,
                previousGenerationId: previousGenerationId,
                previousGeneration: previousGeneration,
                runId: runId,
                agentId: agentId,
                projectId: projectId,
                providerKeys: providerKeys,
                queueManager: queueManager,
                modelContext: modelContext
            )
        }
    }

    /// Expands template variables in a prompt string.
    ///
    /// Replaces `{{input}}` placeholders with the previous card's prompt.
    /// If the result is empty after expansion, falls back to the previous prompt entirely.
    ///
    /// - Parameters:
    ///   - template: The prompt template potentially containing `{{input}}`
    ///   - previousPrompt: The prompt from the previous card in the chain
    /// - Returns: The expanded prompt string
    nonisolated static func expandPrompt(template: String, previousPrompt: String) -> String {
        var result = template.replacingOccurrences(of: "{{input}}", with: previousPrompt)
        if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result = previousPrompt
        }
        return result
    }

    nonisolated static func xAIImageInputValidationError(
        modelId: String,
        hasSourceImage: Bool,
        referenceImageCount: Int
    ) -> String? {
        let selectedModelId = UUID(uuidString: modelId)
        guard selectedModelId == EnumProviderModelCode.XAI_GROK_IMAGINE_IMAGE.modelId
            || selectedModelId == EnumProviderModelCode.XAI_GROK_IMAGINE_IMAGE_QUALITY.modelId
        else {
            return nil
        }

        let totalInputs = (hasSourceImage ? 1 : 0) + referenceImageCount
        guard totalInputs > 3 else { return nil }
        return "xAI image generation accepts at most three source and reference images combined."
    }

    nonisolated static func xAIVideoInputValidationError(
        modelId: String,
        hasSourceImage: Bool
    ) -> String? {
        guard UUID(uuidString: modelId) == EnumProviderModelCode.XAI_GROK_IMAGINE_VIDEO_1_5.modelId,
              !hasSourceImage
        else {
            return nil
        }
        return "Grok Imagine Video 1.5 requires a source image from the previous card."
    }

    private func executeImageGeneration(
        card: AgentCard,
        previousGenerationId: UUID?,
        previousGeneration: Generation?,
        runId: UUID,
        agentId: UUID,
        projectId: UUID,
        providerKeys: [ProviderKey],
        queueManager: QueueManager,
        modelContext: ModelContext
    ) async -> ProcessCardResult {
        let config = card.imageGenerationConfiguration

        guard !config.selectedProviderId.isEmpty else {
            return ProcessCardResult(error: "No provider selected")
        }
        guard !config.selectedModelId.isEmpty else {
            return ProcessCardResult(error: "No model selected")
        }

        guard let providerId = UUID(uuidString: config.selectedProviderId),
              let providerKey = providerKeys.first(where: { $0.providerId == providerId })
        else {
            return ProcessCardResult(error: "Provider key not found")
        }

        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else {
            return ProcessCardResult(error: "Provider not found")
        }

        let keychain = KeychainSwift()
        keychain.accessGroup = TEAM_KEYCHAIN_AG
        keychain.synchronizable = true

        let keychainKey = ProjectManager.keychainKey(projectId: projectId, providerId: providerId)
        guard let providerSecret = keychain.get(keychainKey) else {
            return ProcessCardResult(error: "API key not found in keychain")
        }

        let previousPrompt = previousGeneration?.prompt ?? ""
        let effectivePrompt = Self.expandPrompt(template: config.prompt, previousPrompt: previousPrompt)

        var referenceImageData: [ReferenceImageData] = []

        if config.usePreviousImageAsReference, let prevGenId = previousGenerationId {
            if let imageBase64 = loadImageBase64FromDocuments(withName: prevGenId.uuidString) {
                referenceImageData.append(ReferenceImageData(
                    base64Image: imageBase64,
                    referenceType: ""
                ))
            }
        }

        for refConfig in config.referenceImages {
            let imageName = "imggen_ref_\(card.id.uuidString)_\(refConfig.id.uuidString)"
            if let imageBase64 = loadImageBase64FromDocuments(withName: imageName) {
                referenceImageData.append(ReferenceImageData(
                    base64Image: imageBase64,
                    referenceType: refConfig.referenceType
                ))
            }
        }

        var clientImage: String? = nil
        if config.usePreviousImageAsSourceImage, let prevGenId = previousGenerationId {
            clientImage = loadImageBase64FromDocuments(withName: prevGenId.uuidString)
        }

        if let validationError = Self.xAIImageInputValidationError(
            modelId: config.selectedModelId,
            hasSourceImage: clientImage != nil,
            referenceImageCount: referenceImageData.count
        ) {
            return ProcessCardResult(error: validationError)
        }

        let request = ImageGenerationRequest(
            modelId: config.selectedModelId,
            prompt: effectivePrompt,
            searchPrompt: config.searchPrompt.isEmpty ? nil : config.searchPrompt,
            negativePrompt: config.negativePrompt.isEmpty ? nil : config.negativePrompt,
            variant: config.selectedVariant,
            quality: config.selectedQuality,
            style: config.selectedStyle,
            dimensions: config.selectedDimensions,
            clientImage: clientImage,
            clientReferenceImages: referenceImageData.isEmpty ? nil : referenceImageData,
            providerKey: providerKeyInfo,
            providerSecret: providerSecret,
            numberOfImages: 1,
            resolution: config.selectedResolution.isEmpty ? nil : config.selectedResolution,
            steps: config.stepsValue > 0 ? Int(config.stepsValue) : nil,
            guidance: config.guidanceValue > 0 ? config.guidanceValue : nil,
            seed: config.seedValue.isEmpty ? nil : Int(config.seedValue),
            safetyTolerance: Int(config.safetyValue),
            promptEnhance: config.modelPromptEnhance,
            inputFidelity: config.selectedInputFidelity.isEmpty ? nil : config.selectedInputFidelity,
            moderation: config.selectedModeration.isEmpty ? nil : config.selectedModeration,
            growMask: config.growMaskValue > 0 ? Int(config.growMaskValue) : nil,
            selectedTools: config.selectedTools.isEmpty ? nil : config.selectedTools,
            personGeneration: config.personGeneration.isEmpty ? nil : config.personGeneration
        )

        let response = await queueManager.submitImageGenerationAndAwait(
            request: request,
            modelContext: modelContext,
            runId: runId,
            agentId: agentId
        )

        if response.status == .GENERATED, let generations = response.generations, let firstGen = generations.first {
            return ProcessCardResult(generationId: firstGen.id)
        } else {
            return ProcessCardResult(error: response.errorMessage ?? "Image generation failed")
        }
    }

    private func executeVideoGeneration(
        card: AgentCard,
        previousGenerationId: UUID?,
        previousGeneration: Generation?,
        runId: UUID,
        agentId: UUID,
        projectId: UUID,
        providerKeys: [ProviderKey],
        queueManager: QueueManager,
        modelContext: ModelContext
    ) async -> ProcessCardResult {
        let config = card.videoGenerationConfiguration

        guard !config.selectedProviderId.isEmpty else {
            return ProcessCardResult(error: "No provider selected")
        }
        guard !config.selectedModelId.isEmpty else {
            return ProcessCardResult(error: "No model selected")
        }

        guard let providerId = UUID(uuidString: config.selectedProviderId),
              let providerKey = providerKeys.first(where: { $0.providerId == providerId })
        else {
            return ProcessCardResult(error: "Provider key not found")
        }

        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else {
            return ProcessCardResult(error: "Provider not found")
        }

        let keychain = KeychainSwift()
        keychain.accessGroup = TEAM_KEYCHAIN_AG
        keychain.synchronizable = true

        let keychainKey = ProjectManager.keychainKey(projectId: projectId, providerId: providerId)
        guard let providerSecret = keychain.get(keychainKey) else {
            return ProcessCardResult(error: "API key not found in keychain")
        }

        let previousPrompt = previousGeneration?.prompt ?? ""
        let effectivePrompt = Self.expandPrompt(template: config.prompt, previousPrompt: previousPrompt)

        var clientImage: String? = nil
        if config.usePreviousImageAsSourceImage, let prevGenId = previousGenerationId {
            clientImage = loadImageBase64FromDocuments(withName: prevGenId.uuidString)
        }

        if let validationError = Self.xAIVideoInputValidationError(
            modelId: config.selectedModelId,
            hasSourceImage: clientImage != nil
        ) {
            return ProcessCardResult(error: validationError)
        }

        let request = VideoGenerationRequest(
            modelId: config.selectedModelId,
            prompt: effectivePrompt.isEmpty ? nil : effectivePrompt,
            negativePrompt: config.negativePrompt.isEmpty ? nil : config.negativePrompt,
            dimensions: config.selectedDimensions,
            clientImage: clientImage,
            providerKey: providerKeyInfo,
            providerSecret: providerSecret,
            numberOfVideos: 1,
            durationSeconds: config.durationSeconds > 0 ? config.durationSeconds : nil,
            resolution: config.selectedResolution.isEmpty ? nil : config.selectedResolution,
            fps: config.selectedFPS > 0 ? config.selectedFPS : nil,
            generateAudio: config.generateAudio ? true : nil,
            guidance: config.guidanceValue > 0 ? config.guidanceValue : nil,
            seed: config.seedValue.isEmpty ? nil : Int(config.seedValue),
            safetyTolerance: Int(config.safetyValue),
            promptEnhance: config.modelPromptEnhance
        )

        let response = await queueManager.submitVideoGenerationAndAwait(
            request: request,
            modelContext: modelContext,
            runId: runId,
            agentId: agentId
        )

        if response.status == .GENERATED, let generations = response.generations, let firstGen = generations.first {
            return ProcessCardResult(generationId: firstGen.id)
        } else {
            return ProcessCardResult(error: response.errorMessage ?? "Video generation failed")
        }
    }

    private func loadImageBase64FromDocuments(withName name: String) -> String? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let imageFileURL = documentsURL.appendingPathComponent("\(name).png")
        guard let data = try? Data(contentsOf: imageFileURL) else {
            return nil
        }
        return data.base64EncodedString()
    }
}
