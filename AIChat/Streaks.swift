import Foundation

enum Streaks {
    static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    static func markDone() -> Int {
        let d = UserDefaults.standard
        if d.string(forKey: "streakLast") == todayString() { return d.integer(forKey: "streakCount") }
        let n = d.integer(forKey: "streakCount") + 1
        d.set(n, forKey: "streakCount")
        d.set(todayString(), forKey: "streakLast")
        return n
    }
    static func message(_ n: Int) -> String {
        if n >= 7 { return "Стрик 7+ дней — легенда" }
        if n >= 3 { return "Стрик 3 дня — так держать" }
        return "Стрик 1 день — начало"
    }
}
