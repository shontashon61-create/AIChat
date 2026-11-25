import Foundation

enum ColumnMath {
    static func multiply(_ a: Int, _ b: Int) -> String {
        let digits = String(b).reversed().map { Int(String($0)) ?? 0 }
        var partials: [Int] = []
        for d in digits { partials.append(a * d) }
        var lines: [String] = []
        lines.append("   \(a)")
        lines.append("x  \(b)")
        lines.append("------")
        for (i, p) in partials.enumerated() {
            let shift = String(repeating: " ", count: i)
            lines.append(shift + "\(p)   \(a) × \(digits[i])")
        }
        lines.append("--------")
        lines.append("\(a * b)")
        return lines.joined(separator: "\n")
    }
}
