import UIKit
import UserNotifications

final class BackgroundSupport {
    static let shared = BackgroundSupport()
    private var taskID: UIBackgroundTaskIdentifier = .invalid
    private init() {}
    func begin() {
        guard taskID == .invalid else { return }
        taskID = UIApplication.shared.beginBackgroundTask(withName: "AIChatGeneration") { [weak self] in self?.end() }
    }
    func end() {
        guard taskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(taskID)
        taskID = .invalid
    }
    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    static func notifyAnswerReady() {
        guard UIApplication.shared.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = "AIChat"
        content.body = "Ответ готов"
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
