// MARK: - AddProviderView.swift

// Form for adding a new provider API key.
//
// Presents:
// - API key input field (supports both API keys and JSON credentials)
// - Instructions for obtaining the key
// - Link to provider's key management page
//
// ## Key Storage
// API keys are stored in Keychain with:
// - Shared access group for app extensions
// - iCloud sync enabled
// - Project-scoped keys

import KeychainSwift
import OSLog
import SwiftData
import SwiftUI

/// Form for entering and saving provider API credentials.
struct AddProviderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var projectManager: ProjectManager

    @State var providerId: UUID

    @State private var provider: Provider
    @State private var keyValue = ""
    @State private var jsonFieldValues: [String: String] = [:]
    @State private var saveErrorMessage: String?

    init(providerId: UUID) {
        self.providerId = providerId
        provider = providers.first { $0.providerId == providerId }!
    }

    private var isFormValid: Bool {
        if provider.keyType != .API, !provider.credentialFields.isEmpty {
            return provider.credentialFields.filter(\.isRequired).allSatisfy { field in
                let value = jsonFieldValues[field.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return !value.isEmpty
            }
        }
        return !keyValue.isEmpty
    }

    var body: some View {
        Form {
            Section("Link Provider") {
                if provider.keyType != .API, !provider.credentialFields.isEmpty {
                    ForEach(provider.credentialFields) { field in
                        if field.isSensitive {
                            SecureField(field.label, text: binding(for: field.id), prompt: Text(field.placeholder))
                        } else {
                            TextField(field.label, text: binding(for: field.id), prompt: Text(field.placeholder))
                        }
                    }
                } else if provider.keyType == .JSON {
                    TextField(
                        provider.keyType.label,
                        text: $keyValue,
                        prompt: Text(provider.keyPlaceholder),
                        axis: .vertical
                    )
                    .lineLimit(3 ... 8)
                } else {
                    SecureField(provider.keyType.label, text: $keyValue, prompt: Text(provider.keyPlaceholder))
                }
                Button("Save") {
                    addProviderKey()
                }
                .disabled(!isFormValid)
                if let saveErrorMessage {
                    Label(saveErrorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section("Instructions") {
                Image(providerArtworkName(code: provider.providerCode, variant: .base))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                Label(
                    "To connect \(provider.providerName), you will need the \(provider.keyType.label). If you don't have one, use the reference link for assistance on how to get one.",
                    systemImage: "1.circle.fill"
                )
                Label(
                    "Once you link the key here, the same will be stored securely in your Apple Keychain. Illustrate will authenticate your requests with the provider via this key.",
                    systemImage: "2.circle.fill"
                )
                Label(
                    "To remove or revoke, simply delete from here or via the Keychain access application. Note that Illustrate never stores your keys outside your Keychain.",
                    systemImage: "3.circle.fill"
                )
                Label(
                    "Illustrate doesn't manage billing for these providers. Generation and other workflows might incur charges based on your usage. Refer to your provider for details.",
                    systemImage: "4.circle.fill"
                )
                Button("Get \(provider.keyType.label)") {
                    guard let url = URL(string: provider.providerOnboardingUrl) else { return }
                    #if os(macOS)
                    NSWorkspace.shared.open(url)
                    #else
                    UIApplication.shared.open(url)
                    #endif
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(labelForItem(EnumNavigationItem.addProvider(providerId: providerId)))
    }

    private func binding(for fieldId: String) -> Binding<String> {
        Binding(
            get: { jsonFieldValues[fieldId] ?? "" },
            set: { jsonFieldValues[fieldId] = $0 }
        )
    }

    private func addProviderKey() {
        saveErrorMessage = nil
        let valueToSave: String
        if provider.keyType != .API, !provider.credentialFields.isEmpty {
            let dict = Dictionary(
                uniqueKeysWithValues: provider.credentialFields.compactMap { field in
                    let val = jsonFieldValues[field.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return val.isEmpty ? nil : (field.id, val)
                }
            )
            guard let data = try? JSONSerialization.data(withJSONObject: dict),
                  let jsonString = String(data: data, encoding: .utf8)
            else {
                saveErrorMessage = "The credential fields could not be encoded. Check the values and try again."
                return
            }
            valueToSave = jsonString
        } else {
            valueToSave = keyValue
        }

        let keychain = KeychainSwift()
        keychain.accessGroup = TEAM_KEYCHAIN_AG
        keychain.synchronizable = true

        let keychainKey = projectManager.keychainKey(for: provider.providerId)

        if keychain.set(valueToSave, forKey: keychainKey) {
            // Check if a ProviderKey already exists for this provider and project
            // Capture values as local constants for use in #Predicate macro
            let providerId = provider.providerId
            let projectId = projectManager.currentProjectId
            let existingDescriptor = FetchDescriptor<ProviderKey>(
                predicate: #Predicate {
                    $0.providerId == providerId && $0.projectId == projectId
                }
            )

            do {
                let existingKeys = try modelContext.fetch(existingDescriptor)
                if existingKeys.isEmpty {
                    let newKey = ProviderKey(
                        providerId: provider.providerId,
                        projectId: projectManager.currentProjectId
                    )
                    modelContext.insert(newKey)
                }
                try modelContext.save()
                NotificationCenter.default.post(name: .providerKeysChanged, object: nil)
                presentationMode.wrappedValue.dismiss()
            } catch {
                saveErrorMessage = "Your credential is in Keychain, but the provider link could not be saved. Try saving again."
                AppLogger.data.error("Failed to save provider link: \(error.localizedDescription, privacy: .private)")
            }
        } else {
            saveErrorMessage = "The credential could not be saved to Keychain. Check your app signing and Keychain access, then try again."
            AppLogger.data.error("Failed to save provider key")

            if keychain.lastResultCode != noErr {
                AppLogger.data.error("Keychain error: \(keychain.lastResultCode, privacy: .public)")
            }
        }
    }
}
