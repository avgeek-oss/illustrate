import Foundation
import Testing
@testable import IllustrateProviders

struct CloudflareSchnellContractTests {
    @Test func catalogueUsesTheDocumentedPromptLimit() throws {
        let model = try #require(AllModels.createModels().first { $0.modelCode == .CLOUDFLARE_FLUX_1_SCHNELL })
        #expect(model.modelParams.maxPromptLength == 2048)
    }

    @Test func requestOmitsUnsupportedOptions() throws {
        let request = ImageGenerationRequest(
            modelId: "cloudflare-schnell-fixture",
            prompt: "A sketch of a lighthouse",
            negativePrompt: "blur",
            dimensions: "1024x768",
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.CLOUDFLARE_AI.providerId,
                providerCode: .CLOUDFLARE_AI,
                projectId: UUID()
            ),
            providerSecret: "fixture",
            steps: 4,
            guidance: 7.5,
            seed: 42
        )
        let payload = G_CLOUDFLARE_FLUX_1_SCHNELL().transformRequest(request: request)
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        #expect(Set(json.keys) == ["prompt", "steps", "seed"])
        #expect(json["steps"] as? Int == 4)
        #expect(json["seed"] as? Int == 42)
    }
}
