// MARK: - ProviderModelDeepTests.swift

// Deep tests for Provider model decode edge cases, key validation,
// and static array consistency beyond what ProviderConfigurationTests covers.
//
// ProviderConfigurationTests covers: count, unique IDs/codes, names, descriptions,
// onboarding URLs, active, code→ID match, key regex validation, basic Codable round-trip,
// balance checking, getProvider lookup.
//
// This file adds: decode with missing optionals, all-provider round-trip field
// equality, key regex compilation, onboarding URL validity, description constraints,
// deterministic UUID stability, and deeper getProvider edge cases.

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

final class ProviderModelDeepTests: XCTestCase {
    // MARK: - Decode with Missing Optionals

    func testDecode_missingSupportsBalanceCheck_defaultsToFalse() throws {
        let original = providers[0] // OpenAI
        var json = try encodeToDictionary(original)
        json.removeValue(forKey: "supportsBalanceCheck")

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(Provider.self, from: data)
        XCTAssertFalse(decoded.supportsBalanceCheck)
    }

    func testDecode_missingBalanceEndpoint_defaultsToNil() throws {
        let original = providers[0] // OpenAI
        var json = try encodeToDictionary(original)
        json.removeValue(forKey: "balanceEndpoint")

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(Provider.self, from: data)
        XCTAssertNil(decoded.balanceEndpoint)
    }

    func testDecode_missingBothOptionals_defaultsApplied() throws {
        let stability = try XCTUnwrap(providers.first(where: { $0.providerCode == .STABILITY_AI }))
        var json = try encodeToDictionary(stability)
        json.removeValue(forKey: "supportsBalanceCheck")
        json.removeValue(forKey: "balanceEndpoint")

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(Provider.self, from: data)
        XCTAssertFalse(decoded.supportsBalanceCheck)
        XCTAssertNil(decoded.balanceEndpoint)
    }

    // MARK: - Provider Codable Deep

    func testCodable_eachProvider_allFieldsPreserved() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for provider in providers {
            let data = try encoder.encode(provider)
            let restored = try decoder.decode(Provider.self, from: data)

            XCTAssertEqual(restored.providerId, provider.providerId)
            XCTAssertEqual(restored.providerCode, provider.providerCode)
            XCTAssertEqual(restored.providerName, provider.providerName)
            XCTAssertEqual(restored.providerDescription, provider.providerDescription)
            XCTAssertEqual(restored.providerOnboardingUrl, provider.providerOnboardingUrl)
            XCTAssertEqual(restored.keyStructure, provider.keyStructure)
            XCTAssertEqual(restored.keyPlaceholder, provider.keyPlaceholder)
            XCTAssertEqual(restored.keyType, provider.keyType)
            XCTAssertEqual(restored.creditCurrency, provider.creditCurrency)
            XCTAssertEqual(restored.active, provider.active)
            XCTAssertEqual(restored.supportsBalanceCheck, provider.supportsBalanceCheck)
            XCTAssertEqual(restored.balanceEndpoint, provider.balanceEndpoint)
        }
    }

    func testCodable_modifiedProvider_preservesChange() throws {
        let original = providers[0]
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(Provider.self, from: data)
        restored.active = false

        let data2 = try JSONEncoder().encode(restored)
        let restored2 = try JSONDecoder().decode(Provider.self, from: data2)
        XCTAssertFalse(restored2.active)
        XCTAssertEqual(restored2.providerId, original.providerId)
    }

    func testCodable_stabilityAI_balanceEndpointPreserved() throws {
        let stability = try XCTUnwrap(providers.first(where: { $0.providerCode == .STABILITY_AI }))
        let data = try JSONEncoder().encode(stability)
        let restored = try JSONDecoder().decode(Provider.self, from: data)

        XCTAssertEqual(restored.balanceEndpoint, "https://api.stability.ai/v1/user/balance")
        XCTAssertTrue(restored.supportsBalanceCheck)
    }

    func testCodable_multipleRoundTrips_stable() throws {
        var current = providers[0]
        for _ in 0 ..< 3 {
            let data = try JSONEncoder().encode(current)
            current = try JSONDecoder().decode(Provider.self, from: data)
        }
        XCTAssertEqual(current.providerId, providers[0].providerId)
        XCTAssertEqual(current.providerName, providers[0].providerName)
        XCTAssertEqual(current.keyStructure, providers[0].keyStructure)
    }

    func testCodable_encodesValidJSON() throws {
        for provider in providers {
            let data = try JSONEncoder().encode(provider)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            XCTAssertTrue(jsonObject is [String: Any], "\(provider.providerCode) should produce valid JSON")
        }
    }

    // MARK: - Static Array Consistency

    func testAllKeyStructures_areValidRegex() {
        for provider in providers {
            XCTAssertNoThrow(
                try NSRegularExpression(pattern: provider.keyStructure),
                "\(provider.providerCode) keyStructure should be a valid regex"
            )
        }
    }

    func testAllOnboardingUrls_areValidURLs() {
        for provider in providers {
            XCTAssertNotNil(
                URL(string: provider.providerOnboardingUrl),
                "\(provider.providerCode) onboarding URL should be a valid URL"
            )
        }
    }

    func testDeterministicUuids_stableAcrossCalls() {
        let firstCall = EnumProviderCode.OPENAI.providerId
        let secondCall = EnumProviderCode.OPENAI.providerId
        XCTAssertEqual(firstCall, secondCall)

        for code in [EnumProviderCode.OPENAI, .STABILITY_AI, .GOOGLE_CLOUD, .REPLICATE, .FAL_AI, .FIRECRAWL] {
            let id1 = code.providerId
            let id2 = code.providerId
            XCTAssertEqual(id1, id2, "\(code) should have deterministic UUID")
        }
    }

    func testAllDescriptions_underReasonableLength() {
        for provider in providers {
            XCTAssertLessThan(
                provider.providerDescription.count, 200,
                "\(provider.providerCode) description should be concise"
            )
        }
    }

    // MARK: - Key Regex Prefix Verification

    func testOpenAI_keyPrefixIsSkProj() throws {
        let openAI = try XCTUnwrap(providers.first(where: { $0.providerCode == .OPENAI }))
        XCTAssertTrue(openAI.keyStructure.hasPrefix("^sk-proj-"))
    }

    func testFirecrawl_keyPrefixIsFc() throws {
        let firecrawl = try XCTUnwrap(providers.first(where: { $0.providerCode == .FIRECRAWL }))
        XCTAssertTrue(firecrawl.keyStructure.hasPrefix("^fc-"))
    }

    func testFalAI_regexMatchesEmpty() throws {
        let falAI = try XCTUnwrap(providers.first(where: { $0.providerCode == .FAL_AI }))
        XCTAssertEqual(falAI.keyStructure, "^$")
    }

    func testStabilityAI_keyPrefixIsSk() throws {
        let stability = try XCTUnwrap(providers.first(where: { $0.providerCode == .STABILITY_AI }))
        XCTAssertTrue(stability.keyStructure.hasPrefix("^sk-"))
    }

    func testGoogleCloud_keyPrefixIsAIza() throws {
        let google = try XCTUnwrap(providers.first(where: { $0.providerCode == .GOOGLE_CLOUD }))
        XCTAssertTrue(google.keyStructure.hasPrefix("^AIza"))
    }

    func testReplicate_keyPrefixIsR8() throws {
        let replicate = try XCTUnwrap(providers.first(where: { $0.providerCode == .REPLICATE }))
        XCTAssertTrue(replicate.keyStructure.hasPrefix("^r8_"))
    }

    // MARK: - getProvider Edge Cases

    func testGetProvider_randomUUID_returnsNil() {
        XCTAssertNil(getProvider(providerId: UUID()))
    }

    func testGetProvider_allSixProviders_findableById() {
        for provider in providers {
            let found = getProvider(providerId: provider.providerId)
            XCTAssertNotNil(found)
            XCTAssertEqual(found?.providerCode, provider.providerCode)
        }
    }

    func testGetProvider_multipleLookups_returnsSameInstance() {
        let openAIId = EnumProviderCode.OPENAI.providerId
        let first = getProvider(providerId: openAIId)
        let second = getProvider(providerId: openAIId)
        XCTAssertTrue(first === second, "Multiple lookups should return the same instance")
    }

    // MARK: - Helpers

    private func encodeToDictionary(_ provider: Provider) throws -> [String: Any] {
        let data = try JSONEncoder().encode(provider)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}
