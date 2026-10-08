// MARK: - FormComponents.swift

// Collection of reusable form components for generation views.
//
// This file contains all the UI building blocks used across
// generation forms: pickers, text fields, sliders, toggles, etc.
//
// ## Components Included
// - PromptField: Enum for prompt field focus tracking
// - DimensionPicker: Aspect ratio/dimension selector
// - QualityPicker: Quality tier selector
// - PersonGenerationPicker: People generation permissions
// - StylePicker: Style preset selector
// - VariantPicker: Model variant selector
// - ResolutionPicker: Video resolution selector
// - FPSPicker: Frame rate selector
// - DurationPicker: Video duration selector
// - PromptSection: Text area for prompts
// - ParameterSlider: Numeric parameter with range
// - SeedInput: Random seed text field
// - ReferenceImagesPicker: Multi-image selector
// - GenerateButton: Submit button with cost display
// - (and many more...)
//
// ## Platform Adaptation
// Components adapt their picker style based on platform:
// - macOS: Default picker style
// - iOS: Navigation link style

import AlertToast
import AVFoundation
import AvgeekLocalizationCore
import AvgeekLocalizationUI
import IllustrateProviders
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Common Prompt Field Enum

enum PromptField: Int, CaseIterable {
    case prompt
    case searchPrompt
    case negativePrompt
}

// MARK: - Aspect Ratio Icon

/// A programmatically generated icon representing an aspect ratio
struct AspectRatioIcon: View {
    let widthRatio: Int
    let heightRatio: Int
    let size: CGFloat

    init(widthRatio: Int, heightRatio: Int, size: CGFloat = 20) {
        self.widthRatio = widthRatio
        self.heightRatio = heightRatio
        self.size = size
    }

    var body: some View {
        let aspectRatio = CGFloat(widthRatio) / CGFloat(heightRatio)
        let (width, height): (CGFloat, CGFloat) = if aspectRatio >= 1 {
            (size, size / aspectRatio)
        } else {
            (size * aspectRatio, size)
        }

        RoundedRectangle(cornerRadius: 2)
            .fill(Color.primary.opacity(0.6))
            .frame(width: width, height: height)
            .frame(width: size, height: size)
    }
}

// MARK: - Dimension Picker

struct DimensionPicker: View {
    let label: String
    @Binding var selection: String
    let dimensions: [String]
    var onChange: (() -> Void)?
    @AppLocalized private var localize

    var body: some View {
        Picker(localize(label), selection: safePickerBinding(
            selection: $selection,
            options: dimensions
        )) {
            ForEach(dimensions, id: \.self) { dimension in
                HStack {
                    #if !os(macOS)
                    let ratio = getAspectRatio(dimension: dimension)
                    AspectRatioIcon(widthRatio: ratio.width, heightRatio: ratio.height)
                    #endif
                    Text(
                        dimension
                            .contains(":") ? dimension : "\(dimension) (\(getAspectRatio(dimension: dimension).ratio))"
                    )
                }
                .tag(dimension)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
        .onChange(of: selection) {
            onChange?()
        }
    }
}

// MARK: - Safe Picker Binding Helpers

private func safePickerBinding(selection: Binding<String>, options: [String]) -> Binding<String> {
    Binding(
        get: {
            if options.contains(selection.wrappedValue) {
                return selection.wrappedValue
            }
            return options.first ?? ""
        },
        set: { newValue in
            selection.wrappedValue = newValue
        }
    )
}

private func safePickerBinding(selection: Binding<Int>, options: [Int]) -> Binding<Int> {
    Binding(
        get: {
            if options.contains(selection.wrappedValue) {
                return selection.wrappedValue
            }
            return options.first ?? 0
        },
        set: { newValue in
            selection.wrappedValue = newValue
        }
    )
}

// MARK: - Quality Picker

struct QualityPicker: View {
    @Binding var selection: String
    let qualities: [String]

    var body: some View {
        Picker("Quality", selection: safePickerBinding(selection: $selection, options: qualities)) {
            ForEach(qualities, id: \.self) { quality in
                Text(quality).tag(quality)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
    }
}

// MARK: - Person Generation Picker

struct PersonGenerationPicker: View {
    @Binding var selection: String
    let options: [String]

    private func displayLabel(for option: String) -> String {
        switch option {
        case "dont_allow":
            "Don't Allow"
        case "allow_adult":
            "Allow Adults Only"
        case "allow_all":
            "Allow All (Adults & Children)"
        default:
            option
        }
    }

    var body: some View {
        Picker("Person Generation", selection: safePickerBinding(selection: $selection, options: options)) {
            ForEach(options, id: \.self) { option in
                Text(displayLabel(for: option)).tag(option)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
    }
}

// MARK: - Background Picker

struct BackgroundPicker: View {
    @Binding var selection: String
    let backgrounds: [String]

    var body: some View {
        Picker("Background", selection: safePickerBinding(selection: $selection, options: backgrounds)) {
            ForEach(backgrounds, id: \.self) { background in
                Text(background).tag(background)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
    }
}

// MARK: - Input Fidelity Picker

struct InputFidelityPicker: View {
    @Binding var selection: String
    let fidelities: [String]

    var body: some View {
        Picker("Input Fidelity", selection: safePickerBinding(selection: $selection, options: fidelities)) {
            ForEach(fidelities, id: \.self) { fidelity in
                Text(fidelity).tag(fidelity)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
    }
}

// MARK: - Moderation Picker

struct ModerationPicker: View {
    @Binding var selection: String
    let moderations: [String]

    var body: some View {
        Picker("Moderation", selection: safePickerBinding(selection: $selection, options: moderations)) {
            ForEach(moderations, id: \.self) { moderation in
                Text(moderation).tag(moderation)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
    }
}

// MARK: - Variant Picker

struct VariantPicker: View {
    @Binding var selection: String
    let variants: [String]

    var body: some View {
        Picker("Variant", selection: safePickerBinding(selection: $selection, options: variants)) {
            ForEach(variants, id: \.self) { variant in
                Text(variant).tag(variant)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
    }
}

// MARK: - Style Picker

struct StylePicker: View {
    @Binding var selection: String
    let styles: [String]

    var body: some View {
        Picker("Color Style", selection: safePickerBinding(selection: $selection, options: styles)) {
            ForEach(styles, id: \.self) { style in
                HStack {
                    #if !os(macOS)
                    Image("symbol_color_\(style)".lowercased())
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    #endif
                    Text(style)
                }
                .tag(style)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
    }
}

// MARK: - Resolution Picker

struct ResolutionPicker: View {
    @Binding var selection: String
    let resolutions: [String]

    var body: some View {
        Picker("Resolution", selection: safePickerBinding(selection: $selection, options: resolutions)) {
            ForEach(resolutions, id: \.self) { resolution in
                Text(resolution).tag(resolution)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
    }
}

// MARK: - Steps Slider

struct StepsSlider: View {
    @Binding var value: Double
    let range: (min: Int, max: Int)

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Steps")
                Spacer()
                Text("\(Int(value))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: $value,
                in: Double(range.min) ... Double(range.max),
                step: 1
            )
        }
    }
}

// MARK: - Guidance Slider

struct GuidanceSlider: View {
    @Binding var value: Double
    let range: (min: Double, max: Double)

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Guidance")
                Spacer()
                Text(String(format: "%.1f", value))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: $value,
                in: range.min ... range.max,
                step: 0.1
            )
        }
    }
}

// MARK: - Safety Slider

struct SafetySlider: View {
    @Binding var value: Double
    let range: (min: Int, max: Int)

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Safety Level")
                Spacer()
                Text("\(Int(value))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: $value,
                in: Double(range.min) ... Double(range.max),
                step: 1
            )
        }
    }
}

// MARK: - Grow Mask Slider

struct GrowMaskSlider: View {
    @Binding var value: Double
    let range: (min: Int, max: Int)

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Grow Mask")
                Spacer()
                Text("\(Int(value)) px")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: $value,
                in: Double(range.min) ... Double(range.max),
                step: 1
            )
        }
    }
}

// MARK: - Seed Field

struct SeedField: View {
    @Binding var value: String

    var body: some View {
        TextField("Seed", text: $value, prompt: Text("Leave empty for random"))
            #if !os(macOS)
            .keyboardType(.numberPad)
            #endif
    }
}

// MARK: - Text Area Field

struct TextAreaField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var lineRange: ClosedRange<Int> = 3 ... 8
    @FocusState private var isFocused: Bool
    @AppLocalized private var localize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(localize(label))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.body)
                    .lineLimit(lineRange)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .focused($isFocused)
                    #if os(macOS)
                    .textSelection(.enabled)
                    #endif

                if text.isEmpty {
                    Text(localize(placeholder))
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: CGFloat(lineRange.lowerBound) * 20, maxHeight: CGFloat(lineRange.upperBound) * 20)
            .padding(8)
            #if os(macOS)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isFocused ? Color.accentColor : Color.secondary.opacity(0.25),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            #else
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            #endif
        }
    }
}

// MARK: - Negative Prompt Field

struct NegativePromptField: View {
    @Binding var text: String
    let maxLength: Int
    var placeholder = "Enter negative prompt here"

    var body: some View {
        TextAreaField(
            label: "Negative Prompt",
            text: $text,
            placeholder: placeholder
        )
        .limitText($text, to: maxLength)
    }
}

// MARK: - Prompt Enhance Toggle

struct PromptEnhanceToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("Enhance Prompt", isOn: $isOn)
    }
}

// MARK: - Tools Picker

struct ToolsPicker: View {
    @Binding var selection: Set<String>
    let tools: [String]

    var body: some View {
        ForEach(tools, id: \.self) { tool in
            Toggle(toolDisplayName(tool), isOn: Binding(
                get: { selection.contains(tool) },
                set: { isSelected in
                    if isSelected {
                        selection.insert(tool)
                    } else {
                        selection.remove(tool)
                    }
                }
            ))
        }
    }

    private func toolDisplayName(_ tool: String) -> String {
        switch tool {
        case "google_search":
            "Google Search"
        case "url_context":
            "URL Context"
        default:
            tool.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - Strength Slider

struct StrengthSlider: View {
    @Binding var value: Double
    let range: (min: Double, max: Double)

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Strength")
                Spacer()
                Text(String(format: "%.2f", value))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: $value,
                in: range.min ... range.max,
                step: 0.01
            )
        }
    }
}

// MARK: - Creativity Slider

struct CreativitySlider: View {
    @Binding var value: Double
    let range: (min: Double, max: Double)

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Creativity")
                Spacer()
                Text(String(format: "%.2f", value))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: $value,
                in: range.min ... range.max,
                step: 0.01
            )
        }
    }
}

// MARK: - Estimated Cost Row

struct EstimatedCostRow: View {
    let cost: String

    var body: some View {
        HStack {
            Text("Estimated Cost")
            Spacer()
            Text(cost)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Balance Row

struct BalanceRow: View {
    let balance: Double?
    let estimatedCost: Double
    let creditCurrency: EnumProviderCreditCurrency

    private var balanceColor: Color {
        guard let balance else { return .secondary }

        if estimatedCost > balance {
            return .red
        } else if balance < estimatedCost * 10 {
            return .yellow
        }
        return .secondary
    }

    private var formattedBalance: String {
        guard let balance else { return "—" }

        if creditCurrency == .USD {
            return formatEstimatedCost(balance)
        } else {
            return balance == floor(balance)
                ? String(format: "%.0f credits", balance)
                : String(format: "%.2f credits", balance)
        }
    }

    var body: some View {
        HStack {
            Text("Available Balance")
            Spacer()
            Text(formattedBalance)
                .foregroundStyle(balanceColor)
        }
    }
}

// MARK: - Provider Picker

struct ProviderPicker: View {
    @Binding var selection: String
    let providers: [Provider]
    var onChange: (() -> Void)?

    private var safeSelection: Binding<String> {
        let providerIds = providers.map(\.providerId.uuidString)
        return safePickerBinding(selection: $selection, options: providerIds)
    }

    var body: some View {
        Picker("Provider", selection: safeSelection) {
            ForEach(providers, id: \.providerId) { provider in
                HStack {
                    #if !os(macOS)
                    Image(providerArtworkName(code: provider.providerCode, variant: .square))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                    #endif
                    Text(provider.providerName)
                }
                .tag(provider.providerId.uuidString)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
        .onChange(of: selection) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                onChange?()
            }
        }
    }
}

// MARK: - Model Picker

struct ModelPicker: View {
    @Binding var selection: String
    let models: [ProviderModel]
    var onChange: (() -> Void)?

    private var safeSelection: Binding<String> {
        let modelIds = models.map(\.modelId.uuidString)
        return safePickerBinding(selection: $selection, options: modelIds)
    }

    var body: some View {
        Picker("Model", selection: safeSelection) {
            ForEach(models) { model in
                Text(model.modelName)
                    .tag(model.modelId.uuidString)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
        .onChange(of: selection) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                onChange?()
            }
        }
    }
}

// MARK: - Duration Picker

struct DurationPicker: View {
    let label: String
    @Binding var selection: Int
    let durations: [Int]
    @AppLocalized private var localize

    var body: some View {
        Picker(localize(label), selection: safePickerBinding(selection: $selection, options: durations)) {
            ForEach(durations, id: \.self) { duration in
                Text("\(duration) seconds")
                    .tag(duration)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
    }
}

// MARK: - Frame Rate Picker

struct FrameRatePicker: View {
    @Binding var selection: Int
    let frameRates: [Int]

    var body: some View {
        Picker("Frame Rate", selection: safePickerBinding(selection: $selection, options: frameRates)) {
            ForEach(frameRates, id: \.self) { fps in
                Text("\(fps) fps")
                    .tag(fps)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
    }
}

// MARK: - Aspect Ratio Picker

struct AspectRatioPicker: View {
    let label: String
    @Binding var selection: String
    let dimensions: [String]
    var onChange: (() -> Void)?
    @AppLocalized private var localize

    var body: some View {
        Picker(localize(label), selection: safePickerBinding(
            selection: $selection,
            options: dimensions
        )) {
            ForEach(dimensions, id: \.self) { dimension in
                Text(
                    dimension.contains(":") ? dimension :
                        "\(dimension) (\(getAspectRatio(dimension: dimension).ratio))"
                )
                .tag(dimension)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
        .onChange(of: selection) {
            onChange?()
        }
    }
}

// MARK: - Duration Slider

struct DurationSlider: View {
    @Binding var value: Int
    let range: (min: Int, max: Int)

    var body: some View {
        VStack(alignment: .leading) {
            Text("Duration: \(value) seconds")
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ),
                in: Double(range.min) ... Double(range.max),
                step: 1
            )
        }
    }
}

// MARK: - Motion Slider

struct MotionSlider: View {
    @Binding var value: Double
    let range: (min: Double, max: Double)

    var body: some View {
        VStack {
            #if os(iOS)
            Text("Motion: \(Int(value / 255 * 100))% (\(Int(value)))")
            #endif
            Slider(value: $value, in: range.min ... range.max, step: 15) {
                Text("Motion: \(Int(value / 255 * 100))% (\(Int(value)))")
            }
        }
    }
}

// MARK: - Stickyness Slider

struct StickynessSlider: View {
    @Binding var value: Double
    let range: (min: Double, max: Double)

    var body: some View {
        VStack {
            #if os(iOS)
            Text("Stickyness: \(Int(value * 10))% \(value, specifier: "%.1f")")
            #endif
            Slider(value: $value, in: range.min ... range.max, step: 0.5) {
                Text("Stickyness: \(Int(value * 10))% \(value, specifier: "%.1f")")
            }
        }
    }
}

// MARK: - Number of Videos Picker

struct NumberOfVideosPicker: View {
    @Binding var selection: Int
    let maxVideos: Int

    private var options: [Int] {
        Array(1 ... max(1, maxVideos))
    }

    var body: some View {
        Picker("Number of videos", selection: safePickerBinding(selection: $selection, options: options)) {
            ForEach(options, id: \.self) { count in
                Text("\(count)")
                    .tag(count)
            }
        }
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
    }
}

// MARK: - Image Selection View

#if os(macOS)
typealias UniversalImage = NSImage
#else
typealias UniversalImage = UIImage
#endif

struct ImageSelectionView: View {
    let selectedImage: UniversalImage?
    let colorPalette: [String]
    let onSelectImage: () -> Void
    var isDropTargeted = false

    @State private var isHovered = false

    /// Whether to show accent styling (drop targeted or hovered)
    private var isHighlighted: Bool {
        isDropTargeted || isHovered
    }

    var body: some View {
        ZStack {
            SmoothAnimatedGradientView(colors: colorPalette.compactMap { hex in
                Color(getUniversalColorFromHex(hexString: hex))
            })

            if let image = selectedImage {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxHeight: 400)
                    .shadow(color: .black.opacity(0.4), radius: 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.vertical, 6)
                #endif
            } else {
                VStack(spacing: 8) {
                    Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "photo.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(isHighlighted ? Color.accentColor : .secondary)
                    Text(isDropTargeted ? "Drop to use" : "Select or drop an image")
                        .foregroundStyle(isHighlighted ? Color.accentColor : .secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHighlighted ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isHighlighted ? Color.accentColor : Color.secondary,
                            style: isHighlighted
                                ? StrokeStyle(lineWidth: 2)
                                : StrokeStyle(lineWidth: 1, dash: [5])
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    DispatchQueue.main.async {
                        onSelectImage()
                    }
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                }
            }
        }
    }
}

struct ImageSelectionButton: View {
    let hasImage: Bool
    let onSelectImage: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Spacer()
            Button(hasImage ? "Change Image" : "Select Image") {
                DispatchQueue.main.async {
                    onSelectImage()
                }
            }
            Spacer()
        }
    }
}

// MARK: - Primary Reference Image Section

/// A reusable section for primary reference image selection in edit views.
struct PrimaryReferenceImageSection: View {
    let selectedImage: UniversalImage?
    let colorPalette: [String]
    let description: String
    let onSelectImage: () -> Void
    var expandDirections: (
        expandLeft: Binding<Bool>,
        expandRight: Binding<Bool>,
        expandTop: Binding<Bool>,
        expandBottom: Binding<Bool>
    )?
    var onImageDropped: ((PlatformImage) -> Void)?
    var onRemoveImage: (() -> Void)?

    @State private var isDropTargeted = false

    var body: some View {
        Section(header: Text("Primary Reference Image (Optional)")) {
            if let directions = expandDirections {
                ExpandableImageSelectionView(
                    selectedImage: selectedImage,
                    colorPalette: colorPalette,
                    expandLeft: directions.expandLeft,
                    expandRight: directions.expandRight,
                    expandTop: directions.expandTop,
                    expandBottom: directions.expandBottom,
                    onSelectImage: onSelectImage
                )
            } else {
                ImageSelectionView(
                    selectedImage: selectedImage,
                    colorPalette: colorPalette,
                    onSelectImage: onSelectImage,
                    isDropTargeted: isDropTargeted
                )
                .imageDropTarget(isTargeted: $isDropTargeted) { image in
                    onImageDropped?(image)
                }
            }

            #if os(macOS)
            if let directions = expandDirections, selectedImage != nil {
                VStack {
                    Text("Expand Directions")
                    HStack(spacing: 12) {
                        Spacer()
                        Toggle(isOn: directions.expandLeft) {
                            Text("Left")
                        }
                        .toggleStyle(IllustrateToggleStyle())
                        Toggle(isOn: directions.expandRight) {
                            Text("Right")
                        }
                        .toggleStyle(IllustrateToggleStyle())
                        Toggle(isOn: directions.expandTop) {
                            Text("Top")
                        }
                        .toggleStyle(IllustrateToggleStyle())
                        Toggle(isOn: directions.expandBottom) {
                            Text("Bottom")
                        }
                        .toggleStyle(IllustrateToggleStyle())
                        Spacer()
                    }
                }
            }
            #endif

            HStack(spacing: 24) {
                Spacer()
                Button(selectedImage != nil ? "Change Image" : "Select Image") {
                    DispatchQueue.main.async {
                        onSelectImage()
                    }
                }
                if let onRemove = onRemoveImage, selectedImage != nil {
                    Button(role: .destructive) {
                        DispatchQueue.main.async {
                            onRemove()
                        }
                    } label: {
                        Label("Remove Image", systemImage: "xmark.circle")
                    }
                }
                Spacer()
            }

            Text(description)
                .multilineTextAlignment(.leading)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Expandable Image Selection View

struct ExpandableImageSelectionView: View {
    let selectedImage: UniversalImage?
    let colorPalette: [String]
    @Binding var expandLeft: Bool
    @Binding var expandRight: Bool
    @Binding var expandTop: Bool
    @Binding var expandBottom: Bool
    let onSelectImage: () -> Void

    var body: some View {
        ZStack {
            SmoothAnimatedGradientView(colors: colorPalette.compactMap { hex in
                Color(getUniversalColorFromHex(hexString: hex))
            })

            if let image = selectedImage {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.leading, CGFloat(expandLeft ? 48 : 0))
                    .padding(.trailing, CGFloat(expandRight ? 48 : 0))
                    .padding(.top, CGFloat(expandTop ? 48 : 0))
                    .padding(.bottom, CGFloat(expandBottom ? 48 : 0))
                    .background(Color(NSColor.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxHeight: 400)
                    .shadow(color: .black.opacity(0.4), radius: 8)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.vertical, 6)
                #endif
            } else {
                Image("placeholder_select_image")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(height: 180)
                    .onTapGesture {
                        DispatchQueue.main.async {
                            onSelectImage()
                        }
                    }
            }
        }
    }
}

// MARK: - Image Frame Section

/// A reusable section for starting or ending frame image selection.
struct ImageFrameSection: View {
    let headerText: String
    let selectedImage: UniversalImage?
    let colorPalette: [String]
    let buttonLabel: String
    let changeLabel: String
    let removeLabel: String
    let isDisabled: Bool
    let onSelectImage: () -> Void
    var onRemoveImage: (() -> Void)?
    var onImageDropped: ((PlatformImage) -> Void)?

    @State private var isDropTargeted = false

    init(
        headerText: String,
        selectedImage: UniversalImage?,
        colorPalette: [String],
        buttonLabel: String = "Select Image",
        changeLabel: String = "Change Image",
        removeLabel: String = "Remove",
        isDisabled: Bool = false,
        onSelectImage: @escaping () -> Void,
        onRemoveImage: (() -> Void)? = nil,
        onImageDropped: ((PlatformImage) -> Void)? = nil
    ) {
        self.headerText = headerText
        self.selectedImage = selectedImage
        self.colorPalette = colorPalette
        self.buttonLabel = buttonLabel
        self.changeLabel = changeLabel
        self.removeLabel = removeLabel
        self.isDisabled = isDisabled
        self.onSelectImage = onSelectImage
        self.onRemoveImage = onRemoveImage
        self.onImageDropped = onImageDropped
    }

    var body: some View {
        Section(header: Text(headerText)) {
            ZStack {
                SmoothAnimatedGradientView(colors: colorPalette.compactMap { hex in
                    Color(getUniversalColorFromHex(hexString: hex))
                })

                if let image = selectedImage {
                    #if os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(maxHeight: 400)
                        .shadow(color: .black.opacity(0.4), radius: 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                    #else
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.vertical, 6)
                    #endif
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "wand.and.sparkles")
                            .font(.largeTitle)
                            .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                        Text(isDropTargeted ? "Drop to use" : "Select\nReference\nImage")
                            .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isDropTargeted ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isDropTargeted ? Color.accentColor : Color.secondary,
                                style: isDropTargeted
                                    ? StrokeStyle(lineWidth: 2)
                                    : StrokeStyle(lineWidth: 1, dash: [5])
                            )
                    )
                    .onTapGesture {
                        if !isDisabled {
                            onSelectImage()
                        }
                    }
                    .opacity(isDisabled ? 0.5 : 1.0)
                }
            }
            .imageDropTarget(isTargeted: $isDropTargeted) { image in
                if !isDisabled {
                    onImageDropped?(image)
                }
            }

            HStack(spacing: 24) {
                Spacer()
                Button(selectedImage != nil ? changeLabel : buttonLabel) {
                    onSelectImage()
                }
                .disabled(isDisabled)
                if let onRemove = onRemoveImage, selectedImage != nil {
                    Button(removeLabel, role: .destructive) {
                        onRemove()
                    }
                }
                Spacer()
            }

            Text(
                "The selected image will be used as the starting frame for video generation. For best results, use a high-quality image with clear composition."
            )
            .multilineTextAlignment(.leading)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Keyboard Done Toolbar

extension View {
    func keyboardDoneToolbar(onDone: @escaping () -> Void) -> some View {
        #if os(macOS)
        return self
        #else
        return self
        #endif
    }
}

// MARK: - Prompt Text Field Modifier

extension View {
    func promptFieldStyle(text: Binding<String>, maxLength: Int, lineRange: ClosedRange<Int> = 2 ... 8) -> some View {
        limitText(text, to: maxLength)
            .lineLimit(lineRange)
    }
}

// MARK: - Image With Mask Section

/// A reusable section for displaying an image with mask drawing overlay.
struct PrimaryReferenceImageWithMaskSection: View {
    let selectedImage: UniversalImage?
    let colorPalette: [String]
    let description: String
    @Binding var maskPath: Path
    @Binding var canvasSize: CGSize
    let onSelectImage: () -> Void
    let onClearMask: (() -> Void)?
    var onRemoveImage: (() -> Void)?

    var body: some View {
        Section(header: Text("Primary Reference Image")) {
            ZStack {
                SmoothAnimatedGradientView(colors: colorPalette.compactMap { hex in
                    Color(getUniversalColorFromHex(hexString: hex))
                })

                if let image = selectedImage {
                    #if os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(maxHeight: 400)
                        .overlay(
                            GeometryReader { geometry in
                                MaskDrawingView(
                                    path: $maskPath,
                                    size: geometry.size
                                )
                                .onAppear {
                                    DispatchQueue.main.async {
                                        canvasSize = geometry.size
                                    }
                                }
                                .onChange(of: geometry.size) {
                                    DispatchQueue.main.async {
                                        canvasSize = geometry.size
                                    }
                                }
                            }
                        )
                        .shadow(color: .black.opacity(0.4), radius: 8)
                        .frame(maxWidth: .infinity)
                    #else
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            GeometryReader { geometry in
                                MaskDrawingView(
                                    path: $maskPath,
                                    size: geometry.size
                                )
                                .onAppear {
                                    DispatchQueue.main.async {
                                        canvasSize = geometry.size
                                    }
                                }
                                .onChange(of: geometry.size) {
                                    DispatchQueue.main.async {
                                        canvasSize = geometry.size
                                    }
                                }
                            }
                        )
                    #endif
                } else {
                    Image("placeholder_select_image")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(height: 180)
                        .onTapGesture {
                            DispatchQueue.main.async {
                                onSelectImage()
                            }
                        }
                }
            }

            HStack(spacing: 24) {
                Spacer()
                Button(selectedImage != nil ? "Change Image" : "Select Image") {
                    DispatchQueue.main.async {
                        onSelectImage()
                    }
                }
                if let onRemove = onRemoveImage, selectedImage != nil {
                    Button(role: .destructive) {
                        DispatchQueue.main.async {
                            onRemove()
                        }
                    } label: {
                        Label("Remove Image", systemImage: "xmark.circle")
                    }
                }
                if selectedImage != nil, !maskPath.isEmpty, let onClearMask {
                    Button(role: .destructive) {
                        DispatchQueue.main.async {
                            onClearMask()
                        }
                    } label: {
                        Label("Clear Mask", systemImage: "eraser")
                    }
                }
                Spacer()
            }

            Text(description)
                .multilineTextAlignment(.leading)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Submit Generation Button

/// A reusable button for submitting image/video generation requests.
struct SubmitGenerationButton: View {
    let title: String
    let isDisabled: Bool
    let onSubmit: () -> Void

    var body: some View {
        Section {
            Button(title) {
                onSubmit()
            }
            .disabled(isDisabled)
            .accessibilityLabel(title)
            .accessibilityHint(isDisabled ? "Currently unavailable" : "Generates output using the current settings")
        }
    }
}

// MARK: - Focused Prompt Section

/// A prompt section with focus state support for keyboard dismissal.
struct FocusedPromptSection<F: Hashable>: View {
    let model: ProviderModel?
    let headerText: String
    let promptPlaceholder: String
    let searchPromptPlaceholder: String
    let negativePlaceholder: String

    @Binding var prompt: String
    @Binding var searchPrompt: String
    @Binding var negativePrompt: String

    var focusedField: FocusState<F?>.Binding
    let promptFieldValue: F
    let searchFieldValue: F
    let negativeFieldValue: F

    @State private var activeSheet: FocusedPromptSheet?

    var body: some View {
        Group {
            if model?.modelParams.supportsPrompt ?? true {
                Section(header: Text(headerText)) {
                    TextAreaField(
                        label: "Prompt",
                        text: $prompt,
                        placeholder: promptPlaceholder
                    )
                    .limitText($prompt, to: model?.modelParams.maxPromptLength ?? 1)
                    .focused(focusedField, equals: promptFieldValue)

                    if model?.modelParams.supportsSearchPrompt ?? false {
                        TextAreaField(
                            label: "Search Prompt",
                            text: $searchPrompt,
                            placeholder: searchPromptPlaceholder
                        )
                        .limitText($searchPrompt, to: model?.modelParams.maxPromptLength ?? 256)
                        .focused(focusedField, equals: searchFieldValue)
                    }

                    if model?.modelParams.supportsNegativePrompt ?? false {
                        NegativePromptField(
                            text: $negativePrompt,
                            maxLength: model?.modelParams.maxPromptLength ?? 1,
                            placeholder: negativePlaceholder
                        )
                        .focused(focusedField, equals: negativeFieldValue)
                    }

                    Text(
                        "Be descriptive and specific about what you want to create as more details will help generate better results. Include details about style, lighting, colors, and composition." +
                            (
                                model?.modelParams
                                    .supportsNegativePrompt ?? false ?
                                    " You can also add a negative prompt to exclude certain elements or concepts." : ""
                            )
                    )
                    .multilineTextAlignment(.leading)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    Button {
                        focusedField.wrappedValue = nil
                        activeSheet = .promptGallery
                    } label: {
                        Label("Pick from Prompt Gallery", systemImage: "text.book.closed")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .promptGallery:
                PromptGalleryPickerView { selectedPrompt in
                    prompt = selectedPrompt
                }
            }
        }
    }
}

private enum FocusedPromptSheet: Identifiable {
    case promptGallery

    var id: String {
        switch self {
        case .promptGallery:
            "prompt-gallery"
        }
    }
}

// MARK: - Video Parameters Section

/// A reusable section that displays video parameters based on model capabilities.
struct VideoParametersSection: View {
    let model: ProviderModel?

    @Binding var dimensions: String
    @Binding var selectedResolution: String
    @Binding var selectedFPS: Int
    @Binding var durationSeconds: Int
    @Binding var generateAudio: Bool
    @Binding var motion: Double
    @Binding var stickyness: Double
    @Binding var quality: String
    @Binding var variant: String
    @Binding var style: String
    @Binding var inputFidelity: String
    @Binding var moderation: String
    @Binding var guidanceValue: Double
    @Binding var safetyValue: Double
    @Binding var seedValue: String
    @Binding var modelPromptEnhance: Bool

    var onDimensionChange: (() -> Void)?

    var body: some View {
        if hasAnyParameters {
            Section(header: Text("Video Settings")) {
                if hasDimensions {
                    if hasAspectRatioDimensions {
                        AspectRatioPicker(
                            label: "Aspect Ratio",
                            selection: $dimensions,
                            dimensions: model?.modelParams.effectiveDimensions ?? [],
                            onChange: onDimensionChange
                        )
                    } else {
                        DimensionPicker(
                            label: "Dimensions",
                            selection: $dimensions,
                            dimensions: model?.modelParams.effectiveDimensions ?? [],
                            onChange: onDimensionChange
                        )
                    }
                }

                if hasResolutions {
                    ResolutionPicker(
                        selection: $selectedResolution,
                        resolutions: model?.modelParams.supportedVideoResolutions ?? []
                    )
                }

                if hasFPS {
                    FrameRatePicker(
                        selection: $selectedFPS,
                        frameRates: model?.modelParams.supportedVideoFPS ?? []
                    )
                }

                if (model?.modelParams.supportedVideoDurations ?? []).count > 1 {
                    DurationPicker(
                        label: "Duration",
                        selection: $durationSeconds,
                        durations: model?.modelParams.supportedVideoDurations ?? []
                    )
                }

                if supportsAudio {
                    Toggle("Generate Audio", isOn: $generateAudio)
                }

                if let motionRange = model?.modelParams.supportedMotionRange {
                    MotionSlider(
                        value: $motion,
                        range: (motionRange.min, motionRange.max)
                    )
                }

                if let stickynessRange = model?.modelParams.supportedStickynessRange {
                    StickynessSlider(
                        value: $stickyness,
                        range: (stickynessRange.min, stickynessRange.max)
                    )
                }

                if model?.modelParams.supportsQualities == true {
                    QualityPicker(
                        selection: $quality,
                        qualities: model?.modelParams.supportedImageQualities ?? []
                    )
                }

                if model?.modelParams.supportsVariants ?? false {
                    VariantPicker(
                        selection: $variant,
                        variants: model?.modelParams.supportedVariants ?? []
                    )
                }

                if model?.modelParams.supportsStyles ?? false {
                    StylePicker(
                        selection: $style,
                        styles: model?.modelParams.supportedStyles ?? []
                    )
                }

                if model?.modelParams.supportsInputFidelity == true {
                    InputFidelityPicker(
                        selection: $inputFidelity,
                        fidelities: model?.modelParams.supportedInputFidelities ?? []
                    )
                }

                if model?.modelParams.supportsModeration == true {
                    ModerationPicker(
                        selection: $moderation,
                        moderations: model?.modelParams.supportedModerations ?? []
                    )
                }

                if let guidanceRange = model?.modelParams.supportedGuidanceRange {
                    GuidanceSlider(value: $guidanceValue, range: (guidanceRange.min, guidanceRange.max))
                }

                if let safetyRange = model?.modelParams.supportedSafetyRange {
                    SafetySlider(value: $safetyValue, range: (safetyRange.min, safetyRange.max))
                }

                if model?.modelParams.supportsSeed == true {
                    SeedField(value: $seedValue)
                }

                if model?.modelParams.supportsPromptEnhance == true {
                    PromptEnhanceToggle(isOn: $modelPromptEnhance)
                }

                Text(
                    "The above setting parameters are recommended by the provider for optimal usage of the model. Feel free to modify the parameters based on your requirements to generate the desired output."
                )
                .multilineTextAlignment(.leading)
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Computed Properties

    private var hasAnyParameters: Bool {
        hasDimensions || hasResolutions || hasFPS || supportsAudio || supportsMotion || supportsStickyness ||
            hasQualityVariantStyle || supportsInputFidelity || supportsModeration || supportsGuidance ||
            supportsSafety ||
            supportsSeed || supportsPromptEnhance
    }

    private var hasDimensions: Bool {
        !(model?.modelParams.effectiveDimensions ?? []).isEmpty
    }

    private var hasAspectRatioDimensions: Bool {
        (model?.modelParams.effectiveDimensions ?? []).contains { $0.contains(":") }
    }

    private var hasResolutions: Bool {
        !(model?.modelParams.supportedVideoResolutions ?? []).isEmpty
    }

    private var hasFPS: Bool {
        !(model?.modelParams.supportedVideoFPS ?? []).isEmpty
    }

    private var supportsAudio: Bool {
        model?.modelParams.supportsAudio ?? false
    }

    private var supportsMotion: Bool {
        model?.modelParams.supportsMotion ?? false
    }

    private var supportsStickyness: Bool {
        model?.modelParams.supportsStickyness ?? false
    }

    private var hasQualityVariantStyle: Bool {
        guard let params = model?.modelParams else { return false }
        return params.supportsQualities || params.supportsVariants || params.supportsStyles
    }

    private var supportsInputFidelity: Bool {
        model?.modelParams.supportsInputFidelity ?? false
    }

    private var supportsModeration: Bool {
        model?.modelParams.supportsModeration ?? false
    }

    private var supportsGuidance: Bool {
        model?.modelParams.supportsGuidanceRange ?? false
    }

    private var supportsSafety: Bool {
        model?.modelParams.supportsSafetyRange ?? false
    }

    private var supportsSeed: Bool {
        model?.modelParams.supportsSeed ?? false
    }

    private var supportsPromptEnhance: Bool {
        model?.modelParams.supportsPromptEnhance ?? false
    }
}

// MARK: - Video Source Section

/// A reusable section for selecting and displaying a video source with thumbnail preview.
struct VideoSourceSection: View {
    let headerText: String
    let selectedVideoURL: URL?
    let isProcessing: Bool
    let hasVideo: Bool
    let onSelectVideo: () -> Void
    let onRemoveVideo: () -> Void

    var body: some View {
        Section(header: Text(headerText)) {
            if isProcessing {
                HStack(spacing: 8) {
                    Spacer()
                    GradientSpinner()
                    Text("Processing video...")
                    Spacer()
                }
            } else if let videoURL = selectedVideoURL {
                #if os(macOS)
                SafeVideoPlayerView(url: videoURL)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.3), radius: 6)
                    .padding(.vertical, 6)
                #else
                SafeVideoPlayerView(url: videoURL)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.vertical, 6)
                #endif
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Select a video")
                        .foregroundStyle(.secondary)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .onTapGesture { onSelectVideo() }
            }

            HStack(spacing: 24) {
                Spacer()
                Button(hasVideo ? "Change Video" : "Select Video") {
                    onSelectVideo()
                }
                if hasVideo {
                    Button(role: .destructive) {
                        onRemoveVideo()
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                Spacer()
            }

            Text(
                "The selected video will be used as the source for editing or extending. Ensure the video format is compatible with the selected model."
            )
            .multilineTextAlignment(.leading)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Additional Reference Images Section

/// A reusable section for uploading and managing reference images with selectable types.
struct AdditionalReferenceImagesSection: View {
    let referenceImages: [ReferenceImage]
    let maxReferenceImages: Int
    let supportedReferenceTypes: [String]
    let onAddImage: () -> Void
    let onRemoveImage: (UUID) -> Void
    let onUpdateType: (UUID, String) -> Void
    var onImageDropped: ((PlatformImage) -> Void)?

    @State private var isDropTargeted = false

    private var canAddMore: Bool {
        referenceImages.count < maxReferenceImages
    }

    #if os(macOS)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]
    #else
    private let columns = [GridItem(.flexible(), spacing: 12)]
    #endif

    var body: some View {
        Section(header: Text("Additional Reference Images (Optional)")) {
            if referenceImages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                    VStack(spacing: 4) {
                        Text(isDropTargeted ? "Drop to use" : "Add reference images to guide generation")
                            .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                            .multilineTextAlignment(.center)
                        if !isDropTargeted {
                            Text("Up to \(maxReferenceImages) images")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.2) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isDropTargeted ? Color.accentColor : Color.clear,
                            style: StrokeStyle(lineWidth: 2)
                        )
                )
                .onTapGesture { onAddImage() }
                .imageDropTarget(isTargeted: $isDropTargeted) { image in
                    onImageDropped?(image)
                }
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(referenceImages) { refImage in
                        ReferenceImageCard(
                            referenceImage: refImage,
                            supportedTypes: supportedReferenceTypes,
                            onRemove: { onRemoveImage(refImage.id) },
                            onUpdateType: { newType in onUpdateType(refImage.id, newType) }
                        )
                    }

                    if canAddMore {
                        AddReferenceImageCard(
                            hasTypePicker: !supportedReferenceTypes.isEmpty,
                            onAdd: onAddImage,
                            onImageDropped: onImageDropped
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            if referenceImages.isEmpty {
                HStack(spacing: 24) {
                    Spacer()
                    Button {
                        onAddImage()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Reference Image")
                        }
                    }
                    Spacer()
                }
            }

            if !referenceImages.isEmpty {
                Text("\(referenceImages.count) of \(maxReferenceImages) reference images")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Text(
                "Reference images help guide the style, composition, or content of the generation. The model will use these as visual context to influence the output."
            )
            .multilineTextAlignment(.leading)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}

/// A card displaying a single reference image with type selection and remove button overlay.
struct ReferenceImageCard: View {
    let referenceImage: ReferenceImage
    let supportedTypes: [String]
    let onRemove: () -> Void
    let onUpdateType: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                #if os(macOS)
                Image(nsImage: referenceImage.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                #else
                Image(uiImage: referenceImage.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                #endif

                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .red.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel("Remove reference image")
                .accessibilityHint("Removes this image from the reference set")
            }
            .frame(height: 160)

            if !supportedTypes.isEmpty {
                Picker("Type", selection: Binding(
                    get: { referenceImage.referenceType },
                    set: { onUpdateType($0) }
                )) {
                    ForEach(supportedTypes, id: \.self) { type in
                        Text(type.capitalized).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }
}

/// A card for adding a new reference image.
struct AddReferenceImageCard: View {
    let hasTypePicker: Bool
    let onAdd: () -> Void
    var onImageDropped: ((PlatformImage) -> Void)?

    @State private var isDropTargeted = false

    var body: some View {
        Button {
            onAdd()
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        style: isDropTargeted
                            ? StrokeStyle(lineWidth: 2)
                            : StrokeStyle(lineWidth: 2, dash: [6])
                    )
                    .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)
                    .frame(height: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isDropTargeted ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "plus")
                                .font(.title2)
                            Text(isDropTargeted ? "Drop" : "Add")
                                .font(.caption)
                        }
                        .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                    }
                    .contentShape(Rectangle())

                if hasTypePicker {
                    Text(" ")
                        .font(.subheadline)
                        .frame(height: 28)
                }
            }
        }
        .buttonStyle(.plain)
        .imageDropTarget(isTargeted: $isDropTargeted) { image in
            onImageDropped?(image)
        }
    }
}
