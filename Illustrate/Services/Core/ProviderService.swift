// MARK: - ProviderService.swift

// Central service for managing AI provider models and their configurations.
//
// ProviderService is the single source of truth for all AI model information.
// It loads model definitions from provider-specific factory classes and provides
// query methods for finding models by various criteria.
//
// ## Architecture
// Model definitions are created in IllustrateProviders package (Models/).
// These are loaded at initialization and stored in memory for fast lookups.
//
// ## Query Methods
// The service provides various ways to find models:
// - `allModels`: All registered models
// - `activeModels`: Only models with active=true
// - `models(for setType:)`: Filter by generation type
// - `models(for providerId:)`: Filter by provider UUID
// - `model(by modelId:)`: Lookup by UUID string
// - `model(by code:)`: Lookup by enum code
//
// ## Environment Integration
// Injected as both @EnvironmentObject and @Environment(\.providerService)
// for convenient access throughout the view hierarchy.

import Foundation
import IllustrateProviders
import OSLog
import SwiftUI

/// Singleton service managing all AI model configurations.
///
/// This service:
/// - Loads model definitions from provider factory classes
/// - Provides query methods for finding models
/// - Exposes model capabilities for UI adaptation
///
/// ## Usage
/// Access via `ProviderService.shared` or environment injection.
/// Query models using the various filter methods based on your needs.
class ProviderService: ObservableObject {
    static let shared = ProviderService()

    @Published private var _models: [ProviderModel] = []

    private var modelById: [String: ProviderModel] = [:]
    private var modelByCode: [EnumProviderModelCode: ProviderModel] = [:]
    private var modelsBySetType: [EnumSetType: [ProviderModel]] = [:]
    private var modelsByProviderId: [UUID: [ProviderModel]] = [:]
    private var cachedActiveModels: [ProviderModel] = []

    private init() {
        loadModels()
        let modelCount = _models.count
        AppLogger.app.info("ProviderService initialized with \(modelCount, privacy: .public) models")
    }

    var allModels: [ProviderModel] {
        _models
    }

    var activeModels: [ProviderModel] {
        cachedActiveModels
    }

    func models(for setType: EnumSetType) -> [ProviderModel] {
        modelsBySetType[setType] ?? []
    }

    func models(for providerId: UUID) -> [ProviderModel] {
        modelsByProviderId[providerId] ?? []
    }

    func model(by modelId: String) -> ProviderModel? {
        modelById[modelId]
    }

    func model(by code: EnumProviderModelCode) -> ProviderModel? {
        modelByCode[code]
    }

    private func loadModels() {
        _models = AllModels.createModels().map { $0.toProviderModel() }

        cachedActiveModels = _models.filter(\.active)

        var byId: [String: ProviderModel] = [:]
        byId.reserveCapacity(_models.count)
        var byCode: [EnumProviderModelCode: ProviderModel] = [:]
        byCode.reserveCapacity(_models.count)

        for model in _models {
            byId[model.modelId.uuidString] = model
            byCode[model.modelCode] = model
        }

        var bySetType: [EnumSetType: [ProviderModel]] = [:]
        var byProviderId: [UUID: [ProviderModel]] = [:]

        for model in cachedActiveModels {
            bySetType[model.modelSetType, default: []].append(model)
            byProviderId[model.providerId, default: []].append(model)
        }

        modelById = byId
        modelByCode = byCode
        modelsBySetType = bySetType
        modelsByProviderId = byProviderId
    }
}

// MARK: - Environment Key

/// SwiftUI environment key for ProviderService injection.
struct ProviderServiceKey: EnvironmentKey {
    static let defaultValue = ProviderService.shared
}

extension EnvironmentValues {
    /// Access to ProviderService via @Environment(\.providerService)
    var providerService: ProviderService {
        get { self[ProviderServiceKey.self] }
        set { self[ProviderServiceKey.self] = newValue }
    }
}
