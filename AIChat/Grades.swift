import Foundation

struct GradeEntry: Identifiable, Codable {
    var id = UUID()
    var subject: String
    var value: Int
    var date = Date()
}

enum Grades {
    static func average(_ grades: [Int]) -> Double {
        guard !grades.isEmpty else { return 0 }
        return Double(grades.reduce(0, +)) / Double(grades.count)
    }
    static func forecast(_ grades: [Int]) -> String {
        let avg = average(grades)
        if avg >= 4.5 { return "Прогноз: 5" }
        if avg >= 3.5 { return "Прогноз: 4" }
        if avg >= 2.5 { return "Прогноз: 3" }
        return "Прогноз: 2"
    }
    static func neededFor(_ grades: [Int], target: Double) -> Int {
        var g = grades
        var n = 0
        while average(g) < target && n < 10 { g.append(5); n += 1 }
        return n
    }
}
