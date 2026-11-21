import SwiftUI

enum DesignTheme {
    static var palette: ThemePalette {
        AppThemes.palette(for: UserDefaults.standard.string(forKey: "appTheme") ?? "paper")
    }
    static var background: Color { palette.background }
    static var surface: Color { palette.surface }
    static var text: Color { palette.text }
    static var muted: Color { palette.muted }
    static var border: Color { palette.border }
    static var chip: Color { palette.chip }
    static var primary: Color { palette.primary }
    static var onPrimary: Color { palette.onPrimary }
    static var codeBackground: Color { palette.codeBackground }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 16).padding(.vertical, 10).background(DesignTheme.primary).foregroundStyle(DesignTheme.onPrimary).clipShape(Capsule()).opacity(configuration.isPressed ? 0.85 : 1).scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(20).background(DesignTheme.surface).overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignTheme.border)).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}
