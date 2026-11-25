import Foundation

struct CDZTask: Identifiable {
    var id = UUID()
    var question: String
    var answer: String
    var type: String
}

enum CDZResolver {
    static func context(from link: String) -> (String, String)? {
        let markers: [(String, String)] = [("test_by_binding/", "homework"), ("training_spec/", "spec"), ("selftest/spec/", "spec")]
        for (marker, ctx) in markers {
            if let r = link.range(of: marker) {
                let rest = String(link[r.upperBound...])
                let id = rest.components(separatedBy: CharacterSet(charactersIn: "/?&#")).first ?? ""
                if !id.isEmpty { return (ctx, id) }
            }
        }
        return nil
    }
    static func fetch(link: String, token: String) async -> [CDZTask]? {
        guard let (ctx, gid) = context(from: link) else { return nil }
        guard let url = URL(string: "https://uchebnik.mos.ru/exam/rest/secure/testplayer/generate") else { return nil }
        let payload: [String: String] = ["test_type": "training_test", "generation_context_type": ctx, "generation_by_id": gid]
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("aupd_token=\(token)", forHTTPHeaderField: "Cookie")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        guard let (data, resp) = try? await URLSession.shared.data(for: req), let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return parse(data: data)
    }
    static func parse(data: Data) -> [CDZTask]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let rawTasks = (root["training_tasks"] as? [[String: Any]]) ?? (root["tasks"] as? [[String: Any]]) ?? []
        var out: [CDZTask] = []
        for item in rawTasks {
            let task = (item["test_task"] as? [String: Any]) ?? item
            var question = ""
            if let elements = task["question_elements"] as? [[String: Any]], let first = elements.first, let text = first["text"] as? String { question = text }
            if question.isEmpty { question = (task["question"] as? String) ?? "Задание" }
            guard let answer = task["answer"] as? [String: Any], let right = answer["right_answer"] as? [String: Any] else { continue }
            let type = (answer["type"] as? String) ?? ""
            var value = ""
            if let n = right["number"] { value = String(describing: n) }
            if let s = right["string"] as? String, !s.isEmpty { value = s }
            if value.isEmpty, let ids = right["id"] as? [String], let options = task["options"] as? [[String: Any]] {
                value = options.filter { ids.contains(($0["id"] as? String) ?? "") }.compactMap { $0["text"] as? String }.joined(separator: ", ")
            }
            if value.isEmpty, let single = right["id"] as? String, let options = task["options"] as? [[String: Any]] {
                value = options.first(where: { ($0["id"] as? String) == single })?["text"] as? String ?? ""
            }
            if !value.isEmpty { out.append(CDZTask(question: question, answer: value, type: type)) }
        }
        return out.isEmpty ? nil : out
    }
    static func format(_ tasks: [CDZTask]) -> String {
        tasks.enumerated().map { "\($0.offset + 1). \($0.element.question)\nОтвет: \($0.element.answer)" }.joined(separator: "\n\n")
    }
}
