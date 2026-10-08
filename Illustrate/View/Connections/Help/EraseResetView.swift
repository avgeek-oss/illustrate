// MARK: - EraseResetView.swift

import KeychainSwift
import OSLog
import SwiftData
import SwiftUI

struct EraseResetView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var showResetSheet = false
    @State private var resetConfirmationText = ""
    @State private var isResetting = false

    private let confirmationPhrase = "ERASE"

    private var isConfirmed: Bool {
        resetConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines) == confirmationPhrase
    }

    var body: some View {
        Form {
            Section {
                Label(
                    "This will permanently erase all application data across all projects. This includes all generated images, videos, agents, brand kits, chat threads, playgrounds, storyboards, provider connections, cached files, and iCloud documents.",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)

                Label("This action cannot be undone.", systemImage: "xmark.shield")
                    .foregroundStyle(.red)
            } header: {
                Text("Warning")
            }

            Section("What will be erased") {
                Label("All SwiftData database records across all projects", systemImage: "internaldrive")
                Label("All provider API keys from Keychain", systemImage: "key")
                Label(
                    "All generated media files (images, videos, thumbnails)",
                    systemImage: "photo.on.rectangle.angled"
                )
                Label("All iCloud Documents created by the app", systemImage: "cloud")
                Label("All local cached images and backdrop assets", systemImage: "trash")
                Label("All in-memory caches (gallery, provider keys, images)", systemImage: "memorychip")
            }

            Section {
                Button(role: .destructive, action: {
                    resetConfirmationText = ""
                    showResetSheet = true
                }) {
                    Label("Erase & Reset Application", systemImage: "exclamationmark.triangle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isResetting)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Erase & Reset Application")
        .sheet(isPresented: $showResetSheet) {
            EraseResetConfirmationSheet(
                confirmationPhrase: confirmationPhrase,
                confirmationText: $resetConfirmationText,
                isResetting: $isResetting,
                onCancel: { showResetSheet = false },
                onErase: {
                    performFullReset()
                    showResetSheet = false
                }
            )
        }
    }

    private func performFullReset() {
        isResetting = true
        defer { isResetting = false }

        do {
            let keychain = KeychainSwift()
            keychain.accessGroup = TEAM_KEYCHAIN_AG
            keychain.synchronizable = true

            let allProviderKeys = try modelContext.fetch(FetchDescriptor<ProviderKey>())
            for providerKey in allProviderKeys {
                let keychainKey = ProjectManager.keychainKey(
                    projectId: providerKey.projectId,
                    providerId: providerKey.providerId
                )
                keychain.delete(keychainKey)
            }

            try modelContext.delete(model: ChatMessage.self)
            try modelContext.delete(model: ProviderKey.self)
            try modelContext.delete(model: Project.self)
            try modelContext.save()

            deleteAllICloudDocuments()

            deleteLocalDocuments()

            PodiumBackdropsManager.shared.clearAllCache()

            ImageCache.shared.removeAllImages()
            GalleryCache.shared.invalidate()
            ProviderKeysCache.shared.invalidate()
            NotificationCenter.default.post(name: .providerKeysChanged, object: nil)

            ProjectManager.shared.ensureDefaultProjectExists(modelContext: modelContext)
            ProjectManager.shared.currentProjectId = Project.defaultProjectId

            AppLogger.app.notice("Full application reset completed successfully")
        } catch {
            AppLogger.storage.error("Failed to erase application: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteLocalDocuments() {
        let fm = FileManager.default

        let documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first
        if let url = documentsURL {
            try? fm.removeItem(at: url)
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }

        let supportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let url = supportURL {
            try? fm.removeItem(at: url)
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

private struct EraseResetConfirmationSheet: View {
    let confirmationPhrase: String
    @Binding var confirmationText: String
    @Binding var isResetting: Bool
    let onCancel: () -> Void
    let onErase: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(
                    "This will permanently erase ALL application data across all projects. There is no undo."
                )
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

                Text("Type **\(confirmationPhrase)** to confirm.")
                    .fixedSize(horizontal: false, vertical: true)

                TextField(confirmationPhrase, text: $confirmationText)
                    .textFieldStyle(.roundedBorder)
                    #if os(macOS)
                    .font(.system(.body, design: .monospaced))
                    #endif
            }
            .padding(.all, 24)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erase Everything", role: .destructive, action: onErase)
                        .disabled(confirmationText
                            .trimmingCharacters(in: .whitespacesAndNewlines) != confirmationPhrase || isResetting)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400)
        #endif
    }
}
