// MARK: - FirecrawlModels.swift

// Factory for Firecrawl model configurations.

import Foundation

/// Factory enum for creating Firecrawl model configurations.
public enum FirecrawlModels {
    /// Creates all Firecrawl model configurations.
    /// Currently returns empty array as Firecrawl is used for web scraping,
    /// not image/video generation.
    public static func createModels() -> [ProviderModelData] {
        []
    }
}
