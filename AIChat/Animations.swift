import SwiftUI
import UIKit

enum AppAnim {
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.82)
    static let smooth = Animation.easeInOut(duration: 0.25)
    static let pop = Animation.spring(response: 0.35, dampingFraction: 0.65)
}

enum Haptic {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

struct TypingDots: View {
    @State private var phase = 0
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle().frame(width: 7, height: 7).opacity(phase == i ? 1 : 0.35).scaleEffect(phase == i ? 1.25 : 1)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in withAnimation(.easeInOut(duration: 0.3)) { phase = (phase + 1) % 3 } }
        }
    }
}

struct MessageAppear: ViewModifier {
    @State private var shown = false
    func body(content: Content) -> some View {
        content.opacity(shown ? 1 : 0).offset(y: shown ? 0 : 12).scaleEffect(shown ? 1 : 0.98).onAppear { withAnimation(AppAnim.spring) { shown = true } }
    }
}

extension View {
    func messageAppear() -> some View { modifier(MessageAppear()) }
}
