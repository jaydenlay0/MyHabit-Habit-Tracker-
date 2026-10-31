import SwiftUI

private struct AppScreenStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        // Keep the same scroll view identity when appearance changes.
        content
            .scrollContentBackground(scheme == .dark ? .hidden : .automatic)
            .background(scheme == .dark ? AppTheme.background : Color.clear)
            .foregroundStyle(scheme == .dark ? AppTheme.primaryText : Color.primary)
            .tint(scheme == .dark ? AppTheme.accent : Color.accentColor)
            .toolbarBackground(scheme == .dark ? AppTheme.background : Color.clear, for: .navigationBar)
            .toolbarBackground(scheme == .dark ? .visible : .automatic, for: .navigationBar)
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
    func body(content: Content) -> some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
            }
            // Keep the outline inside the List's own rounded clipping boundary.
            .padding(4)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
    @State private var collapsed = false

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                let maximum = max(0, geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom - geometry.containerSize.height)
                return min(maximum, max(0, geometry.contentOffset.y + geometry.contentInsets.top))
            } action: { _, offset in
                if offset <= 1 {
                    anchor = offset
                    if collapsed { collapsed = false; setCollapsed(false) }
                } else if collapsed {
                    anchor = max(anchor, offset)
                    if anchor - offset >= 14 {
                        collapsed = false
                        anchor = offset
                        setCollapsed(false)
                    }
                } else {
                    anchor = min(anchor, offset)
                    if offset - anchor >= 28 {
                        collapsed = true
                        anchor = offset
                        setCollapsed(true)
                    }
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
