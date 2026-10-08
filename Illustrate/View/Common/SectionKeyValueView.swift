// MARK: - SectionKeyValueView.swift

// Reusable key-value display component for detail views.
//
// Displays a labeled value with optional icon. Adapts layout
// for iOS (vertical) vs macOS (horizontal).
//
// ## Usage
// ```swift
// SectionKeyValueView(icon: "photo", key: "Dimensions", value: "1024x1024")
// ```

import SwiftUI

/// Key-value pair display with platform-adaptive layout.
struct SectionKeyValueView<T: View>: View {
    var customValueView: T
    var useCustomValueView: Bool

    var icon: String?
    var key: String
    var value: String
    var monospaced: Bool?
    var multilineValue: Bool

    init(
        icon: String? = nil,
        key: String,
        value: String,
        customValueView: T? = nil,
        monospaced: Bool? = nil,
        multilineValue: Bool = false
    ) {
        self.icon = icon
        self.key = key
        self.value = value
        self.monospaced = monospaced
        self.multilineValue = multilineValue

        if let customValueView {
            self.customValueView = customValueView
            useCustomValueView = true
        } else {
            self.customValueView = EmptyView() as! T
            useCustomValueView = false
        }
    }

    init(icon: String? = nil, key: String, value: String, monospaced: Bool? = nil, multilineValue: Bool = false)
        where T == EmptyView
    {
        self.init(
            icon: icon,
            key: key,
            value: value,
            customValueView: nil,
            monospaced: monospaced,
            multilineValue: multilineValue
        )
    }

    var body: some View {
        VStack(alignment: .leading) {
            #if os(iOS)

            HStack(alignment: .top) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(secondaryLabel)
                        .padding(.top, 4)
                }
                VStack(alignment: .leading) {
                    Text(key)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(secondaryLabel)
                    if useCustomValueView {
                        customValueView
                    } else {
                        Text(value)
                            .font(.body)
                            .monospaced(monospaced ?? false)
                    }
                }
                Spacer()
            }
            #else
            if multilineValue {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.body)
                                .foregroundStyle(secondaryLabel)
                        }
                        Text(key)
                            .font(.body)
                            .foregroundStyle(secondaryLabel)
                    }
                    if useCustomValueView {
                        customValueView
                    } else {
                        Text(value)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                            .monospaced(monospaced ?? false)
                    }
                }
            } else {
                HStack(alignment: .center) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.body)
                            .foregroundStyle(secondaryLabel)
                    }
                    Text(key)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(secondaryLabel)
                    Spacer()
                    if useCustomValueView {
                        customValueView
                    } else {
                        Text(value)
                            .font(.body)
                            .multilineTextAlignment(.trailing)
                            .monospaced(monospaced ?? false)
                    }
                }
            }
            #endif
        }
    }
}
