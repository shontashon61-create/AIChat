import SwiftUI
import UIKit

enum QuickTools {
    static func photoAnswersPrompt() -> String { return "По фото страницы с пропусками: перепиши весь текст по порядку, на месте каждого пропуска впиши ответ и обведи его тегом box. Нечитаемое по правилу 90 процентов пиши ровно: Непонятно именно это задание." }
    static func countdown(hours: Double) -> String { if hours <= 0 { return "Срок вышел" }; if hours >= 24 { return "Осталось " + String(Int(hours / 24)) + " дн." }; return "Осталось " + String(Int(hours)) + " ч" }
    static func urgency(hours: Double) -> String { if hours <= 0 { return "Просрочено" }; if hours < 3 { return "Срочно, делать сейчас" }; if hours < 24 { return "Сегодня" }; return "Есть время" }
    static func minutes(subject: String, text: String) -> Int { let words = text.split(separator: " ").count; var base = 10; if subject.contains("Математика") { base = 15 }; if subject.contains("Русский") { base = 12 }; return base + words / 20 }
    static func totalMinutes(items: [(String, String)]) -> Int { items.reduce(0) { $0 + minutes(subject: $1.0, text: $1.1) } }
    static func pdfFromImages(images: [UIImage]) -> URL? { let url = FileManager.default.temporaryDirectory.appendingPathComponent("textbook.pdf"); let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)); do { try renderer.writePDF(to: url) { ctx in for img in images { ctx.beginPage(); img.draw(in: CGRect(x: 36, y: 36, width: 523, height: 770)) } }; return url } catch { return nil } }
    static func noPalevoPrompt(text: String) -> String { return "Проверь текст без палева для 6 класса. Замени слишком умные и взрослые слова на простые, укороти длинные предложения, сохрани все факты, числа, формулы и итоговый ответ. Верни только исправленный текст, без объяснений. Текст: " + text }
    static func simplePrompt(text: String) -> String { return "Перепиши условие задания простыми словами для 6 класса, по пунктам: что дано, что нужно найти. Само задание не решай. Условие: " + text }
}
