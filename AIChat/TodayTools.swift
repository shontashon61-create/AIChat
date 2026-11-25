import Foundation
import SwiftUI
import UIKit

enum TodayTools {
    static func clean(_ text: String) -> String {
        var out = text
        for tag in ["u", "ud", "dot", "wave", "dash", "circ", "hl", "box", "strike"] { out = out.replacingOccurrences(of: "[[" + tag + ":", with: "") }
        out = out.replacingOccurrences(of: "]]", with: "")
        var lines: [String] = []
        var skipping = false
        for line in out.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```scheme") || t.hasPrefix("```draw") || t.hasPrefix("```free") || t.hasPrefix("```diagram") { skipping = true; continue }
            if skipping && t.hasPrefix("```") { skipping = false; continue }
            if !skipping { lines.append(line) }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func redoPrompt(number: String, answer: String) -> String { return "Переделай только задание №" + number + ". Остальные задания не трогай. Верни только исправленное задание №" + number + ". Текущий ответ:\n" + answer }
    static func renumber(_ lines: [String]) -> String { return lines.enumerated().map { "№" + String($0.offset + 1) + ". " + $0.element }.joined(separator: "\n") }
    static func tableCells(_ text: String) -> [String] { return text.components(separatedBy: "\n").filter { $0.contains("|") && !$0.contains("---") }.flatMap { $0.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } } }
    static func notebookOCRPrompt() -> String { return "Перепиши фото рукописной тетради в чистый печатный текст по строкам, сохраняя все числа и формулы. Нечитаемое по правилу 90%: Непонятно именно это задание, укажи строку." }
    static func todayText(items: [ArchiveItem]) -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; let today = f.string(from: Date()); let todays = items.filter { $0.date == today }; let use = todays.isEmpty ? items : todays; return use.map { $0.subject + "\n" + $0.answer }.joined(separator: "\n\n") }
    static func searchArchive(query: String, items: [ArchiveItem]) -> [ArchiveItem] { let q = query.lowercased(); if q.isEmpty { return items }; return items.filter { $0.subject.lowercased().contains(q) || $0.text.lowercased().contains(q) || $0.answer.lowercased().contains(q) } }
    static func folder(for text: String) -> String { return SchoolSkills.detectSubject(text: text) }
    static func grouped(_ items: [ArchiveItem]) -> [String: [ArchiveItem]] { return Dictionary(grouping: items, by: { $0.subject }) }
    static func cdzHistoryText(total: Int, solved: Int) -> String { return "19. ЦДЗ решено через базу: " + String(solved) + ", осталось: " + String(max(total - solved, 0)) }
}
