// MARK: - ProviderConfigurationTests.swift

// Tests for the static providers array and Provider model configuration.
//
// Tests cover:
// - Static providers array: count, unique IDs, unique codes, metadata validation
// - Key validation regex: valid/invalid patterns for all 6 providers
// - Provider Codable round-trip: encode/decode preserves all 12 fields
// - Balance checking: only Stability AI supports balance check
// - getProvider(providerId:) lookup: finds correct provider for each known UUID

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

#if os(macOS)
import AppKit
#else
import UIKit
#endif

final class ProviderConfigurationTests: XCTestCase {
    // MARK: - Static Providers Array

    func testProviders_CountIsTwentySeven() {
        XCTAssertEqual(providers.count, 27)
    }

    func testProviders_AllHaveUniqueProviderId() {
        let ids = providers.map(\.providerId)
        XCTAssertEqual(Set(ids).count, ids.count, "All provider IDs should be unique")
    }

    func testProviders_AllHaveUniqueProviderCode() {
        let codes = providers.map(\.providerCode)
        XCTAssertEqual(Set(codes).count, codes.count, "All provider codes should be unique")
    }

    func testProviders_AllHaveNonEmptyName() {
        for provider in providers {
            XCTAssertFalse(provider.providerName.isEmpty, "\(provider.providerCode) should have a non-empty name")
        }
    }

    func testProviders_AllHaveNonEmptyDescription() {
        for provider in providers {
            XCTAssertFalse(
                provider.providerDescription.isEmpty,
                "\(provider.providerCode) should have a non-empty description"
            )
        }
    }

    func testProviders_AllHaveHttpsOnboardingUrl() {
        for provider in providers {
            XCTAssertTrue(
                provider.providerOnboardingUrl.hasPrefix("https://"),
                "\(provider.providerCode) onboarding URL should start with https://"
            )
        }
    }

    func testProviders_AllAreActive() {
        XCTAssertTrue(providers.allSatisfy(\.active))
    }

    func testProviders_ExpectedNames() {
        let names = Set(providers.map(\.providerName))
        let expected: Set = [
            "OpenAI",
            "Stability AI",
            "Google Cloud",
            "Replicate",
            "Fal AI",
            "Firecrawl",
            "Together AI",
            "Luma AI",
            "Cloudflare AI",
            "Recraft",
            "Ideogram",
            "Black Forest Labs",
            "Bria AI",
            "Runway",
            "LTX",
            "Google Vertex AI",
            "Azure AI Foundry",
            "Amazon Bedrock",
            "Alibaba Model Studio",
            "MiniMax",
            "Kling AI",
            "xAI",
            "BytePlus ModelArk",
            "Vidu",
            "PixVerse",
            "DeepInfra",
            "Novita AI",
        ]
        XCTAssertEqual(names, expected)
    }

    func testAlibabaConfiguration_RequiresExactNamedFields() {
        let provider = providers.first { $0.providerCode == .ALIBABA_MODEL_STUDIO }

        XCTAssertEqual(provider?.keyType, .CONFIGURATION)
        XCTAssertEqual(provider?.credentialFields.map(\.id), ["api_key", "workspace_id", "region"])
        XCTAssertEqual(provider?.credentialFields.filter(\.isSensitive).map(\.id), ["api_key"])
    }

    func testMiniMaxConfiguration_RequiresExactNamedFields() {
        let provider = providers.first { $0.providerCode == .MINIMAX }

        XCTAssertEqual(provider?.keyType, .CONFIGURATION)
        XCTAssertEqual(provider?.credentialFields.map(\.id), ["api_key", "region"])
        XCTAssertEqual(provider?.credentialFields.filter(\.isSensitive).map(\.id), ["api_key"])
    }

    func testKlingConfiguration_UsesOneRawAPIKey() throws {
        let provider = providers.first { $0.providerCode == .KLING_AI }

        XCTAssertEqual(provider?.keyType, .API)
        XCTAssertTrue(provider?.credentialFields.isEmpty == true)
        let regex = try NSRegularExpression(pattern: XCTUnwrap(provider?.keyStructure))
        let validKey = "kling-direct-key"
        let invalidKey = "{\"access_key\":\"...\"}"
        XCTAssertNotNil(regex.firstMatch(
            in: validKey,
            range: NSRange(validKey.startIndex ..< validKey.endIndex, in: validKey)
        ))
        XCTAssertNil(regex.firstMatch(
            in: invalidKey,
            range: NSRange(invalidKey.startIndex ..< invalidKey.endIndex, in: invalidKey)
        ))
    }

    func testXAI_UsesSimpleAPIKeyConfiguration() throws {
        let provider = try XCTUnwrap(providers.first { $0.providerCode == .XAI })
        XCTAssertEqual(provider.keyType, .API)
        XCTAssertEqual(provider.creditCurrency, .USD)
        XCTAssertTrue(provider.credentialFields.isEmpty)

        let regex = try NSRegularExpression(pattern: provider.keyStructure)
        let key = "xai-key-with-no-documented-prefix"
        let range = NSRange(key.startIndex ..< key.endIndex, in: key)
        XCTAssertNotNil(regex.firstMatch(in: key, range: range))
    }

    func testProviderArtworkName_UsesBundledVariantFallbacks() {
        let missingCode = "PROVIDER_WITH_NO_BUNDLED_ARTWORK"

        XCTAssertEqual(providerArtworkName(code: missingCode, variant: .base), "provider_generic")
        XCTAssertEqual(providerArtworkName(code: missingCode, variant: .square), "provider_generic_square")
        XCTAssertEqual(providerArtworkName(code: missingCode, variant: .trimmed), "provider_generic_trimmed")

        for provider in providers {
            for variant in ProviderArtworkVariant.allCases {
                let resolvedName = providerArtworkName(code: provider.providerCode, variant: variant)
                #if os(macOS)
                XCTAssertNotNil(
                    NSImage(named: NSImage.Name(resolvedName)),
                    "\(provider.providerCode) \(variant) should resolve to bundled artwork"
                )
                #else
                XCTAssertNotNil(
                    UIImage(named: resolvedName),
                    "\(provider.providerCode) \(variant) should resolve to bundled artwork"
                )
                #endif
            }
        }
    }

    func testBytePlusModelArk_RequiresExactNamedConfiguration() throws {
        let provider = try XCTUnwrap(providers.first { $0.providerCode == .BYTEPLUS_MODELARK })
        XCTAssertEqual(provider.keyType, .CONFIGURATION)
        XCTAssertEqual(provider.creditCurrency, .USD)
        XCTAssertEqual(provider.credentialFields.map(\.id), ["api_key", "region"])
        XCTAssertTrue(provider.credentialFields[0].isSensitive)
        XCTAssertTrue(provider.credentialFields.allSatisfy(\.isRequired))
    }

    func testConnectionGroups_ExposeEveryUnlinkedProvider() {
        let groups = partitionProvidersForConnections(providers, linkedProviderIds: [])

        XCTAssertTrue(groups.linked.isEmpty)
        XCTAssertEqual(Set(groups.unlinked.map(\.providerCode)), Set(EnumProviderCode.allCases))
    }

    func testProviders_ProviderIdMatchesEnumCode() {
        for provider in providers {
            XCTAssertEqual(
                provider.providerId,
                provider.providerCode.providerId,
                "\(provider.providerCode) providerId should be derived from its enum code"
            )
        }
    }

    // MARK: - Key Validation Regex: OpenAI

    func testKeyRegex_OpenAI_ValidKey_Matches() throws {
        let provider = try XCTUnwrap(providers.first(where: { $0.providerCode == .OPENAI }))
        let regex = try NSRegularExpression(pattern: provider.keyStructure)
        let validKey = "sk-proj-" + String(repeating: "a", count: 32)
        let range = NSRange(validKey.startIndex ..< validKey.endIndex, in: validKey)
        XCTAssertNotNil(regex.firstMatch(in: validKey, range: range), "Valid OpenAI key should match")
    }

    func testKeyRegex_OpenAI_WrongPrefix_DoesNotMatch() throws {
        let provider = try XCTUnwrap(providers.first(where: { $0.providerCode == .OPENAI }))
        let regex = try NSRegularExpression(pattern: provider.keyStructure)
        let invalidKey = "sk-" + String(repeating: "a", count: 32)
        let range = NSRange(invalidKey.startIndex ..< invalidKey.endIndex, in: invalidKey)
        XCTAssertNil(regex.firstMatch(in: invalidKey, range: range), "Invalid prefix should not match")
    }

    func testKeyRegex_OpenAI_TooShort_DoesNotMatch() throws {
        let provider = try XCTUnwrap(providers.first(where: { $0.providerCode == .OPENAI }))
        let regex = try NSRegularExpression(pattern: provider.keyStructure)
        let shortKey = "sk-proj-" + String(repeating: "a", count: 10)
        let range = NSRange(shortKey.startIndex ..< shortKey.endIndex, in: shortKey)
        XCTAssertNil(regex.firstMatch(in: shortKey, range: range), "Too-short key should not match")
    }

    // MARK: - Key Validation Regex: Stability AI

    func testKeyRegex_StabilityAI_ValidKey_Matches() throws {
        let provider = try XCTUnwrap(providers.first(where: { $0.providerCode == .STABILITY_AI }))
        let regex = try NSRegularExpression(pattern: provider.keyStructure)
        let validKey = "sk-" + String(repeating: "B", count: 38)
        let range = NSRange(validKey.startIndex ..< validKey.endIndex, in: validKey)
        XCTAssertNotNil(regex.firstMatch(in: validKey, range: range), "Valid Stability AI key should match")
    }

    func testKeyRegex_StabilityAI_TooShort_DoesNotMatch() throws {
        let provider = try XCTUnwrap(providers.first(where: { $0.providerCode == .STABILITY_AI }))
        let regex = try NSRegularExpression(pattern: provider.keyStructure)
        let shortKey = "sk-" + String(repeating: "B", count: 10)
        let range = NSRange(shortKey.startIndex ..< shortKey.endIndex, in: shortKey)
        XCTAssertNil(regex.firstMatch(in: shortKey, range: range), "Too-short key should not match")
    }

    // MARK: - Key Validation Regex: Google Cloud

    func testKeyRegex_GoogleCloud_ValidKey_Matches() throws {
        let provider = try XCTUnwrap(providers.first(where: { $0.providerCode == .GOOGLE_CLOUD }))
        let regex = try NSRegularExpression(pattern: provider.keyStructure)
        let validKey = "AIza" + String(repeating: "x", count: 35)
        let range = NSRange(validKey.startIndex ..< validKey.endIndex, in: validKey)
        XCTAssertNotNil(regex.firstMatch(in: validKey, range: range), "Valid Google Cloud key should match")
    }

    func testKeyRegex_GoogleCloud_WrongPrefix_DoesNotMatch() throws {
        let provider = try XCTUnwrap(providers.first(where: { $0.providerCode == .GOOGLE_CLOUD }))
        let regex = try NSRegularExpression(pattern: provider.keyStructure)
        let invalidKey = "WRONG" + String(repeating: "x", count: 35)
        let range = NSRange(invalidKey.startIndex ..< invalidKey.endIndex, in: invalidKey)
        XCTAssertNil(regex.firstMatch(in: invalidKey, range: range), "Invalid prefix should not match")
    }

    // MARK: - Key Validation Regex: Replicate

    func testKeyRegex_Replicate_ValidKey_Matches() throws {
        let provider = try XCTUnwrap(providers.first(where: { $0.providerCode == .REPLICATE }))
        let regex = try NSRegularExpression(pattern: provider.keyStructure)
        let validKey = "r8_" + String(repeating: "c", count: 38)
        let range = NSRange(validKey.startIndex ..< validKey.endIndex, in: validKey)
        XCTAssertNotNil(regex.firstMatch(in: validKey, range: range), "Valid Replicate key should match")
    }

    func testKeyRegex_Replicate_TooLong_DoesNotMatch() throws {
        let provider = try XCTUnwrap(providers.first(where: { $0.providerCode == .REPLICATE }))
        let regex = try NSRegularExpression(pattern: provider.keyStructure)
        let longKey = "r8_" + String(repeating: "c", count: 50)
        let range = NSRange(longKey.startIndex ..< longKey.endIndex, in: longKey)
        XCTAssertNil(regex.firstMatch(in: longKey, range: range), "Too-long key should not match")
    }

    // MARK: - Key Validation Regex: Firecrawl

    func testKeyRegex_Firecrawl_ValidKey_Matches() throws {
        let provider = try XCTUnwrap(providers.first(where: { $0.providerCode == .FIRECRAWL }))
        let regex = try NSRegularExpression(pattern: provider.keyStructure)
        let validKey = "fc-" + String(repeating: "a", count: 32)
        let range = NSRange(validKey.startIndex ..< validKey.endIndex, in: validKey)
        XCTAssertNotNil(regex.firstMatch(in: validKey, range: range), "Valid Firecrawl key should match")
    }

    func testKeyRegex_Firecrawl_UppercaseHex_DoesNotMatch() throws {
        let provider = try XCTUnwrap(providers.first(where: { $0.providerCode == .FIRECRAWL }))
        let regex = try NSRegularExpression(pattern: provider.keyStructure)
        let invalidKey = "fc-" + String(repeating: "A", count: 32)
        let range = NSRange(invalidKey.startIndex ..< invalidKey.endIndex, in: invalidKey)
        XCTAssertNil(
            regex.firstMatch(in: invalidKey, range: range),
            "Uppercase hex should not match (Firecrawl uses lowercase)"
        )
    }

    // MARK: - Key Validation Regex: Fal AI

    func testKeyRegex_FalAI_EmptyString_Matches() throws {
        let provider = try XCTUnwrap(providers.first(where: { $0.providerCode == .FAL_AI }))
        let regex = try NSRegularExpression(pattern: provider.keyStructure)
        let emptyKey = ""
        let range = NSRange(emptyKey.startIndex ..< emptyKey.endIndex, in: emptyKey)
        XCTAssertNotNil(regex.firstMatch(in: emptyKey, range: range), "Fal AI regex '^$' should match empty string")
    }

    // MARK: - Key Validation Regex: Runway

    func testKeyRegex_Runway_UsesDocumentedFormat() throws {
        let provider = try XCTUnwrap(providers.first(where: { $0.providerCode == .RUNWAY }))
        let regex = try NSRegularExpression(pattern: provider.keyStructure)
        let validKey = "key_" + String(repeating: "a", count: 128)
        let invalidKey = "key_" + String(repeating: "g", count: 128)

        let validRange = NSRange(validKey.startIndex ..< validKey.endIndex, in: validKey)
        let invalidRange = NSRange(invalidKey.startIndex ..< invalidKey.endIndex, in: invalidKey)
        XCTAssertNotNil(regex.firstMatch(in: validKey, range: validRange))
        XCTAssertNil(regex.firstMatch(in: invalidKey, range: invalidRange))
    }

    // MARK: - Balance Checking

    func testBalanceCheck_StabilityAIAndLumaAI_SupportBalanceCheck() {
        let balanceProviders = providers.filter(\.supportsBalanceCheck)
        XCTAssertEqual(balanceProviders.count, 2, "Two providers should support balance check")
        let balanceCodes = Set(balanceProviders.map(\.providerCode))
        XCTAssertTrue(balanceCodes.contains(.STABILITY_AI))
        XCTAssertTrue(balanceCodes.contains(.LUMA_AI))
    }

    func testBalanceCheck_StabilityAI_HasValidEndpoint() throws {
        let stabilityAI = try XCTUnwrap(providers.first(where: { $0.providerCode == .STABILITY_AI }))
        XCTAssertNotNil(stabilityAI.balanceEndpoint)
        XCTAssertTrue(try XCTUnwrap(stabilityAI.balanceEndpoint?.hasPrefix("https://")))
    }

    func testBalanceCheck_NonBalanceProviders_HaveNilEndpoint() {
        let nonBalance = providers.filter { !$0.supportsBalanceCheck }
        for provider in nonBalance {
            XCTAssertNil(provider.balanceEndpoint, "\(provider.providerCode) should not have a balance endpoint")
        }
    }

    // MARK: - Credit Currency

    func testCreditCurrency_CreditProvidersUseCredits() {
        let expected: Set<EnumProviderCode> = [
            .STABILITY_AI,
            .BLACK_FOREST_LABS,
            .RUNWAY,
            .PIXVERSE,
        ]
        let actual = Set(providers.filter { $0.creditCurrency == .CREDITS }.map(\.providerCode))
        XCTAssertEqual(actual, expected)
    }

    func testCreditCurrency_NonCreditProvidersUseUSD() {
        let creditProviders: Set<EnumProviderCode> = [
            .STABILITY_AI,
            .BLACK_FOREST_LABS,
            .RUNWAY,
            .PIXVERSE,
        ]
        let usdProviders = providers.filter { !creditProviders.contains($0.providerCode) }
        for provider in usdProviders {
            XCTAssertEqual(
                provider.creditCurrency, .USD,
                "\(provider.providerCode) should use USD currency"
            )
        }
    }

    // MARK: - Key Type

    func testKeyType_AllProviders_UseCorrectKeyType() {
        for provider in providers {
            let expected: EnumProviderKeyType = switch provider.providerCode {
            case .CLOUDFLARE_AI: .JSON
            case .GOOGLE_VERTEX_AI, .AZURE_AI_FOUNDRY, .AMAZON_BEDROCK, .ALIBABA_MODEL_STUDIO, .MINIMAX,
                 .BYTEPLUS_MODELARK: .CONFIGURATION
            default: .API
            }
            XCTAssertEqual(provider.keyType, expected, "Unexpected key type for \(provider.providerCode)")
        }
    }

    func testCredentialFields_VertexUsesShortLivedTokenProjectAndLocation() throws {
        let provider = try XCTUnwrap(providers.first { $0.providerCode == .GOOGLE_VERTEX_AI })

        XCTAssertEqual(provider.credentialFields.map(\.id), ["access_token", "project_id", "location"])
        XCTAssertTrue(try XCTUnwrap(provider.credentialFields.first { $0.id == "access_token" }?.isSensitive))
        XCTAssertFalse(provider.credentialFields.contains { $0.id.contains("private") || $0.id.contains("secret") })
    }

    func testCredentialFields_AzureUsesResourceScopedEndpointAndDeployments() throws {
        let provider = try XCTUnwrap(providers.first { $0.providerCode == .AZURE_AI_FOUNDRY })

        XCTAssertEqual(
            provider.credentialFields.map(\.id),
            ["endpoint", "api_key", "image_deployment", "video_deployment"]
        )
        XCTAssertTrue(try XCTUnwrap(provider.credentialFields.first { $0.id == "api_key" }?.isSensitive))
        XCTAssertFalse(try XCTUnwrap(provider.credentialFields.first { $0.id == "endpoint" }?.isSensitive))
    }

    func testCredentialFields_BedrockUsesBearerKeyAndRegion() throws {
        let provider = try XCTUnwrap(providers.first { $0.providerCode == .AMAZON_BEDROCK })

        XCTAssertEqual(provider.credentialFields.map(\.id), ["api_key", "region"])
        XCTAssertTrue(try XCTUnwrap(provider.credentialFields.first { $0.id == "api_key" }?.isSensitive))
        XCTAssertFalse(try XCTUnwrap(provider.credentialFields.first { $0.id == "region" }?.isSensitive))
    }

    // MARK: - getProvider(providerId:) Lookup

    func testGetProvider_ValidId_ReturnsCorrectProvider() {
        for provider in providers {
            let found = getProvider(providerId: provider.providerId)
            XCTAssertNotNil(found, "Should find provider for \(provider.providerCode)")
            XCTAssertEqual(found?.providerCode, provider.providerCode)
        }
    }

    func testGetProvider_InvalidId_ReturnsNil() {
        let result = getProvider(providerId: UUID())
        XCTAssertNil(result, "Random UUID should not match any provider")
    }

    // MARK: - Codable Round-Trip

    func testCodable_RoundTrip_PreservesAllFields() throws {
        let original = providers[0] // OpenAI
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let restored = try decoder.decode(Provider.self, from: data)

        XCTAssertEqual(restored.providerId, original.providerId)
        XCTAssertEqual(restored.providerCode, original.providerCode)
        XCTAssertEqual(restored.providerName, original.providerName)
        XCTAssertEqual(restored.providerDescription, original.providerDescription)
        XCTAssertEqual(restored.providerOnboardingUrl, original.providerOnboardingUrl)
        XCTAssertEqual(restored.keyStructure, original.keyStructure)
        XCTAssertEqual(restored.keyPlaceholder, original.keyPlaceholder)
        XCTAssertEqual(restored.keyType, original.keyType)
        XCTAssertEqual(restored.creditCurrency, original.creditCurrency)
        XCTAssertEqual(restored.active, original.active)
        XCTAssertEqual(restored.supportsBalanceCheck, original.supportsBalanceCheck)
        XCTAssertEqual(restored.balanceEndpoint, original.balanceEndpoint)
    }

    func testCodable_StabilityAI_PreservesBalanceFields() throws {
        let stabilityAI = try XCTUnwrap(providers.first(where: { $0.providerCode == .STABILITY_AI }))
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(stabilityAI)
        let restored = try decoder.decode(Provider.self, from: data)

        XCTAssertTrue(restored.supportsBalanceCheck)
        XCTAssertEqual(restored.balanceEndpoint, "https://api.stability.ai/v1/user/balance")
    }

    func testCodable_AllProviders_SurviveRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for provider in providers {
            let data = try encoder.encode(provider)
            let restored = try decoder.decode(Provider.self, from: data)
            XCTAssertEqual(restored.providerId, provider.providerId, "Round-trip failed for \(provider.providerCode)")
            XCTAssertEqual(
                restored.providerName,
                provider.providerName,
                "Round-trip failed for \(provider.providerCode)"
            )
        }
    }
}
