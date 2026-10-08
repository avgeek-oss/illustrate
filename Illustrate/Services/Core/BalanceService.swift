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
    @Published private var _balances: [UUID: ProviderBalance] = [:]

    /// Keychain for persistent balance storage
    private let keychain = KeychainSwift()

    /// Key prefix for balance storage
    private let balanceKeyPrefix = "balance_"

    private init() {
        keychain.accessGroup = TEAM_KEYCHAIN_AG
        keychain.synchronizable = true
        loadCachedBalances()
    }

    // MARK: - Public API

    /// Get the cached balance for a provider
    func balance(for providerId: UUID) -> Double? {
        _balances[providerId]?.balance
    }

    /// Get the balance info for a provider
    func balanceInfo(for providerId: UUID) -> ProviderBalance? {
        _balances[providerId]
    }

    /// Fetch balance for all eligible providers
    func fetchAllBalances(providerKeys: [ProviderKey], projectId: UUID) async {
        let eligibleProviderIds = providers
            .filter(\.supportsBalanceCheck)
            .filter { provider in providerKeys.contains { $0.providerId == provider.providerId } }
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

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200
            else { return }

            if let balance = parseBalance(data: data, providerCode: providerCode) {
                let providerBalance = ProviderBalance(
                    providerId: providerId,
                    balance: balance,
                    lastUpdated: Date()
                )

                await MainActor.run {
                    self._balances[providerId] = providerBalance
                    self.saveBalanceToKeychain(providerBalance)
                }
            }
        } catch {
            AppLogger.network
                .error(
                    "Error fetching balance for \(providerName, privacy: .public): \(error.localizedDescription, privacy: .public)"
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

    private func loadCachedBalances() {
        for provider in providers where provider.supportsBalanceCheck {
            let key = balanceKeyPrefix + provider.providerId.uuidString
            if let data = keychain.getData(key),
               let balance = try? JSONDecoder().decode(ProviderBalance.self, from: data)
            {
                _balances[provider.providerId] = balance
            }
        }
    }

    private func saveBalanceToKeychain(_ balance: ProviderBalance) {
        let key = balanceKeyPrefix + balance.providerId.uuidString
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
