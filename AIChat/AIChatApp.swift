import SwiftUI

@main
struct AIChatApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(store)
        }
    }
}
