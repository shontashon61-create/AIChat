import Foundation
import SwiftUI
import Combine
import Security

struct MeshHomework: Identifiable, Codable, Equatable {
    var id: String
    var subject: String
    var text: String
    var date: String
    var isDigital: Bool
    var link: String
    var answer: String?
}

enum MeshKeychain {
    static func save(_ v: String) {
        let d = v.data(using: .utf8) ?? Data()
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: "mesh_aupd_token"]
        SecItemDelete(q as CFDictionary)
        var add = q; add[kSecValueData as String] = d
        SecItemAdd(add as CFDictionary, nil)
    }
    static func load() -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: "mesh_aupd_token", kSecReturnData as String: true]
        var r: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess, let d = r as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    static func delete() {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: "mesh_aupd_token"]
        SecItemDelete(q as CFDictionary)
    }
}

class MeshStore: ObservableObject {
    @Published var homeworks: [MeshHomework] = []
    @Published var lessons: [LessonItem] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var solvingStatus: String = ""
    @Published var solvingIndex: Int = 0
    @Published var studentId: String = UserDefaults.standard.string(forKey: "meshStudentId") ?? ""
    @Published var isLoggedIn = false
    init() { isLoggedIn = !(MeshKeychain.load() ?? "").isEmpty }
    var token: String? { MeshKeychain.load() }
    func saveToken(_ t: String) { MeshKeychain.save(t.trimmingCharacters(in: .whitespacesAndNewlines)); isLoggedIn = true }
    func logout() { MeshKeychain.delete(); homeworks = []; lessons = []; isLoggedIn = false }
    func saveStudentId() { UserDefaults.standard.set(studentId, forKey: "meshStudentId") }
    func fetchHomeworks() async {
        await MainActor.run { isLoading = true; error = nil }
        guard let token = token, !token.isEmpty else { await MainActor.run { error = "Сначала войди в МЭШ"; isLoading = false }; return }
        guard !studentId.trimmingCharacters(in: .whitespaces).isEmpty else { await MainActor.run { error = "Введи ID ученика"; isLoading = false }; return }
        saveStudentId()
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let from = df.string(from: Date())
        let to = df.string(from: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
        let s = "https://school.mos.ru/api/eventcalendar/v1/api/events?person_ids=\(studentId)&begin_date=\(from)&end_date=\(to)&expand=homework,marks"
        guard let url = URL(string: s) else { return }
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.setValue("aupd_token=\(token)", forHTTPHeaderField: "Cookie")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("student", forHTTPHeaderField: "profile-type")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { throw NSError(domain: "MESH", code: (resp as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: "МЭШ вернул ошибку. Токен мог устареть — войди заново."]) }
            let list = parse(data: data)
            let events = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
            let ls = ScheduleParser.lessons(from: events)
            await MainActor.run { homeworks = list; lessons = ls; isLoading = false; if list.isEmpty { error = "Заданий на неделю нет или МЭШ не отдал их по этому ID" } }
        } catch {
            await MainActor.run { error = error.localizedDescription; isLoading = false }
        }
    }
    func parse(data: Data) -> [MeshHomework] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        var out: [MeshHomework] = []
        for ev in arr {
            let subject = (ev["subject_name"] as? String) ?? (ev["subject"] as? String) ?? "Предмет"
            let date = (ev["date"] as? String) ?? (ev["begin_date"] as? String) ?? ""
            var texts: [String] = []
            var link = ""
            if let hw = ev["homework"] as? [String: Any] {
                if let ds = hw["descriptions"] as? [[String: Any]] { texts = ds.compactMap { $0["description"] as? String } }
                if let d = hw["description"] as? String { texts.append(d) }
                link = (hw["link"] as? String) ?? ""
            }
            if let hws = ev["homeworks"] as? [[String: Any]] { for h in hws { if let d = h["description"] as? String { texts.append(d) } } }
            let text = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            let id = "\(ev["id"] ?? UUID().uuidString)-\(out.count)"
            out.append(MeshHomework(id: id, subject: subject, text: text, date: date, isDigital: text.contains("ЦДЗ") || link.contains("uchebnik"), link: link, answer: nil))
        }
        return out
    }
    func solve(_ hw: MeshHomework, settings: SettingsStore) async -> String? {
        if let dup = FinalTools.duplicateAnswer(for: hw.text) { return dup }
        if hw.isDigital, !hw.link.isEmpty, let token = token, let tasks = await CDZResolver.fetch(link: hw.link, token: token), !tasks.isEmpty { return CDZResolver.format(tasks) }
        let q = "Предмет: \(hw.subject)\nЗадание:\n\(hw.text)"
        return await APIClient.complete(settings: settings, model: settings.selectedModel, system: SchoolSkills.systemPrompt(settings: settings, lastUserText: q), user: q)
    }
    func solveAll(settings: SettingsStore, minutes: Double = 10) async {
        let pending = homeworks.indices.filter { homeworks[$0].answer == nil }
        guard !pending.isEmpty else { return }
        let digitalCount = pending.filter { homeworks[$0].isDigital }.count
        let delayPerDigital = digitalCount > 0 ? minutes * 60.0 / Double(digitalCount) : 0
        for (n, i) in pending.enumerated() {
            await MainActor.run { solvingIndex = n + 1; solvingStatus = "Решаю " + String(n + 1) + " из " + String(pending.count) }
            if !homeworks[i].link.isEmpty, let cached = CDZDatabase.get(link: homeworks[i].link) { await MainActor.run { homeworks[i].answer = cached }; continue }
            if settings.humanCDZ && homeworks[i].isDigital && n > 0 && delayPerDigital > 0 { try? await Task.sleep(nanoseconds: UInt64(min(delayPerDigital, 120) * 1_000_000_000)) }
            if let a = await solve(homeworks[i], settings: settings) { await MainActor.run { homeworks[i].answer = a }; if !homeworks[i].link.isEmpty { CDZDatabase.save(link: homeworks[i].link, answer: a) } }
        }
        await MainActor.run { solvingStatus = "Готово" }
    }
    func fetchAndSolveAll(settings: SettingsStore, minutes: Double = 10) async {
        if homeworks.isEmpty { await fetchHomeworks() }
        await solveAll(settings: settings, minutes: minutes)
    }
}
