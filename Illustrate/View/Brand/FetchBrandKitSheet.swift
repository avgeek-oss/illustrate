// MARK: - FetchBrandKitSheet.swift

// Modal sheet for fetching brand information from URLs using Firecrawl Agent.
//
// This view provides:
// - URL input fields (up to 3, at least 1 required)
// - Fetch button to start the extraction
// - Progress indicator during polling
// - Preview of extracted data before applying
// - Error handling and retry functionality
//
// ## States
// - Input: User enters URLs
// - Processing: Agent job is running, polling for results
// - Preview: Shows extracted data for user review
// - Error: Shows error message with retry option

import IllustrateProviders
import KeychainSwift
import OSLog
import SwiftData
import SwiftUI

/// Sheet view for fetching brand information from URLs.
struct FetchBrandKitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var brandKitManager = BrandKitManager.shared
    @StateObject private var projectManager = ProjectManager.shared

    // URL input state
    @State private var url1 = ""
    @State private var url2 = ""
    @State private var url3 = ""
    @State private var skipImages = false

    // Processing state
    @State private var isProcessing = false
    @State private var statusMessage = ""
    @State private var errorMessage: String?

    // Preview state
    @State private var extractedData: BrandKitExtraction?
    @State private var downloadedLogoImages: [BrandImageVariant: PlatformImage] = [:]
    @State private var downloadedModelAssets: [PlatformImage] = []
    @State private var isDownloadingImages = false

    /// Keychain for API key retrieval
    private let keychain: KeychainSwift = {
        let kc = KeychainSwift()
        kc.accessGroup = TEAM_KEYCHAIN_AG
        kc.synchronizable = true
        return kc
    }()

    /// Whether at least one valid URL is entered
    private var hasValidURL: Bool {
        isValidURL(url1) || isValidURL(url2) || isValidURL(url3)
    }

    /// Collects all valid URLs from input fields
    private var validURLs: [String] {
        [url1, url2, url3].filter { isValidURL($0) }
    }

    /// Whether we're showing the preview
    private var isShowingPreview: Bool {
        extractedData != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if isShowingPreview {
                    previewSection
                } else {
                    if !isProcessing {
                        headerSection
                        urlInputSection
                    }

                    if isProcessing {
                        processingSection
                    } else if let error = errorMessage {
                        errorSection(error)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isShowingPreview ? "Preview" : "Auto-extract brand information")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isShowingPreview ? "Back" : "Cancel") {
                        if isShowingPreview {
                            extractedData = nil
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(isProcessing)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isShowingPreview {
                        Button("Apply") {
                            applyExtractedData()
                        }
                    } else {
                        Button("Fetch") {
                            Task {
                                await fetchBrandKit()
                            }
                        }
                        .disabled(!hasValidURL || isProcessing)
                    }
                }
            }
        }
        .interactiveDismissDisabled(isProcessing)
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Uses Firecrawl Agent")
                        .font(.headline)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }

                Text(
                    "Once you submit the URLs, the Firecrawl Agent will analyze the websites and extract the brand information."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } footer: {
            Text(
                "Agent usually consumes upto 500-2000 credits per request."
            )
        }
    }

    private var urlInputSection: some View {
        Section {
            TextField(
                "Primary URL",
                text: $url1,
                prompt: Text("required").foregroundStyle(.secondary)
            )
            .textContentType(.URL)
            .autocorrectionDisabled()
            #if os(iOS)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            #endif

            TextField(
                "Additional URL 1",
                text: $url2,
                prompt: Text("optional").foregroundStyle(.secondary)
            )
            .textContentType(.URL)
            .autocorrectionDisabled()
            #if os(iOS)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            #endif

            TextField(
                "Additional URL 2",
                text: $url3,
                prompt: Text("optional").foregroundStyle(.secondary)
            )
            .textContentType(.URL)
            .autocorrectionDisabled()
            #if os(iOS)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            #endif

            Toggle("Skip fetching images", isOn: $skipImages)
        } header: {
            Text("Brand URLs")
        } footer: {
            Text(
                skipImages
                    ? "Images will be skipped. You can manually upload logos and assets later."
                    :
                    "All URLs should be related to a single brand for better results. Include pages like About, Home, or Brand Guidelines."
            )
        }
    }

    private var processingSection: some View {
        Section {
            VStack(alignment: .center, spacing: 16) {
                VStack(alignment: .center, spacing: 8) {
                    GradientSpinner()
                    Text(statusMessage.isEmpty ? "Starting..." : statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.accent)
                    Text(
                        "Please stay and do not dismiss this section until the extraction is complete. Feel free to navigate to other apps if needed. This process may take a few minutes to complete."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } header: {
            Text("Extraction in progress")
        }
    }

    private func errorSection(_ error: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("Extraction failed")
                        .font(.headline)
                }

                Text(error)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button {
                    errorMessage = nil
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Preview Section

    @ViewBuilder
    private var previewSection: some View {
        if let data = extractedData {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("Review extracted information")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                    }

                    Text(
                        "The following brand information was extracted. Review for correctness below and tap Apply to update your Brand Kit."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Brand Details
            Section {
                if let name = data.brandName, !name.isEmpty {
                    PreviewRow(label: "Brand Name", value: name)
                }

                if let about = data.brandAbout, !about.isEmpty {
                    PreviewRow(label: "About", value: String(about.prefix(500)))
                }

                if let personality = data.brandPersonality, !personality.isEmpty {
                    PreviewRow(label: "Personality", value: String(personality.prefix(160)))
                }
            } header: {
                Text("Details")
            }

            // Colors
            Section {
                if let primary = data.primaryColor {
                    ColorPreviewRow(label: "Primary", hexColor: primary)
                }

                if let secondary = data.secondaryColor {
                    ColorPreviewRow(label: "Secondary", hexColor: secondary)
                }

                if let accent = data.accentColor {
                    ColorPreviewRow(label: "Accent", hexColor: accent)
                }

                if let background = data.backgroundColor {
                    ColorPreviewRow(label: "Background", hexColor: background)
                }

                if let additionalColors = data.additionalColors, !additionalColors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Colors")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(additionalColors.prefix(4), id: \.self) { color in
                                ColorSwatch(hexColor: color)
                            }
                        }
                    }
                }
            } header: {
                Text("Colors")
            }

            // Logo Assets
            if !downloadedLogoImages.isEmpty {
                Section {
                    ForEach(BrandImageVariant.logoVariants, id: \.self) { variant in
                        if let image = downloadedLogoImages[variant] {
                            LogoImagePreviewRow(variant: variant, image: image)
                        }
                    }
                } header: {
                    Text("Logo Assets")
                } footer: {
                    Text("Transparent versions are preferred for logos.")
                }
            }

            // Reference Images
            if !downloadedModelAssets.isEmpty {
                Section {
                    ForEach(Array(downloadedModelAssets.enumerated()), id: \.offset) { index, image in
                        ModelAssetPreviewRow(index: index + 1, image: image)
                    }
                } header: {
                    Text("Reference Images")
                } footer: {
                    Text("Common brand themes and reference images.")
                }
            }

            // Show loading indicator while downloading images
            if isDownloadingImages {
                Section {
                    HStack {
                        GradientSpinner()
                        Text("Downloading images...")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Typeface (only show if font is available in system)
            if let fontFace = data.fontFace, !fontFace.isEmpty,
               let systemFont = BrandKitManager.shared.findSystemFont(fontFace)
            {
                Section {
                    FontPreviewRow(fontName: systemFont)
                } header: {
                    Text("Typeface")
                }
            }
        }
    }

    // MARK: - URL Validation

    private func isValidURL(_ urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Add https:// if no scheme is provided
        var urlToCheck = trimmed
        if !urlToCheck.lowercased().hasPrefix("http://"), !urlToCheck.lowercased().hasPrefix("https://") {
            urlToCheck = "https://" + urlToCheck
        }

        guard let url = URL(string: urlToCheck),
              let host = url.host,
              host.contains(".")
        else {
            return false
        }

        return true
    }

    /// Normalizes URL by adding https:// if needed
    private func normalizeURL(_ urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.lowercased().hasPrefix("http://"), !trimmed.lowercased().hasPrefix("https://") {
            return "https://" + trimmed
        }
        return trimmed
    }

    // MARK: - Fetch Logic

    private func fetchBrandKit() async {
        isProcessing = true
        errorMessage = nil
        statusMessage = "Starting agent..."

        // Get Firecrawl API key
        let keychainKey = ProjectManager.keychainKey(
            projectId: projectManager.currentProjectId,
            providerId: EnumProviderCode.FIRECRAWL.providerId
        )

        guard let apiKey = keychain.get(keychainKey) else {
            errorMessage = "Firecrawl API key not found. Connect Firecrawl to proceed."
            isProcessing = false
            return
        }

        // Normalize and collect URLs
        let urls = validURLs.map { normalizeURL($0) }

        do {
            // Start the agent job
            statusMessage = "Analyzing brand websites..."
            let jobId = try await FirecrawlAgentService.shared.startAgentJob(
                urls: urls,
                apiKey: apiKey,
                includeImages: !skipImages
            )

            // Poll for results
            let extraction = try await FirecrawlAgentService.shared.pollForResult(
                jobId: jobId,
                apiKey: apiKey
            ) { status in
                Task { @MainActor in
                    statusMessage = status
                }
            }

            // Show preview
            await MainActor.run {
                extractedData = extraction
                isProcessing = false
            }

            // Download images in background (if not skipped)
            if !skipImages {
                await downloadImagesFromExtraction(extraction)
            }

        } catch let error as FirecrawlAgentError {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }

    // MARK: - Apply Extracted Data

    private func applyExtractedData() {
        guard let data = extractedData else { return }
        brandKitManager.applyExtraction(data, modelContext: modelContext)

        // Save downloaded logo images
        for (variant, image) in downloadedLogoImages {
            brandKitManager.saveBrandImage(image, variant: variant, modelContext: modelContext)
        }

        // Save downloaded model assets
        for image in downloadedModelAssets {
            brandKitManager.addModelAsset(image, modelContext: modelContext)
        }

        dismiss()
    }

    // MARK: - Image Download

    private func downloadImagesFromExtraction(_ extraction: BrandKitExtraction) async {
        guard let assets = extraction.imageAssets else { return }

        await MainActor.run {
            isDownloadingImages = true
        }

        // Download logo images
        let logoMappings: [(BrandImageVariant, String?)] = [
            (.lightLogo, assets.lightLogoUrl),
            (.darkLogo, assets.darkLogoUrl),
        ]

        for (variant, urlString) in logoMappings {
            guard let urlString, !urlString.isEmpty else { continue }

            if let image = await downloadImage(from: urlString) {
                await MainActor.run {
                    downloadedLogoImages[variant] = image
                }
            }
        }

        // Download model assets (dynamic array)
        let modelAssetUrls = [
            assets.asset1Url,
            assets.asset2Url,
            assets.asset3Url,
            assets.asset4Url,
            assets.asset5Url,
        ].compactMap { $0 }.filter { !$0.isEmpty }

        for urlString in modelAssetUrls {
            if let image = await downloadImage(from: urlString) {
                await MainActor.run {
                    downloadedModelAssets.append(image)
                }
            }
        }

        await MainActor.run {
            isDownloadingImages = false
        }
    }

    private func downloadImage(from urlString: String) async -> PlatformImage? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Check if response is an image
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let mimeType = httpResponse.mimeType,
                  mimeType.hasPrefix("image/")
            else {
                return nil
            }

            #if os(macOS)
            return NSImage(data: data)
            #else
            return UIImage(data: data)
            #endif
        } catch {
            AppLogger.network
                .error(
                    "Failed to download image from \(urlString, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            return nil
        }
    }
}

// MARK: - Preview Row

private struct PreviewRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Font Preview Row

private struct FontPreviewRow: View {
    let fontName: String

    var body: some View {
        HStack {
            Text(fontName)
                .font(.custom(fontName, size: 15))
        }
    }
}

// MARK: - Color Preview Row

private struct ColorPreviewRow: View {
    let label: String
    let hexColor: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 100, alignment: .leading)

            Spacer()

            Text(hexColor.uppercased())
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            ColorSwatch(hexColor: hexColor)
        }
    }
}

// MARK: - Color Swatch

private struct ColorSwatch: View {
    let hexColor: String

    var body: some View {
        Capsule()
            .fill(colorFromHex(hexColor))
            .frame(width: 28, height: 28)
            .overlay(
                Capsule()
                    .stroke(Color.secondary, lineWidth: 1)
            )
    }

    private func colorFromHex(_ hex: String) -> Color {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }

        guard hexString.count == 6 else { return .gray }

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - Logo Image Preview Row

private struct LogoImagePreviewRow: View {
    let variant: BrandImageVariant
    let image: PlatformImage

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                    )

                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                #endif
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(variant.displayName)
                    .fontWeight(.medium)

                Text("Valid image URL")
                    .font(.caption)
                    .foregroundStyle(.accent)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Model Asset Preview Row

private struct ModelAssetPreviewRow: View {
    let index: Int
    let image: PlatformImage

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                    )

                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                #endif
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model Asset \(index)")
                    .fontWeight(.medium)

                Text("Valid image URL")
                    .font(.caption)
                    .foregroundStyle(.accent)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
