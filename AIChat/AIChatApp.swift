import SwiftUI

@main
struct AIChatApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            ZStack {
                DesignTheme.background.ignoresSafeArea()
                Group {
                    if !settings.hasSeenOnboarding {
                        OnboardingView()
                    } else {
                        ContentView()
                    }
                }
                .environmentObject(settings)
                .environmentObject(store)
                .preferredColorScheme(AppThemes.palette(for: settings.appTheme).isDark ? .dark : .light)
                .onAppear { BackgroundSupport.requestNotificationPermission() }
            }
        }
    }
}
