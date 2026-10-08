import SwiftUI

/// A reusable badge view that displays a numeric count indicator.
///
/// Use `BadgeView` to show notification counts, item quantities, or other numeric indicators
/// overlaid on buttons or icons. The badge automatically hides when count is zero.
///
/// Example usage:
/// ```swift
/// ZStack(alignment: .topTrailing) {
///     Image(systemName: "bell")
///     BadgeView(count: 5)
///         .offset(x: 6, y: -6)
/// }
/// ```
struct BadgeView: View {
    /// The number to display in the badge. Badge is hidden when count is 0.
    let count: Int

    /// The background color of the badge capsule. Defaults to accent color.
    var backgroundColor: Color = .accentColor

    /// The text color of the count label. Defaults to system background.
    var textColor: Color = systemBackground

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(textColor)
                .padding(.horizontal, count > 9 ? 6 : 5)
                .padding(.vertical, 2)
                .background(backgroundColor)
                .clipShape(Capsule())
                .transition(.scale.combined(with: .opacity))
        }
    }
}
