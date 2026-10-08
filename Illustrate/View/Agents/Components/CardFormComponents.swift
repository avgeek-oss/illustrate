// MARK: - CardFormComponents.swift

// Form components optimized for agent card configuration.
//
// These components are designed for the compact card form layout:
// - SyntaxHighlightedTextEditor: Text editor with {{input}} highlighting
// - CardPromptSection: Prompt input with character count
// - CardParameterSlider: Compact slider for numeric params
// - CardModelPicker: Provider/model dropdown
// - CardDimensionPicker: Aspect ratio selector
// - CardToggle: Compact toggle for boolean params
//
// ## Syntax Highlighting
// The text editor highlights {{input}} template variables
// to help users see where previous card output will be inserted.
//
// ## Platform Differences
// - macOS: Native NSTextView for better performance
// - iOS: SwiftUI TextEditor fallback

import AvgeekLocalizationCore
import AvgeekLocalizationUI
import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Syntax Highlighted Text Editor

#if os(macOS)
/// Custom NSTextView subclass that properly handles first responder in popovers.
class FocusableTextView: NSTextView {
    override var acceptsFirstResponder: Bool {
        true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        // Ensure cursor is visible when becoming first responder
        if result {
            setSelectedRange(NSRange(location: string.count, length: 0))
        }
        return result
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // Force becoming first responder when clicked
        window?.makeFirstResponder(self)
    }
}

struct SyntaxHighlightedTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: 12)
    var minHeight: CGFloat = 60
    var maxHeight: CGFloat = 80

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = FocusableTextView()

        textView.isRichText = false
        textView.font = font
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller = nil
        scrollView.horizontalScroller = nil
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView: NSTextView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selectedRanges: [NSValue] = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        context.coordinator.applySyntaxHighlighting(to: textView)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxHighlightedTextEditor
        weak var textView: NSTextView?

        private let variablePattern = "\\{\\{[^}]+\\}\\}"

        init(_ parent: SyntaxHighlightedTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView: NSTextView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applySyntaxHighlighting(to: textView)
        }

        func applySyntaxHighlighting(to textView: NSTextView) {
            let text: String = textView.string
            let fullRange = NSRange(location: 0, length: text.utf16.count)

            let selectedRanges: [NSValue] = textView.selectedRanges

            textView.textStorage?.beginEditing()
            textView.textStorage?.setAttributes([
                .font: parent.font,
                .foregroundColor: NSColor.labelColor,
            ], range: fullRange)

            if let regex: NSRegularExpression = try? NSRegularExpression(pattern: variablePattern, options: []) {
                let matches: [NSTextCheckingResult] = regex.matches(in: text, options: [], range: fullRange)

                for match: NSTextCheckingResult in matches {
                    textView.textStorage?.addAttributes([
                        .foregroundColor: NSColor.controlAccentColor,
                        .font: NSFont.monospacedSystemFont(ofSize: parent.font.pointSize, weight: .medium),
                    ], range: match.range)
                }
            }

            textView.textStorage?.endEditing()

            textView.selectedRanges = selectedRanges
        }
    }
}
#endif

struct CardSectionLabel: View {
    let text: String
    var hint: String?
    @State private var isHovering = false
    @AppLocalized private var localize

    var body: some View {
        HStack(spacing: 4) {
            Text(localize(text))
                .font(.callout)
                .foregroundStyle(.secondary)

            if let hint: String, isHovering {
                Text(localize(hint))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

struct CardDropdownPicker<T: Hashable>: View {
    let label: String
    @Binding var selection: T
    let options: [T]
    let displayName: (T) -> String
    var iconName: ((T) -> String)?
    var placeholder = "Select"
    var emptyOption: T?
    var onChange: (() -> Void)?

    @AppLocalized private var localize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localize(label))
                .font(.callout)
                .foregroundStyle(.secondary)

            Menu {
                if let emptyOption: T {
                    Button(localize(placeholder)) {
                        selection = emptyOption
                        onChange?()
                    }
                }
                ForEach(options, id: \.self) { option in
                    Button(displayName(option)) {
                        selection = option
                        onChange?()
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if let iconName: (T) -> String, !isEmptySelection {
                        Image(iconName(selection))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    }
                    Text(isEmptySelection ? localize(placeholder) : displayName(selection))
                        .foregroundStyle(isEmptySelection ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(secondarySystemFill)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    private var isEmptySelection: Bool {
        if let emptyOption: T {
            return selection == emptyOption
        }
        if let stringSelection: String = selection as? String {
            return stringSelection.isEmpty
        }
        return false
    }
}

struct CardStringDropdown: View {
    let label: String
    @Binding var selection: String
    let options: [String]
    var placeholder = "Select"
    var capitalize = true
    var onChange: (() -> Void)?

    var body: some View {
        CardDropdownPicker(
            label: label,
            selection: $selection,
            options: options,
            displayName: { capitalize ? $0.capitalized : $0 },
            placeholder: placeholder,
            emptyOption: "",
            onChange: onChange
        )
    }
}

struct CardCollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content
    @AppLocalized private var localize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.callout)
                    Text(localize(title))
                        .font(.callout)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.leading, 8)
            }
        }
    }
}

struct CardPromptField: View {
    let label: String
    @Binding var text: String
    var hint: String?
    var minHeight: CGFloat = 60
    var maxHeight: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CardSectionLabel(text: label, hint: hint)

            #if os(macOS)
            SyntaxHighlightedTextEditor(
                text: $text,
                font: .systemFont(ofSize: 13),
                minHeight: minHeight,
                maxHeight: maxHeight
            )
            .frame(minHeight: minHeight, maxHeight: maxHeight)
            .padding(8)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            #else
            TextEditor(text: $text)
                .font(.callout)
                .frame(minHeight: minHeight, maxHeight: maxHeight)
                .padding(8)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            #endif
        }
    }
}

struct CardTextField: View {
    let placeholder: String
    @Binding var text: String
    @AppLocalized private var localize

    var body: some View {
        TextField(localize(placeholder), text: $text)
            .font(.callout)
            .textFieldStyle(.plain)
            .padding(6)
            .background(secondarySystemFill)
            .cornerRadius(6)
    }
}

struct CardSegmentedPicker: View {
    let label: String
    @Binding var selection: String
    let options: [String]
    @AppLocalized private var localize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localize(label))
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option.capitalized).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }
}

struct CardAddButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    var dropTitle = "Drop to use"
    var onImageDropped: ((PlatformImage) -> Void)?

    @State private var isDropTargeted = false
    @AppLocalized private var localize

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : icon)
                Text(localize(isDropTargeted ? dropTitle : title))
            }
            .font(.callout)
            .foregroundStyle(isDropTargeted ? Color.accentColor : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isDropTargeted ? Color.accentColor.opacity(0.2) : secondarySystemFill)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isDropTargeted ? Color.accentColor : Color.secondary,
                        style: isDropTargeted
                            ? StrokeStyle(lineWidth: 2)
                            : StrokeStyle(lineWidth: 1, dash: [5])
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .imageDropTarget(isTargeted: $isDropTargeted) { image in
            onImageDropped?(image)
        }
    }
}

struct CardReferenceImageRow: View {
    let image: PlatformImage
    let referenceType: String
    let supportedTypes: [String]
    let onTypeChange: (String) -> Void
    let onDelete: () -> Void
    @AppLocalized private var localize

    var body: some View {
        HStack(spacing: 8) {
            #if os(macOS)
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            #else
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            #endif

            if !supportedTypes.isEmpty {
                Menu {
                    ForEach(supportedTypes, id: \.self) { type in
                        Button(type.capitalized) {
                            onTypeChange(type)
                        }
                    }
                } label: {
                    HStack {
                        Text(referenceType.isEmpty ? localize("Select Type") : referenceType.capitalized)
                            .font(.callout)
                            .foregroundStyle(referenceType.isEmpty ? .secondary : .primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(secondarySystemFill)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(secondarySystemFill.opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Compact Reference Image Cell

struct CardReferenceImageCell: View {
    let image: PlatformImage
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            #if os(macOS)
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            #else
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            #endif

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
        }
    }
}

// MARK: - Input Image Cell

struct CardInputImageCell: View {
    let image: PlatformImage
    var isLocked = false

    var body: some View {
        #if os(macOS)
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(secondaryLabel.opacity(0.5), lineWidth: 2)
            )
            .opacity(isLocked ? 0.5 : 1.0)
        #else
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(secondaryLabel.opacity(0.5), lineWidth: 2)
            )
            .opacity(isLocked ? 0.5 : 1.0)
        #endif
    }
}

struct CardInputPlaceholderCell: View {
    var isLocked = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(secondarySystemFill)
            Image(systemName: "photo.fill")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
        }
        .frame(width: 56, height: 56)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(secondaryLabel.opacity(0.5), lineWidth: 2)
        )
        .opacity(isLocked ? 0.5 : 1.0)
    }
}

// MARK: - Compact Reference Images Grid

struct CardReferenceImagesGrid<RefImage: Identifiable>: View {
    let images: [RefImage]
    let getImage: (RefImage) -> PlatformImage
    let getReferenceType: (RefImage) -> String
    let supportedTypes: [String]
    let onTypeChange: (RefImage.ID, String) -> Void
    let onDelete: (RefImage.ID) -> Void
    let canAddMore: Bool
    let onAdd: () -> Void
    var inputImage: PlatformImage?
    var isInputImagePlaceholder = false
    var isLocked = false
    var onImageDropped: ((PlatformImage) -> Void)?

    @State private var isAddButtonDropTargeted = false
    @State private var isAddButtonHovered = false

    /// Whether the add button should show the highlighted state (drop target or hover)
    private var isAddButtonHighlighted: Bool {
        isAddButtonDropTargeted || isAddButtonHovered
    }

    private let gridColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 56, maximum: 70), spacing: 8),
    ]

    var body: some View {
        if supportedTypes.isEmpty {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
                if inputImage != nil {
                    if isInputImagePlaceholder {
                        CardInputPlaceholderCell(isLocked: isLocked)
                    } else if let inputImage: PlatformImage {
                        CardInputImageCell(image: inputImage, isLocked: isLocked)
                    }
                }

                ForEach(images) { refImage in
                    CardReferenceImageCell(
                        image: getImage(refImage),
                        onDelete: { onDelete(refImage.id) }
                    )
                }

                if canAddMore {
                    addButton
                }
            }
        } else {
            VStack(spacing: 6) {
                ForEach(images) { refImage in
                    CardReferenceImageRow(
                        image: getImage(refImage),
                        referenceType: getReferenceType(refImage),
                        supportedTypes: supportedTypes,
                        onTypeChange: { onTypeChange(refImage.id, $0) },
                        onDelete: { onDelete(refImage.id) }
                    )
                }

                if canAddMore {
                    CardAddButton(
                        icon: "photo.badge.plus",
                        title: images.isEmpty ? "Add Reference Image" : "Add Another",
                        action: onAdd,
                        onImageDropped: onImageDropped
                    )
                }
            }
        }
    }

    private var addButton: some View {
        VStack(spacing: 4) {
            Image(systemName: isAddButtonDropTargeted ? "arrow.down.circle.fill" : "plus")
                .font(.system(size: 16, weight: .medium))
        }
        .foregroundStyle(isAddButtonHighlighted ? Color.accentColor : .secondary)
        .frame(width: 56, height: 56)
        .background(isAddButtonHighlighted ? Color.accentColor.opacity(0.2) : secondarySystemFill)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isAddButtonHighlighted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: isAddButtonHighlighted
                        ? StrokeStyle(lineWidth: 2)
                        : StrokeStyle(lineWidth: 1, dash: [4])
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onAdd()
        }
        .onHover { hovering in
            isAddButtonHovered = hovering
        }
        .imageDropTarget(isTargeted: $isAddButtonDropTargeted) { image in
            onImageDropped?(image)
        }
    }
}

// MARK: - Slider Component

struct CardSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var showValue = true
    var valueFormatter: ((Double) -> String)?
    @AppLocalized private var localize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(localize(label))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if showValue {
                    Spacer()
                    Text(valueFormatter?(value) ?? String(format: "%.0f", value))
                        .font(.callout)
                        .foregroundStyle(.primary)
                }
            }

            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
        }
    }
}

// MARK: - Toggle Component

struct CardToggle: View {
    let label: String
    @Binding var isOn: Bool
    var hint: String?
    @AppLocalized private var localize

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(localize(label))
                    .font(.callout)
                if let hint: String {
                    Text(localize(hint))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}

// MARK: - Number Stepper

struct CardStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    @AppLocalized private var localize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localize(label))
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Stepper(value: $value, in: range) {
                    Text("\(value)")
                        .font(.system(size: 12, weight: .medium))
                }
                .labelsHidden()

                Text("\(value)")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24)
            }
        }
    }
}

// MARK: - Seed Field

struct CardSeedField: View {
    let label: String
    @Binding var value: String
    var placeholder = "Random"
    @AppLocalized private var localize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localize(label))
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField(localize(placeholder), text: $value)
                .font(.callout)
                .textFieldStyle(.plain)
                .padding(6)
                .background(secondarySystemFill)
                .cornerRadius(6)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
        }
    }
}

// MARK: - Tools Picker

struct CardToolsPicker: View {
    let label: String
    @Binding var selection: Set<String>
    let tools: [String]
    @AppLocalized private var localize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localize(label))
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(tools, id: \.self) { tool in
                    Button {
                        if selection.contains(tool) {
                            selection.remove(tool)
                        } else {
                            selection.insert(tool)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selection.contains(tool) ? "checkmark.square.fill" : "square")
                                .font(.callout)
                                .foregroundStyle(selection.contains(tool) ? Color.accentColor : .secondary)
                            Text(tool.capitalized.replacingOccurrences(of: "_", with: " "))
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
