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
