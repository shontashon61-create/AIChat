import Foundation

enum FractionCalc {
    static func gcd(_ a: Int, _ b: Int) -> Int { var x = abs(a); var y = abs(b); while y != 0 { let r = x % y; x = y; y = r }; return max(x, 1) }
    static func simplify(_ n: Int, _ d: Int) -> String { let g = gcd(n, d); if d / g == 1 { return "\(n / g)" }; return "\(n / g)/\(d / g)" }
    static func add(_ a: Int, _ b: Int, _ c: Int, _ d: Int) -> String {
        let lcm = b * d / gcd(b, d)
        let n1 = a * (lcm / b); let n2 = c * (lcm / d)
        return "\(a)/\(b) + \(c)/\(d)\nОбщий знаменатель: \(lcm)\n= \(n1)/\(lcm) + \(n2)/\(lcm)\n= \(n1 + n2)/\(lcm)\nСокращаем: \(simplify(n1 + n2, lcm))"
    }
    static func multiply(_ a: Int, _ b: Int, _ c: Int, _ d: Int) -> String {
        return "\(a)/\(b) × \(c)/\(d)\n= (\(a) × \(c)) / (\(b) × \(d))\n= \(a * c)/\(b * d)\nСокращаем: \(simplify(a * c, b * d))"
    }
    static func percent(of number: Double, p: Double) -> String {
        let result = number * p / 100
        return "\(Int(p))% от \(Int(number))\nВ столбик: \(Int(number)) × \(Int(p)) = \(Int(number * p))\nДелим на 100: \(Int(number * p)) / 100 = \(result)\nОтвет: \(result)"
    }
    static func percentPrompt() -> String { "Проценты считай по шагам, как в тетради: сначала число умножить на процент в столбик, потом разделить на 100. Не пиши результат сразу из ума." }
}
