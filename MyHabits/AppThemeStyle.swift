import SwiftUI

private struct AppScreenStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder func body(content: Content) -> some View {
        if scheme == .dark {
            content
                .scrollContentBackground(.hidden)
                .background(AppTheme.background)
                .foregroundStyle(AppTheme.primaryText)
                .tint(AppTheme.accent)
                .toolbarBackground(AppTheme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        } else {
            content
        }
    }
}

private struct AppSectionStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder func body(content: Content) -> some View {
        if scheme == .dark {
            content
                .listRowBackground(AppTheme.surface)
                .listRowSeparatorTint(AppTheme.border)
        } else {
            content
        }
    }
}

private struct AppHabitCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder func body(content: Content) -> some View {
        if scheme == .dark {
            content
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(AppTheme.border, lineWidth: 1)
                        }
                )
                .listRowSeparator(.hidden)
        } else {
            content
        }
    }
}

extension View {
    func appScreenStyle() -> some View { modifier(AppScreenStyle()) }
    func appSectionStyle() -> some View { modifier(AppSectionStyle()) }
    func appHabitCardStyle() -> some View { modifier(AppHabitCardStyle()) }
}

private struct BottomNavigationVisibilityKey: EnvironmentKey {
    static let defaultValue: (Bool) -> Void = { _ in }
}

private struct NavigationScrollHandlerKey: EnvironmentKey {
    static let defaultValue: (Bool) -> Void = { _ in }
}

extension EnvironmentValues {
    var setBottomNavigationHidden: (Bool) -> Void {
        get { self[BottomNavigationVisibilityKey.self] }
        set { self[BottomNavigationVisibilityKey.self] = newValue }
    }

    var navigationBarCollapsed: (Bool) -> Void {
        get { self[NavigationScrollHandlerKey.self] }
        set { self[NavigationScrollHandlerKey.self] = newValue }
    }
}

private struct NavigationScrollTracking: ViewModifier {
    @Environment(\.navigationBarCollapsed) private var setCollapsed
    @State private var anchor: CGFloat = 0

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                let maximum = max(0, geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom - geometry.containerSize.height)
                return min(maximum, max(0, geometry.contentOffset.y + geometry.contentInsets.top))
            } action: { _, offset in
                if offset <= 1 {
                    anchor = offset
                    setCollapsed(false)
                } else if abs(offset - anchor) >= 18 {
                    setCollapsed(offset > anchor)
                    anchor = offset
                }
            }
        } else {
            content
        }
    }
}

extension View {
    func tracksNavigationScroll() -> some View { modifier(NavigationScrollTracking()) }
}
