// MARK: - FalPricingHelpers.swift

// Shared pricing utilities for Fal.ai models.
// Provides dynamic cost calculation based on megapixels, dimensions, etc.

import Foundation

// MARK: - Megapixel Parsing

/// Parse megapixels from various dimension formats
/// Supports: "1024x1024", "square_hd", "1 MP", "1.5", etc.
public func falParseMegapixels(from input: String?) -> Double {
    guard let input = input?.trimmingCharacters(in: .whitespaces), !input.isEmpty else {
        return 1.0
    }

    // Simple numeric like "1" or "0.5" or "1.5"
    if let mp = Double(input) {
        return mp
    }

    // Resolution string like "1 MP" or "2 MP"
    if input.contains("MP") {
        let cleaned = input
            .replacingOccurrences(of: " MP", with: "")
            .replacingOccurrences(of: "MP", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 1.0
    }

    // Pixel dimensions like "1024x1024"
    let parts = input.lowercased().split(separator: "x")
    if parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]) {
        return (width * height) / 1_000_000.0
    }

    // FAL dimension presets - approximate megapixels
    switch input.lowercased() {
    case "square_hd":
        return 1.05 // ~1024x1024
    case "square":
        return 0.26 // ~512x512
    case "portrait_4_3":
        return 1.05 // ~896x1152
    case "portrait_16_9":
        return 1.05 // ~768x1344
    case "portrait_9_16":
        return 1.05 // ~768x1344
    case "landscape_4_3":
        return 1.05 // ~1152x896
    case "landscape_16_9":
        return 1.05 // ~1344x768
    case "1:1":
        return 1.05
    case "4:3", "3:4":
        return 1.05
    case "16:9", "9:16":
        return 1.05
    case "3:2", "2:3":
        return 1.05
    case "21:9":
        return 1.2
    default:
        return 1.0
    }
}

// MARK: - Pricing Unit Types

/// Types of pricing units used by Fal.ai models.
public enum FalPricingUnit: Sendable {
    case perImage(Double) // Flat rate per image
    case perMegapixel(Double) // Cost per megapixel
    case perComputeSecond(Double, avgSeconds: Double) // Cost per compute second with estimated time
}

// MARK: - Cost Calculation

/// Calculate cost based on pricing unit and request parameters
public func falCalculateCost(
    pricing: FalPricingUnit,
    dimensions: String?,
    numberOfImages: Int
) -> Double {
    let imageCount = Double(max(1, numberOfImages))

    switch pricing {
    case let .perImage(rate):
        return rate * imageCount

    case let .perMegapixel(rate):
        let megapixels = falParseMegapixels(from: dimensions)
        return rate * megapixels * imageCount

    case let .perComputeSecond(rate, avgSeconds):
        return rate * avgSeconds * imageCount
    }
}
