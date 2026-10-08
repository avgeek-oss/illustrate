// MARK: - ModelParametersSection.swift

// Dynamic form section for model-specific parameters.
//
// Renders only the parameters supported by the selected model:
// - Dimensions/aspect ratio
// - Quality tier
// - Style preset
// - Inference steps
// - Guidance scale
// - Seed
// - Safety tolerance
// - And more...
//
// ## Dynamic Rendering
// Uses model.modelParams to determine which controls to show.
// Empty section hidden when model has no configurable params.

import IllustrateProviders
import SwiftUI

// MARK: - Model Parameters Section

/// Dynamic section showing model-specific parameters.
struct ModelParametersSection: View {
    let model: ProviderModel?

    @Binding var dimensions: String
    @Binding var quality: String
    @Binding var variant: String
    @Binding var style: String
    @Binding var inputFidelity: String
    @Binding var moderation: String
    @Binding var selectedResolution: String
    @Binding var stepsValue: Double
    @Binding var guidanceValue: Double
    @Binding var seedValue: String
    @Binding var safetyValue: Double
    @Binding var growMaskValue: Double
    @Binding var modelPromptEnhance: Bool
    @Binding var personGeneration: String

    var onDimensionChange: (() -> Void)?

    var body: some View {
        if hasAnyParameters {
            Section(header: Text("Model Parameters")) {
                DimensionPicker(
                    label: "Dimensions",
                    selection: $dimensions,
                    dimensions: model?.modelParams.effectiveDimensions ?? [],
                    onChange: onDimensionChange
                )

                if model?.modelParams.supportsQualities == true {
                    QualityPicker(
                        selection: $quality,
                        qualities: model?.modelParams.supportedImageQualities ?? []
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

                if model?.modelParams.supportsImageResolution == true {
                    ResolutionPicker(
                        selection: $selectedResolution,
                        resolutions: model?.modelParams.supportedImageResolutions ?? []
                    )
                }

                if let stepsRange = model?.modelParams.supportedStepsRange {
                    StepsSlider(value: $stepsValue, range: (stepsRange.min, stepsRange.max))
                }

                if let guidanceRange = model?.modelParams.supportedGuidanceRange {
                    GuidanceSlider(value: $guidanceValue, range: (guidanceRange.min, guidanceRange.max))
                }

                if let safetyRange = model?.modelParams.supportedSafetyRange {
                    SafetySlider(value: $safetyValue, range: (safetyRange.min, safetyRange.max))
                }

                if let growMaskRange = model?.modelParams.supportedGrowMaskRange {
                    GrowMaskSlider(value: $growMaskValue, range: (growMaskRange.min, growMaskRange.max))
                }

                if model?.modelParams.supportsSeed == true {
                    SeedField(value: $seedValue)
                }

                if model?.modelParams.supportsPromptEnhance == true {
                    PromptEnhanceToggle(isOn: $modelPromptEnhance)
                }

                if model?.modelParams.supportsPersonGeneration == true {
                    PersonGenerationPicker(
                        selection: $personGeneration,
                        options: model?.modelParams.supportedPersonGenerationOptions ?? []
                    )
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

    private var hasAnyParameters: Bool {
        guard let params = model?.modelParams else { return false }

        return !params.effectiveDimensions.isEmpty ||
            params.supportsQualities ||
            params.supportsInputFidelity ||
            params.supportsModeration ||
            params.supportsVariants ||
            params.supportsStyles ||
            params.supportsImageResolution ||
            params.supportedStepsRange != nil ||
            params.supportedGuidanceRange != nil ||
            params.supportedSafetyRange != nil ||
            params.supportedGrowMaskRange != nil ||
            params.supportsSeed ||
            params.supportsPromptEnhance ||
            params.supportsPersonGeneration
    }
}

// MARK: - Available Tools Section

struct AvailableToolsSection: View {
    let model: ProviderModel?
    @Binding var selectedTools: Set<String>

    var body: some View {
        if model?.modelParams.supportsTools == true {
            Section(header: Text("Available Tools")) {
                ToolsPicker(
                    selection: $selectedTools,
                    tools: model?.modelParams.supportedTools ?? []
                )
                Text(
                    "Usage of tools may incur additional costs. The total cost estimation shown in metrics will not include the usage cost of tools. You might need to refer to the provider's pricing page for more information."
                )
                .multilineTextAlignment(.leading)
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Number of Generations Section

/// A reusable section for selecting the number of images/videos to generate.
struct NumberOfGenerationsSection: View {
    let model: ProviderModel?
    @Binding var numberOfItems: Int
    var label = "Number of images"

    var body: some View {
        if let maxGenerations = model?.modelParams.maxGenerations, maxGenerations > 1 {
            Section {
                Picker(label, selection: $numberOfItems) {
                    ForEach(1 ... maxGenerations, id: \.self) { count in
                        Text("\(count)")
                            .tag(count)
                    }
                }
                #if !os(macOS)
                .pickerStyle(.navigationLink)
                #endif
                Text(
                    "If the selected model supports multiple generations with a single request, it will be preferred. In absence of this feature, parallel generation calls will be performed. You may use the seed value to control the similarity of the images."
                )
                .multilineTextAlignment(.leading)
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Estimated Cost Section

/// A reusable section for displaying estimated cost and balance.
struct EstimatedCostSection: View {
    let cost: String
    var estimatedCostValue: Double = 0
    var balance: Double?
    var creditCurrency: EnumProviderCreditCurrency = .USD

    var body: some View {
        Section {
            EstimatedCostRow(cost: cost)
            if balance != nil {
                BalanceRow(
                    balance: balance,
                    estimatedCost: estimatedCostValue,
                    creditCurrency: creditCurrency
                )
            }
            Text(
                "The estimates shown may fluctuate from the actual cost due to additional factors including but not limited to token usage, tool usage, etc. Refer to the model provider's billing for accurate information."
            )
            .multilineTextAlignment(.leading)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}
