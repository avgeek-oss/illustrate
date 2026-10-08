import SwiftUI

struct BrandDashboardView: View {
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Brand")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Manage your brand identity and assets")
                            .opacity(0.6)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Brand Tools")
                            .font(.caption)
                            .textCase(.uppercase)
                            .opacity(0.5)
                        LazyVGrid(columns: columns(for: geometry.size.width), spacing: 12) {
                            ForEach(brandItems, id: \.self) { item in
                                WorkspaceGenerateShortcut(item: item)
                            }
                        }
                    }
                }
                .padding(.all, 16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .navigationTitle("Brand")
    }

    private let brandItems: [EnumNavigationItem] = [.brandKit, .promptGallery, .productGallery]

    private func columns(for width: CGFloat) -> [GridItem] {
        #if os(macOS)
        var columnCount = 3
        if width < 500 { columnCount = 1 }
        else if width < 650 { columnCount = 2 }
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
        #else
        return Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: UIDevice.current.userInterfaceIdiom == .pad ? 3 : 1
        )
        #endif
    }
}
