// MARK: - HistoryView.swift

// Navigation hub for gallery-related views.
//
// Lists available gallery views (Image Gallery, Video Gallery, Failed Requests).
// Failed Requests only shown if there are failures to display.

import SwiftUI

/// Navigation list for gallery section items.
struct GalleryView: View {
    var body: some View {
        Form {
            Section("Gallery") {
                List(sectionItems(section: .History), id: \.self) { item in
                    NavigationLink(value: item) {
                        Label(labelForItem(item), systemImage: iconForItem(item))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Gallery")
    }
}

/// Legacy alias for compatibility
typealias HistoryView = GalleryView
