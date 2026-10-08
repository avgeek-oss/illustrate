// MARK: - ProviderDetailsView.swift

// Sheet view showing provider details and available models.
//
// Displays when tapping a provider card on WorkspaceView:
// - Provider name and logo
// - Connection status
// - Account balance (if supported)
// - List of available models by type
// - Quick action to connect/manage
//
// ## Model Categories
// Shows models grouped by capability (image generate, edit, video).

import IllustrateProviders
import SwiftData
import SwiftUI

/// Provider detail sheet with models and balance.
struct ProviderDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var balanceService: BalanceService
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    private var providerKeys: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    @Binding var isPresented: Bool
    @State var selectedProvider: Provider

    var isConnected: Bool {
        providerKeys.contains { $0.providerId == selectedProvider.providerId }
    }

    private var balance: Double? {
        guard isConnected else { return nil }
        return balanceService.balance(for: selectedProvider.providerId)
    }

    private var formattedBalance: String? {
        guard let balance else { return nil }
        if selectedProvider.creditCurrency == .USD {
            return formatEstimatedCost(balance)
        } else {
            return balance == floor(balance)
                ? String(format: "%.0f credits", balance)
                : String(format: "%.2f credits", balance)
        }
    }

    private func navigateToAddProvider() {
        isPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigationManager.navigate(to: .settingsProviders)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigationManager.pushDetail(.addProvider(providerId: selectedProvider.providerId))
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SectionKeyValueView(
                        key: "Provider",
                        value: selectedProvider.providerName,
                        customValueView: Image(
                            providerArtworkName(code: selectedProvider.providerCode, variant: .trimmed)
                        ).resizable()
                            .scaledToFit().frame(height: 20)
                    )
                    SectionKeyValueView(key: "Description", value: selectedProvider.providerDescription)
                    if isConnected {
                        SectionKeyValueView(key: "Status", value: "Connected")
                        if let formattedBalance {
                            SectionKeyValueView(key: "Available Balance", value: formattedBalance)
                        }
                    }
                }
                Section("Models") {
                    ForEach(EnumSetType.allCases, id: \.self) { set in
                        let models = ProviderService.shared.models(for: set)
                            .filter { $0.providerId == selectedProvider.providerId }
                        if !models.isEmpty {
                            Section(header: Label(labelForSetType(set), systemImage: iconForSetType(set))) {
                                ForEach(models, id: \.modelCode) { model in
                                    Text(model.modelName)
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(selectedProvider.providerName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss") {
                        DispatchQueue.main.async {
                            isPresented = false
                        }
                    }
                }
                if !isConnected {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Connect") {
                            navigateToAddProvider()
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 480, height: 600)
        #endif
    }
}
