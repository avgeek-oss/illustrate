// MARK: - RealtimeEditPromptBar.swift

// Bottom prompt bar for Realtime Edit canvas.

import IllustrateProviders
import SwiftData
import SwiftUI

enum RealtimeEditModelSupport {
    private static let seedlessRealtimeModelCodes: Set<EnumProviderModelCode> = [
        .GOOGLE_GEMINI_31_FLASH_LITE_IMAGE,
    ]

    static func supportsRealtimeEdit(_ model: ProviderModel) -> Bool {
        model.active &&
            model.modelSetType == .IMAGE_GENERATE &&
            supportsCanvasInput(model) &&
            (model.modelParams.supportsSeed || seedlessRealtimeModelCodes.contains(model.modelCode))
    }

    static func showsSeedControl(for model: ProviderModel?) -> Bool {
        model?.modelParams.supportsSeed == true
    }

    private static func supportsCanvasInput(_ model: ProviderModel) -> Bool {
        model.modelParams.supportsSourceImage || model.modelParams.supportsReferenceImages
    }
}

struct RealtimeEditPromptBar: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var session: RealtimeEditSession
    let providerKeys: [ProviderKey]
    let layers: [RealtimeEditLayer]
    @Binding var selectedTool: EditTool
    @Binding var showCanvas: Bool
    @Binding var showLayersPopover: Bool
    @Binding var selectedLayerIds: Set<UUID>
    @Binding var previewRefreshTrigger: UUID
    @Binding var showImagePicker: Bool
    let onLayerUpdate: (RealtimeEditLayer) -> Void
    let onLayerDelete: (UUID) -> Void
    let onLayerReorder: ([RealtimeEditLayer]) -> Void
    let onClearAllLayers: () -> Void
    var onBrushSettingsChanged: (() -> Void)?

    @State private var showBrushPopover = false
    @State private var showShapePopover = false

    // Confirmation dialog state for provider/model/dimension changes
    @State private var showProviderChangeConfirmation = false
    @State private var showModelChangeConfirmation = false
    @State private var showDimensionChangeConfirmation = false
    @State private var pendingProviderId: String?
    @State private var pendingModelId: String?
    @State private var pendingDimensions: String?

    private var hasModelSelected: Bool {
        !session.selectedModelId.isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            // Row 1: Canvas tools
            HStack(spacing: 8) {
                Button {
                    showLayersPopover.toggle()
                } label: {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 16))
                        .frame(width: 36, height: 36)
                        .background(secondarySystemFill)
                        .foregroundStyle(hasModelSelected ? .primary : .secondary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!hasModelSelected)
                .accessibilityLabel("Layers")
                .accessibilityHint("Manage canvas layers")
                .popover(isPresented: $showLayersPopover, arrowEdge: .top) {
                    LayersPanelView(
                        layers: layers,
                        selectedLayerIds: $selectedLayerIds,
                        onLayerUpdate: onLayerUpdate,
                        onLayerDelete: onLayerDelete,
                        onLayerReorder: onLayerReorder,
                        onRefreshPreview: {
                            previewRefreshTrigger = UUID()
                        }
                    )
                    .frame(
                        minWidth: 250,
                        idealWidth: 280,
                        maxWidth: 320,
                        minHeight: 300,
                        idealHeight: 400,
                        maxHeight: 600
                    )
                }

                // Separator
                Divider()
                    .frame(height: 24)

                // Editing tools
                ForEach(EditTool.allCases, id: \.self) { tool in
                    if tool == .brush {
                        // Brush button with two-click behavior
                        brushToolButton
                    } else if tool == .shape {
                        // Shape button with two-click behavior
                        shapeToolButton
                    } else {
                        Button {
                            switch tool {
                            case .select:
                                selectedTool = tool
                            case .attach:
                                showImagePicker = true
                            case .shape, .brush:
                                break // Handled by separate buttons
                            }
                        } label: {
                            toolButtonLabel(for: tool)
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasModelSelected)
                        .accessibilityLabel(tool.label)
                        .accessibilityHint(tool.description)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)

            Divider()

            // Row 2: Prompt input
            promptTextField
                .padding(.horizontal, 16)

            // Row 3: Model selection + dimensions + seed + speed + cost
            HStack(spacing: 12) {
                providerPicker
                modelPicker
                if hasModelSelected {
                    dimensionsPicker
                    if RealtimeEditModelSupport.showsSeedControl(for: selectedModel) {
                        seedInput
                    }
                    speedPicker
                }
                Spacer()
                if hasModelSelected {
                    estimatedCostView
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .onAppear {
            // Load selected tool from session
            if let tool = EditTool(rawValue: session.selectedToolRawValue) {
                selectedTool = tool
            }
        }
        .onChange(of: hasModelSelected) { _, newValue in
            showCanvas = newValue
        }
        .onChange(of: session.selectedProviderId) { oldProviderId, newProviderId in
            // When provider changes, reset model selection
            // Note: Layer clearing is handled via confirmation dialog in providerPicker
            if oldProviderId != newProviderId, !newProviderId.isEmpty {
                session.selectedModelId = ""

                // Reset dimensions to default
                session.selectedDimensions = "1024x1024"
            }
        }
        .onChange(of: session.selectedModelId) { _, newModelId in
            // Note: Layer clearing is handled via confirmation dialog in modelPicker
            if !newModelId.isEmpty {
                validateDimensions()
            }
        }
        .onChange(of: selectedTool) {
            session.selectedToolRawValue = selectedTool.rawValue
        }
        .alert("Change Model?", isPresented: $showModelChangeConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingModelId = nil
            }
            Button("Change", role: .destructive) {
                if let newModelId = pendingModelId {
                    onClearAllLayers()
                    session.selectedModelId = newModelId
                }
                pendingModelId = nil
            }
        } message: {
            Text("Changing the model will remove all current layers. This action cannot be undone.")
        }
        .alert("Change Dimensions?", isPresented: $showDimensionChangeConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingDimensions = nil
            }
            Button("Change", role: .destructive) {
                if let newDimensions = pendingDimensions {
                    onClearAllLayers()
                    session.selectedDimensions = newDimensions
                }
                pendingDimensions = nil
            }
        } message: {
            Text("Changing dimensions will remove all current layers. This action cannot be undone.")
        }
        .alert("Change Provider?", isPresented: $showProviderChangeConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingProviderId = nil
            }
            Button("Change", role: .destructive) {
                if let newProviderId = pendingProviderId {
                    onClearAllLayers()
                    session.selectedProviderId = newProviderId
                }
                pendingProviderId = nil
            }
        } message: {
            Text("Changing the provider will remove all current layers. This action cannot be undone.")
        }
    }

    // MARK: - Tool Buttons

    private func toolButtonLabel(for tool: EditTool) -> some View {
        let foregroundColor: Color = if !hasModelSelected {
            .secondary
        } else if isToolSelected(tool) {
            .white
        } else {
            .primary
        }

        return Image(systemName: tool.icon)
            .font(.system(size: 16))
            .frame(width: 36, height: 36)
            .background(isToolSelected(tool) ? Color.accentColor : secondarySystemFill)
            .foregroundStyle(foregroundColor)
            .cornerRadius(8)
    }

    private var brushToolButton: some View {
        Button {
            if selectedTool == .brush {
                // Already selected: toggle popover
                showBrushPopover.toggle()
            } else {
                // First click: select brush tool, deselect layers, and show popover
                selectedLayerIds.removeAll()
                selectedTool = .brush
                showBrushPopover = true
            }
        } label: {
            toolButtonLabel(for: .brush)
        }
        .buttonStyle(.plain)
        .disabled(!hasModelSelected)
        .accessibilityLabel(EditTool.brush.label)
        .accessibilityHint(EditTool.brush.description)
        .popover(isPresented: $showBrushPopover, arrowEdge: .top) {
            BrushSettingsPopover(
                brushColor: Binding(
                    get: { colorFromHex(session.brushColorHex) },
                    set: { session.brushColorHex = hexFromColor($0) }
                ),
                brushSize: Binding(
                    get: { session.brushSize },
                    set: { session.brushSize = $0 }
                )
            )
        }
    }

    private var shapeToolButton: some View {
        Button {
            if selectedTool == .shape {
                // Already selected: toggle popover
                showShapePopover.toggle()
            } else {
                // First click: select shape tool, deselect layers, and show popover
                selectedLayerIds.removeAll()
                selectedTool = .shape
                showShapePopover = true
            }
        } label: {
            toolButtonLabel(for: .shape)
        }
        .buttonStyle(.plain)
        .disabled(!hasModelSelected)
        .accessibilityLabel(EditTool.shape.label)
        .accessibilityHint(EditTool.shape.description)
        .disabled(!hasModelSelected)
        .popover(isPresented: $showShapePopover, arrowEdge: .top) {
            ShapeSettingsPopover(
                shapeColor: Binding(
                    get: { colorFromHex(session.shapeColorHex) },
                    set: { session.shapeColorHex = hexFromColor($0) }
                ),
                selectedShapeType: Binding(
                    get: { ShapeType(rawValue: session.selectedShapeTypeRawValue) ?? .square },
                    set: { session.selectedShapeTypeRawValue = $0.rawValue }
                )
            )
        }
    }

    // MARK: - Helpers

    private func isToolSelected(_ tool: EditTool) -> Bool {
        // Only select, brush, and shape tools show as selected
        // attach is a temporary action
        guard tool == .select || tool == .brush || tool == .shape else {
            return false
        }
        return selectedTool == tool
    }

    // MARK: - Components

    private var promptTextField: some View {
        TextField("Enter your prompt...", text: Binding(
            get: { session.configuration.prompt },
            set: { newValue in
                var config = session.configuration
                config.prompt = newValue
                session.configuration = config
            }
        ), axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1 ... 3)
            .padding(12)
            .frame(minHeight: 44)
            .background(secondarySystemFill)
            .cornerRadius(12)
    }

    private var providerPicker: some View {
        Menu {
            ForEach(supportedProviders, id: \.providerId) { provider in
                Button(provider.providerName) {
                    let newProviderId = provider.providerId.uuidString
                    // Only show confirmation if there are layers and switching to a different provider
                    if !layers.isEmpty, !session.selectedProviderId.isEmpty,
                       session.selectedProviderId != newProviderId
                    {
                        pendingProviderId = newProviderId
                        showProviderChangeConfirmation = true
                    } else {
                        session.selectedProviderId = newProviderId
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if !session.selectedProviderId.isEmpty,
                   let provider = UUID(uuidString: session.selectedProviderId).flatMap({ providersById[$0] })
                {
                    Image(providerArtworkName(code: provider.providerCode, variant: .square))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                    Text(provider.providerName)
                        .font(.callout)
                        .lineLimit(1)
                } else {
                    Text("Provider")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(secondarySystemFill)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var modelPicker: some View {
        Menu {
            ForEach(supportedModels, id: \.modelId) { model in
                Button(model.modelName) {
                    let newModelId = model.modelId.uuidString
                    // Only show confirmation if there are layers and switching to a different model
                    if !layers.isEmpty, !session.selectedModelId.isEmpty,
                       session.selectedModelId != newModelId
                    {
                        pendingModelId = newModelId
                        showModelChangeConfirmation = true
                    } else {
                        session.selectedModelId = newModelId
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let model = supportedModels.first(where: { $0.modelId.uuidString == session.selectedModelId }) {
                    Text(model.modelName)
                        .font(.callout)
                        .lineLimit(1)
                } else {
                    Text("Model")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(secondarySystemFill)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(session.selectedProviderId.isEmpty)
    }

    private var dimensionsPicker: some View {
        Menu {
            ForEach(availableDimensions, id: \.self) { dimension in
                Button(formatDimensionWithAspectRatio(dimension)) {
                    // Only show confirmation if there are layers and changing dimensions
                    if !layers.isEmpty, session.selectedDimensions != dimension {
                        pendingDimensions = dimension
                        showDimensionChangeConfirmation = true
                    } else {
                        session.selectedDimensions = dimension
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(formatDimensionWithAspectRatio(session.selectedDimensions))
                    .font(.callout)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(secondarySystemFill)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(session.selectedModelId.isEmpty)
    }

    private var seedInput: some View {
        HStack(spacing: 4) {
            TextField("", value: Binding(
                get: { session.seed },
                set: { session.seed = $0 }
            ), format: .number.grouping(.never))
                .font(.callout)
                .monospacedDigit()
                .textFieldStyle(.plain)
                .frame(width: 90, height: 20)

            Button {
                session.seed = Int.random(in: 0 ... 999_999_999)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(secondarySystemFill)
        .cornerRadius(8)
        .help("Same seed value helps the model maintain the output theme")
    }

    private var speedPicker: some View {
        Menu {
            ForEach(GenerationSpeed.allCases) { speed in
                Button(speed.label) {
                    session.generationSpeedMs = speed.intervalMs
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(GenerationSpeed.from(ms: session.generationSpeedMs).label)
                    .font(.callout)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(secondarySystemFill)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .help("Generation speed - higher speeds consume more credits")
    }

    private var estimatedCostView: some View {
        HStack(spacing: 4) {
            Text("\(estimatedCostPerTurn) / frame")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(secondarySystemFill)
        .cornerRadius(8)
        .help("Estimated cost per generation turn")
    }

    /// Calculates the estimated cost per turn based on selected model and dimensions.
    private var estimatedCostPerTurn: String {
        guard let model = selectedModel else {
            return "—"
        }
        return model.modelCode.formattedImageCost(
            dimensions: session.selectedDimensions,
            hasSourceImage: true
        )
    }

    // MARK: - Helpers

    private var selectedModel: ProviderModel? {
        supportedModels.first { $0.modelId.uuidString == session.selectedModelId }
    }

    private var supportedProviders: [Provider] {
        let providerService = ProviderService.shared
        return providers.filter { provider in
            providerKeys.contains { $0.providerId == provider.providerId } &&
                providerService.allModels.contains {
                    $0.providerId == provider.providerId &&
                        RealtimeEditModelSupport.supportsRealtimeEdit($0)
                }
        }
    }

    private var supportedModels: [ProviderModel] {
        guard !session.selectedProviderId.isEmpty else {
            return []
        }
        let providerService = ProviderService.shared
        let allModels = providerService.models(for: .IMAGE_GENERATE)
        return allModels.filter {
            $0.providerId.uuidString == session.selectedProviderId &&
                RealtimeEditModelSupport.supportsRealtimeEdit($0)
        }
    }

    private var availableDimensions: [String] {
        guard !session.selectedModelId.isEmpty,
              let model = supportedModels.first(where: { $0.modelId.uuidString == session.selectedModelId })
        else {
            return ["1024x1024"]
        }

        let dimensions = model.modelParams.effectiveDimensions
        let converted = dimensions.map { dimension in
            convertAspectRatioToDimension(dimension, baseSize: 1024)
        }

        return converted.isEmpty ? ["1024x1024"] : converted
    }

    private var originalDimensionsMap: [String: String] {
        guard !session.selectedModelId.isEmpty,
              let model = supportedModels.first(where: { $0.modelId.uuidString == session.selectedModelId })
        else {
            return [:]
        }

        var mapping: [String: String] = [:]
        let originalDimensions = model.modelParams.effectiveDimensions

        for original in originalDimensions {
            let converted = convertAspectRatioToDimension(original, baseSize: 1024)
            if original.contains(":") {
                mapping[converted] = original
            }
        }

        return mapping
    }

    /// Converts aspect ratio string to pixel dimensions using specified base size.
    ///
    /// - Parameters:
    ///   - aspectRatio: Aspect ratio string (e.g., "16:9", "1:1") or dimension string (e.g., "1024x1024")
    ///   - baseSize: Base size to use for conversion (default: 1024)
    /// - Returns: Dimension string (e.g., "1024x576")
    private func convertAspectRatioToDimension(_ aspectRatio: String, baseSize: Int = 1024) -> String {
        // If already in dimension format, return as-is
        if aspectRatio.contains("x") || aspectRatio.contains("X") {
            return aspectRatio
        }

        // Parse aspect ratio format (e.g., "16:9")
        if aspectRatio.contains(":") {
            let parts = aspectRatio.split(separator: ":")
            guard parts.count == 2,
                  let ratioWidth = Int(parts[0]),
                  let ratioHeight = Int(parts[1]),
                  ratioWidth > 0,
                  ratioHeight > 0
            else {
                return "\(baseSize)x\(baseSize)"
            }

            // Calculate dimensions based on aspect ratio
            // Use baseSize for the larger dimension
            if ratioWidth >= ratioHeight {
                // Landscape or square
                let width = baseSize
                let height = (baseSize * ratioHeight) / ratioWidth
                return "\(width)x\(height)"
            } else {
                // Portrait
                let height = baseSize
                let width = (baseSize * ratioWidth) / ratioHeight
                return "\(width)x\(height)"
            }
        }

        // Fallback to square
        return "\(baseSize)x\(baseSize)"
    }

    /// Validates current dimension selection and adjusts if not supported by current model.
    private func validateDimensions() {
        let available = availableDimensions
        if !available.contains(session.selectedDimensions), let firstDimension = available.first {
            session.selectedDimensions = firstDimension
        }
    }

    private func formatDimensionWithAspectRatio(_ dimension: String) -> String {
        if let originalRatio = originalDimensionsMap[dimension] {
            return "\(dimension) (\(originalRatio))"
        }

        let aspectRatio = calculateAspectRatio(dimension)
        if let ratio = aspectRatio, isStandardRatio(ratio) {
            return "\(dimension) (\(ratio))"
        }

        return dimension
    }

    private func calculateAspectRatio(_ dimension: String) -> String? {
        if dimension.contains(":") {
            return dimension
        }

        let parts = dimension.lowercased().split(separator: "x")
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1]),
              width > 0,
              height > 0
        else {
            return nil
        }

        let gcdValue = gcd(width, height)
        return "\(width / gcdValue):\(height / gcdValue)"
    }

    private func isStandardRatio(_ ratio: String) -> Bool {
        let parts = ratio.split(separator: ":")
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1])
        else {
            return false
        }

        return max(width, height) <= 21 && min(width, height) <= 16
    }

    private func gcd(_ a: Int, _ b: Int) -> Int {
        var a = a
        var b = b
        while b != 0 {
            let temp = b
            b = a % b
            a = temp
        }
        return a
    }
}
