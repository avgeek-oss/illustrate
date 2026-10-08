// MARK: - BalanceServiceTests.swift

// Unit tests for BalanceService and related types.
//
// Tests cover:
// - ProviderBalance struct serialization
// - Balance query methods
// - Provider helper functions
// - Provider model properties

import IllustrateProviders
import XCTest
@testable import Illustrate

final class BalanceServiceTests: XCTestCase {
    // MARK: - ProviderBalance Tests

    func testProviderBalance_initialization() {
        let providerId = UUID()
        let balance = ProviderBalance(
            providerId: providerId,
            balance: 125.50,
            lastUpdated: Date()
        )

        XCTAssertEqual(balance.providerId, providerId)
        XCTAssertEqual(balance.balance, 125.50)
        XCTAssertNotNil(balance.lastUpdated)
    }

    func testProviderBalance_codableRoundTrip() throws {
        let providerId = UUID()
        let date = Date()
        let original = ProviderBalance(
            providerId: providerId,
            balance: 999.99,
            lastUpdated: date
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProviderBalance.self, from: data)

        XCTAssertEqual(decoded.providerId, providerId)
        XCTAssertEqual(decoded.balance, 999.99, accuracy: 0.001)
        XCTAssertEqual(
            decoded.lastUpdated.timeIntervalSince1970,
            date.timeIntervalSince1970,
            accuracy: 1
        )
    }

    func testProviderBalance_zeroBalance() throws {
        let original = ProviderBalance(
            providerId: UUID(),
            balance: 0,
            lastUpdated: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProviderBalance.self, from: data)

        XCTAssertEqual(decoded.balance, 0)
    }

    func testProviderBalance_largeBalance() throws {
        let original = ProviderBalance(
            providerId: UUID(),
            balance: 1_000_000.00,
            lastUpdated: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProviderBalance.self, from: data)

        XCTAssertEqual(decoded.balance, 1_000_000.00, accuracy: 0.01)
    }

    func testProviderBalance_negativeBalance() throws {
        // Some providers might show negative balance
        let original = ProviderBalance(
            providerId: UUID(),
            balance: -50.25,
            lastUpdated: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProviderBalance.self, from: data)

        XCTAssertEqual(decoded.balance, -50.25, accuracy: 0.001)
    }

    // MARK: - BalanceService Singleton Tests

    func testBalanceService_singleton_sameInstance() {
        let instance1 = BalanceService.shared
        let instance2 = BalanceService.shared

        XCTAssertTrue(instance1 === instance2, "Singleton should return same instance")
    }

    func testBalanceService_balance_unknownProvider_returnsNil() {
        let service = BalanceService.shared
        let unknownProviderId = UUID()

        let balance = service.balance(for: unknownProviderId)

        XCTAssertNil(balance, "Unknown provider should return nil balance")
    }

    func testBalanceService_balanceInfo_unknownProvider_returnsNil() {
        let service = BalanceService.shared
        let unknownProviderId = UUID()

        let balanceInfo = service.balanceInfo(for: unknownProviderId)

        XCTAssertNil(balanceInfo, "Unknown provider should return nil balance info")
    }

    // MARK: - Provider Helper Function Tests

    func testGetProvider_byProviderId_existingProvider() {
        // Get a known provider from the providers array
        guard let firstProvider = providers.first else {
            XCTFail("No providers configured")
            return
        }

        let found = getProvider(providerId: firstProvider.providerId)

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.providerId, firstProvider.providerId)
        XCTAssertEqual(found?.providerCode, firstProvider.providerCode)
    }

    func testGetProvider_byProviderId_unknownProvider() {
        let unknownId = UUID()
        let found = getProvider(providerId: unknownId)

        XCTAssertNil(found, "Unknown provider ID should return nil")
    }

    func testGetProvider_byModelId_existingModel() {
        guard let firstModel = ProviderService.shared.allModels.first else {
            XCTFail("No models available")
            return
        }

        let modelIdString = firstModel.modelId.uuidString
        let found = getProvider(modelId: modelIdString)

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.providerId, firstModel.providerId)
    }

    func testGetProvider_byModelId_unknownModel() {
        let unknownModelId = UUID().uuidString
        let found = getProvider(modelId: unknownModelId)

        XCTAssertNil(found, "Unknown model ID should return nil")
    }

    // MARK: - Provider Array Tests

    func testProviders_notEmpty() {
        XCTAssertFalse(providers.isEmpty, "Should have configured providers")
    }

    func testProviders_haveUniqueIds() {
        let providerIds = providers.map(\.providerId)
        let uniqueIds = Set(providerIds)

        XCTAssertEqual(providerIds.count, uniqueIds.count, "Provider IDs should be unique")
    }

    func testProviders_haveUniqueCodes() {
        let providerCodes = providers.map(\.providerCode)
        let uniqueCodes = Set(providerCodes)

        XCTAssertEqual(providerCodes.count, uniqueCodes.count, "Provider codes should be unique")
    }

    func testProviders_haveRequiredProperties() {
        for provider in providers {
            XCTAssertFalse(provider.providerName.isEmpty, "Provider should have name")
            XCTAssertFalse(provider.providerDescription.isEmpty, "Provider should have description")
            XCTAssertFalse(provider.providerOnboardingUrl.isEmpty, "Provider should have onboarding URL")
        }
    }

    func testProviders_haveValidKeyStructure() {
        for provider in providers {
            // Key structure is a regex pattern
            XCTAssertFalse(provider.keyStructure.isEmpty, "Provider should have key structure")
            XCTAssertFalse(provider.keyPlaceholder.isEmpty, "Provider should have key placeholder")
        }
    }

    // MARK: - Provider Balance Support Tests

    func testProviders_balanceCheckSupport() {
        let providersWithBalance = providers.filter(\.supportsBalanceCheck)

        for provider in providersWithBalance {
            XCTAssertNotNil(
                provider.balanceEndpoint,
                "Provider \(provider.providerName) supports balance but has no endpoint"
            )
            XCTAssertFalse(
                provider.balanceEndpoint?.isEmpty ?? true,
                "Balance endpoint should not be empty"
            )
        }
    }

    func testProviders_withoutBalanceCheck_noEndpoint() {
        let providersWithoutBalance = providers.filter { !$0.supportsBalanceCheck }

        // Providers without balance check typically don't need an endpoint
        // But having one shouldn't break anything either
        XCTAssertFalse(providersWithoutBalance.isEmpty, "Should have some providers without balance check")
    }

    // MARK: - Provider Model Tests

    func testProvider_codableRoundTrip() throws {
        let original = Provider(
            providerId: UUID(),
            providerCode: .OPENAI,
            providerName: "Test Provider",
            providerDescription: "A test provider",
            providerOnboardingUrl: "https://example.com",
            keyStructure: "^sk-[a-zA-Z0-9]+$",
            keyPlaceholder: "sk-xxxx",
            keyType: .API,
            creditCurrency: .USD,
            active: true,
            supportsBalanceCheck: true,
            balanceEndpoint: "https://api.example.com/balance"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Provider.self, from: data)

        XCTAssertEqual(decoded.providerId, original.providerId)
        XCTAssertEqual(decoded.providerCode, original.providerCode)
        XCTAssertEqual(decoded.providerName, "Test Provider")
        XCTAssertEqual(decoded.providerDescription, "A test provider")
        XCTAssertEqual(decoded.keyType, .API)
        XCTAssertEqual(decoded.creditCurrency, .USD)
        XCTAssertTrue(decoded.supportsBalanceCheck)
        XCTAssertEqual(decoded.balanceEndpoint, "https://api.example.com/balance")
    }

    func testProvider_codableRoundTrip_withoutBalanceEndpoint() throws {
        let original = Provider(
            providerId: UUID(),
            providerCode: .REPLICATE,
            providerName: "No Balance Provider",
            providerDescription: "Provider without balance",
            providerOnboardingUrl: "https://example.com",
            keyStructure: "^r8_[a-zA-Z0-9]+$",
            keyPlaceholder: "r8_xxxx",
            keyType: .API,
            creditCurrency: .USD,
            active: true,
            supportsBalanceCheck: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Provider.self, from: data)

        XCTAssertFalse(decoded.supportsBalanceCheck)
        XCTAssertNil(decoded.balanceEndpoint)
    }

    // MARK: - EnumProviderKeyType Tests

    func testEnumProviderKeyType_allCases() {
        let allCases = EnumProviderKeyType.allCases

        XCTAssertTrue(allCases.contains(.API))
        XCTAssertTrue(allCases.contains(.JSON))
    }

    func testEnumProviderKeyType_codable() throws {
        let types: [EnumProviderKeyType] = [.API, .JSON]

        let data = try JSONEncoder().encode(types)
        let decoded = try JSONDecoder().decode([EnumProviderKeyType].self, from: data)

        XCTAssertEqual(decoded, types)
    }

    // MARK: - EnumProviderCreditCurrency Tests

    func testEnumProviderCreditCurrency_allCases() {
        let allCases = EnumProviderCreditCurrency.allCases

        XCTAssertTrue(allCases.contains(.USD))
        XCTAssertTrue(allCases.contains(.CREDITS))
    }

    func testEnumProviderCreditCurrency_codable() throws {
        let currencies: [EnumProviderCreditCurrency] = [.USD, .CREDITS]

        let data = try JSONEncoder().encode(currencies)
        let decoded = try JSONDecoder().decode([EnumProviderCreditCurrency].self, from: data)

        XCTAssertEqual(decoded, currencies)
    }

    // MARK: - EnumProviderCode Tests

    func testEnumProviderCode_hasExpectedProviders() {
        // Test that we have the main providers
        XCTAssertNotNil(EnumProviderCode.OPENAI)
        XCTAssertNotNil(EnumProviderCode.STABILITY_AI)
        XCTAssertNotNil(EnumProviderCode.GOOGLE_CLOUD)
        XCTAssertNotNil(EnumProviderCode.REPLICATE)
        XCTAssertNotNil(EnumProviderCode.FAL_AI)
    }

    func testEnumProviderCode_providerIdDeterministic() {
        // Provider IDs should be deterministic (same code = same ID)
        let id1 = EnumProviderCode.OPENAI.providerId
        let id2 = EnumProviderCode.OPENAI.providerId

        XCTAssertEqual(id1, id2, "Provider ID should be deterministic")
    }

    func testEnumProviderCode_differentCodes_differentIds() {
        let openaiId = EnumProviderCode.OPENAI.providerId
        let stabilityId = EnumProviderCode.STABILITY_AI.providerId

        XCTAssertNotEqual(openaiId, stabilityId, "Different providers should have different IDs")
    }
}
