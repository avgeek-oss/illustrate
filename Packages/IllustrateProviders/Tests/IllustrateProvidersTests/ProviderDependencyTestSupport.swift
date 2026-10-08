import Foundation
@testable import IllustrateProviders

struct AllModelsTestProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        AllModels.createModels().first { $0.modelCode == code }
    }
}

func withProviderDependencies<Result>(
    networkProvider: some NetworkProvider,
    modelProvider: some ModelProvider = AllModelsTestProvider(),
    operation: () async throws -> Result
) async rethrows -> Result {
    try await ProviderDependencies.shared.withDependencies(
        networkProvider: networkProvider,
        modelProvider: modelProvider,
        operation: operation
    )
}

func withProviderDependencies<Result>(
    networkProvider: some NetworkProvider,
    modelProvider: some ModelProvider = AllModelsTestProvider(),
    operation: () throws -> Result
) rethrows -> Result {
    try ProviderDependencies.shared.withDependencies(
        networkProvider: networkProvider,
        modelProvider: modelProvider,
        operation: operation
    )
}
