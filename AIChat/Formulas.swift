import Foundation

struct FormulaItem: Identifiable {
    let id = UUID()
    let subject: String
    let title: String
    let formula: String
    let example: String
}

enum Formulas {
    static let all: [FormulaItem] = [
        FormulaItem(subject: "Математика", title: "Площадь прямоугольника", formula: "S = a × b", example: "a = 5, b = 3, S = 15"),
        FormulaItem(subject: "Математика", title: "Периметр прямоугольника", formula: "P = 2 × (a + b)", example: "a = 5, b = 3, P = 16"),
        FormulaItem(subject: "Математика", title: "Объём параллелепипеда", formula: "V = a × b × c", example: "2 × 3 × 4 = 24"),
        FormulaItem(subject: "Физика", title: "Скорость", formula: "v = s / t", example: "s = 120 км, t = 2 ч, v = 60 км/ч"),
        FormulaItem(subject: "Математика", title: "Процент от числа", formula: "часть = число × процент / 100", example: "20% от 50 = 10")
    ]
    static func search(_ q: String) -> [FormulaItem] {
        let t = q.lowercased()
        if t.isEmpty { return all }
        return all.filter { $0.title.lowercased().contains(t) || $0.formula.lowercased().contains(t) || $0.subject.lowercased().contains(t) }
    }
}
