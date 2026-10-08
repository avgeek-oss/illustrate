import Foundation
import Testing
@testable import IllustrateProviders

struct CatalogueIntegrityTests {
    @Test func allProvidersHaveModelsAndStableUniqueIdentifiers() {
        let providers = EnumProviderCode.allCases
        let models = AllModels.createModels()
        #expect(providers.count == 27)
        #expect(Set(providers.map(\.providerId)).count == providers.count)
        #expect(Set(models.map(\.modelCode)).count == models.count)
        #expect(Set(models.map(\.modelId)).count == models.count)
        let generationProviders = providers.filter { $0 != .FIRECRAWL }
        #expect(Set(models.map(\.providerId)) == Set(generationProviders.map(\.providerId)))
        #expect(FirecrawlModels.createModels().isEmpty)
    }

    @Test(arguments: EnumProviderCode.allCases.filter { $0 != .FIRECRAWL })
    func everyProviderHasDocumentedHTTPSModels(provider: EnumProviderCode) {
        let models = AllModels.createModels().filter { $0.providerId == provider.providerId }
        #expect(!models.isEmpty)
        for model in models {
            #expect(!model.modelName.isEmpty)
            #expect(model.modelGenerateBaseURL.hasPrefix("https://"))
            #expect(model.modelAPIDocumentationURL.hasPrefix("https://"))
        }
    }
}
