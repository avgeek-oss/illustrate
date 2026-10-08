// MARK: - BrandKitView.swift

// View for managing project brand assets.
//
// Allows users to configure brand identity across 4 sections:
// - Details: Brand name and personality
// - Logo Assets: Light and dark logo variants
// - Typeface: System font selection
// - Reference Images: Reference images for ad generation
//
// ## Brand Colors
// Structured as predefined types (primary, secondary, accent, background, text)
// plus additional custom colors.
//
// ## Brand Images
// Uploaded via BrandKitManager with:
// - Full image stored in iCloud
// - Thumbnails generated and cached locally

import IllustrateProviders
import KeychainSwift
import SwiftData
import SwiftUI

/// Brand kit management view with colors and images.
struct BrandKitView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var brandKitManager = BrandKitManager.shared
    @StateObject private var projectManager = ProjectManager.shared

    @Query private var providerKeys: [ProviderKey]

    @State private var brandImages: [BrandImageVariant: PlatformImage] = [:]
    @State private var loadingVariants: Set<BrandImageVariant> = []

    // Model assets state
    @State private var modelAssetImages: [UUID: PlatformImage] = [:]
    @State private var loadingModelAssets: Set<UUID> = []

    // Brand details state
    @State private var brandName = ""
    @State private var brandAbout = ""
    @State private var brandPersonality = ""

    /// Fetch brand kit sheet state
    @State private var showFetchSheet = false

    /// Whether Firecrawl provider is configured for the current project
    private var isFirecrawlConfigured: Bool {
        providerKeys.contains { $0.providerId == EnumProviderCode.FIRECRAWL.providerId }
    }

    var body: some View {
        Form {
            // Auto-fetch brand kit sections
            fetchBrandKitBanner

            // Brand kit particulars sections
            detailsSection
            brandColorsSection
            typefaceSection
            logoAssetsSection
            referenceImagesSection
        }
        .formStyle(.grouped)
        .navigationTitle("Brand Kit")
        .onAppear {
            brandKitManager.ensureBrandKitExists(modelContext: modelContext, projectId: projectManager.currentProjectId)
        }
        .onChange(of: projectManager.currentProjectId) { _, newProjectId in
            brandKitManager.ensureBrandKitExists(modelContext: modelContext, projectId: newProjectId)
        }
        .onChange(of: brandKitManager.currentBrandKit?.id) { _, _ in
            // Reload data when brand kit is loaded or changes
            loadBrandData()
            loadBrandImagesAsync()
        }
        .sheet(isPresented: $showFetchSheet, onDismiss: {
            // Reload images after fetch sheet is dismissed
            loadBrandImagesAsync()
        }) {
            FetchBrandKitSheet()
        }
        .onChange(of: brandKitManager.currentBrandKit?.brandName) { _, newName in
            // Sync local state when brand kit is updated externally
            if let newName, newName != brandName {
                brandName = newName
            }
        }
        .onChange(of: brandKitManager.currentBrandKit?.brandAbout) { _, newAbout in
            if let newAbout, newAbout != brandAbout {
                brandAbout = newAbout
            }
        }
        .onChange(of: brandKitManager.currentBrandKit?.brandPersonality) { _, newPersonality in
            if let newPersonality, newPersonality != brandPersonality {
                brandPersonality = newPersonality
            }
        }
    }

    // MARK: - Fetch Brand Kit Banner

    @ViewBuilder
    private var fetchBrandKitBanner: some View {
        #if os(macOS)
        if isFirecrawlConfigured {
            Section {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "wand.and.rays.inverse")
                            .font(.system(size: 18))
                            .foregroundStyle(.accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-extract brand information")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Automatically extract brand information from your website")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    showFetchSheet = true
                }
            } footer: {
                Text("Uses your connected Firecrawl account to analyze brand websites.")
            }
        } else {
            Section {
                NavigationLink {
                    ProvidersView()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 40, height: 40)

                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connect Firecrawl")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text("Auto-fill brand details from your website")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("Connect your Firecrawl account in the Providers section to enable automatic brand extraction.")
            }
        }
        #endif
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        Section {
            TextField("Brand Name", text: $brandName)
                .onChange(of: brandName) { _, newValue in
                    brandKitManager.updateBrandName(newValue, modelContext: modelContext)
                }

            VStack(alignment: .leading, spacing: 4) {
                TextField(
                    "About",
                    text: $brandAbout,
                    prompt: Text("What does your brand do? Mission, values, offerings..."),
                    axis: .vertical
                )
                .lineLimit(3 ... 6)
                #if os(macOS)
                .textFieldStyle(.roundedBorder)
                .textSelection(.enabled)
                .focusEffectDisabled()
                #endif
                .onChange(of: brandAbout) { _, newValue in
                    if newValue.count > 500 {
                        brandAbout = String(newValue.prefix(500))
                    }
                    brandKitManager.updateBrandAbout(brandAbout, modelContext: modelContext)
                }

                Text("\(brandAbout.count)/500 characters")
                    .font(.caption)
                    .foregroundStyle(brandAbout.count >= 500 ? .orange : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                TextField(
                    "Personality",
                    text: $brandPersonality,
                    prompt: Text("e.g., Professional, innovative, trustworthy..."),
                    axis: .vertical
                )
                .lineLimit(2 ... 4)
                #if os(macOS)
                .textFieldStyle(.roundedBorder)
                .textSelection(.enabled)
                .focusEffectDisabled()
                #endif
                .onChange(of: brandPersonality) { _, newValue in
                    if newValue.count > 160 {
                        brandPersonality = String(newValue.prefix(160))
                    }
                    brandKitManager.updateBrandPersonality(brandPersonality, modelContext: modelContext)
                }

                Text("\(brandPersonality.count)/160 characters")
                    .font(.caption)
                    .foregroundStyle(brandPersonality.count >= 160 ? .orange : .secondary)
            }
        } header: {
            Text("Details")
        } footer: {
            Text("Describe your brand to help generate consistent content that matches your identity.")
        }
    }

    // MARK: - Brand Colors Section

    private var brandColorsSection: some View {
        Section {
            // Static brand colors
            ForEach(BrandColorType.allCases, id: \.self) { colorType in
                BrandColorRow(
                    colorType: colorType,
                    hexColor: brandKitManager.getBrandColor(for: colorType),
                    onUpdate: { newColor in
                        brandKitManager.updateBrandColor(newColor, for: colorType, modelContext: modelContext)
                    }
                )
            }

            // Additional colors
            if let kit = brandKitManager.currentBrandKit {
                if !kit.additionalColors.isEmpty {
                    ForEach(Array(kit.additionalColors.enumerated()), id: \.offset) { index, color in
                        AdditionalColorRow(
                            hexColor: color,
                            index: index,
                            onUpdate: { newColor in
                                brandKitManager.updateAdditionalColor(
                                    at: index,
                                    with: newColor,
                                    modelContext: modelContext
                                )
                            },
                            onDelete: {
                                brandKitManager.removeAdditionalColor(at: index, modelContext: modelContext)
                            }
                        )
                    }
                }

                Button {
                    brandKitManager.addAdditionalColor("#808080", modelContext: modelContext)
                } label: {
                    Label("Add Custom Color", systemImage: "plus.circle")
                }
            }
        } header: {
            Text("Brand Colors")
        }
    }

    // MARK: - Logo Assets Section

    private var logoAssetsSection: some View {
        Section {
            ForEach(BrandImageVariant.logoVariants, id: \.self) { variant in
                BrandImageRow(
                    variant: variant,
                    image: brandImages[variant],
                    isLoading: loadingVariants.contains(variant),
                    onImageSelected: { image in
                        brandImages[variant] = image
                        brandKitManager.saveBrandImage(image, variant: variant, modelContext: modelContext)
                    },
                    onDelete: {
                        brandImages[variant] = nil
                        brandKitManager.removeBrandImage(variant: variant, modelContext: modelContext)
                    }
                )
            }

            ImageAddRow(label: "Add Logo Variant") { image in
                if let variant = BrandImageVariant.logoVariants.first(where: { brandImages[$0] == nil }) {
                    brandImages[variant] = image
                    brandKitManager.saveBrandImage(image, variant: variant, modelContext: modelContext)
                }
            }
        } header: {
            Text("Logo Assets")
        } footer: {
            Text("Prefer to upload the transparent images for better results.")
        }
    }

    // MARK: - Typeface Section

    private var typefaceSection: some View {
        Section {
            FontFacePicker(
                selectedFont: brandKitManager.currentBrandKit?.fontFace,
                onFontSelected: { fontName in
                    brandKitManager.updateFontFace(fontName, modelContext: modelContext)
                }
            )
        } header: {
            Text("Typeface")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    "Select your brand's primary font from installed system fonts. If using a proprietary or uncommon font, upload a screenshot of your font specimen to Reference Images for better results in generation."
                )
            }
        }
    }

    // MARK: - Reference Images Section

    private var referenceImagesSection: some View {
        Section {
            if let kit = brandKitManager.currentBrandKit {
                ForEach(kit.modelAssets) { asset in
                    ModelAssetRow(
                        asset: asset,
                        image: modelAssetImages[asset.id],
                        isLoading: loadingModelAssets.contains(asset.id),
                        onDelete: {
                            modelAssetImages[asset.id] = nil
                            brandKitManager.removeModelAsset(id: asset.id, modelContext: modelContext)
                        }
                    )
                }

                ImageAddRow(label: "Add Reference Image") { image in
                    if let asset = brandKitManager.addModelAsset(image, modelContext: modelContext) {
                        modelAssetImages[asset.id] = image
                    }
                }
            }
        } header: {
            Text("Reference Images")
        } footer: {
            Text(
                "Upload reference images, product photos, or other relevant images to use as reference inputs."
            )
        }
    }

    // MARK: - Data Loading

    private func loadBrandData() {
        guard let kit = brandKitManager.currentBrandKit else { return }
        brandName = kit.brandName
        brandAbout = kit.brandAbout
        brandPersonality = kit.brandPersonality
    }

    private func loadBrandImagesAsync() {
        guard let kit = brandKitManager.currentBrandKit else {
            brandImages = [:]
            modelAssetImages = [:]
            return
        }

        // Load logo variants
        for variant in BrandImageVariant.allCases {
            let thumbFileName = kit.thumbFileName(for: variant) ?? kit.imageFileName(for: variant)

            guard let fileName = thumbFileName else {
                brandImages[variant] = nil
                continue
            }

            if let cached = ImageCache.shared.get(forKey: fileName) {
                brandImages[variant] = cached
            } else {
                loadingVariants.insert(variant)
                DispatchQueue.global(qos: .userInitiated).async {
                    let image = loadImageFromiCloud(fileName)
                    DispatchQueue.main.async {
                        if let image {
                            ImageCache.shared.set(image, forKey: fileName)
                        }
                        brandImages[variant] = image
                        loadingVariants.remove(variant)
                    }
                }
            }
        }

        // Load model assets
        for asset in kit.modelAssets {
            let fileName = asset.thumbFileName

            if let cached = ImageCache.shared.get(forKey: fileName) {
                modelAssetImages[asset.id] = cached
            } else {
                loadingModelAssets.insert(asset.id)
                DispatchQueue.global(qos: .userInitiated).async {
                    let image = loadImageFromiCloud(fileName)
                    DispatchQueue.main.async {
                        if let image {
                            ImageCache.shared.set(image, forKey: fileName)
                        }
                        modelAssetImages[asset.id] = image
                        loadingModelAssets.remove(asset.id)
                    }
                }
            }
        }
    }
}

// MARK: - Brand Color Row (for predefined colors)

struct BrandColorRow: View {
    let colorType: BrandColorType
    let hexColor: String
    let onUpdate: (String) -> Void

    @State private var editableHex = ""
    @State private var selectedColor: Color = .black

    var body: some View {
        HStack(spacing: 12) {
            Text(colorType.displayName)
                .frame(width: 100, alignment: .leading)

            Spacer()

            TextField("", text: $editableHex)
                .font(.system(.body, design: .monospaced))
                .frame(width: 80)
                .multilineTextAlignment(.center)
                #if !os(macOS)
                .autocapitalization(.allCharacters)
                .keyboardType(.asciiCapable)
                #endif
                .onChange(of: editableHex) { _, newValue in
                    let filtered = filterHexInput(newValue)
                    if filtered != newValue {
                        editableHex = filtered
                    }
                    if filtered.count == 6 {
                        selectedColor = colorFromHex(filtered)
                        onUpdate("#" + filtered)
                    }
                }

            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: selectedColor) { _, newColor in
                    let hex = hexFromColor(newColor)
                    editableHex = hex
                    onUpdate("#" + hex)
                }
        }
        .onAppear {
            let hex = hexColor.replacingOccurrences(of: "#", with: "")
            editableHex = hex
            selectedColor = colorFromHex(hex)
        }
        .onChange(of: hexColor) { _, newHexColor in
            let hex = newHexColor.replacingOccurrences(of: "#", with: "")
            editableHex = hex
            selectedColor = colorFromHex(hex)
        }
    }

    private func filterHexInput(_ input: String) -> String {
        let allowed = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        let filtered = String(input.unicodeScalars.filter { allowed.contains($0) })
        return String(filtered.prefix(6)).uppercased()
    }

    private func colorFromHex(_ hex: String) -> Color {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }

        guard hexString.count == 6 else { return .black }

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        return Color(red: r, green: g, blue: b)
    }

    private func hexFromColor(_ color: Color) -> String {
        #if os(macOS)
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return "000000" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
        #else
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        #endif
    }
}

// MARK: - Additional Color Row (for custom colors with delete)

struct AdditionalColorRow: View {
    let hexColor: String
    let index: Int
    let onUpdate: (String) -> Void
    let onDelete: () -> Void

    @State private var editableHex = ""
    @State private var selectedColor: Color = .black
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            Text("Custom Color \(index + 1)")
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Spacer()

            TextField("", text: $editableHex)
                .font(.system(.body, design: .monospaced))
                .frame(width: 80)
                .multilineTextAlignment(.center)
                #if !os(macOS)
                .autocapitalization(.allCharacters)
                .keyboardType(.asciiCapable)
                #endif
                .onChange(of: editableHex) { _, newValue in
                    let filtered = filterHexInput(newValue)
                    if filtered != newValue {
                        editableHex = filtered
                    }
                    if filtered.count == 6 {
                        selectedColor = colorFromHex(filtered)
                        onUpdate("#" + filtered)
                    }
                }

            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: selectedColor) { _, newColor in
                    let hex = hexFromColor(newColor)
                    editableHex = hex
                    onUpdate("#" + hex)
                }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .confirmationDialog(
            "Delete Custom Color \(index + 1)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This color will be removed from your Brand Kit.")
        }
        .onAppear {
            let hex = hexColor.replacingOccurrences(of: "#", with: "")
            editableHex = hex
            selectedColor = colorFromHex(hex)
        }
        .onChange(of: hexColor) { _, newHexColor in
            let hex = newHexColor.replacingOccurrences(of: "#", with: "")
            editableHex = hex
            selectedColor = colorFromHex(hex)
        }
    }

    private func filterHexInput(_ input: String) -> String {
        let allowed = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        let filtered = String(input.unicodeScalars.filter { allowed.contains($0) })
        return String(filtered.prefix(6)).uppercased()
    }

    private func colorFromHex(_ hex: String) -> Color {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }

        guard hexString.count == 6 else { return .black }

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        return Color(red: r, green: g, blue: b)
    }

    private func hexFromColor(_ color: Color) -> String {
        #if os(macOS)
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return "000000" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
        #else
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        #endif
    }
}

// MARK: - Font Face Picker

struct FontFacePicker: View {
    let selectedFont: String?
    let onFontSelected: (String?) -> Void

    @State private var availableFonts: [String] = []
    @State private var searchText = ""
    @State private var isLoadingFonts = true

    private var filteredFonts: [String] {
        if searchText.isEmpty {
            return availableFonts
        }
        return availableFonts.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            #if os(macOS)
            if isLoadingFonts {
                HStack {
                    Text("Font Family")
                    Spacer()
                    GradientSpinner()
                }
            } else {
                Picker("Font Family", selection: Binding(
                    get: { selectedFont ?? "" },
                    set: { onFontSelected($0.isEmpty ? nil : $0) }
                )) {
                    Text("None").tag("")
                    ForEach(availableFonts, id: \.self) { font in
                        Text(font)
                            .font(.custom(font, size: 14))
                            .tag(font)
                    }
                }
            }
            #else
            NavigationLink {
                FontSelectionView(
                    selectedFont: selectedFont,
                    availableFonts: availableFonts,
                    onFontSelected: onFontSelected
                )
            } label: {
                HStack {
                    Text("Font Family")
                    Spacer()
                    if isLoadingFonts {
                        GradientSpinner()
                    } else {
                        Text(selectedFont ?? "None")
                            .foregroundStyle(.secondary)
                            .font(selectedFont != nil ? .custom(selectedFont!, size: 17) : .body)
                    }
                }
            }
            .disabled(isLoadingFonts)
            #endif
        }
        .task {
            await loadAvailableFonts()
        }
    }

    private func loadAvailableFonts() async {
        let fonts = await Task.detached(priority: .userInitiated) {
            #if os(macOS)
            return NSFontManager.shared.availableFontFamilies.sorted()
            #else
            return UIFont.familyNames.sorted()
            #endif
        }.value

        await MainActor.run {
            availableFonts = fonts
            isLoadingFonts = false
        }
    }
}

// MARK: - Font Selection View (iOS)

#if !os(macOS)
struct FontSelectionView: View {
    let selectedFont: String?
    let availableFonts: [String]
    let onFontSelected: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredFonts: [String] {
        if searchText.isEmpty {
            return availableFonts
        }
        return availableFonts.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            Button {
                onFontSelected(nil)
                dismiss()
            } label: {
                HStack {
                    Text("None")
                    Spacer()
                    if selectedFont == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .foregroundStyle(.primary)

            ForEach(filteredFonts, id: \.self) { font in
                Button {
                    onFontSelected(font)
                    dismiss()
                } label: {
                    HStack {
                        Text(font)
                            .font(.custom(font, size: 17))
                        Spacer()
                        if selectedFont == font {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Select Font")
        .searchable(text: $searchText, prompt: "Search fonts")
    }
}
#endif

// MARK: - Brand Image Row

struct BrandImageRow: View {
    let variant: BrandImageVariant
    let image: PlatformImage?
    var isLoading = false
    let onImageSelected: (PlatformImage) -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isDropTargeted ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                                lineWidth: isDropTargeted ? 2 : 1
                            )
                    )

                if isLoading {
                    GradientSpinner()
                } else if let image {
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
                } else {
                    Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "photo")
                        .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(variant.displayName)
                    .fontWeight(.medium)
                Text(
                    isDropTargeted ? "Drop to upload" :
                        (isLoading ? "Loading..." : (image != nil ? "Uploaded" : "Not uploaded"))
                )
                .font(.callout)
                .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
            }

            Spacer()

            if image != nil {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            ImageSourcePicker(
                buttonLabel: image != nil ? "Change" : "Upload",
                onImageSelected: onImageSelected
            )
        }
        .padding(.vertical, 4)
        .imageDropTarget(isTargeted: $isDropTargeted) { droppedImage in
            onImageSelected(droppedImage)
        }
        .confirmationDialog(
            "Delete \(variant.displayName)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This asset will be removed from your Brand Kit.")
        }
    }
}

// MARK: - Model Asset Row

struct ModelAssetRow: View {
    let asset: ModelAsset
    let image: PlatformImage?
    var isLoading = false
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

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

                if isLoading {
                    GradientSpinner()
                } else if let image {
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
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model Asset")
                    .fontWeight(.medium)
                Text(isLoading ? "Loading..." : "Uploaded")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            "Delete Model Asset?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This asset will be removed from your Brand Kit.")
        }
    }
}

// MARK: - Image Add Row

struct ImageAddRow: View {
    let label: String
    let onImageSelected: (PlatformImage) -> Void

    @State private var isDropTargeted = false
    @State private var isHovered = false
    @State private var showImagePicker = false

    /// Whether the row should show the highlighted state (drop target or hover)
    private var isHighlighted: Bool {
        isDropTargeted || isHovered
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHighlighted ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isHighlighted ? Color.accentColor : Color.secondary,
                                style: isHighlighted
                                    ? StrokeStyle(lineWidth: 2)
                                    : StrokeStyle(lineWidth: 1, dash: [4])
                            )
                    )

                Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "plus")
                    .foregroundStyle(isHighlighted ? Color.accentColor : .secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showImagePicker = true
            }

            Text(isDropTargeted ? "Drop to upload" : label)
                .foregroundStyle(isHighlighted ? Color.accentColor : .secondary)

            Spacer()

            ImageSourcePicker(
                buttonLabel: "Upload",
                showPicker: $showImagePicker,
                onImageSelected: onImageSelected
            )
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            isHovered = hovering
        }
        .imageDropTarget(isTargeted: $isDropTargeted) { droppedImage in
            onImageSelected(droppedImage)
        }
    }
}
