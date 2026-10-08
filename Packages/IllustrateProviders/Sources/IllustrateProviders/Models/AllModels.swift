// MARK: - AllModels.swift

// Aggregates all provider model definitions.

import Foundation

/// Factory enum that aggregates all provider model configurations.
public enum AllModels {
    /// Creates all model configurations from all providers.
    public static func createModels() -> [ProviderModelData] {
        [
            OpenAIModels.createModels(),
            StabilityModels.createModels(),
            GoogleCloudModels.createModels(),
            ReplicateModels.createModels(),
            FALModels.createModels(),
            FirecrawlModels.createModels(),
            TogetherAIModels.createModels(),
            LumaAIModels.createModels(),
            CloudflareAIModels.createModels(),
            RecraftModels.createModels(),
            IdeogramModels.createModels(),
            BlackForestLabsModels.createModels(),
            BriaModels.createModels(),
            RunwayModels.createModels(),
            LTXModels.createModels(),
            GoogleVertexAIModels.createModels(),
            AzureAIFoundryModels.createModels(),
            AmazonBedrockModels.createModels(),
            AlibabaModelStudioModels.createModels(),
            MiniMaxModels.createModels(),
            KlingAIModels.createModels(),
            XAIModels.createModels(),
            BytePlusModelArkModels.createModels(),
            ViduModels.createModels(),
            PixVerseModels.createModels(),
            DeepInfraModels.createModels(),
            NovitaAIModels.createModels(),
        ].flatMap { $0 }
    }
}
