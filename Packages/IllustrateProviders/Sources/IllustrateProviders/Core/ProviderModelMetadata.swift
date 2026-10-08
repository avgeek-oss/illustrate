// MARK: - ProviderModelMetadata.swift

import Foundation

/// Billing grain used by a provider's public price table.
public enum ProviderPricingUnit: String, Codable, CaseIterable, Sendable {
    case image
    case video
    case second
    case megapixel
    case token
    case credit
    case request
}

/// Source-backed pricing provenance for a model.
///
/// Runtime cost estimators remain adapter-specific; this metadata records where
/// the estimator came from and when it was last verified.
public struct ProviderPricingMetadata: Codable, Equatable, Sendable {
    public var currency: String
    public var unit: ProviderPricingUnit
    public var sourceURL: String
    public var verifiedAt: Date
    public var notes: String?

    public init(
        currency: String = "USD",
        unit: ProviderPricingUnit,
        sourceURL: String,
        verifiedAt: Date,
        notes: String? = nil
    ) {
        self.currency = currency
        self.unit = unit
        self.sourceURL = sourceURL
        self.verifiedAt = verifiedAt
        self.notes = notes
    }
}
