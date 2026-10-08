// MARK: - GuidePopover.swift

// Reusable guide popover component for displaying help content.
//
// Provides a consistent way to show contextual help across the app
// with a button that opens a popover containing guide sections.

import SwiftUI

// MARK: - Guide Popover

/// A reusable guide button with popover content.
///
/// Displays a help button that shows a popover with guide sections
/// and quick reference items.
struct GuidePopover: View {
    let title: String
    let sections: [GuideSection]
    @Binding var isPresented: Bool
    var width: CGFloat = 380
    var height: CGFloat = 400

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label("Guide", systemImage: "questionmark.circle")
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $isPresented) {
            popoverContent
        }
    }

    private var popoverContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                        if index > 0 {
                            Divider()
                        }

                        if let sectionTitle = section.title {
                            Text(sectionTitle)
                                .font(.headline)
                        }

                        if let content = section.content {
                            Text(content)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        ForEach(section.items, id: \.icon) { item in
                            guideItemView(icon: item.icon, text: item.text)
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(width: width, height: height)
    }

    private func guideItemView(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A section within a guide popover.
struct GuideSection {
    let title: String?
    let content: String?
    let items: [GuideItem]

    init(title: String? = nil, content: String? = nil, items: [GuideItem] = []) {
        self.title = title
        self.content = content
        self.items = items
    }
}

/// An individual item within a guide section.
struct GuideItem {
    let icon: String
    let text: String
}
