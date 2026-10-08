// MARK: - GenerateView.swift

// Navigation hub for quick actions (generate image, generate video).
//
// Simple list view that presents available generation actions
// as navigation links. Used in the mobile navigation flow.

import OSLog
import SwiftUI

/// Navigation list for generation quick actions.
struct GenerateView: View {
    var body: some View {
        Form {
            Section(EnumNavigationSection.QuickActions.title) {
                List(sectionItems(section: EnumNavigationSection.QuickActions), id: \.self) { item in
                    NavigationLink(value: item) {
                        Label(labelForItem(item), systemImage: iconForItem(item))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(EnumNavigationSection.QuickActions.title)
    }
}
