import SwiftUI

private struct AppScreenStyle: ViewModifier {
    func body(content: Content) -> some View {
        // Keep the same scroll view identity when appearance changes.
        content
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .foregroundStyle(AppTheme.primaryText)
            .tint(AppTheme.accent)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct AppSectionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(AppTheme.surface)
            .listRowSeparatorTint(AppTheme.border)
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

private struct NavigationScrollSample: Equatable {
    let offset: CGFloat
    let viewportHeight: CGFloat
    let topInset: CGFloat
}

private struct NavigationScrollTracking: ViewModifier {
    @Environment(\.navigationBarCollapsed) private var setCollapsed
    @State private var anchor: CGFloat = 0
    @State private var collapsed = false

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: NavigationScrollSample.self) { geometry in
                let maximum = max(0, geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom - geometry.containerSize.height)
                let offset = min(maximum, max(0, geometry.contentOffset.y + geometry.contentInsets.top))
                return NavigationScrollSample(offset: offset, viewportHeight: geometry.containerSize.height, topInset: geometry.contentInsets.top)
            } action: { previous, current in
                let offset = current.offset
                // Header expansion changes the viewport, not the user's scroll direction.
                guard abs(current.viewportHeight - previous.viewportHeight) < 0.5,
                      abs(current.topInset - previous.topInset) < 0.5 else {
                    anchor = offset
                    return
                }
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
