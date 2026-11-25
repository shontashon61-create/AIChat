import SwiftUI
import UIKit

enum RewriteAsMe {
    static func system(style: String) -> String {
        var s = "Ты переписываешь готовый ответ так, как написал бы ученик 6 класса сам. Сохрани все факты, числа, формулы и итоговый ответ без изменений. Убери канцелярит, длинные вступления и слова из интернета. Пиши коротко, обычными словами, по строкам, как в тетради. Не добавляй объяснений и не учи пользователя. Верни только переписанный текст."
        if !style.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { s += "\nПример моего стиля: " + style + "\nПиши похоже по длине предложений и словам, но не копируй ошибки из примера." }
        return s
    }
    static func user(answer: String) -> String { "Перепиши как я этот готовый ответ:\n" + answer }
}

struct CopyStepsView: View {
    let text: String
    @State private var index = 0
    var lines: [String] { text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if lines.isEmpty { Text("Вставь готовый ответ выше — покажу его по одной строке.").font(.caption).foregroundStyle(.secondary) } else {
                Text("Строка \(min(index + 1, lines.count)) из \(lines.count)").font(.caption).foregroundStyle(.secondary)
                Text(lines[min(index, lines.count - 1)]).font(.title3.bold()).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                HStack { Button("Назад") { if index > 0 { index -= 1 } }.disabled(index == 0); Button("Копировать строку") { UIPasteboard.general.string = lines[min(index, lines.count - 1)] }; Spacer(); Button(index >= lines.count - 1 ? "Готово" : "Переписал, дальше") { if index < lines.count - 1 { index += 1 } } }.font(.caption)
                Button("Сначала") { index = 0 }.font(.caption)
            }
        }
    }
}
