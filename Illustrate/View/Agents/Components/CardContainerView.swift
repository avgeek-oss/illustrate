// MARK: - CardContainerView.swift

// Common container for all agent card types.
//
// Provides consistent visual styling for canvas cards:
// - Fixed width (300pt)
// - Header, content, footer slots
// - Running/error state indicators
// - Hover highlight
// - Rounded corners and shadow
//
// ## Content Height
// Content area has max height with scrolling if exceeded.
// Uses PreferenceKey to measure and constrain content.
//
// ## State Indicators
// - Running: Blue border with animation
// - Errored: Red border with error message
// - Hovered: Subtle highlight

import SwiftUI

/// Fixed card dimensions.
let cardFixedWidth: CGFloat = 300
let cardContentMaxHeight: CGFloat = 600

private struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct CardContainerView<Header: View, Content: View, Footer: View>: View {
    let headerContent: Header
    let mainContent: Content
    let footerContent: Footer

    var isHovered = false
    var isRunning = false
    var isErrored = false
    var errorMessage: String?

    @State private var contentHeight: CGFloat = 100

    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        headerContent = header()
        mainContent = content()
        footerContent = footer()
    }

    init(
        isHovered: Bool,
        isRunning: Bool = false,
        isErrored: Bool = false,
        errorMessage: String? = nil,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.isHovered = isHovered
        self.isRunning = isRunning
        self.isErrored = isErrored
        self.errorMessage = errorMessage
        headerContent = header()
        mainContent = content()
        footerContent = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            headerContent
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            ScrollView(showsIndicators: false) {
                mainContent
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: ContentHeightPreferenceKey.self, value: geo.size.height)
                        }
                    )
            }
            .coordinateSpace(name: "cardContentScroll")
            .scrollIndicators(.never)
            .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                contentHeight = height
            }
            .frame(height: min(max(contentHeight, 100), cardContentMaxHeight))

            footerSection

            if isErrored, let errorMessage {
                Divider()
                    .frame(height: 2.5)
                    .background(Color.red)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(Color.red.opacity(0.04))
            }
        }
        .frame(width: cardFixedWidth)
        .background(systemBackground)
        .cornerRadius(12)
        .overlay(
            Group {
                if isRunning {
                    TimelineView(.animation) { timeline in
                        let seconds = timeline.date.timeIntervalSinceReferenceDate
                        let rotation = Angle.degrees(seconds.truncatingRemainder(dividingBy: 1.5) / 1.5 * 360)
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        .accentColor,
                                        .accentColor.opacity(0.3),
                                        .accentColor.opacity(0.2),
                                        .accentColor.opacity(0.3),
                                        .accentColor,
                                    ]),
                                    center: .center,
                                    angle: rotation
                                ),
                                lineWidth: borderWidth
                            )
                    }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: borderWidth)
                }
            }
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    private var footerSection: some View {
        if Footer.self != EmptyView.self {
            Divider()

            footerContent
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }

    private var borderColor: Color {
        if isErrored {
            return .red
        }
        if isRunning {
            return .accentColor
        }
        if isHovered {
            return Color.accentColor.opacity(0.8)
        }
        return secondaryLabel.opacity(0.2)
    }

    private var borderWidth: CGFloat {
        if isRunning || isErrored {
            return 2.5
        }
        return isHovered ? 2.5 : 1
    }
}

extension CardContainerView where Footer == EmptyView {
    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        headerContent = header()
        mainContent = content()
        footerContent = EmptyView()
    }

    init(
        isHovered: Bool,
        isRunning: Bool = false,
        isErrored: Bool = false,
        errorMessage: String? = nil,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.isHovered = isHovered
        self.isRunning = isRunning
        self.isErrored = isErrored
        self.errorMessage = errorMessage
        headerContent = header()
        mainContent = content()
        footerContent = EmptyView()
    }
}

extension CardContainerView where Header == EmptyView {
    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        headerContent = EmptyView()
        mainContent = content()
        footerContent = footer()
    }
}

struct CardHeaderView: View {
    let title: String
    let icon: String?
    let iconColor: Color
    let hasGenerationId: Bool

    init(title: String, icon: String? = nil, iconColor: Color = .accentColor, hasGenerationId: Bool = false) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.hasGenerationId = hasGenerationId
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.system(size: 13, weight: .semibold))
            }

            Text(title)
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            if hasGenerationId {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CardFooterView: View {
    let lastRunDate: Date?

    init(lastRunDate: Date? = nil) {
        self.lastRunDate = lastRunDate
    }

    private func formatLastRun(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "<1 min"
        }
        return date.formatted(.relative(presentation: .named))
    }

    var body: some View {
        HStack {
            Spacer()
            if let date = lastRunDate {
                Text("Last run: \(formatLastRun(date))")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Not run yet")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
