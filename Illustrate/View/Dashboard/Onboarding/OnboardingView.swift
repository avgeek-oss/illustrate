import AvgeekLocalizationCore
import AvgeekLocalizationUI
import SwiftData
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    private var providerKeys: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    struct OnboardingChecklist {
        let label: String
        let subLabel: String
        let isCompleted: Bool
        let item: EnumNavigationItem
    }

    func checklist() -> [OnboardingChecklist] {
        [
            OnboardingChecklist(
                label: "Connect Provider Models",
                subLabel: "Securely connect to leading AI models",
                isCompleted: !providerKeys.isEmpty,
                item: .settingsProviders
            ),
        ]
    }

    func columns(for width: CGFloat) -> [GridItem] {
        #if os(macOS)
        var columnCount = 3
        if width < 600 {
            columnCount = 1
        } else if width < 900 {
            columnCount = 2
        }
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount)
        #else
        return Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: UIDevice.current.userInterfaceIdiom == .pad ? 3 : 1
        )
        #endif
    }

    var width: CGFloat

    var body: some View {
        LazyVGrid(columns: columns(for: width), spacing: 8) {
            ForEach(checklist(), id: \.item) { checklistItem in
                OnboardingChecklistItem(checklistItem: checklistItem)
            }
        }
    }
}

struct OnboardingChecklistItem: View {
    @EnvironmentObject private var navigationManager: NavigationManager
    @AppLocalized private var localize

    var checklistItem: OnboardingView.OnboardingChecklist
    @State private var isHovered = false

    private var coverImage: String? {
        coverImageForItem(checklistItem.item)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let coverImage {
                Image(coverImage)
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(21.0 / 9.0, contentMode: .fit)
                    .clipped()
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(localize(checklistItem.label))
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                Text(localize(checklistItem.subLabel))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(0.8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .frame(minHeight: coverImage != nil ? nil : 72, maxHeight: .infinity, alignment: .topLeading)
        .background(
            Color.mint.opacity(
                checklistItem.isCompleted ? (isHovered ? 0.2 : 0.1) : (isHovered ? 0.1 : 0)
            )
        )
        .background(tertiarySystemFill)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            navigationManager.navigate(to: checklistItem.item)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
