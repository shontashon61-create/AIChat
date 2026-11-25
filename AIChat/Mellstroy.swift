import SwiftUI

enum Mellstroy {
    static let accent = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let accent2 = Color(red: 0.98, green: 0.20, blue: 0.32)
    static let icons: [String: String] = [
        "newChat": "bolt.fill",
        "history": "clock.arrow.circlepath",
        "settings": "slider.horizontal.3",
        "send": "paperplane.fill",
        "photo": "camera.fill",
        "school": "graduationcap.fill",
        "test": "checklist",
        "fire": "flame.fill",
        "crown": "crown.fill",
        "money": "banknote.fill"
    ]
    static let emptyTitles = ["Легенда на связи", "Что решаем, чемпион?", "Кидай задание — разнесём", "Меллстрой режим: ON"]
    static let emptySubtitles = ["Фото листочка, тест или домашка — только по делу и кратко.", "Нечитаемо на фото? Честно скажу: непонятно именно это задание.", "Тест: сначала буква и ответ, потом одно предложение почему."]
    static let jokes = ["Стрим начался, домашка закончилась.", "Это не списывание, это скоростное обучение.", "Один листочек — один точный ответ.", "Без воды, только факты и буква ответа."]
    static func randomEmpty() -> (String, String) {
        let i = Int.random(in: 0..<emptyTitles.count)
        return (emptyTitles[i], emptySubtitles[i % emptySubtitles.count])
    }
}
