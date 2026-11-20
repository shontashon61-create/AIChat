import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var page = 0
    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $page) {
                pageView(title: "Чаты без лишнего", text: "Стриминг, ход мыслей и код с кнопкой копирования.", icon: "text.bubble").tag(0)
                pageView(title: "Фото, видео и голос", text: "Прикрепляйте файлы, диктуйте и слушайте ответы.", icon: "mic").tag(1)
                pageView(title: "Свой API и темы", text: "Любой OpenAI-совместимый адрес, свой промт и 6 тем оформления.", icon: "paintpalette").tag(2)
            }.tabViewStyle(.page(indexDisplayMode: .always)).frame(maxHeight: 420)
            Button(page == 2 ? "Начать" : "Далее") { if page == 2 { settings.hasSeenOnboarding = true } else { page += 1 } }.buttonStyle(PrimaryButtonStyle())
            if page < 2 { Button("Пропустить") { settings.hasSeenOnboarding = true }.font(.caption) }
        }.padding().background(DesignTheme.background)
    }
    func pageView(title: String, text: String, icon: String) -> some View {
        VStack(spacing: 16) { Image(systemName: icon).font(.system(size: 44)).foregroundStyle(DesignTheme.primary); Text(title).font(.title2.bold()); Text(text).multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal) }
    }
}
