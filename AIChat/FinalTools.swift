import SwiftUI
import UIKit

struct ArchiveItem: Identifiable, Codable {
    var id = UUID()
    var date: String
    var subject: String
    var text: String
    var answer: String
}

enum FinalTools {
    static func numbers(in text: String) -> [Int] {
        var out: [Int] = []
        var cur = ""
        for ch in text + " " {
            if ch.isNumber { cur.append(ch) } else { if let n = Int(cur), n > 0, n < 100, !out.contains(n) { out.append(n) }; cur = "" }
        }
        return out.sorted()
    }
    static func missing(expected: String, answer: String) -> [Int] {
        let a = Set(numbers(in: answer))
        return numbers(in: expected).filter { !a.contains($0) }
    }
    static func verifyCopyPrompt(original: String) -> String {
        return "Сверь фото моей тетради с этим готовым ответом по каждой цифре, букве и знаку. Формат: строка за строкой ВЕРНО или ОШИБКА: было / должно быть. В конце: всего ошибок N. Готовый ответ:\n" + original
    }
    static func splitFields(_ answer: String) -> [String] {
        answer.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.lowercased().contains("ответ") || $0.contains(":") }.filter { !$0.isEmpty }
    }
    static func onlyAnswers(_ text: String) -> [String] {
        text.components(separatedBy: "\n").filter { $0.lowercased().contains("ответ") }
    }
    static func fitPrompt(_ text: String) -> String {
        return "Сожми запись ответа так, чтобы влезала на одну страницу тетради: короче строки, компактный столбик, без длинных фраз. Все числа, формулы, схемы тегами и итоговый ответ сохрани без изменений. Верни только сжатую запись:\n" + text
    }
    static func key(_ text: String) -> String {
        text.lowercased().split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).joined(separator: " ")
    }
    static func archiveLoad() -> [ArchiveItem] {
        guard let d = UserDefaults.standard.data(forKey: "hw_archive"), let v = try? JSONDecoder().decode([ArchiveItem].self, from: d) else { return [] }
        return v
    }
    static func archiveSave(subject: String, text: String, answer: String) {
        var all = archiveLoad()
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        all.append(ArchiveItem(date: f.string(from: Date()), subject: subject, text: text, answer: answer))
        if let d = try? JSONEncoder().encode(all) { UserDefaults.standard.set(d, forKey: "hw_archive") }
    }
    static func duplicateAnswer(for text: String) -> String? {
        let all = archiveLoad()
        return all.first(where: { key($0.text) == key(text) })?.answer
    }
}

struct NotebookSheetView: View {
    let text: String
    let lined: Bool
    var body: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geo in
                Path { p in
                    var y: CGFloat = 28
                    while y < geo.size.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y)); y += 28 }
                    if !lined { var x: CGFloat = 28; while x < geo.size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: geo.size.height)); x += 28 } }
                }.stroke(Color.blue.opacity(0.25), lineWidth: 1)
            }
            Text(text).font(.callout).padding(10)
        }.frame(minHeight: 300).background(Color.white).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    static func makeImage(text: String, lined: Bool) -> UIImage? {
        let v = NotebookSheetView(text: text, lined: lined).frame(width: 700, height: 900)
        let r = ImageRenderer(content: v)
        return r.uiImage
    }
}
