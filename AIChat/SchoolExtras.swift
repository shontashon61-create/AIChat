import Foundation

struct LessonItem: Identifiable {
    var id = UUID()
    var subject: String
    var time: String
    var date: String
    var homework: String
}

enum ScheduleParser {
    static func lessons(from events: [[String: Any]]) -> [LessonItem] {
        var out: [LessonItem] = []
        for ev in events {
            let subject = (ev["subject_name"] as? String) ?? "Урок"
            let time = (ev["begin_time"] as? String) ?? ""
            let date = (ev["date"] as? String) ?? ""
            var hw = ""
            if let h = ev["homework"] as? [String: Any] { hw = (h["description"] as? String) ?? "" }
            out.append(LessonItem(subject: subject, time: time, date: date, homework: hw))
        }
        return out
    }
}

enum EssayHelper {
    static func prompt(topic: String, type: String) -> String {
        return "Напиши " + type + " для 6 класса на тему: " + topic + ". Сначала план из 3 пунктов, потом текст 150-200 слов, простыми словами."
    }
}

struct EnglishWord: Identifiable {
    var id = UUID()
    var word: String
    var transcription: String
    var translation: String
    var example: String
}

enum EnglishHelper {
    static let words: [EnglishWord] = [
        EnglishWord(word: "homework", transcription: "houm-werk", translation: "домашнее задание", example: "I do my homework every day."),
        EnglishWord(word: "school", transcription: "skuul", translation: "школа", example: "I go to school."),
        EnglishWord(word: "book", transcription: "buk", translation: "книга", example: "This is my book."),
        EnglishWord(word: "friend", transcription: "frend", translation: "друг", example: "He is my friend.")
    ]
    static func lookup(_ q: String) -> EnglishWord? {
        let t = q.lowercased()
        return words.first { $0.word.lowercased() == t || $0.translation.contains(t) }
    }
}

enum PresentationHelper {
    static func slides(topic: String) -> [String] {
        return ["1. " + topic, "2. Что это такое?", "3. Главные факты", "4. Пример", "5. Вывод"]
    }
}

enum PageHelper {
    static let prompt = "Перескажи страницу учебника кратко: 3 главных факта и 1 пример."
    static let boardPrompt = "Прочитай доску: перепиши все задания и примеры чистым текстом, по номерам."
}
