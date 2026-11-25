import Foundation

enum CDZDatabase {
    static let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("cdz_base.json")
    static func load() -> [String: String] {
        guard let d = try? Data(contentsOf: fileURL), let v = try? JSONDecoder().decode([String: String].self, from: d) else { return [:] }
        return v
    }
    static func save(link: String, answer: String) {
        var base = load()
        base[link] = answer
        try? JSONEncoder().encode(base).write(to: fileURL, options: .atomic)
    }
    static func get(link: String) -> String? { load()[link] }
}

enum HumanMode {
    static func delay() -> UInt64 {
        let s = Double.random(in: 8...25)
        return UInt64(s * 1_000_000_000)
    }
}

enum OfflineCache {
    static func saveAnswer(_ text: String, for key: String) {
        UserDefaults.standard.set(text, forKey: "offline_" + key)
    }
    static func loadAnswer(for key: String) -> String? {
        UserDefaults.standard.string(forKey: "offline_" + key)
    }
}
