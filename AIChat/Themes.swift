import SwiftUI

struct ThemePalette: Identifiable {
    let id: String
    let name: String
    let background: Color
    let surface: Color
    let text: Color
    let muted: Color
    let border: Color
    let chip: Color
    let primary: Color
    let onPrimary: Color
    let codeBackground: Color
    let isDark: Bool
}

enum AppThemes {
    static let all: [ThemePalette] = [paper, midnight, ocean, sunset, forest, mono, violet, rose, neon, graphite]
    static let paper = ThemePalette(id: "paper", name: "Paper", background: Color.white, surface: Color.white, text: Color(red: 0.07, green: 0.09, blue: 0.15), muted: Color(red: 0.42, green: 0.45, blue: 0.50), border: Color(red: 0.90, green: 0.91, blue: 0.92), chip: Color(red: 0.95, green: 0.96, blue: 0.97), primary: Color(red: 0.07, green: 0.09, blue: 0.15), onPrimary: Color.white, codeBackground: Color(red: 0.07, green: 0.09, blue: 0.15), isDark: false)
    static let midnight = ThemePalette(id: "midnight", name: "Midnight", background: Color(red: 0.05, green: 0.05, blue: 0.07), surface: Color(red: 0.09, green: 0.09, blue: 0.12), text: Color(red: 0.96, green: 0.96, blue: 0.97), muted: Color(red: 0.62, green: 0.63, blue: 0.68), border: Color(red: 0.20, green: 0.20, blue: 0.24), chip: Color(red: 0.13, green: 0.13, blue: 0.17), primary: Color.white, onPrimary: Color.black, codeBackground: Color.black, isDark: true)
    static let ocean = ThemePalette(id: "ocean", name: "Ocean", background: Color(red: 0.97, green: 0.99, blue: 1.0), surface: Color.white, text: Color(red: 0.05, green: 0.15, blue: 0.25), muted: Color(red: 0.35, green: 0.50, blue: 0.60), border: Color(red: 0.82, green: 0.90, blue: 0.95), chip: Color(red: 0.90, green: 0.96, blue: 0.99), primary: Color(red: 0.02, green: 0.35, blue: 0.55), onPrimary: Color.white, codeBackground: Color(red: 0.03, green: 0.20, blue: 0.32), isDark: false)
    static let sunset = ThemePalette(id: "sunset", name: "Sunset", background: Color(red: 1.0, green: 0.98, blue: 0.96), surface: Color.white, text: Color(red: 0.25, green: 0.12, blue: 0.08), muted: Color(red: 0.60, green: 0.45, blue: 0.38), border: Color(red: 0.95, green: 0.87, blue: 0.80), chip: Color(red: 0.99, green: 0.93, blue: 0.87), primary: Color(red: 0.85, green: 0.33, blue: 0.15), onPrimary: Color.white, codeBackground: Color(red: 0.20, green: 0.10, blue: 0.08), isDark: false)
    static let forest = ThemePalette(id: "forest", name: "Forest", background: Color(red: 0.96, green: 0.99, blue: 0.97), surface: Color.white, text: Color(red: 0.07, green: 0.20, blue: 0.13), muted: Color(red: 0.40, green: 0.55, blue: 0.45), border: Color(red: 0.83, green: 0.92, blue: 0.86), chip: Color(red: 0.89, green: 0.96, blue: 0.91), primary: Color(red: 0.08, green: 0.40, blue: 0.22), onPrimary: Color.white, codeBackground: Color(red: 0.06, green: 0.18, blue: 0.12), isDark: false)
    static let mono = ThemePalette(id: "mono", name: "Mono", background: Color(red: 0.98, green: 0.98, blue: 0.98), surface: Color.white, text: Color.black, muted: Color(red: 0.45, green: 0.45, blue: 0.45), border: Color(red: 0.88, green: 0.88, blue: 0.88), chip: Color(red: 0.94, green: 0.94, blue: 0.94), primary: Color.black, onPrimary: Color.white, codeBackground: Color.black, isDark: false)
    static let violet = ThemePalette(id: "violet", name: "Violet", background: Color(red: 0.98, green: 0.97, blue: 1.0), surface: Color.white, text: Color(red: 0.16, green: 0.10, blue: 0.30), muted: Color(red: 0.50, green: 0.42, blue: 0.65), border: Color(red: 0.89, green: 0.85, blue: 0.97), chip: Color(red: 0.93, green: 0.90, blue: 0.99), primary: Color(red: 0.45, green: 0.25, blue: 0.85), onPrimary: Color.white, codeBackground: Color(red: 0.14, green: 0.08, blue: 0.28), isDark: false)
    static let rose = ThemePalette(id: "rose", name: "Rose", background: Color(red: 1.0, green: 0.97, blue: 0.98), surface: Color.white, text: Color(red: 0.30, green: 0.10, blue: 0.16), muted: Color(red: 0.62, green: 0.42, blue: 0.48), border: Color(red: 0.96, green: 0.86, blue: 0.89), chip: Color(red: 0.99, green: 0.91, blue: 0.93), primary: Color(red: 0.82, green: 0.20, blue: 0.38), onPrimary: Color.white, codeBackground: Color(red: 0.24, green: 0.08, blue: 0.13), isDark: false)
    static let neon = ThemePalette(id: "neon", name: "Neon", background: Color(red: 0.02, green: 0.03, blue: 0.05), surface: Color(red: 0.06, green: 0.09, blue: 0.13), text: Color(red: 0.92, green: 0.99, blue: 0.97), muted: Color(red: 0.50, green: 0.65, blue: 0.62), border: Color(red: 0.12, green: 0.25, blue: 0.22), chip: Color(red: 0.07, green: 0.14, blue: 0.13), primary: Color(red: 0.10, green: 0.90, blue: 0.70), onPrimary: Color.black, codeBackground: Color.black, isDark: true)
    static let graphite = ThemePalette(id: "graphite", name: "Graphite", background: Color(red: 0.11, green: 0.11, blue: 0.12), surface: Color(red: 0.16, green: 0.16, blue: 0.18), text: Color(red: 0.96, green: 0.96, blue: 0.97), muted: Color(red: 0.62, green: 0.63, blue: 0.68), border: Color(red: 0.26, green: 0.26, blue: 0.29), chip: Color(red: 0.20, green: 0.20, blue: 0.22), primary: Color.white, onPrimary: Color.black, codeBackground: Color.black, isDark: true)
    static func palette(for id: String) -> ThemePalette { all.first { $0.id == id } ?? paper }
}
