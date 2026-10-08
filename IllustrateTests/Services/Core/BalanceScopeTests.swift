import Foundation
import IllustrateProviders
import KeychainSwift
import XCTest
@testable import Illustrate

@MainActor
final class BalanceScopeTests: XCTestCase {
    private let providerId = EnumProviderCode.STABILITY_AI.providerId

    func testBalancesStayWithTheirProjectAndCredentialAcrossReloads() async {
        let keychain = BalanceMemoryKeychain()
        let firstProject = UUID()
        let secondProject = UUID()
        keychain.set("first-fixture", forKey: credentialKey(firstProject))
        keychain.set("second-fixture", forKey: credentialKey(secondProject))
        let service = BalanceService(keychain: keychain) { request in
            let credits = request.value(forHTTPHeaderField: "Authorization") == "Bearer first-fixture" ? 10 : 25
            return try self.response(request, credits: credits)
        }

        await service.fetchBalance(for: providerId, projectId: firstProject)
        await service.fetchBalance(for: providerId, projectId: secondProject)

        XCTAssertEqual(service.balance(for: providerId, projectId: firstProject), 10)
        XCTAssertEqual(service.balance(for: providerId, projectId: secondProject), 25)
        let reloaded = BalanceService(keychain: keychain) { _ in
            XCTFail("Reading cached balances must not issue a request")
            throw URLError(.notConnectedToInternet)
        }
        XCTAssertEqual(reloaded.balance(for: providerId, projectId: firstProject), 10)
        XCTAssertEqual(reloaded.balance(for: providerId, projectId: secondProject), 25)

        keychain.set("changed-fixture", forKey: credentialKey(firstProject))
        XCTAssertNil(service.balance(for: providerId, projectId: firstProject))
        XCTAssertNil(reloaded.balance(for: providerId, projectId: firstProject))
        XCTAssertEqual(service.balance(for: providerId, projectId: secondProject), 25)
    }

    func testAResponseForReplacedCredentialsIsDiscarded() async {
        let keychain = BalanceMemoryKeychain()
        let projectId = UUID()
        keychain.set("old-fixture", forKey: credentialKey(projectId))
        let service = BalanceService(keychain: keychain) { request in
            keychain.set("new-fixture", forKey: self.credentialKey(projectId))
            return try self.response(request, credits: 90)
        }

        await service.fetchBalance(for: providerId, projectId: projectId)

        XCTAssertNil(service.balance(for: providerId, projectId: projectId))
        XCTAssertFalse(keychain.values.keys.contains { $0.hasPrefix("balance_") })
    }

    func testLegacyUnscopedBalancesAreNotUsed() throws {
        let keychain = BalanceMemoryKeychain()
        let projectId = UUID()
        keychain.set("fixture", forKey: credentialKey(projectId))
        let legacy = ProviderBalance(providerId: providerId, balance: 700, lastUpdated: Date())
        try keychain.set(JSONEncoder().encode(legacy), forKey: "balance_\(providerId.uuidString)")
        let service = BalanceService(keychain: keychain)

        XCTAssertNil(service.balance(for: providerId, projectId: projectId))
    }

    func testFetchAllIgnoresAnotherProjectsConnections() async {
        let keychain = BalanceMemoryKeychain()
        let projectId = UUID()
        keychain.set("fixture", forKey: credentialKey(projectId))
        var requests = 0
        let service = BalanceService(keychain: keychain) { request in
            requests += 1
            return try self.response(request, credits: 5)
        }

        await service.fetchAllBalances(
            providerKeys: [ProviderKey(providerId: providerId, projectId: UUID())],
            projectId: projectId
        )

        XCTAssertEqual(requests, 0)
        XCTAssertNil(service.balance(for: providerId, projectId: projectId))
    }

    func testRejectedBalanceResponseDoesNotPopulateTheCache() async {
        let keychain = BalanceMemoryKeychain()
        let projectId = UUID()
        keychain.set("fixture", forKey: credentialKey(projectId))
        let service = BalanceService(keychain: keychain) { request in
            try self.response(request, credits: 999, status: 403)
        }

        await service.fetchBalance(for: providerId, projectId: projectId)

        XCTAssertNil(service.balance(for: providerId, projectId: projectId))
    }

    private func credentialKey(_ projectId: UUID) -> String {
        ProjectManager.keychainKey(projectId: projectId, providerId: providerId)
    }

    private func response(_ request: URLRequest, credits: Int, status: Int = 200) throws -> (Data, URLResponse) {
        let url = try XCTUnwrap(request.url)
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
        return (Data("{\"credits\":\(credits)}".utf8), response)
    }
}

private final class BalanceMemoryKeychain: KeychainSwift {
    var values: [String: Data] = [:]

    override func getData(_ key: String, asReference _: Bool = false) -> Data? {
        values[key]
    }

    override func set(_ value: Data, forKey key: String, withAccess _: KeychainSwiftAccessOptions? = nil) -> Bool {
        values[key] = value
        return true
    }
}
