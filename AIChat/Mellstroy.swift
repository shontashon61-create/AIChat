import SwiftUI

enum Mellstroy {
    static let accent = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let accent2 = Color(red: 0.98, green: 0.20, blue: 0.32)
    static let dark = Color(red: 0.08, green: 0.05, blue: 0.02)
    static let wallpapers = ["Градиент", "Мемы", "Тёмный стрим", "Выкл"]
    static let icons: [String: String] = [
        "newChat": "bolt.fill",
        "history": "clock.arrow.circlepath",
        "settings": "slider.horizontal.3",
        "send": "paperplane.fill",
        "photo": "camera.fill",
        "gallery": "photo.fill",
        "school": "graduationcap.fill",
        "mesh": "book.fill",
        "tools": "backpack.fill",
        "test": "checklist",
        "copy": "doc.on.doc.fill",
        "speak": "speaker.wave.2.fill",
        "regen": "arrow.clockwise",
        "delete": "trash.fill",
        "edit": "pencil",
        "stop": "stop.circle.fill",
        "down": "arrow.down",
        "fire": "flame.fill",
        "crown": "crown.fill",
        "money": "banknote.fill",
        "meme": "theatermasks.fill",
        "key": "key.fill"
    ]
    static let emptyTitles = ["Легенда на связи", "Что решаем, чемпион?", "Кидай задание — разнесём", "Меллстрой режим: ON", "Стрим пошёл, домашка горит"]
    static let emptySubtitles = ["Фото листочка, тест или домашка — только по делу и кратко.", "Нечитаемо на фото? Честно скажу: непонятно именно это задание.", "Три режима: кратко, с решением, подробно. Выбирай и кидай задание."]
    static let jokes = ["Стрим начался, домашка закончилась.", "Это не списывание, это скоростное обучение.", "Один листочек — один точный ответ.", "Без воды, только факты и буква ответа.", "Мелл одобряет: кратко и по делу."]
    static func randomEmpty() -> (String, String) {
        let i = Int.random(in: 0..<emptyTitles.count)
        return (emptyTitles[i], emptySubtitles[i % emptySubtitles.count])
    }
}

struct MellAvatarView: View {
    var size: CGFloat = 64
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Mellstroy.accent, Mellstroy.accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(spacing: 0) {
                Image(systemName: "crown.fill").font(.system(size: size * 0.28)).foregroundStyle(.yellow)
                Text("MELL").font(.system(size: size * 0.22, weight: .black, design: .rounded)).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 2))
        .shadow(color: Mellstroy.accent2.opacity(0.45), radius: 6)
    }
}

struct MellWallpaperView: View {
    let style: String
    var body: some View {
        ZStack {
            if style != "Выкл" {
                LinearGradient(colors: style == "Тёмный стрим" ? [Mellstroy.dark, Color(red: 0.25, green: 0.08, blue: 0.02)] : [Color(red: 1.0, green: 0.96, blue: 0.88), Color(red: 1.0, green: 0.88, blue: 0.82)], startPoint: .top, endPoint: .bottom)
                if style == "Мемы" || style == "Тёмный стрим" {
                    VStack(spacing: 34) {
                        ForEach(0..<8, id: \.self) { _ in
                            HStack(spacing: 38) {
                                Image(systemName: "flame.fill")
                                Image(systemName: "crown.fill")
                                Image(systemName: "bolt.fill")
                                Image(systemName: "banknote.fill")
                                Image(systemName: "theatermasks.fill")
                            }
                            .font(.title3)
                            .foregroundStyle((style == "Тёмный стрим" ? Color.white : Mellstroy.accent2).opacity(0.10))
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
