// MARK: - BalanceService.swift

// Service for fetching and caching provider account balances.
//
// Some AI providers (like Stability AI) support checking account balance/credits
// via their API. This service fetches and caches those balances for display
// in the UI.
//
// ## Supported Providers
// Currently only Stability AI supports balance checking. Other providers
// are skipped automatically based on their `supportsBalanceCheck` flag.
//
// ## Caching Strategy
// - In-memory: `_balances` dictionary for fast access
// - Keychain: Persistent storage across app launches
// - Balances are refreshed after each generation
//
// ## Balance Fetching
// - `fetchBalance`: Fetch for a single provider
// - `fetchAllBalances`: Fetch all eligible providers in parallel

import CryptoKit
import Foundation
import IllustrateProviders
import KeychainSwift
import OSLog
import SwiftUI

/// Cached balance information for a provider.
struct ProviderBalance: Codable {
    /// Provider this balance belongs to
    let providerId: UUID
    /// Current balance (in provider's currency unit)
    let balance: Double
    /// When this balance was last fetched
    let lastUpdated: Date
    var credentialFingerprint: String? = nil
}

/// Singleton service for fetching and caching provider balances.
///
/// This service manages balance information for providers that support
/// balance checking. Balances are cached in keychain for persistence
/// and refreshed after each generation.
class BalanceService: ObservableObject {
    /// Shared singleton instance
    static let shared = BalanceService()

    /// In-memory balance cache
    @Published private var _balances: [String: ProviderBalance] = [:]

    /// Keychain for persistent balance storage
    private let keychain: KeychainSwift
    private let dataLoader: (URLRequest) async throws -> (Data, URLResponse)

    init(
        keychain: KeychainSwift = KeychainSwift(),
        dataLoader: @escaping (URLRequest) async throws -> (Data, URLResponse) = {
            try await URLSession.shared.data(for: $0)
        }
    ) {
        self.keychain = keychain
        self.dataLoader = dataLoader
        keychain.accessGroup = TEAM_KEYCHAIN_AG
        keychain.synchronizable = true
    }

    // MARK: - Public API

    /// Get the cached balance for a provider
    func balance(for providerId: UUID, projectId: UUID) -> Double? {
        balanceInfo(for: providerId, projectId: projectId)?.balance
    }

    /// Get the balance info for a provider
    func balanceInfo(for providerId: UUID, projectId: UUID) -> ProviderBalance? {
        let key = Self.cacheKey(providerId: providerId, projectId: projectId)
        let credentialKey = ProjectManager.keychainKey(projectId: projectId, providerId: providerId)
        guard let credential = keychain.get(credentialKey) else { return nil }
        let cached = _balances[key] ?? keychain.getData(key).flatMap {
            try? JSONDecoder().decode(ProviderBalance.self, from: $0)
        }
        guard let cached,
              cached.providerId == providerId,
              cached.credentialFingerprint == Self.fingerprint(credential)
        else { return nil }
        return cached
    }

    /// Fetch balance for all eligible providers
    func fetchAllBalances(providerKeys: [ProviderKey], projectId: UUID) async {
        let eligibleProviderIds = providers
            .filter(\.supportsBalanceCheck)
            .filter { provider in
                providerKeys.contains { $0.providerId == provider.providerId && $0.projectId == projectId }
            }
            .map(\.providerId)

        await withTaskGroup(of: Void.self) { group in
            for providerId in eligibleProviderIds {
                group.addTask {
                    await self.fetchBalance(for: providerId, projectId: projectId)
                }
            }
        }
    }

    /// Fetch balance for a provider by ID
    func fetchBalance(for providerId: UUID, projectId: UUID) async {
        guard let provider = getProvider(providerId: providerId),
              provider.supportsBalanceCheck,
              let endpoint = provider.balanceEndpoint,
              let url = URL(string: endpoint)
        else { return }

        let providerCode = provider.providerCode
        let providerName = provider.providerName

        let keychainKey = ProjectManager.keychainKey(projectId: projectId, providerId: providerId)
        guard let apiKey = keychain.get(keychainKey) else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await dataLoader(request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200
            else { return }

            if let balance = parseBalance(data: data, providerCode: providerCode) {
                let providerBalance = ProviderBalance(
                    providerId: providerId,
                    balance: balance,
                    lastUpdated: Date(),
                    credentialFingerprint: Self.fingerprint(apiKey)
                )

                await MainActor.run {
                    guard self.keychain.get(keychainKey) == apiKey else { return }
                    let cacheKey = Self.cacheKey(providerId: providerId, projectId: projectId)
                    self._balances[cacheKey] = providerBalance
                    self.saveBalanceToKeychain(providerBalance, key: cacheKey)
                }
            }
        } catch {
            AppLogger.network
                .error(
                    "Error fetching balance for \(providerName, privacy: .public): \(error.localizedDescription, privacy: .private)"
                )
        }
    }

    // MARK: - Private Methods

    private func parseBalance(data: Data, providerCode: EnumProviderCode) -> Double? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                switch providerCode {
                case .STABILITY_AI:
                    return json["credits"] as? Double
                case .LUMA_AI:
                    if let creditBalance = json["credit_balance"] as? Double {
                        return creditBalance / 100.0
                    }
                    return nil
                default:
                    return nil
                }
            }
        } catch {
            AppLogger.network.error("Error parsing balance: \(error.localizedDescription, privacy: .public)")
        }
        return nil
    }

    private static func cacheKey(providerId: UUID, projectId: UUID) -> String {
        "balance_\(projectId.uuidString)_\(providerId.uuidString)"
    }

    private static func fingerprint(_ credential: String) -> String {
        SHA256.hash(data: Data(credential.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func saveBalanceToKeychain(_ balance: ProviderBalance, key: String) {
        if let data = try? JSONEncoder().encode(balance) {
            keychain.set(data, forKey: key)
        }
    }
}

// MARK: - Environment Key

struct BalanceServiceKey: EnvironmentKey {
    static let defaultValue = BalanceService.shared
}

extension EnvironmentValues {
    var balanceService: BalanceService {
        get { self[BalanceServiceKey.self] }
        set { self[BalanceServiceKey.self] = newValue }
    }
}
