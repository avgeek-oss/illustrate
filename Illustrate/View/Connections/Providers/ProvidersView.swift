// MARK: - ProvidersView.swift

// Provider management view for connecting/disconnecting AI providers.
//
// Shows two sections:
// 1. Connected providers (with remove option)
// 2. Available providers to add
//
// ## Provider Connection
// When a provider is connected, a ProviderKey is created and the
// API key is stored securely in Keychain.
//
// ## Provider Removal
// Removes both the ProviderKey record and the Keychain entry.
// Posts .providerKeysChanged notification to update caches.

import AppTrackingTransparency
import KeychainSwift
import OSLog
import SwiftData
import SwiftUI

/// Row view for a connected provider with delete option.
struct LinkedProviderView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager

    @State private var isLongPressActive = false
    @State private var showDeleteConfirmation = false

    let provider: Provider
    let providerKey: ProviderKey

    var body: some View {
        HStack {
            Label {
                Text("\(provider.providerName)")
            } icon: {
                Image(providerArtworkName(code: provider.providerCode, variant: .square))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
            Spacer()
            Image(systemName: "minus.circle")
                .font(.headline)
                .foregroundStyle(.red)
                .onTapGesture {
                    DispatchQueue.main.async {
                        showDeleteConfirmation = true
                    }
                }
        }
        .confirmationDialog(
            "Are you sure you want to remove \(provider.providerName)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                deleteProviderKey(providerKey)
            }

            Button("Cancel", role: .cancel) {
                DispatchQueue.main.async {
                    showDeleteConfirmation = false
                }
            }
        }
    }

    private func deleteProviderKey(_ providerKey: ProviderKey) {
        let keychain = KeychainSwift()
        keychain.accessGroup = TEAM_KEYCHAIN_AG
        keychain.synchronizable = true

        let keychainKey = ProjectManager.keychainKey(
            projectId: providerKey.projectId,
            providerId: providerKey.providerId
        )

        if keychain.get(keychainKey) != nil {
            keychain.delete(keychainKey)
        }

        modelContext.delete(providerKey)

        try? modelContext.save()

        // Notify that provider keys changed
        NotificationCenter.default.post(name: .providerKeysChanged, object: nil)
    }
}

struct ProvidersView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @Query(sort: \ProviderKey.createdAt, order: .reverse) private var allProviderKeys: [ProviderKey]
    @AppStorage("hasRequestedTrackingAuthorization") private var hasRequestedTrackingAuthorization = false

    @State private var providerKeys: [ProviderKey] = []
    @State private var linkedProviders: [Provider] = []
    @State private var unlinkedProviders: [Provider] = []

    private func updateProviderData() {
        let currentProjectId = projectManager.currentProjectId
        providerKeys = allProviderKeys.filter { $0.projectId == currentProjectId }
        let keyProviderIds = Set(providerKeys.map(\.providerId))
        let groups = partitionProvidersForConnections(
            providers,
            linkedProviderIds: keyProviderIds
        )
        linkedProviders = groups.linked
        unlinkedProviders = groups.unlinked
    }

    func requestTrackingAuthorization() {
        ATTrackingManager.requestTrackingAuthorization { status in
            hasRequestedTrackingAuthorization = true

            switch status {
            case .authorized:
                AppLogger.app.debug("Tracking authorized")
            case .denied:
                AppLogger.app.debug("Tracking denied")
            case .notDetermined:
                AppLogger.app.debug("Tracking not determined")
            case .restricted:
                AppLogger.app.debug("Tracking restricted")
            @unknown default:
                AppLogger.app.debug("Unknown tracking status")
            }
        }
    }

    var body: some View {
        Form {
            if !linkedProviders.isEmpty {
                Section("Linked") {
                    ForEach(linkedProviders, id: \.self) { provider in
                        if let providerKey = providerKeys.first(where: { $0.providerId == provider.providerId }) {
                            LinkedProviderView(provider: provider, providerKey: providerKey)
                        }
                    }
                }
            }

            if !unlinkedProviders.isEmpty {
                Section("Unlinked") {
                    ForEach(unlinkedProviders, id: \.self) { provider in
                        NavigationLink(value: EnumNavigationItem.addProvider(providerId: provider.providerId)) {
                            Label {
                                Text("\(provider.providerName)")
                            } icon: {
                                Image(providerArtworkName(code: provider.providerCode, variant: .square))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            updateProviderData()
            if !hasRequestedTrackingAuthorization {
                requestTrackingAuthorization()
            }
        }
        .onChange(of: allProviderKeys) { _, _ in updateProviderData() }
        .onChange(of: projectManager.currentProjectId) { _, _ in updateProviderData() }
        .navigationTitle(labelForItem(.settingsProviders))
    }
}

/// Keeps inactive providers out of the connection flow while preserving an
/// existing linked entry so a user can inspect or remove legacy credentials.
func partitionProvidersForConnections(
    _ providerCatalog: [Provider],
    linkedProviderIds: Set<UUID>
) -> (linked: [Provider], unlinked: [Provider]) {
    let linked = providerCatalog.filter { linkedProviderIds.contains($0.providerId) }
    let unlinked = providerCatalog.filter {
        $0.active && !linkedProviderIds.contains($0.providerId)
    }
    return (linked, unlinked)
}
