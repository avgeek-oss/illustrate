// MARK: - GoogleCloudModelLifecycleTests.swift

import Testing
@testable import IllustrateProviders

@Suite("Google Cloud model lifecycle")
struct GoogleCloudModelLifecycleTests {
    @Test("Native Imagen 4 records remain available for history but inactive for new generations")
    func nativeImagen4ModelsAreHistoricalOnly() throws {
        let models = GoogleCloudModels.createModels()
        let retiredCodes: [EnumProviderModelCode] = [
            .GOOGLE_IMAGEN_4_FAST,
            .GOOGLE_IMAGEN_4_STANDARD,
            .GOOGLE_IMAGEN_4_ULTRA,
        ]

        for code in retiredCodes {
            let model = try #require(models.first { $0.modelCode == code })

            #expect(!model.active)
            #expect(model.modelDeprecationDate == getDateFromString("2026-06-15"))
            #expect(model.modelVerificationDate == getDateFromString("2026-07-10"))
            #expect(model.modelShutdownDate == getDateFromString("2026-08-17"))
            #expect(model.replacementModelCode == .GOOGLE_GEMINI_31_FLASH_IMAGE)
            #expect(model.modelAPIDocumentationURL == "https://ai.google.dev/gemini-api/docs/models/imagen")
            #expect(model.generateURL != nil)
        }
    }
}
